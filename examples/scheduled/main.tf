provider "aws" {
  region = "us-east-1"
}

module "js_recon" {
  source = "../../"

  url                 = "https://example.com"
  schedule_expression = "rate(1 day)"

  break_on_map_files       = true
  break_on_vulnerabilities = true
  vulnerability_severity   = "high"

  tags = {
    Team = "security"
  }
}

output "codebuild_project_name" {
  value = module.js_recon.codebuild_project_name
}

output "s3_bucket_name" {
  value = module.js_recon.s3_bucket_name
}
