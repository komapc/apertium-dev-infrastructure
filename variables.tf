variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-west-1"
}

variable "create_s3_bucket" {
  description = "Create S3 bucket for extractor results"
  type        = bool
  default     = true
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "ido-epo-translator"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"

  validation {
    condition     = can(regex("^t3\\.(nano|micro|small|medium|large|xlarge)$", var.instance_type))
    error_message = "Instance type must be a valid t3 instance type (nano, micro, small, medium, large, xlarge)."
  }
}

variable "disk_size" {
  description = "Root disk size in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.disk_size >= 20
    error_message = "Disk size must be at least 20GB."
  }
}

variable "ssh_ip" {
  description = "Your IP address for SSH access (CIDR notation)"
  type        = string

  validation {
    condition     = can(cidrhost(var.ssh_ip, 0))
    error_message = "SSH IP must be a valid CIDR block (e.g., 192.168.1.1/32)."
  }
}

variable "ssh_public_key_path" {
  description = "Path to your SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_path" {
  description = "Path to your SSH private key file"
  type        = string
  default     = "~/.ssh/id_rsa"
}

