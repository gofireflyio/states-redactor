variable "aws_region" {
  description = "The AWS region where the ECS cluster should be created."
  type        = string
}

variable "firefly_account_id" {
  description = "The account id in Firefly."
  type        = string
}

variable "firefly_crawler_id" {
  description = "The crawler id in Firefly."
  type        = string
}

variable "firefly_remote_log_hash" {
  description = "The hash for sending remote logs to Firefly. If empty, no logs will be sent to Firefly."
  type        = string
  default     = ""
}

variable "image_uri" {
  description = "The URL of the image to run."
  default     = "094724549126.dkr.ecr.us-east-1.amazonaws.com/firefly-states-redactor"
  type        = string
}

variable "image_version" {
  description = "The version of the image to run."
  default     = "latest"
  type        = string
}

variable "schedule_expression" {
  description = "The CloudWatch Events schedule expression for the task."
  default     = "rate(2 hours)"
  type        = string
}

variable "container_memory" {
  description = "The memory limit of the container."
  default     = 512
  type        = number
}

variable "container_cpu" {
  description = "The CPU units of the container."
  default     = 256
  type        = number
}

variable "redacted_bucket_name" {
  description = "The name of the bucket where the redacted states will be written to."
  type        = string
}

variable "source_bucket_name" {
  description = "The name of the bucket where the original states are."
  type        = string
}

variable "source_bucket_region" {
  description = "The region of the bucket where the original states are."
  type        = string
}

variable "security_groups" {
  type        = list(string)
  description = "A list of security group IDs to apply to an AWS resource."
}

variable "subnets" {
  type        = list(string)
  description = "A list of subnet IDs to launch an AWS resource in."
}

variable "assign_public_ip" {
  type        = bool
  default     = false
  description = "Should the ECS task have public ip (for getting the remote ECR). If assigned to false, you should add VPC endpoint to ECR."
}

variable "ecs_cluster_arn" {
  type        = string
  default     = ""
  description = "If ECS cluster already exists, use this one, otherwise if empty, create the cluster."
}

variable "cloudwatch_log_group_name" {
  type = string
  default = "firefly-on-prem-redactor"
  description = "In case of blocking the shipment of remote logs to Firefly. We will save the logs to a local cloud watch group."
}

variable "cloudwatch_stream_prefix" {
  type = string
  default = "firefly"
  description = "In case of blocking the shipment of remote logs to Firefly. We will save the logs to a local cloud watch group with that prefix."
}

variable "cloudwatch_should_create_log_group" {
  type = bool
  default = true
  description = "In case of blocking the shipment of remote logs to Firefly. We will save the logs to a local cloud watch group. This vairable meant for creating or using an exist group."
}

