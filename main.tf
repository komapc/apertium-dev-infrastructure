terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source for Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC (optional - uses default VPC if not specified)
data "aws_vpc" "default" {
  default = true
}

# Security Group for APy Server
resource "aws_security_group" "apy_server" {
  name        = "${var.project_name}-apy-server-sg"
  description = "Security group for Ido-Esperanto APy translation server"
  vpc_id      = data.aws_vpc.default.id

  # SSH access from your IP
  ingress {
    description = "SSH from specified IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_ip]
  }

  # HTTP access from anywhere (Cloudflare Worker will connect here)
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Optional: Direct APy access on port 2737 (can be restricted)
  ingress {
    description = "APy server port (optional, can be restricted)"
    from_port   = 2737
    to_port     = 2737
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound internet access
  egress {
    description = "Outbound internet access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-apy-server-sg"
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# Key pair for SSH access
resource "aws_key_pair" "apy_server" {
  key_name   = "${var.project_name}-key"
  public_key = file(var.ssh_public_key_path)

  tags = {
    Name      = "${var.project_name}-key"
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# EC2 Instance
resource "aws_instance" "apy_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  
  key_name               = aws_key_pair.apy_server.key_name
  vpc_security_group_ids = [aws_security_group.apy_server.id]

  # Root volume configuration
  root_block_device {
    volume_type = "gp3"
    volume_size = var.disk_size
    encrypted   = true
  }

  # User data script to install Docker and setup APy
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get upgrade -y

    # Install Docker
    apt-get install -y \
      ca-certificates \
      curl \
      gnupg \
      lsb-release

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Add ubuntu user to docker group
    usermod -aG docker ubuntu

    # Install Docker Compose
    apt-get install -y docker-compose

    # Create directories
    mkdir -p /opt/ido-epo-translator
    chown ubuntu:ubuntu /opt/ido-epo-translator

    # Log initialization
    echo "EC2 instance initialized successfully" > /var/log/apy-init.log
    echo "Instance ready for APy server deployment" >> /var/log/apy-init.log
  EOF

  tags = {
    Name        = "${var.project_name}-apy-server"
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Role        = "APy Translation Server"
  }

  # Prevent accidental termination
  disable_api_termination = false
}

# Elastic IP for stable address
resource "aws_eip" "apy_server" {
  domain = "vpc"
  
  instance = aws_instance.apy_server.id
  
  tags = {
    Name      = "${var.project_name}-apy-server-eip"
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

# Outputs
output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.apy_server.id
}

output "public_ip" {
  description = "Public IP address of the instance"
  value       = aws_eip.apy_server.public_ip
}

output "public_dns" {
  description = "Public DNS name of the instance"
  value       = aws_instance.apy_server.public_dns
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ${var.ssh_private_key_path} ubuntu@${aws_eip.apy_server.public_ip}"
}

output "apy_url" {
  description = "APy server URL"
  value       = "http://${aws_eip.apy_server.public_ip}:2737"
}

output "apy_url_http" {
  description = "APy server URL via HTTP (port 80)"
  value       = "http://${aws_eip.apy_server.public_ip}"
}

