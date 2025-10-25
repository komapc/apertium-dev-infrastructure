# Additional outputs for Cloudflare configuration

output "cloudflare_worker_config" {
  description = "Configuration values for Cloudflare Worker environment variables"
  value = {
    APY_SERVER_URL = "http://${aws_eip.apy_server.public_ip}"
    REBUILD_WEBHOOK_URL = "http://${aws_eip.apy_server.public_ip}/rebuild"
  }
}

output "setup_instructions" {
  description = "Next steps after instance creation"
  value = <<-EOT
    ============================================
    Instance Created Successfully!
    ============================================
    
    SSH to instance:
    ssh -i <path-to-key> ubuntu@${aws_eip.apy_server.public_ip}
    
    Setup APy server:
    1. scp setup-ec2.sh ubuntu@${aws_eip.apy_server.public_ip}:~
    2. ssh -i <path-to-key> ubuntu@${aws_eip.apy_server.public_ip}
    3. chmod +x setup-ec2.sh
    4. ./setup-ec2.sh
    
    Configure Cloudflare Worker variables:
    - APY_SERVER_URL: http://${aws_eip.apy_server.public_ip}
    - REBUILD_WEBHOOK_URL: http://${aws_eip.apy_server.public_ip}/rebuild
    
    Test APy server:
    curl http://${aws_eip.apy_server.public_ip}:2737/listPairs
    
    ============================================
  EOT
}

