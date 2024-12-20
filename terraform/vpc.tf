# # terraform/main.tf (continued)

# # Create VPC
# resource "aws_vpc" "main" {
#   cidr_block           = var.vpc_cidr
#   enable_dns_support   = true
#   enable_dns_hostnames = true

#   tags = {
#     Name = "${var.project_name}-vpc"
#   }
# }

# # Create Internet Gateway
# resource "aws_internet_gateway" "gw" {
#   vpc_id = aws_vpc.main.id

#   tags = {
#     Name = "${var.project_name}-gw"
#   }
# }

# # Create Public Subnets
# resource "aws_subnet" "public" {
#   count                   = length(var.public_subnets)
#   vpc_id                  = aws_vpc.main.id
#   cidr_block              = var.public_subnets[count.index]
#   availability_zone       = data.aws_availability_zones.available.names[count.index]
#   map_public_ip_on_launch = true

#   tags = {
#     Name = "${var.project_name}-public-subnet-${count.index + 1}"
#   }
# }

# # Create Private Subnets
# resource "aws_subnet" "private" {
#   count             = length(var.private_subnets)
#   vpc_id            = aws_vpc.main.id
#   cidr_block        = var.private_subnets[count.index]
#   availability_zone = data.aws_availability_zones.available.names[count.index]

#   tags = {
#     Name = "${var.project_name}-private-subnet-${count.index + 1}"
#   }
# }

# # Create Route Table for Public Subnets
# resource "aws_route_table" "public" {
#   vpc_id = aws_vpc.main.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.gw.id
#   }

#   tags = {
#     Name = "${var.project_name}-public-rt"
#   }
# }

# # Associate Route Table with Public Subnets
# resource "aws_route_table_association" "public_assoc" {
#   count          = length(aws_subnet.public)
#   subnet_id      = aws_subnet.public[count.index].id
#   route_table_id = aws_route_table.public.id
# }

# # Data source for Availability Zones
# data "aws_availability_zones" "available" {}