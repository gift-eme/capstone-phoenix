output "state_bucket_name" {
  description = "S3 bucket holding the root module's remote state"
  value       = aws_s3_bucket.state.bucket
}

output "lock_table_name" {
  description = "DynamoDB table used for state locking"
  value       = aws_dynamodb_table.locks.name
}

output "region" {
  value = var.region
}
