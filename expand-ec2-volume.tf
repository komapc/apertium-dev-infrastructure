# Terraform configuration to expand EC2 volume
# This will expand the root volume of your existing EC2 instance

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"  # Change if your instance is in a different region
}

# Data source to find your existing instance
data "aws_instance" "extractor" {
  filter {
    name   = "private-ip-address"
    values = ["172.31.45.145"]
  }
  
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

# Data source to find the root volume
data "aws_ebs_volume" "root" {
  most_recent = true

  filter {
    name   = "attachment.instance-id"
    values = [data.aws_instance.extractor.id]
  }

  filter {
    name   = "attachment.device"
    values = ["/dev/sda1", "/dev/xvda", data.aws_instance.extractor.root_block_device[0].device_name]
  }
}

# Modify the volume size
resource "aws_volume_attachment" "root_volume_modification" {
  device_name = data.aws_instance.extractor.root_block_device[0].device_name
  volume_id   = data.aws_ebs_volume.root.id
  instance_id = data.aws_instance.extractor.id

  # This forces recreation if volume size changes
  lifecycle {
    ignore_changes = [device_name]
  }
}

# Expand the volume
resource "aws_ebs_volume" "expanded_root" {
  availability_zone = data.aws_instance.extractor.availability_zone
  size              = 20  # New size in GB
  type              = data.aws_ebs_volume.root.volume_type
  encrypted         = data.aws_ebs_volume.root.encrypted
  kms_key_id        = data.aws_ebs_volume.root.kms_key_id
  
  tags = merge(
    data.aws_ebs_volume.root.tags,
    {
      Name = "extractor-root-expanded"
    }
  )
}

output "instance_id" {
  value = data.aws_instance.extractor.id
}

output "volume_id" {
  value = data.aws_ebs_volume.root.id
}

output "current_size" {
  value = data.aws_ebs_volume.root.size
}

output "new_size" {
  value = 20
}
