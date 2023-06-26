locals {
  firefly_prefix = "firefly-states-redactor"
  firefly_prefix_with_crawler = "${local.firefly_prefix}-${substr(var.firefly_crawler_id, -4, 4)}"
  image_uri = replace(var.image_uri, ".us-east-1.", ".${var.aws_region}.")
  log_options = var.firefly_remote_log_hash != "" ? {} : {
    "options"   = {
        "awslogs-group"         = var.cloudwatch_log_group_name,
        "awslogs-region"        = var.aws_region,
        "awslogs-create-group"  = tostring(var.cloudwatch_should_create_log_group),
        "awslogs-stream-prefix" =  var.cloudwatch_stream_prefix,
    }
  }
  log_driver = var.firefly_remote_log_hash != "" ? {} : {"logDriver" =  "awslogs"}
  container_definition = {
    name                    = local.firefly_prefix_with_crawler
    image                   = "${local.image_uri}:${var.image_version}"
    environment             = [
          {
            name  = "FIREFLY_ACCOUNT_ID"
            value = var.firefly_account_id
          },
          {
            name  = "FIREFLY_CRAWLER_ID"
            value = var.firefly_crawler_id
          },
          {
            name  = "SAAS_MODE"
            value = "false"
          },
          {
            name  = "STATES_BUCKET"
            value = var.redacted_bucket_name
          },
          {
            name  = "AWS_REGION"
            value = var.aws_region
          },
          {
            name  = "REMOTE_LOG_HASH"
            value = var.firefly_remote_log_hash
          },
          {
            name  = "LOCAL_CRAWLER_JSON"
            value = "{\"_id\" : \"${var.firefly_crawler_id}\",\"accountId\" : \"${var.firefly_account_id}\",\"location\" : {    \"s3\" : {        \"isLocal\" : true, \"bucket\" : \"${var.source_bucket_name}\",        \"region\" : \"${var.source_bucket_region}\"    }},\"type\" : \"s3\",\"active\" : true, \"fullMapInterval\" : 86400000000000,\"isAutoCreated\" : true,\"isLocal\" : true,\"mainLocation\" : \"${var.source_bucket_name}\"}"
          }
    ]
    memory                  = var.container_memory
    cpu                     = var.container_cpu
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "ecs_task_role" {
  name = "${local.firefly_prefix_with_crawler}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_policy_source_bucket" {
  name = "${local.firefly_prefix_with_crawler}-ecs-task-policy-source-bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ]
      Effect = "Allow"
      Resource = [
        "arn:aws:s3:::${var.source_bucket_name}",
        "arn:aws:s3:::${var.source_bucket_name}/*tfstate"
      ]
    }]
  })

  role = aws_iam_role.ecs_task_role.id
}

resource "aws_iam_role_policy" "ecs_task_policy_redacted_bucket" {
  name = "${local.firefly_prefix_with_crawler}-ecs-task-policy-redacted-bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:GetObjectVersion",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ]
      Effect = "Allow"
      Resource = [
        "arn:aws:s3:::${var.redacted_bucket_name}",
        "arn:aws:s3:::${var.redacted_bucket_name}/*tfstate",
        "arn:aws:s3:::${var.redacted_bucket_name}/*jsonl"
      ]
    }]
  })

  role = aws_iam_role.ecs_task_role.id
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${local.firefly_prefix_with_crawler}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "redactor_logs" {
  count       = var.firefly_remote_log_hash == "" ? 1 : 0
  name        = "${local.firefly_prefix_with_crawler}-redactor-logs-policy"
  path        = "/"
  description = "Firefly creates this polocy to enable the ecs to manage the states-redactor logs with cloudwatch"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:*"
        ]
        Effect   = "Allow"
        Resource = [format("arn:aws:logs:%s:%s:log-group:%s*", var.aws_region, data.aws_caller_identity.current.account_id, var.cloudwatch_log_group_name)]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_logs_policy_attachment" {
  count      = var.firefly_remote_log_hash == "" ? 1 : 0
  policy_arn = aws_iam_policy.redactor_logs[0].arn
  role       = aws_iam_role.ecs_task_execution_role.name
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution_role.name
}

resource "aws_iam_role" "ecs_events_rule_role" {
  name = "${local.firefly_prefix_with_crawler}-ecs-events-rule-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_events_rule_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"
  role       = aws_iam_role.ecs_events_rule_role.name
}

resource "aws_ecs_cluster" "this" {
  count = var.ecs_cluster_arn == "" ? 1 : 0
  name = local.firefly_prefix
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.firefly_prefix_with_crawler
  container_definitions    =  var.firefly_remote_log_hash != "" ? jsonencode([local.container_definition]) : jsonencode([merge(local.container_definition, {logConfiguration = merge(local.log_options, local.log_driver)})])

  cpu                      = var.container_cpu
  memory                   = var.container_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_cloudwatch_event_rule" "this" {
  name                = "${local.firefly_prefix_with_crawler}-ecs-task-schedule"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "this" {
  rule     = aws_cloudwatch_event_rule.this.name
  arn      = var.ecs_cluster_arn == "" ? aws_ecs_cluster.this[0].arn : var.ecs_cluster_arn
  role_arn = aws_iam_role.ecs_events_rule_role.arn

  ecs_target {
    task_count = 1
    task_definition_arn = aws_ecs_task_definition.this.arn
    launch_type             = "FARGATE"
    platform_version        = "LATEST"

    network_configuration {
      assign_public_ip = var.assign_public_ip
      security_groups  = var.security_groups
      subnets          = var.subnets
    }
  }
}

output "instance_ip_addr" {
  value = {logConfiguration = merge(local.log_options, local.log_driver)}
}