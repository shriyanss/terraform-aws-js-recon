locals {
  bucket_name = var.s3_bucket_name != "" ? var.s3_bucket_name : "${var.project_name}-artifacts-${random_id.bucket_suffix[0].hex}"
}

resource "random_id" "bucket_suffix" {
  count       = var.create_s3_bucket && var.s3_bucket_name == "" ? 1 : 0
  byte_length = 4
}

# ─── S3 artifact bucket ───────────────────────────────────────────────────────

resource "aws_s3_bucket" "artifacts" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = local.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.artifacts[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.artifacts[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─── IAM role for CodeBuild ───────────────────────────────────────────────────

data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codebuild_policy" {
  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "S3Artifacts"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = var.create_s3_bucket ? [
      aws_s3_bucket.artifacts[0].arn,
      "${aws_s3_bucket.artifacts[0].arn}/*",
      ] : [
      "arn:aws:s3:::${var.s3_bucket_name}",
      "arn:aws:s3:::${var.s3_bucket_name}/*",
    ]
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "${var.project_name}-codebuild"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "${var.project_name}-codebuild"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild_policy.json
}

# ─── CloudWatch log group ─────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "js_recon" {
  name              = "/aws/codebuild/${var.project_name}"
  retention_in_days = 30
  tags              = var.tags
}

# ─── CodeBuild project ────────────────────────────────────────────────────────

resource "aws_codebuild_project" "js_recon" {
  name          = var.project_name
  description   = "JS Recon — JavaScript bundle security scanner"
  build_timeout = var.build_timeout
  service_role  = aws_iam_role.codebuild.arn
  tags          = var.tags

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "ghcr.io/puppeteer/puppeteer:24.43.1"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "SERVICE_ROLE"

    environment_variable {
      name  = "JSR_URL"
      value = var.url
    }

    environment_variable {
      name  = "JSR_VERSION"
      value = var.version
    }

    environment_variable {
      name  = "JSR_BREAK_ON_MAP"
      value = tostring(var.break_on_map_files)
    }

    environment_variable {
      name  = "JSR_BREAK_ON_VULNS"
      value = tostring(var.break_on_vulnerabilities)
    }

    environment_variable {
      name  = "JSR_SEVERITY"
      value = var.vulnerability_severity
    }

    environment_variable {
      name  = "JSR_OUTPUT_DIR"
      value = var.output_dir
    }

    environment_variable {
      name  = "JSR_S3_BUCKET"
      value = var.create_s3_bucket ? aws_s3_bucket.artifacts[0].bucket : var.s3_bucket_name
    }

    environment_variable {
      name  = "JSR_S3_PREFIX"
      value = var.s3_artifact_prefix
    }

    environment_variable {
      name  = "PUPPETEER_SKIP_DOWNLOAD"
      value = "true"
    }

    environment_variable {
      name  = "IS_DOCKER"
      value = "true"
    }

    environment_variable {
      name  = "NODE_OPTIONS"
      value = "--max-http-header-size=99999999"
    }

    environment_variable {
      name  = "PUPPETEER_CACHE_DIR"
      value = "/home/pptruser/.cache/puppeteer"
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.js_recon.name
      stream_name = "build"
    }
  }

  buildspec = <<-BUILDSPEC
    version: 0.2

    phases:
      install:
        commands:
          - npm config set prefix /home/pptruser/.npm-global
          - export PATH="/home/pptruser/.npm-global/bin:$PATH"
          - echo "[js-recon] Installing @shriyanss/js-recon@$${JSR_VERSION}..."
          - npm install -g "@shriyanss/js-recon@$${JSR_VERSION}"
          - INSTALLED_VERSION=$(js-recon --version 2>/dev/null || echo "unknown")
          - echo "[js-recon] Installed version: $${INSTALLED_VERSION}"

      build:
        commands:
          - export PATH="/home/pptruser/.npm-global/bin:$PATH"
          - |
            if [ -n "$${JSR_START_CMD:-}" ]; then
              echo "[js-recon] Starting app with: $${JSR_START_CMD}"
              cd "$${JSR_WORKING_DIR:-.}"
              eval "$${JSR_START_CMD}" &
              cd -
              echo "[js-recon] Waiting for $${JSR_URL} to be ready..."
              curl \
                --silent \
                --output /dev/null \
                --retry 30 \
                --retry-connrefused \
                --retry-delay 2 \
                --retry-max-time 120 \
                "$${JSR_URL}" || {
                echo "[js-recon] ERROR: Timed out waiting for $${JSR_URL}"
                exit 1
              }
              echo "[js-recon] App is ready."
            fi
          - echo "[js-recon] Running js-recon against $${JSR_URL}..."
          - js-recon run -u "$${JSR_URL}" -o "$${JSR_OUTPUT_DIR}" --no-sandbox -y -k || { echo "[js-recon] ERROR: js-recon run failed."; exit 1; }
          - echo "[js-recon] Scan complete."
          - HOST_DIR=$(echo "$${JSR_URL}" | sed 's|https\?://||' | sed 's|[/?].*||' | tr ':' '_')
          - mkdir -p "$${JSR_OUTPUT_DIR}/$${HOST_DIR}"
          - |
            for f in analyze.json mapped.json mapped-openapi.json endpoints.json strings.json report.html report.db js-recon.db; do
              [ -f "$f" ] && mv "$f" "$${JSR_OUTPUT_DIR}/$${HOST_DIR}/" 2>/dev/null || true
            done
          - |
            MAP_FILES=$(find "$${JSR_OUTPUT_DIR}" -name "*.map" 2>/dev/null | head -50)
            if [ -n "$${MAP_FILES}" ]; then
              echo "[js-recon] Source map files detected:"
              echo "$${MAP_FILES}"
              if [ "$${JSR_BREAK_ON_MAP}" = "true" ]; then
                echo "[js-recon] ERROR: Source map files are publicly accessible. Set break_on_map_files = false to suppress."
                exit 1
              fi
            fi
          - |
            ANALYZE_JSON=$(find "$${JSR_OUTPUT_DIR}" -name "analyze.json" 2>/dev/null | head -1)
            if [ -n "$${ANALYZE_JSON}" ] && [ "$${JSR_BREAK_ON_VULNS}" = "true" ]; then
              node -e "
            const fs = require('fs');
            const RANK = {info: 0, low: 1, medium: 2, high: 3};
            let findings = [];
            try { findings = JSON.parse(fs.readFileSync(process.argv[1], 'utf8')); } catch {
              console.log('[js-recon] analyze.json is empty or invalid. Skipping.');
              process.exit(0);
            }
            if (!Array.isArray(findings) || findings.length === 0) {
              console.log('[js-recon] No findings in analyze.json.');
              process.exit(0);
            }
            const severity = process.argv[2];
            const threshold = RANK[severity] ?? 3;
            const matched = findings.filter(f => (RANK[f.severity?.toLowerCase()] ?? -1) >= threshold);
            if (matched.length === 0) {
              console.log('[js-recon] No findings at or above severity \"' + severity + '\".');
              process.exit(0);
            }
            console.log('[js-recon] ' + matched.length + ' finding(s) at or above severity \"' + severity + '\":\n');
            console.log('Rule'.padEnd(40) + ' ' + 'Severity'.padEnd(10) + ' Location');
            console.log('-'.repeat(80));
            for (const f of matched) {
              const rule = (f.ruleName || f.ruleId || 'unknown').substring(0, 39).padEnd(40);
              const sev  = (f.severity || '?').padEnd(10);
              const loc  = f.findingLocation || '';
              console.log(rule + ' ' + sev + ' ' + loc);
            }
            console.log('\n[js-recon] ERROR: ' + matched.length + ' vulnerability/vulnerabilities at severity \"' + severity + '\" or above.');
            process.exit(matched.length > 255 ? 255 : matched.length);
              " "$${ANALYZE_JSON}" "$${JSR_SEVERITY}" || exit 1
            fi
          - |
            if [ -n "$${JSR_S3_BUCKET}" ]; then
              echo "[js-recon] Uploading artifacts to s3://$${JSR_S3_BUCKET}/$${JSR_S3_PREFIX}/"
              aws s3 sync "$${JSR_OUTPUT_DIR}/" "s3://$${JSR_S3_BUCKET}/$${JSR_S3_PREFIX}/"
              echo "[js-recon] Artifacts uploaded."
            fi
  BUILDSPEC
}

# ─── Optional EventBridge schedule ───────────────────────────────────────────

data "aws_iam_policy_document" "events_assume" {
  count = var.schedule_expression != "" ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "events_policy" {
  count = var.schedule_expression != "" ? 1 : 0

  statement {
    sid     = "StartBuild"
    effect  = "Allow"
    actions = ["codebuild:StartBuild"]
    resources = [
      aws_codebuild_project.js_recon.arn,
    ]
  }
}

resource "aws_iam_role" "events" {
  count              = var.schedule_expression != "" ? 1 : 0
  name               = "${var.project_name}-events"
  assume_role_policy = data.aws_iam_policy_document.events_assume[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy" "events" {
  count  = var.schedule_expression != "" ? 1 : 0
  name   = "${var.project_name}-events"
  role   = aws_iam_role.events[0].id
  policy = data.aws_iam_policy_document.events_policy[0].json
}

resource "aws_cloudwatch_event_rule" "schedule" {
  count               = var.schedule_expression != "" ? 1 : 0
  name                = "${var.project_name}-schedule"
  description         = "Trigger JS Recon scan on schedule"
  schedule_expression = var.schedule_expression
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "schedule" {
  count     = var.schedule_expression != "" ? 1 : 0
  rule      = aws_cloudwatch_event_rule.schedule[0].name
  target_id = "js-recon"
  arn       = aws_codebuild_project.js_recon.arn
  role_arn  = aws_iam_role.events[0].arn
}
