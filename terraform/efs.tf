resource "aws_efs_file_system" "prometheus_data" {
  creation_token = "${var.project_name}-prometheus-data"
  encrypted      = true

  tags = {
    Name = "${var.project_name}-prometheus-data"
  }
}

resource "aws_efs_mount_target" "prometheus_data" {
  count           = length(aws_subnet.public)
  file_system_id  = aws_efs_file_system.prometheus_data.id
  subnet_id       = aws_subnet.public[count.index].id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_security_group" "efs_sg" {
  name        = "${var.project_name}-efs-sg"
  description = "Security group for EFS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_service_sg.id]
  }
}

resource "aws_efs_access_point" "prometheus_data" {
  file_system_id = aws_efs_file_system.prometheus_data.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/prometheus"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }
}
