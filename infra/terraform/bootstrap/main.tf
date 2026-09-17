# One-time bootstrap: creates the S3 bucket + DynamoDB lock table that the
# root module's "s3" backend uses for remote state. This stack keeps its own
# local state (chicken-and-egg problem for a remote-state backend) — that
# local .tfstate is gitignored, and the resulting bucket/table names are
# recorded in docs/RUNBOOK.md since they aren't secret.

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  bucket_name = "${var.project}-tfstate-${random_id.suffix.hex}"
  table_name  = "${var.project}-tf-locks"
}

resource "aws_s3_bucket" "state" {
  bucket        = local.bucket_name
  force_destroy = true # capstone infra: allow tearing this down with the rest

  tags = {
    Project = var.project
    Purpose = "terraform-remote-state"
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "locks" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST" # free-tier friendly: no idle capacity cost
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Project = var.project
    Purpose = "terraform-state-lock"
  }
}
