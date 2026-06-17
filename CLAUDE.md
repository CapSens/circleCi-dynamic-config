# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains the global CircleCI dynamic configuration templates for CapSens Rails projects. It provides reusable CircleCI pipeline configurations that are cloned into client projects during CI runs.

## Architecture

### Dynamic Configuration System

This repository uses CircleCI's dynamic config feature (setup workflows):

1. Client projects enable "dynamic config using setup workflows" in CircleCI settings
2. Client projects copy `config.yml.example` to their `.circleci/config.yml`
3. During CI runs, the setup workflow clones this repository and uses the `continuation` orb to run one of the template configurations

### Configuration Templates

Located in `configs/`:

- **rails_terraform.yml**: PostgreSQL-based Rails apps deployed to AWS EKS via Terraform
- **rails_terraform_mysql.yml**: MySQL-based Rails apps deployed to AWS EKS via Terraform
- **rails_config_clever_cloud.yml**: Rails apps deployed to Clever Cloud hosting

All templates support the same core workflows but differ in deployment targets and database configurations.

### Core Workflows

Each template defines 4 conditional workflows controlled by the `action` parameter:

1. **tests** (default): Runs specs and security checks
2. **build-and-deploy**: Builds Docker image and deploys to Kubernetes
3. **deploy**: Deploys existing Docker image to Kubernetes
4. **undeploy**: Tears down Terraform resources

### Key Jobs

**save_and_restore_caches**: Caches bundler gems and yarn packages
**spec**: Runs RSpec tests with parallelism support, uses Redis, PostgreSQL/MySQL, and Elasticsearch services
**security_check**: Runs bundler-audit and brakeman, includes custom CVE ignores and email filtering check
**build**: Creates Docker image using `.dockerdev/Dockerfile`, extracts and uploads assets to S3
**deploy**: Uses Terraform to deploy to EKS, includes kubectl failure logging

### Docker Build System

The `.dockerdev/Dockerfile` uses multi-stage builds:

- **base**: Installs runtime dependencies and configures Ruby environment
- **production-builder**: Installs build dependencies, bundler gems, Node.js, compiles assets
- **production**: Final slim image with compiled artifacts, runs as non-root user

Build arguments control Ruby version, distro, packages, Node.js version, database adapter, and more.

## Common Commands

### Validate Configuration Changes

```bash
# Validate a specific config file
circleci config validate configs/rails_terraform.yml

# Validate all config files (runs in CI)
for f in configs/*.yml; do circleci config validate $f; done
```

### Testing Configuration Changes

To test changes to the templates:

1. Update the template file in `configs/`
2. Push changes to this repository
3. In a client project's `.circleci/config.yml`, update the git clone step to use your branch:
   ```yaml
   git clone -b your-branch-name git@github.com:CapSens/circleCi-dynamic-config.git dynamic_configs
   ```
4. Push to client project to trigger CI with your changes

### Common Parameters

All templates accept these key parameters in the continuation step:

- `project-name`: Must match database username/database in `config/database.yml.ci`
- `ruby-version`: Ruby version (e.g., "3.2.2")
- `bundler-version`: Bundler version or empty for latest
- `tests-parallelism`: Number of parallel test containers (default: 1)
- `packages-to-install`: Space-separated apt packages for Docker image
- `ignored_cves`: Space-separated CVE IDs to ignore in security checks
- `rails-env`: Environment name (staging/production)
- `resource-class`: CircleCI resource class (small/medium/large)

Terraform-specific parameters:
- `ecr-repository`: AWS ECR repository name
- `tfvars`: S3 path to terraform tfvars file
- `k8s-cluster`: EKS cluster name (eks_staging uses "staging" branch of terraform-infra)
- `workspace`: Terraform workspace name
- `assets-bucket`: S3 bucket for compiled assets

## Key Constraints

### Security Checks

The security_check job automatically ignores certain CVEs:
- CVE-2015-9284 if omniauth-rails_csrf_protection is used
- CVE-2020-15237 if Shrine's derivation_endpoint is configured
- CVE-2024-34341 (Trix not used)
- CVE-2023-51763, CVE-2024-37031 (ActiveAdmin < 3.2.0)
- CVE-2024-54133 (ActionPack < 7.0 CSP headers)
- CVE-2025-24293 (ActiveStorage not used)
- CVE-2025-55193 (ActiveRecord < 7.1 terminal-only)

The job also enforces that `:email` is removed from `config/initializers/filter_parameter_logging.rb`.

### Database Configuration

Client projects must provide `config/database.yml.ci` with username and database matching `project-name` parameter.

### Auto-Cancellation

The `auto_cancel_redundant_workflows` job cancels older running workflows from the same user on the same branch to save CI resources.

## Test Parallelism

When `tests-parallelism` > 1:
- RSpec tests are split by timing across parallel containers
- Each pipeline spawns N containers (resource cost multiplier)
- Uses `circleci tests glob` and `circleci tests split --split-by=timings`
- Only enable for projects where test speed improvement justifies the cost

## Deployment Flow

### Terraform Deployments

1. Clones CapSens/terraform-infra repository (staging branch for eks_staging, main otherwise)
2. Downloads tfvars from S3 bucket
3. Configures AWS profile and assumes EKS admin role
4. Initializes kubectl with cluster credentials
5. Runs terraform apply with auto-approve
6. On failure, logs kubectl pod descriptions and container logs

### Assets Handling

For Terraform deployments:
- Assets extracted from built Docker container
- Sprockets assets uploaded to S3 with public-read ACL
- Webpacker packs uploaded if present (skipped if directory missing)
- Cache-Control header set to CACHE_MAX_AGE env var (default: 86400)

For Clever Cloud deployments:
- Assets compiled based on branch (staging/master)
- Uploaded to Cellar S3 endpoint with public-read ACL

## Environment Variables

Required CI environment variables (set in CircleCI contexts):

- **COMMON**: CIRCLE_CI_TOKEN (for workflow cancellation)
- **GithubDev**: GITHUB_TOKEN (for git operations and private gems)
- **AWS_ECR**: AWS credentials for ECR and deployment
- **CLEVER_CLOUD**: AWS credentials for Cellar, CLEVER_SSH_KEY

Project-specific variables can be passed via `required-variables` parameter.
