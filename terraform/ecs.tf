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
    name = "prometheus-storage"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.prometheus_data.id
      root_directory          = "/"
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.prometheus_data.id
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "prometheus"
      image     = "prom/prometheus:latest"
      essential = true

      mountPoints = [
        {
          sourceVolume  = "prometheus-storage"
          containerPath = "/prometheus"
          readOnly     = false
        }
      ]

      command = [
        "--config.file=/prometheus/config/prometheus.yml",
        "--storage.tsdb.path=/prometheus/data",
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

  volume {
    name = "grafana-storage"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.prometheus_data.id
      root_directory = "/grafana"
    }
  }

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
          sourceVolume  = "grafana-storage"
          containerPath = "/etc/grafana/provisioning"
          readOnly     = false
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

# Initialize EFS directories
resource "null_resource" "efs_setup" {
  provisioner "local-exec" {
    command = <<-EOT
      # Create temporary mount point
      sudo mkdir -p /mnt/efs
      
      # Mount EFS
      sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_file_system.prometheus_data.dns_name}:/ /mnt/efs
      
      # Create directories
      sudo mkdir -p /mnt/efs/data
      sudo mkdir -p /mnt/efs/config
      sudo mkdir -p /mnt/efs/grafana/datasources
      
      # Create Prometheus config
      sudo tee /mnt/efs/config/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s
EOF

      # Create Grafana datasource config
      sudo tee /mnt/efs/grafana/datasources/datasources.yml > /dev/null <<EOF
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://${aws_ecs_service.prometheus_service.name}.${var.project_name}-cluster:9090
    isDefault: true
EOF

      # Set permissions
      sudo chown -R 1000:1000 /mnt/efs/data
      sudo chown -R 1000:1000 /mnt/efs/config
      sudo chown -R 472:472 /mnt/efs/grafana
      
      # Unmount EFS
      sudo umount /mnt/efs
    EOT
  }

  depends_on = [
    aws_efs_mount_target.prometheus_data
  ]
}


