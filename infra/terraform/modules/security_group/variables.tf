variable "project" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "admin_cidrs" {
  description = "CIDR blocks allowed to SSH (22) and reach the k8s API (6443)"
  type        = list(string)
}
