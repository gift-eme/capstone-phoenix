# Partial backend config — the bucket/table are account-specific (created by
# ../bootstrap) and never hardcoded here. Run:
#   terraform init -backend-config=backend.hcl
# with your own backend.hcl (gitignored; copy backend.hcl.example).
terraform {
  backend "s3" {}
}
