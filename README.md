# ECR + ECS Demo

A hands-on demo showing how to build a Docker image, store it in **Amazon ECR**, and run it on **Amazon ECS Fargate** — using Terraform for all infrastructure.

---

## How it works

```
┌─────────────────────────────────────────────────────┐
│  Your Machine          AWS (Terraform managed)       │
│                                                      │
│  docker build    →→→  ECR Repository                 │
│  docker push          (stores image)                 │
│                              ↓                       │
│                        ECS Fargate                   │
│                        (pulls & runs image)          │
│                              ↓                       │
│                     http://<public-ip>:8080          │
└─────────────────────────────────────────────────────┘
```

**Rule:** Terraform owns all infrastructure. Scripts only build and push the image.

---

## Project Structure

```
ecs-demo/
├── app/
│   ├── app.py               # Flask web app
│   ├── requirements.txt
│   └── templates/
│       └── index.html
├── Dockerfile               # Multi-stage build
├── scripts/
│   ├── 01-build.sh          # Build Docker image locally
│   └── 02-push.sh           # Authenticate + push to ECR
└── terraform/
    ├── main.tf              # ECR repository
    ├── ecs.tf               # ECS cluster, task definition, service
    ├── variables.tf
    └── outputs.tf
```

---

## Prerequisites

| Tool | Purpose |
|------|---------|
| [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | Push image to ECR |
| [Docker](https://docs.docker.com/get-docker/) | Build image locally |
| [Terraform >= 1.5](https://developer.hashicorp.com/terraform/install) | Create all AWS infrastructure |
| AWS credentials configured | Auth |

---

## Step-by-Step

### Step 1 — Create infrastructure with Terraform

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

This creates:
- ECR repository (with scan on push + lifecycle policy)
- ECS cluster (Fargate)
- ECS task definition (points to ECR image)
- ECS service (runs 1 task with a public IP)
- IAM execution role (lets ECS pull from ECR)
- Security group (opens port 8080)
- CloudWatch log group

### Step 2 — Build the Docker image

```bash
./scripts/01-build.sh
```

### Step 3 — Push to ECR

```bash
./scripts/02-push.sh
```

The push script reads the ECR repository URL directly from Terraform output — no hardcoding needed.

### Step 4 — Get the public IP and open the app

```bash
cd terraform
terraform output
```

Then open: `http://<public-ip>:8080`

| Endpoint | Description |
|----------|-------------|
| `/` | Demo UI |
| `/health` | JSON health check |
| `/info` | Image metadata |

### Step 5 — View logs

```bash
# Copy the logs_command from terraform output and run it, e.g:
aws logs tail /ecs/ecr-demo-app --follow --region us-east-1
```

### Step 6 — Tear down

```bash
cd terraform
terraform destroy
```

Removes everything — ECS service, cluster, ECR repo, IAM role, security group.

---

## Updating the image

When you change the app and want to redeploy:

```bash
./scripts/01-build.sh          # rebuild
./scripts/02-push.sh           # push new image to ECR
cd terraform && terraform apply # force ECS to pull the new image
```

---

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region |
| `repo_name` | `ecr-demo-app` | ECR repo and ECS resource names |
| `environment` | `demo` | Environment tag |
| `container_port` | `8080` | Port the container listens on |
| `task_cpu` | `256` | Fargate CPU units (256 = 0.25 vCPU) |
| `task_memory` | `512` | Fargate memory in MB |
| `max_images` | `10` | ECR lifecycle — images to retain |

Override at apply time:
```bash
terraform apply -var="aws_region=eu-west-1" -var="repo_name=my-app"
```
