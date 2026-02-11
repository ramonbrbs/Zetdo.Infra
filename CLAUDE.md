# CLAUDE.md - Zetdo Infrastructure Project

## Project Overview
Terraform infrastructure-as-code for the Zetdo SaaS application on Azure.
Three environments (dev, sit, prod) with Container Apps, CosmosDB, and Static Web App per environment.

## Architecture
- **Multi-subscription**: Each environment can be in a different Azure subscription. Shared resources (state, ACR) live in the dev subscription.
- **Modular Terraform**: Shared modules in `modules/`, per-environment configs in `environments/{dev,sit,prod}/`
- **Bootstrap**: One-time setup in `bootstrap/` for state storage, ACR, OIDC identity, and env resource groups (across subscriptions)
- **CI/CD**: GitHub Actions with OIDC authentication (no stored secrets)
- **Container App**: Application container image updated externally via separate repo
- **Static Web App**: Angular frontend hosted on Azure Static Web Apps, deployed externally via deployment token
- **Cross-subscription ACR**: Each environment uses `provider "azurerm" alias "shared"` to create ACR role assignments in the dev subscription

## Key Commands

### Bootstrap (one-time, run locally)
```bash
cd bootstrap
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### Environment Operations
```bash
cd environments/dev  # or sit, prod
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### Format and Validate
```bash
terraform fmt -recursive
terraform validate
```

## Environment Mapping
| Environment | Trigger              | Branch/Tag           |
|-------------|----------------------|----------------------|
| dev         | Push/merge to dev    | `refs/heads/dev`     |
| sit         | Push/merge to master | `refs/heads/master`  |
| prod        | Tag matching release-* | `refs/tags/release-*` |

## Naming Convention
- Resources: `{type}-zetdo-{env}-{region}` (e.g., `ca-zetdo-dev-weu`, `stapp-zetdo-dev-weu`)
- Storage accounts (no hyphens): `stzetdo{purpose}{region}` (e.g., `stzetdotfstateweu`)
- Container Registry: `crzetdo{region}` (e.g., `crzetdoweu`)

## Multi-Subscription Setup
- Bootstrap takes a `subscription_ids` map: `{ dev = "...", sit = "...", prod = "..." }`
- Shared resources (state storage, ACR) always go in the dev subscription
- Each environment's `terraform.tfvars` has both `subscription_id` (own) and `shared_subscription_id` (dev)
- `ARM_SUBSCRIPTION_ID` in CI/CD always points to dev subscription (for state backend)
- Provider `subscription_id` in tfvars targets the correct environment subscription

## GitHub Secrets Layout
- **Repo-level**: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SHARED_SUBSCRIPTION_ID`, `ACR_LOGIN_SERVER`
- **Environment-level** (per env): `AZURE_ENV_SUBSCRIPTION_ID`

## Important Constraints
- CosmosDB free tier: only 1 per Azure subscription (assigned to dev)
- Container App image: managed externally, protected by `lifecycle { ignore_changes }`
- Static Web App: deployed externally via deployment token (`api_key`), Free tier for dev/sit, Standard for prod
- Terraform state: stored in Azure Storage (dev subscription) with OIDC auth
- ACR: shared across all environments (Basic SKU, dev subscription)
- ACR role assignment: created at environment level with `provider = azurerm.shared`
- Region: West Europe (`westeurope`, short: `weu`)
- GitHub repo: `ramonbrbs/zetdo-infra`

## File Structure
- `bootstrap/` - One-time setup (state storage, ACR, OIDC identity, env RGs across subscriptions)
- `modules/resource_group/` - Resource group data source
- `modules/container_app/` - Container App + Environment + Log Analytics
- `modules/cosmosdb/` - CosmosDB account + database
- `modules/static_web_app/` - Azure Static Web App for Angular frontend
- `modules/container_registry/` - Azure Container Registry data source (optional, for single-subscription)
- `environments/{dev,sit,prod}/` - Environment-specific Terraform configs
- `.github/workflows/` - CI/CD pipelines

## Do NOT
- Modify container image references in Terraform (they are managed externally)
- Set throughput on CosmosDB SQL databases when using serverless accounts
- Use more than one CosmosDB free tier account per subscription
- Store Azure credentials as GitHub secrets (use OIDC only)
- Manage Static Web App deployment content in Terraform (deployed from Angular repo via `api_key`)
