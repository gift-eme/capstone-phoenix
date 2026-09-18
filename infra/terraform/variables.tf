variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "project" {
  description = "Name prefix for all resources"
  type        = string
  default     = "taskapp-phoenix"
}

variable "admin_cidrs" {
  description = "CIDR blocks allowed to SSH (22) and reach the k8s API (6443). No default — set in terraform.tfvars."
  type        = list(string)
}

variable "server_instance_type" {
  description = "Control-plane instance type — sized larger than workers since it's the single point of failure running the k3s server, API server, and embedded datastore"
  type        = string
  default     = "t3.micro"
}

variable "worker_instance_type" {
  description = "Free-tier-eligible instance type for eu-north-1"
  type        = string
  default     = "t3.micro"
}

variable "vpc_cidr" {
  type    = string
  default = "10.60.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.60.1.0/24"
}

variable "availability_zone" {
  type    = string
  default = "eu-north-1a"
}

variable "worker_count" {
  description = "Number of k3s agent nodes"
  type        = number
  default     = 3
}

variable "key_name" {
  description = "AWS key pair name to create"
  type        = string
  default     = "taskapp-phoenix-key"
}

variable "public_key_path" {
  description = "Path to the SSH public key to install on every node"
  type        = string
  default     = "./taskappkey-created.pub"
}

variable "root_volume_size" {
  description = "Root EBS volume size (GB) per node"
  type        = number
  default     = 8
}
