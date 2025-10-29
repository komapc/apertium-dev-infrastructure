# Terraform configuration to expand existing EC2 volume without recreating instance
# This modifies the volume size in-place

# Data source to get the existing instance
data "aws_instance" "existing_apy_server" {
  instance_id = aws_instance.apy_server.id
}

# Data source to get the root volume
data "aws_ebs_volume" "root" {
  most_recent = true

  filter {
    name   = "attachment.instance-id"
    values = [data.aws_instance.existing_apy_server.id]
  }

  filter {
    name   = "attachment.device"
    values = [data.aws_instance.existing_apy_server.root_block_device[0].device_name]
  }
}

# Use null_resource with local-exec to modify the volume
# This is a workaround since Terraform can't modify existing volumes directly
resource "null_resource" "expand_root_volume" {
  # Trigger this resource when disk_size changes
  triggers = {
    disk_size = var.disk_size
    volume_id = data.aws_ebs_volume.root.id
  }

  # Only run if current size is less than desired size
  provisioner "local-exec" {
    command = <<-EOT
      CURRENT_SIZE=$(aws ec2 describe-volumes \
        --volume-ids ${data.aws_ebs_volume.root.id} \
        --query 'Volumes[0].Size' \
        --output text \
        --region ${var.aws_region})
      
      if [ "$CURRENT_SIZE" -lt "${var.disk_size}" ]; then
        echo "Expanding volume ${data.aws_ebs_volume.root.id} from $CURRENT_SIZE GB to ${var.disk_size} GB..."
        aws ec2 modify-volume \
          --volume-id ${data.aws_ebs_volume.root.id} \
          --size ${var.disk_size} \
          --region ${var.aws_region}
        
        echo "Volume expansion initiated. Waiting for completion..."
        aws ec2 wait volume-in-use \
          --volume-ids ${data.aws_ebs_volume.root.id} \
          --region ${var.aws_region}
        
        echo "Volume expansion complete!"
        echo ""
        echo "⚠️  IMPORTANT: SSH into the instance and run:"
        echo "   sudo growpart /dev/nvme0n1 1"
        echo "   sudo resize2fs /dev/nvme0n1p1"
        echo "   df -h"
      else
        echo "Volume is already ${var.disk_size} GB or larger. No expansion needed."
      fi
    EOT
  }
}

output "volume_expansion_info" {
  description = "Information about volume expansion"
  value = {
    volume_id    = data.aws_ebs_volume.root.id
    current_size = data.aws_ebs_volume.root.size
    target_size  = var.disk_size
    instance_id  = data.aws_instance.existing_apy_server.id
  }
}

output "post_expansion_commands" {
  description = "Commands to run on EC2 after volume expansion"
  value = <<-EOT
    SSH into your instance and run these commands:
    
    ssh -i ${var.ssh_private_key_path} ubuntu@${aws_eip.apy_server.public_ip}
    
    Then run:
    sudo growpart /dev/nvme0n1 1
    sudo resize2fs /dev/nvme0n1p1
    df -h
  EOT
}
