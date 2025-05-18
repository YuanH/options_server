# Add EFS permissions to task execution role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_efs" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.efs_access.arn
}

resource "aws_iam_policy" "efs_access" {
  name = "${var.project_name}-efs-access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite"
        ]
        Resource = aws_efs_file_system.prometheus_data.arn
      }
    ]
  })
}