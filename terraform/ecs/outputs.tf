output "cluster_arn" {
  value = var.ecs_cluster_arn == "" ? aws_ecs_cluster.this[0].arn : var.ecs_cluster_arn
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.this.arn
}
