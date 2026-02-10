# Flask Application Deployment on AWS ECS with ALB, ACM, and Cloudflare DNS using Terraform

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)

---

## Project Overview

This project deploys a **Flask** application on **AWS Elastic Container Service (ECS)** using **Terraform** for Infrastructure as Code (IaC). The application is served behind an **Application Load Balancer (ALB)** with **HTTPS** enabled via **AWS Certificate Manager (ACM)**. **Cloudflare DNS** manages DNS records and ACM validation, pointing traffic to the ALB.

## Architecture

```mermaid
flowchart TD
  U[User Browser] -->|DNS| CF[Cloudflare DNS]
  CF -->|CNAME options.yuanhuang.info| ALB[ALB (HTTPS 443)]
  ALB -->|Forward| ECS[ECS Service (Flask + Gunicorn)]
  ACM[ACM Certificate] --> ALB
```

- **ALB:** Distributes incoming traffic to ECS tasks.
- **ACM:** Provides SSL certificates for HTTPS.
- **Cloudflare DNS:** Hosts DNS records and ACM validation CNAMEs.
- **Security Groups:** Control inbound and outbound traffic for the ALB and ECS tasks.

## Prerequisites

Before proceeding, ensure you have the following:

- **AWS Account:** With appropriate permissions to manage ECS, ALB, ACM, Route 53, and related resources.
- **Terraform Installed:** Version 1.0 or later.
- **Docker Installed:** For building and pushing Docker images.
- **AWS CLI Installed:** For interacting with AWS services.
- **uv Installed:** For Python dependency management (optional for local development).
- **Git Installed:** For version control (optional but recommended).

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/YuanH/options_server.git
cd options_server
```

### 2. Configure AWS Credentials

Ensure your AWS credentials are configured. It’s recommended to use an IAM user with the least privileges necessary.

```bash
aws configure
```

### 3. Initialize Terraform

Initialize Terraform to download necessary providers and set up the backend.

```bash
cd terraform
terraform init

# My terraform is run on terraform cloud. Make sure you configure yours
terraform apply
```

### 4. Running the App Locally

Run with uv (recommended for development):

```bash
cd app
uv run python app.py
```

The app will be available at http://localhost:5001

### 5. Building the Docker Image

The Dockerfile uses Python 3.14 with the official uv base image for fast dependency installation.

Building docker locally:

```bash
docker build -t options-app:latest ./app
```

Running docker locally:

```bash
docker run -p 5001:5000 options-app:latest
```

Note: Port 5000 on macOS is often used by AirPlay/ControlCenter, so we map to 5001 on the host.

Building Docker image for ECS:

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin {AccountID}.dkr.ecr.us-east-1.amazonaws.com

docker buildx build --platform linux/amd64 -t {AccountID}.dkr.ecr.us-east-1.amazonaws.com/options-app-repo:latest ./app --push
```

If there is no change to infrastructure (terraform plan has no change), use AWS CLI to do a manual refresh:

```bash
aws ecs update-service --cluster options-app-cluster --service options-app-service --force-new-deployment --region us-east-1
```

## Application Features

- **Options Chain Analysis**: Fetches real-time option data for any stock ticker
- **Dynamic Return Filter**: User-configurable annualized return threshold (default 15%)
- **Strategy Calculations**:
  - Cash-secured puts annualized returns
  - Covered calls annualized returns
- **Responsive Design**: Pivot tables adapt to screen size with horizontal scrolling
- **Filters**:
  - Annualized return threshold (customizable)
  - Out-of-the-money options only

## Technology Stack

- **Backend**: Flask with Python 3.14
- **Dependency Management**: uv (fast Python package installer)
- **Data**: yfinance with curl_cffi for bot detection bypass
- **Frontend**: Bootstrap 4 with custom responsive CSS
- **Deployment**: Docker containers on AWS ECS Fargate
- **Infrastructure**: Terraform

---

## CI/CD Pipeline

A GitHub Actions workflow is configured to automatically build, push, and deploy on merge to master:

1. **Build**: Builds Docker image with Python 3.14 + uv
2. **Push**: Pushes to ECR with commit SHA and `latest` tags
3. **Deploy**: Triggers Terraform Cloud run and forces ECS deployment

See [.github/workflows/README.md](.github/workflows/README.md) for setup instructions.

## Todo

- add observability (Prometheus/Grafana)
- add integration tests
