# ECS Cluster
resource "aws_ecs_cluster" "flask_cluster" {
  name = "${var.project_name}-cluster"

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]

  tags = {
    Name = "${var.project_name}-ecs-task-execution-role"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "flask_task" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # Adjust as needed
  memory                   = "512" # Adjust as needed
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "flask-app"
      image     = "${aws_ecr_repository.flask_app.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
          protocol      = "tcp"
        }
      ]

      #   environment = [
      #     {
      #       name  = "FLASK_SECRET_KEY"
      #       value = var.flask_secret_key
      #     }
      #     # Add other environment variables as needed
      #   ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-task"
  }
}

# CloudWatch Log Group for ECS
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7
}

# ECS Fargate Service
resource "aws_ecs_service" "flask_service" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.flask_cluster.id
  task_definition = aws_ecs_task_definition.flask_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.flask_tg_ip.arn
    container_name   = "flask-app"
    container_port   = 5000
  }

  depends_on = [
    aws_lb_listener.flask_listener
  ]

  tags = {
    Name = "${var.project_name}-service"
  }
}

# Prometheus Task Definition
resource "aws_ecs_task_definition" "prometheus_task" {
  family                   = "${var.project_name}-prometheus"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  volume {
    name = "prometheus-data"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.prometheus_data.id
      root_directory          = "/"
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.prometheus_data.id
      }
    }
  }

  volume {
    name = "prometheus-config"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.prometheus_data.id
      root_directory = "/config"
    }
  }

  container_definitions = jsonencode([
    {
      name      = "prometheus"
      image     = "prom/prometheus:latest"
      essential = true

      mountPoints = [
        {
          sourceVolume  = "prometheus-data"
          containerPath = "/prometheus"
          readOnly     = false
        },
        {
          sourceVolume  = "prometheus-config"
          containerPath = "/etc/prometheus"
          readOnly     = true
        }
      ]

      command = [
        "--config.file=/etc/prometheus/prometheus.yml",
        "--storage.tsdb.path=/prometheus",
        "--storage.tsdb.retention.time=30d",
        "--web.enable-lifecycle"
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "prometheus"
        }
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-prometheus-task"
  }
}

# Grafana Task Definition
resource "aws_ecs_task_definition" "grafana_task" {
  family                   = "${var.project_name}-grafana"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "grafana"
      image     = "grafana/grafana:latest"
      essential = true

      environment = [
        {
          name  = "GF_SECURITY_ADMIN_PASSWORD"
          value = var.grafana_admin_password
        },
        {
          name  = "GF_INSTALL_PLUGINS"
          value = "grafana-clock-panel,grafana-simple-json-datasource"
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "grafana-provisioning"
          containerPath = "/etc/grafana/provisioning"
          readOnly     = true
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "grafana"
        }
      }
    }
  ])

  volume {
    name = "grafana-provisioning"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.prometheus_data.id
      root_directory = "/grafana-provisioning"
    }
  }

  tags = {
    Name = "${var.project_name}-grafana-task"
  }
}

# Prometheus Service
resource "aws_ecs_service" "prometheus_service" {
  name            = "${var.project_name}-prometheus"
  cluster         = aws_ecs_cluster.flask_cluster.id
  task_definition = aws_ecs_task_definition.prometheus_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = true
  }

  tags = {
    Name = "${var.project_name}-prometheus-service"
  }
}

# Create the configuration files in EFS
resource "null_resource" "prometheus_config" {
  provisioner "local-exec" {
    command = <<-EOT
      cat <<EOF > prometheus.yml
      global:
        scrape_interval: 15s
        evaluation_interval: 15s
      EOF

      aws efs put-object --bucket ${aws_efs_file_system.prometheus_data.id} --key config/prometheus.yml --body prometheus.yml
    EOT
  }
}

resource "null_resource" "grafana_config" {
  provisioner "local-exec" {
    command = <<-EOT
      cat <<EOF > datasources.yml
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          access: proxy
          url: http://${aws_ecs_service.prometheus_service.name}.${var.project_name}-cluster:9090
          isDefault: true
      EOF

      aws efs put-object --bucket ${aws_efs_file_system.prometheus_data.id} --key grafana-provisioning/datasources/datasources.yml --body datasources.yml
    EOT
  }
}


