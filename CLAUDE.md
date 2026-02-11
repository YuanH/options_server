# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flask web application that provides options chain analysis for stock tickers. The app fetches option data using yfinance, calculates annualized returns for puts and calls (cash-secured puts and covered calls strategies), and displays pivot tables showing bid prices and returns across different strike prices and expiration dates.

The application is deployed on AWS ECS Fargate behind an Application Load Balancer with HTTPS via ACM. Infrastructure is managed with Terraform, and DNS is handled through Cloudflare.

## Architecture

- **Application Layer**: Flask app with Gunicorn (4 workers) running in Docker containers on ECS Fargate
- **Load Balancer**: ALB with HTTPS listener on port 443, forwarding to ECS tasks on port 5000
- **Networking**: Custom VPC with public/private subnets across 2 AZs
- **Certificate**: ACM certificate validated via Cloudflare DNS CNAME records
- **Container Registry**: AWS ECR for Docker images
- **Logs**: CloudWatch logs with 7-day retention

## Build and Development Commands

### Local Development

Run Flask app with uv (recommended):
```bash
cd app
uv run python app.py
```

The app listens on 0.0.0.0:5001 and is accessible at http://localhost:5001

Generate or update lock file:
```bash
cd app
uv lock
```

### Docker

The Dockerfile uses Python 3.14 with the official uv base image: `ghcr.io/astral-sh/uv:python3.14-bookworm-slim`

Build Docker image locally:
```bash
docker build -t options-app:latest ./app
```

Run container locally (maps host 5001 to container 5000):
```bash
docker run -p 5001:5000 options-app:latest
```

Note: Port 5000 on macOS is often used by AirPlay/ControlCenter.

Build and push to ECR for deployment:
```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin {AccountID}.dkr.ecr.us-east-1.amazonaws.com

docker buildx build --platform linux/amd64 -t {AccountID}.dkr.ecr.us-east-1.amazonaws.com/options-app-repo:latest ./app --push
```

### Terraform

Initialize Terraform (run from project root):
```bash
terraform -chdir=terraform init
```

Apply infrastructure changes:
```bash
terraform -chdir=terraform apply
```

Note: This project uses Terraform Cloud for state management. Ensure you're configured for remote state before applying.

### Dependency Management

The project uses `uv` for Python dependency management with Python 3.14.

Dependencies are defined in `app/pyproject.toml`:
- Flask 3.x
- curl_cffi (for yfinance HTTP requests that bypass bot detection)
- gunicorn
- numpy 2.x
- pandas 3.x
- yfinance

The `app/uv.lock` file locks all transitive dependencies.

Important: `app/pyproject.toml` includes `[tool.setuptools]` configuration with `py-modules = ["app", "option_calculator"]` to prevent setuptools from treating `static/` and `templates/` directories as packages during Docker builds.

## Key Application Logic

### Option Calculations (app/option_calculator.py)

The core pricing logic calculates annualized returns for options strategies:

**Cash-Secured Puts**:
- Capital reserved = strike × 100
- Annualized return = (premium / strike) × (365 / days_to_expiration) × 100
- Breakeven % = (current_price - (strike - premium)) / current_price × 100

**Covered Calls**:
- Annualized return = (premium / stock_price) × (365 / days_to_expiration) × 100
- Breakeven % = (strike + premium - current_price) / current_price × 100

### Data Fetching

Uses yfinance with curl_cffi session impersonation to avoid rate limiting. A single `curl_cffi` session is created per request and shared across `get_current_price()` and `fetch_and_calculate_option_returns()`. Option chains for all expiration dates are fetched concurrently using `ThreadPoolExecutor`.

### Query Parameters

The app supports both POST form submissions and GET query parameters. You can bookmark or share URLs with pre-filled parameters:

```
/?ticker=AAPL&return_filter=on&return_threshold=25&out_of_the_money=on
```

Available parameters:
- `ticker` — Stock ticker symbol (required)
- `return_filter` — Set to `on` to enable annualized return filtering
- `return_threshold` — Minimum annualized return percentage (default 15.0, accepts decimals like 25.5)
- `out_of_the_money` — Set to `on` to show only OTM options

### Filtering Options

- `return_filter`: Checkbox to enable/disable annualized return filtering
- `return_threshold`: User-configurable percentage (default 15.0%, accepts decimals like 25.5%)
  - Value is passed from frontend → backend → option_calculator.py
  - Applied to both puts and calls when return_filter is enabled
- `out_of_the_money`: If enabled, filters to show only OTM options (excludes in-the-money)

### Responsive UI Design

The pivot tables (app/static/styles.css) are designed to be responsive:
- Full-width container with minimal padding
- Horizontal scrolling when table exceeds viewport width
- Smaller font sizes on mobile devices (media query at 768px)
- Tables wrapped in `.table-responsive` divs for Bootstrap support
- Smooth scrolling with `-webkit-overflow-scrolling: touch`

### Health Check

The `/health` endpoint at app/app.py:90 is used by the ALB target group for health checks.

**Important deployment notes:**
- The `uv run` CMD in the Dockerfile rebuilds the venv on every container start (~6 seconds). This is intentional — it ensures packages are compiled for the correct architecture (linux/amd64). Do NOT replace `uv run` with direct venv execution (e.g., `.venv/bin/gunicorn`) as this causes "invalid ELF header" errors when built on ARM Macs.
- ALB health check settings must account for this startup delay. Current config: `healthy_threshold=2`, `unhealthy_threshold=3`, `timeout=5s`, `interval=10s`.
- If a new task definition revision keeps failing health checks during deployment, you may need to manually stop the old revision's tasks to unblock the rolling deployment (ECS waits for `minimumHealthyPercent=100` before draining old tasks).
- Do NOT use `data.aws_ecr_image` digest in the task definition image URL — use `:latest` tag instead. The digest can become stale between Terraform plan and apply. The digest is only used in the ECS service `triggers` block to detect when `:latest` changes.

## Terraform Infrastructure

All Terraform files are in the `terraform/` directory:

- `vpc.tf`: VPC with 2 public and 2 private subnets across us-east-1a and us-east-1b
- `alb.tf`: Application Load Balancer with HTTP→HTTPS redirect and HTTPS listener forwarding to ECS
- `acm.tf`: ACM certificate for options.yuanhuang.info with DNS validation via Cloudflare
- `ecs.tf`: ECS Fargate cluster, task definition (256 CPU, 512 MB memory), and service
- `ecr.tf`: ECR repository for Docker images
- `providers.tf`: AWS and Cloudflare provider configuration
- `variables.tf`: Terraform variables including Cloudflare API token and zone ID (stored in Terraform Cloud)

### Important Configuration Details

- ECS task runs on port 5000 internally
- ALB target group uses IP target type (required for awsvpc network mode)
- Health check path: `/health`
- Container image: Always uses `:latest` tag from ECR
- ECS service desired count: 1
- Security groups allow port 443 (ALB) and port 5000 (ECS tasks)

### Manual ECS Refresh

If infrastructure hasn't changed but you need to pull a new Docker image, force a new ECS deployment:
```bash
aws ecs update-service --cluster options-app-cluster --service options-app-service --force-new-deployment --region us-east-1
```

## CI/CD Pipeline

The `.github/workflows/ci-cd.yml` workflow is configured to run on push to master:

1. **Build Docker Image**: Uses buildx for linux/amd64 platform with Python 3.14 + uv base image
2. **Push to ECR**: Tags with commit SHA and `latest`
3. **Trigger Terraform Cloud**: Creates a new Terraform run via API (requires manual approval)
4. **Force ECS Deployment**: Tells ECS to pull and deploy the new image

**Required GitHub Secrets:**
- `TFC_API_TOKEN` - Terraform Cloud API token
- `TFC_ORGANIZATION` - Terraform Cloud org name
- `TFC_WORKSPACE` - Terraform Cloud workspace name

The workflow uses OIDC authentication for AWS (role: `GitHubActionsECRPushRole`).

See `.github/workflows/README.md` for complete setup instructions.

## Security Considerations

- `app.secret_key` in app/app.py:22 is hardcoded. For production, this should be replaced with an environment variable passed via ECS task definition.
- Cloudflare API token and zone ID are stored as sensitive Terraform variables.
- The ALB security group allows ingress from 0.0.0.0/0 on port 443.

## Python Code Style

- Indentation: 4 spaces
- Naming: `snake_case` for functions/variables, `CamelCase` for classes
- Type hints are used in function signatures where appropriate (see option_calculator.py)
