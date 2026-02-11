# Zetdo Infrastructure - Initial Setup Guide

## Overview

This guide walks through deploying the Zetdo infrastructure from scratch. The process has two phases:

1. **Bootstrap** (local) - Creates shared resources: state storage, ACR, OIDC identity, resource groups
2. **CI/CD deployment** (GitHub Actions) - Deploys environment resources: Container App, CosmosDB

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- Terraform >= 1.5.0
- GitHub repository created (`ramonbrbs/Zetdo.Infra`)
- **Owner** or **User Access Administrator** role on your Azure subscription(s)

## Phase 1: Bootstrap (Local)

### 1.1 Configure bootstrap variables

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
```

Edit `bootstrap/terraform.tfvars`:

```hcl
# For single subscription (dev-only), use the same ID for all three:
subscription_ids = {
  dev  = "<your-dev-subscription-id>"
  sit  = "<your-dev-subscription-id>"    # placeholder for now
  prod = "<your-dev-subscription-id>"    # placeholder for now
}
github_org = "ramonbrbs"
```

### 1.2 Run bootstrap

```bash
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### 1.3 Save the outputs

```bash
terraform output
```

This creates:
- `rg-zetdo-tfstate` - Resource group for Terraform state storage
- `rg-zetdo-shared-weu` - Resource group for shared resources (ACR)
- `rg-zetdo-dev-weu` - Resource group for dev environment
- `rg-zetdo-sit-weu` - Resource group for sit environment (placeholder)
- `rg-zetdo-prod-weu` - Resource group for prod environment (placeholder)
- `stzetdotfstateweu` - Storage account with state containers
- `crzetdoweu` - Azure Container Registry (Basic SKU)
- Azure AD App + Service Principal with OIDC federated credentials
- Role assignments (Contributor, AcrPush, Storage Blob Data Contributor)

## Phase 2: GitHub Configuration

### 2.1 Repository-level secrets

Go to **Settings > Secrets and variables > Actions** and add:

| Secret | Value (from `terraform output`) |
|--------|------|
| `AZURE_CLIENT_ID` | `client_id` |
| `AZURE_TENANT_ID` | `tenant_id` |
| `AZURE_SHARED_SUBSCRIPTION_ID` | `shared_subscription_id` |
| `ACR_LOGIN_SERVER` | `container_registry_login_server` |

### 2.2 Create the `dev` environment

Go to **Settings > Environments > New environment**:
- Name: `dev`
- No protection rules

Add an environment-level secret:

| Secret | Value |
|--------|-------|
| `AZURE_ENV_SUBSCRIPTION_ID` | Your dev subscription ID |

### 2.3 Update dev terraform.tfvars

Edit `environments/dev/terraform.tfvars` with values from `terraform output`:

```hcl
subscription_id        = "<your-dev-subscription-id>"
shared_subscription_id = "<your-dev-subscription-id>"
acr_id                 = "<container_registry_id from output>"
acr_login_server       = "<container_registry_login_server from output>"
```

## Phase 3: Deploy Dev via CI/CD

Push to the `dev` branch to trigger the GitHub Actions pipeline:

```bash
git push origin dev
```

The workflow will:
1. Resolve environment as `dev` (from branch name)
2. Run `terraform plan` against `environments/dev/`
3. Run `terraform apply` with the saved plan

Monitor progress in the **Actions** tab of your GitHub repository.

## What Gets Deployed (Dev)

| Resource | Name | Details |
|----------|------|---------|
| Log Analytics Workspace | `log-zetdo-dev-weu` | 30-day retention |
| Container App Environment | `cae-zetdo-dev-weu` | Linked to Log Analytics |
| User-Assigned Managed Identity | `id-zetdo-dev-weu` | For ACR pull |
| Container App | `ca-zetdo-dev-weu` | 0.25 CPU, 0.5Gi, scale 0-2 |
| CosmosDB Account | `cosmos-zetdo-dev-weu` | Free tier (400 RU/s) |
| CosmosDB Database | `zetdo-db` | SQL API |
| ACR Pull Role Assignment | - | Cross-subscription via shared provider |

## Later: Adding SIT and Prod

When ready for additional environments:

1. Update `bootstrap/terraform.tfvars` with real sit/prod subscription IDs, re-run bootstrap
2. Create `sit` and `prod` GitHub environments with their own `AZURE_ENV_SUBSCRIPTION_ID`
3. Update `environments/sit/terraform.tfvars` and `environments/prod/terraform.tfvars`
4. Push to `master` (deploys sit) or tag `release-*` (deploys prod)
