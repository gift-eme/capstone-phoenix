variable "project" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "server_instance_type" {
  type = string
}

variable "worker_instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "key_name" {
  type = string
}

variable "public_key_path" {
  type = string
}

variable "worker_count" {
  type = number
}

variable "root_volume_size" {
  type = number
}
