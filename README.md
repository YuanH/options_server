# Flask Application Deployment on AWS ECS with ALB, ACM, and Route 53 using Terraform

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)

---

## Project Overview

This project deploys a **Flask** application on **AWS Elastic Container Service (ECS)** using **Terraform** for Infrastructure as Code (IaC). The application is served behind an **Application Load Balancer (ALB)** with **HTTPS** enabled via **AWS Certificate Manager (ACM)**. **Route 53** manages DNS records to point to the ALB, ensuring secure and reliable access to the application.

## Architecture

```markdown
User
|
| HTTPS (443)
v
ALB (Application Load Balancer)
|
| HTTP (80) Redirect to HTTPS (Optional)
| HTTPS (443)
v
ECS Service (Flask Application)
```

- **ALB:** Distributes incoming traffic to ECS tasks.
- **ACM:** Provides SSL certificates for HTTPS.
- **Route 53:** Manages DNS records pointing to the ALB.
- **Security Groups:** Control inbound and outbound traffic for the ALB and ECS tasks.

## Prerequisites

Before proceeding, ensure you have the following:

- **AWS Account:** With appropriate permissions to manage ECS, ALB, ACM, Route 53, and related resources.
- **Terraform Installed:** Version 1.0 or later.
- **Docker Installed:** For building and pushing Docker images.
- **AWS CLI Installed:** For interacting with AWS services.
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

---

## Todo

- finish building ci-cd