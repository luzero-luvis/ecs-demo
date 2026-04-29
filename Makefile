## ── Config ────────────────────────────────────────────────────────────────────
AWS_REGION  ?= us-east-1
REPO_NAME   ?= ecr-demo-app
IMAGE_NAME  ?= ecr-demo-app
IMAGE_TAG   ?= latest
LOCAL_PORT  ?= 8080
APP_VERSION ?= 1.0.0

ACCOUNT_ID  := $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)
REGISTRY    := $(ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
REPO_URI    := $(REGISTRY)/$(REPO_NAME)
FULL_IMAGE  := $(REPO_URI):$(IMAGE_TAG)

## ── Targets ───────────────────────────────────────────────────────────────────
.PHONY: help all create-repo build auth push pull run clean info

help: ## Show this help
	@echo ""
	@echo "ECR Demo — Makefile targets"
	@echo "────────────────────────────────────────────"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Variables (override with: make <target> AWS_REGION=eu-west-1)"
	@echo "  AWS_REGION=$(AWS_REGION)"
	@echo "  REPO_NAME=$(REPO_NAME)"
	@echo "  IMAGE_TAG=$(IMAGE_TAG)"
	@echo "  LOCAL_PORT=$(LOCAL_PORT)"
	@echo ""

all: create-repo build auth push ## Run the full ECR workflow end-to-end

create-repo: ## Step 1 — Create ECR repository
	@AWS_REGION=$(AWS_REGION) REPO_NAME=$(REPO_NAME) ./scripts/01-create-ecr-repo.sh

build: ## Step 2 — Build Docker image locally
	@IMAGE_NAME=$(IMAGE_NAME) IMAGE_TAG=$(IMAGE_TAG) APP_VERSION=$(APP_VERSION) ./scripts/02-build-image.sh

auth: ## Step 3 — Authenticate Docker to ECR
	@AWS_REGION=$(AWS_REGION) ./scripts/03-authenticate-ecr.sh

push: ## Step 4 — Tag and push image to ECR
	@AWS_REGION=$(AWS_REGION) REPO_NAME=$(REPO_NAME) IMAGE_NAME=$(IMAGE_NAME) IMAGE_TAG=$(IMAGE_TAG) ./scripts/04-push-to-ecr.sh

pull: ## Step 5 — Pull image from ECR and run locally
	@AWS_REGION=$(AWS_REGION) REPO_NAME=$(REPO_NAME) IMAGE_TAG=$(IMAGE_TAG) LOCAL_PORT=$(LOCAL_PORT) ./scripts/05-pull-from-ecr.sh

run: ## Run the local image (no ECR, for quick testing)
	docker run --rm -p $(LOCAL_PORT):8080 \
	  -e APP_VERSION=$(APP_VERSION) \
	  -e ENVIRONMENT=local \
	  $(IMAGE_NAME):$(IMAGE_TAG)

clean: ## Step 6 — Delete images from ECR (keeps repo)
	@AWS_REGION=$(AWS_REGION) REPO_NAME=$(REPO_NAME) ./scripts/06-cleanup.sh

clean-all: ## Step 6 — Delete images AND the ECR repository
	@AWS_REGION=$(AWS_REGION) REPO_NAME=$(REPO_NAME) DELETE_REPO=true ./scripts/06-cleanup.sh

hub-to-ecr: ## Mirror a Docker Hub image to ECR  (DOCKERHUB_IMAGE=nginx:latest make hub-to-ecr)
	@DOCKERHUB_IMAGE=$(DOCKERHUB_IMAGE) AWS_REGION=$(AWS_REGION) REPO_NAME=$(REPO_NAME) ECR_TAG=$(ECR_TAG) \
	  ./scripts/dockerhub-to-ecr.sh

info: ## Show ECR repository info and images
	@echo "Registry : $(REGISTRY)"
	@echo "Repo URI : $(REPO_URI)"
	@echo ""
	@aws ecr describe-images \
	  --repository-name $(REPO_NAME) \
	  --region $(AWS_REGION) \
	  --query 'sort_by(imageDetails,&imagePushedAt)[*].{Tag:imageTags[0],Digest:imageDigest,SizeBytes:imageSizeInBytes,PushedAt:imagePushedAt}' \
	  --output table 2>/dev/null || echo "Repository not found — run: make create-repo"
