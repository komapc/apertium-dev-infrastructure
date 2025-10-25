# EventBridge Automation Rules
# Automatically start/stop EC2 instance on schedule

# Optional: Enable/disable automation via variable
variable "enable_automation" {
  description = "Enable automated start/stop scheduling"
  type        = bool
  default     = false
}

variable "stop_schedule" {
  description = "Schedule expression for stopping instance (e.g., 'cron(0 2 * * ? *)' for 2 AM daily)"
  type        = string
  default     = "cron(0 2 * * ? *)"  # Default: 2 AM daily
}

variable "start_schedule" {
  description = "Schedule expression for starting instance (e.g., 'cron(0 8 * * ? *)' for 8 AM daily)"
  type        = string
  default     = "cron(0 8 * * ? *)"  # Default: 8 AM daily
}

# Rule to stop instance automatically
resource "aws_cloudwatch_event_rule" "stop_instance" {
  count               = var.enable_automation ? 1 : 0
  name                = "${var.project_name}-stop-schedule"
  description         = "Automatically stop APy server"
  schedule_expression = var.stop_schedule
  state               = "ENABLED"

  tags = {
    Name      = "${var.project_name}-stop-rule"
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

resource "aws_cloudwatch_event_target" "stop_instance" {
  count     = var.enable_automation ? 1 : 0
  rule      = aws_cloudwatch_event_rule.stop_instance[0].name
  target_id = "StopAPyServer"
  arn       = "arn:aws:events:${var.aws_region}::targets/ec2-stop-instance"
  
  input = jsonencode({
    "Instances" = [aws_instance.apy_server.id]
  })
}

# Rule to start instance automatically
resource "aws_cloudwatch_event_rule" "start_instance" {
  count               = var.enable_automation ? 1 : 0
  name                = "${var.project_name}-start-schedule"
  description         = "Automatically start APy server"
  schedule_expression = var.start_schedule
  state               = "ENABLED"

  tags = {
    Name      = "${var.project_name}-start-rule"
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}

resource "aws_cloudwatch_event_target" "start_instance" {
  count     = var.enable_automation ? 1 : 0
  rule      = aws_cloudwatch_event_rule.start_instance[0].name
  target_id = "StartAPyServer"
  arn       = "arn:aws:events:${var.aws_region}::targets/ec2-start-instance"
  
  input = jsonencode({
    "Instances" = [aws_instance.apy_server.id]
  })
}

# Output automation status
output "automation_enabled" {
  description = "Whether automation is enabled"
  value       = var.enable_automation
}

output "automation_schedule" {
  description = "Current automation schedule"
  value = var.enable_automation ? {
    stop  = var.stop_schedule
    start = var.start_schedule
  } : null
}

