# GitHub Actions CI/CD Pipeline Setup

This directory contains the GitHub Actions workflow for building, pushing, and deploying the options-app.

## Workflow Overview

The CI/CD pipeline (`ci-cd.yml`) runs on:
- Push to `master` branch
- Pull requests to `master` branch

### Pipeline Steps:

1. **Build Docker Image**: Builds the Python 3.14 + uv image for linux/amd64 platform
2. **Push to ECR**: Pushes with two tags - commit SHA and `latest`
3. **Trigger Terraform Cloud**: Creates a new Terraform Cloud run (master branch only)
4. **Force ECS Deployment**: Tells ECS to pull the new image (master branch only, fallback)

## Required GitHub Secrets

You need to configure the following secrets in your GitHub repository:

### AWS Secrets (Already Configured via OIDC)
- Your workflow uses OIDC role assumption: `arn:aws:iam::433356891743:role/GitHubActionsECRPushRole`
- No AWS access keys needed if OIDC is properly configured

### Terraform Cloud Secrets (Need to Add)

Navigate to: `https://github.com/YuanH/options_server/settings/secrets/actions`

Add these secrets:

1. **TFC_API_TOKEN**
   - Description: Terraform Cloud API token
   - How to get:
     1. Go to https://app.terraform.io/app/settings/tokens
     2. Click "Create an API token"
     3. Name it "GitHub Actions CI/CD"
     4. Copy the token value
   - Value: `your-terraform-cloud-api-token`

2. **TFC_ORGANIZATION**
   - Description: Your Terraform Cloud organization name
   - Value: Your org name from the URL `https://app.terraform.io/app/<ORG_NAME>/workspaces`

3. **TFC_WORKSPACE**
   - Description: Your Terraform Cloud workspace name
   - Value: The workspace name for this project (e.g., `options-app` or similar)

## IAM Role Setup (If Not Already Done)

Your IAM role `GitHubActionsECRPushRole` needs these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:UpdateService",
        "ecs:DescribeServices"
      ],
      "Resource": "arn:aws:ecs:us-east-1:433356891743:service/options-app-cluster/options-app-service"
    }
  ]
}
```

Trust relationship for OIDC:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::433356891743:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YuanH/options_server:*"
        }
      }
    }
  ]
}
```

## Terraform Cloud Auto-Apply (Optional)

The workflow triggers a Terraform Cloud run with `"auto-apply": false` by default. This means:
- Terraform will plan the changes
- You need to manually approve the apply in Terraform Cloud UI

To enable auto-apply:
1. Change line 76 in `ci-cd.yml` from `"auto-apply": false` to `"auto-apply": true`
2. OR configure auto-apply in your Terraform Cloud workspace settings

## Testing the Pipeline

### Test on Pull Request:
1. Create a new branch: `git checkout -b test-ci-cd`
2. Make a small change (e.g., update README)
3. Commit and push: `git push origin test-ci-cd`
4. Open a PR to master
5. Workflow will build and push the image but NOT deploy

### Test on Master:
1. Merge the PR to master
2. Workflow will:
   - Build and push Docker image
   - Trigger Terraform Cloud run
   - Force ECS deployment

## Troubleshooting

### "Role assumption failed"
- Check that the OIDC provider is configured in AWS IAM
- Verify the role ARN is correct in the workflow
- Ensure the trust relationship allows your repository

### "Terraform Cloud API failed"
- Verify all three TFC secrets are set correctly
- Check that the API token has permission to trigger runs
- Confirm the workspace name matches exactly

### "ECS deployment failed"
- Verify the IAM role has `ecs:UpdateService` permission
- Check that cluster and service names are correct

## Workflow Notifications

The workflow includes GitHub Actions annotations:
- Terraform Cloud run URL will appear in the workflow summary
- ECS deployment status will be shown as a notice

## Manual Deployment

If you need to deploy manually:

```bash
# Build and push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 433356891743.dkr.ecr.us-east-1.amazonaws.com
docker buildx build --platform linux/amd64 -t 433356891743.dkr.ecr.us-east-1.amazonaws.com/options-app-repo:latest ./app --push

# Force ECS deployment
aws ecs update-service --cluster options-app-cluster --service options-app-service --force-new-deployment --region us-east-1
```
