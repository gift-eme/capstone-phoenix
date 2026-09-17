variable "region" {
  description = "AWS region for the remote state backend"
  type        = string
  default     = "eu-north-1"
}

variable "project" {
  description = "Project prefix used to name the state bucket and lock table"
  type        = string
  default     = "taskapp-phoenix"
}
