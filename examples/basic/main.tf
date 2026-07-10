provider "aws" {
  region = "us-east-1"
}

module "js_recon" {
  source = "../../"

  url = "https://example.com"
}

output "codebuild_project_name" {
  value = module.js_recon.codebuild_project_name
}

output "s3_bucket_name" {
  value = module.js_recon.s3_bucket_name
}
