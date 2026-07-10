output "codebuild_project_name" {
  description = "Name of the JS Recon CodeBuild project"
  value       = aws_codebuild_project.js_recon.name
}

output "codebuild_project_arn" {
  description = "ARN of the JS Recon CodeBuild project"
  value       = aws_codebuild_project.js_recon.arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket where JS Recon artifacts are stored"
  value       = var.create_s3_bucket ? aws_s3_bucket.artifacts[0].bucket : var.s3_bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 artifact bucket"
  value       = var.create_s3_bucket ? aws_s3_bucket.artifacts[0].arn : null
}

output "iam_role_arn" {
  description = "ARN of the IAM role assumed by CodeBuild"
  value       = aws_iam_role.codebuild.arn
}
