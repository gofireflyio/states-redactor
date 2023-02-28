locals {
  firefly_prefix = "firefly-states-redactor"
  firefly_prefix_with_crawler = "${local.firefly_prefix}-${substr(var.firefly_crawler_id, -4, 4)}"
}

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
        "arn:aws:s3:::${var.redacted_bucket_name}/*jsonl",
        "arn:aws:s3:::${var.redacted_bucket_name}/*json"
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

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution_role.name
}

data "aws_iam_role" "ecs_event_rule_role" {
  name = "ecsEventsRole"
}

resource "aws_ecs_cluster" "this" {
  count = var.ecs_cluster_arn == "" ? 1 : 0
  name = local.firefly_prefix
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.firefly_prefix_with_crawler
  container_definitions    = jsonencode([{
    name                    = local.firefly_prefix_with_crawler
    image                   = "${var.image_uri}:${var.image_version}"
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
  }])

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
  role_arn = data.aws_iam_role.ecs_event_rule_role.arn

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
