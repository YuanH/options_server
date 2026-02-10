# terraform/variables.tf

variable "aws_region" {
  description = "The AWS region to deploy resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "App to create option calculations"
  type        = string
  default     = "options-app"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "List of public subnet CIDR blocks."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "List of private subnet CIDR blocks."
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

# variable "flask_secret_key" {
#   description = "Secret key for the Flask application."
#   type        = string
# }

variable "docker_image_tag" {
  description = "Docker image tag."
  type        = string
  default     = "latest"
}

variable "domain_name" {
  description = "domain name"
  type        = string
  default     = "yuanhuang.info"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit permissions."
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the domain."
  type        = string
}

variable "cloudflare_proxied" {
  description = "Whether Cloudflare should proxy traffic for the subdomain."
  type        = bool
  default     = false
}
