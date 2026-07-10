variable "url" {
  description = "Target URL to scan (e.g. https://example.com or http://localhost:3000)"
  type        = string
}

variable "js_recon_version" {
  description = "JS Recon version to install — passed to npm install -g @shriyanss/js-recon@<version> (e.g. latest, alpha, 1.3.1-beta.1)"
  type        = string
  default     = "latest"
}

variable "break_on_map_files" {
  description = "Fail the build if .map source map files are detected in the output"
  type        = bool
  default     = true
}

variable "break_on_vulnerabilities" {
  description = "Fail the build if vulnerabilities at or above the configured severity are detected"
  type        = bool
  default     = true
}

variable "vulnerability_severity" {
  description = "Minimum severity to fail on: low, medium, or high"
  type        = string
  default     = "high"

  validation {
    condition     = contains(["low", "medium", "high"], var.vulnerability_severity)
    error_message = "vulnerability_severity must be one of: low, medium, high"
  }
}

variable "output_dir" {
  description = "Directory inside the CodeBuild workspace where JS Recon output files are saved"
  type        = string
  default     = "js-recon-output"
}

variable "project_name" {
  description = "Name prefix for all AWS resources created by this module"
  type        = string
  default     = "js-recon"
}

variable "create_s3_bucket" {
  description = "Whether to create an S3 bucket for storing JS Recon output artifacts"
  type        = bool
  default     = true
}

variable "s3_bucket_name" {
  description = "Name for the S3 artifact bucket. Auto-generated if empty (requires create_s3_bucket = true)"
  type        = string
  default     = ""
}

variable "s3_artifact_prefix" {
  description = "S3 key prefix under which JS Recon artifacts are uploaded"
  type        = string
  default     = "js-recon-output"
}

variable "schedule_expression" {
  description = "CloudWatch Events schedule expression for automated scans (e.g. rate(1 day) or cron(0 8 * * ? *)). Leave empty to disable scheduling."
  type        = string
  default     = ""
}

variable "build_timeout" {
  description = "Maximum duration in minutes for a single CodeBuild scan job"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all AWS resources created by this module"
  type        = map(string)
  default     = {}
}
