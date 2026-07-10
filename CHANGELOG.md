# Changelog

## 1.0.1 — Unreleased

## 1.0.0 — 2026-07-10

Initial release.

- AWS CodeBuild project that runs JS Recon against any URL
- Optional S3 bucket for artifact storage with server-side encryption
- Optional CloudWatch Events schedule for automated scans
- Inputs mirroring the GitHub Action and GitLab CI component: `url`, `version`, `break_on_map_files`, `break_on_vulnerabilities`, `vulnerability_severity`, `output_dir`
- Outputs: `codebuild_project_name`, `codebuild_project_arn`, `s3_bucket_name`, `s3_bucket_arn`, `iam_role_arn`
- Examples: `basic/` (on-demand) and `scheduled/` (daily cron)
