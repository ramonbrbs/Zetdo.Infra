# CLAUDE.md - Zetdo Infrastructure Project

## Project Overview
Terraform infrastructure-as-code for the Zetdo SaaS application on Azure.
Three environments (dev, sit, prod) with Container Apps, CosmosDB, Key Vault, and Static Web App per environment.

## Architecture
- **Multi-subscription**: Each environment can be in a different Azure subscription. Shared resources (state, ACR) live in the dev subscription.
- **Modular Terraform**: Shared modules in `modules/`, per-environment configs in `environments/{dev,sit,prod}/`
- **Seed Script**: One-time Azure CLI setup in `scripts/seed.sh` for state storage, OIDC identity, resource groups, and role assignments (no Terraform state)
- **Shared Environment**: ACR managed via CI/CD in `environments/shared/`
- **CI/CD**: GitHub Actions with OIDC authentication (no stored secrets)
- **Container App**: Application container image updated externally via separate repo. Uses managed identity for CosmosDB and Key Vault access.
- **Key Vault**: Per-environment vault with RBAC authorization. Purge protection enabled for prod only.
- **Static Web App**: Angular frontend hosted on Azure Static Web Apps, deployed externally via deployment token
- **Cross-subscription ACR**: Each environment uses `provider "azurerm" alias "shared"` to create ACR role assignments in the dev subscription

## Key Commands

### Seed (one-time, run locally)
```bash
export DEV_SUBSCRIPTION_ID="..."
export SIT_SUBSCRIPTION_ID="..."
export PROD_SUBSCRIPTION_ID="..."
./scripts/seed.sh
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
| shared      | Push when `environments/shared/**` changes | `refs/heads/dev` or `refs/heads/master` |
| dev         | Push/merge to dev    | `refs/heads/dev`     |
| sit         | Push/merge to master | `refs/heads/master`  |
| prod        | Tag matching release-* | `refs/tags/release-*` |

## Naming Convention
- Resources: `{type}-zetdo-{env}-{region}` (e.g., `ca-zetdo-dev-weu`, `kv-zetdo-dev-weu`, `stapp-zetdo-dev-weu`)
- Storage accounts (no hyphens): `stzetdo{purpose}{region}` (e.g., `stzetdotfstateweu`)
- Container Registry: `crzetdo{region}` (e.g., `crzetdoweu`)

## Multi-Subscription Setup
- Seed script takes subscription IDs as environment variables: `DEV_SUBSCRIPTION_ID`, `SIT_SUBSCRIPTION_ID`, `PROD_SUBSCRIPTION_ID`
- Shared resources (state storage, ACR) always go in the dev subscription
- Each environment's `terraform.tfvars` has both `subscription_id` (own) and `shared_subscription_id` (dev)
- `ARM_SUBSCRIPTION_ID` in CI/CD always points to dev subscription (for state backend)
- Provider `subscription_id` in tfvars targets the correct environment subscription

## GitHub Secrets Layout
- **Repo-level**: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SHARED_SUBSCRIPTION_ID`, `ACR_LOGIN_SERVER`
- **Environment-level** (per env): `AZURE_ENV_SUBSCRIPTION_ID`

## Important Constraints
- CosmosDB free tier: only 1 per Azure subscription (assigned to dev)
- CosmosDB access: via managed identity (no keys), role `Cosmos DB Built-in Data Contributor` assigned at environment level
- Container App image: managed externally, protected by `lifecycle { ignore_changes }`
- Key Vault: RBAC authorization, purge protection enabled for prod only. Local access managed manually via `az role assignment create`
- Static Web App: deployed externally via deployment token (`api_key`), Free tier for dev/sit, Standard for prod
- Terraform state: stored in Azure Storage (dev subscription) with OIDC auth
- ACR: shared across all environments (Basic SKU, dev subscription)
- ACR role assignment: created at environment level with `provider = azurerm.shared`
- Region: West Europe (`westeurope`, short: `weu`)
- GitHub repo: `ramonbrbs/zetdo-infra`

## File Structure
- `scripts/seed.sh` - Idempotent Azure CLI script for chicken-and-egg resources (state storage, OIDC identity, RGs, role assignments)
- `environments/shared/` - Shared infrastructure managed via CI/CD (ACR)
- `modules/resource_group/` - Resource group data source
- `modules/container_app/` - Container App + Environment + Log Analytics + Managed Identity
- `modules/cosmosdb/` - CosmosDB account + database
- `modules/key_vault/` - Azure Key Vault with RBAC authorization
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
- Use CosmosDB primary keys in Container App configuration (use managed identity instead)
- Disable Key Vault purge protection in production
