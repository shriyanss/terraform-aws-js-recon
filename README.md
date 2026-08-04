<h1 align="center">JS Recon — Terraform AWS Module</h1>

<p align="center">
  Provision an AWS CodeBuild project that runs <a href="https://js-recon.io">JS Recon</a> against any URL.
  Surface exposed endpoints, client-side vulnerabilities, and leaked source maps automatically.
</p>

<p align="center">
  <a href="https://score.getplumber.io/github.com/js-recon/terraform-aws-js-recon">
    <img src="https://score.getplumber.io/github.com/js-recon/terraform-aws-js-recon.svg" alt="Plumber Score">
  </a>
</p>

---

## Quick start

```hcl
module "js_recon" {
  source  = "js-recon/js-recon/aws"
  version = "~> 1.0"

  url = "https://example.com"
}
```

Apply, then trigger a scan:

```bash
aws codebuild start-build --project-name js-recon
```

---

## Scanning a localhost app

To scan an app running inside the CodeBuild environment, override `JSR_START_CMD` and `JSR_WORKING_DIR` at build time:

```bash
aws codebuild start-build \
  --project-name js-recon \
  --environment-variables-override \
    name=JSR_URL,value=http://localhost:3000,type=PLAINTEXT \
    name=JSR_START_CMD,value="npm start",type=PLAINTEXT \
    name=JSR_WORKING_DIR,value=".",type=PLAINTEXT
```

The build waits up to 120 seconds for the URL to respond before scanning.

---

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `url` | Yes | — | Target URL to scan (external or `http://localhost:PORT`) |
| `js_recon_version` | No | `latest` | JS Recon version (`latest`, `alpha`, `1.3.1-beta.1`, …) |
| `break_on_map_files` | No | `true` | Fail if `.map` source map files are detected |
| `break_on_vulnerabilities` | No | `true` | Fail if findings at or above the threshold are detected |
| `vulnerability_severity` | No | `high` | Minimum severity to fail on: `low`, `medium`, or `high` |
| `output_dir` | No | `js-recon-output` | Directory to save output files inside the build |
| `project_name` | No | `js-recon` | Name prefix for all AWS resources |
| `create_s3_bucket` | No | `true` | Whether the module creates an S3 bucket for artifacts |
| `s3_bucket_name` | No | _(auto-generated)_ | Explicit S3 bucket name |
| `s3_artifact_prefix` | No | `js-recon-output` | S3 key prefix for uploaded artifacts |
| `schedule_expression` | No | `""` | CloudWatch Events expression (e.g. `rate(1 day)`). Empty = no schedule. |
| `build_timeout` | No | `30` | Maximum build duration in minutes |
| `tags` | No | `{}` | Tags applied to all AWS resources |

## Outputs

| Name | Description |
|---|---|
| `codebuild_project_name` | Name of the CodeBuild project |
| `codebuild_project_arn` | ARN of the CodeBuild project |
| `s3_bucket_name` | Name of the S3 artifact bucket |
| `s3_bucket_arn` | ARN of the S3 artifact bucket |
| `iam_role_arn` | ARN of the CodeBuild IAM role |

---

## Output files

JS Recon writes the following files inside `<output_dir>/<host>/` and uploads them to S3:

| File | Description |
|---|---|
| `analyze.json` | All vulnerability findings |
| `mapped.json` | Parsed bundle structure |
| `mapped-openapi.json` | Extracted HTTP endpoints (OpenAPI format) |
| `endpoints.json` | Client-side routes |
| `strings.json` | Extracted strings, URLs, and secrets |
| `report.html` | Full HTML report |
| `js-recon.db` | SQLite database of all findings |

Artifacts land at `s3://<bucket>/<s3_artifact_prefix>/`.

---

## Break conditions

### Source maps

By default, the build fails if `.map` source map files are publicly accessible:

```hcl
module "js_recon" {
  source = "js-recon/js-recon/aws"

  url                = "https://example.com"
  break_on_map_files = true # default
}
```

To disable: `break_on_map_files = false`.

### Vulnerabilities

Control which severity level triggers a failure:

```hcl
module "js_recon" {
  source = "js-recon/js-recon/aws"

  url                      = "https://example.com"
  break_on_vulnerabilities = true
  vulnerability_severity   = "medium" # fail on medium or high
}
```

Available: `low`, `medium`, `high` (default: `high`).

---

## Scheduled scans

Run JS Recon automatically on a CloudWatch Events schedule:

```hcl
module "js_recon" {
  source = "js-recon/js-recon/aws"

  url                 = "https://example.com"
  schedule_expression = "rate(1 day)"
}
```

Standard [CloudWatch Events schedule expressions](https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html) are supported: `rate(...)` and `cron(...)`.

---

## Triggering a scan manually

```bash
# Start a scan with default configuration
aws codebuild start-build --project-name js-recon

# Override the target URL at build time
aws codebuild start-build \
  --project-name js-recon \
  --environment-variables-override name=JSR_URL,value=https://other.example.com,type=PLAINTEXT

# Wait for the build to complete and print its status
BUILD_ID=$(aws codebuild start-build --project-name js-recon --query 'build.id' --output text)
aws codebuild wait build-complete --ids "$BUILD_ID"
aws codebuild batch-get-builds --ids "$BUILD_ID" --query 'builds[0].buildStatus' --output text
```

---

## Pinning to a specific JS Recon version

```hcl
module "js_recon" {
  source = "js-recon/js-recon/aws"

  url              = "https://example.com"
  js_recon_version = "1.3.1"
}
```

Use `alpha` to track the latest pre-release.

---

## Examples

- [`examples/basic/`](examples/basic/) — minimal on-demand scan
- [`examples/scheduled/`](examples/scheduled/) — daily automated scan via EventBridge

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

---

## License

MIT — see [LICENSE](LICENSE).
