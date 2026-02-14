---
name: zetdo-infra
description: Provides full context about the Zetdo infrastructure project. Use when working with Terraform modules, environment configs, Azure resources, CI/CD, or infrastructure decisions.
user-invocable: true
---

# Zetdo Infrastructure Context

Multi-environment Terraform IaC for the Zetdo SaaS application on Azure.

## Architecture

- **3 environments**: dev, sit, prod - each in its own Azure subscription
- **Shared resources** (dev subscription): Terraform state storage, Azure Container Registry (ACR)
- **Per-environment resources**: Container App (backend API), Static Web App (Angular frontend), CosmosDB, Key Vault
- **CI/CD**: GitHub Actions with OIDC authentication (no stored secrets)
- **Bootstrap**: One-time local setup in `bootstrap/` for state storage, ACR, OIDC identity, and resource groups

## File Structure

```
bootstrap/                    # One-time setup (state storage, ACR, OIDC, RGs)
modules/
  resource_group/             # Data source for existing RGs
  container_app/              # Container App + Environment + Log Analytics + Managed Identity
  cosmosdb/                   # CosmosDB account + database (managed identity access)
  key_vault/                  # Azure Key Vault with RBAC authorization
  static_web_app/             # Azure Static Web App for Angular frontend
  container_registry/         # ACR data source (optional)
environments/
  dev/                        # Dev environment config
  sit/                        # SIT environment config
  prod/                       # Prod environment config
.github/workflows/            # CI/CD pipelines
```

Each environment directory has: `main.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars`.

## Naming Convention

Pattern: `{type}-zetdo-{env}-{region}` (region: `weu` = westeurope)

| Resource | Prefix | Example |
|----------|--------|---------|
| Resource Group | `rg-` | `rg-zetdo-dev-weu` |
| Container App | `ca-` | `ca-zetdo-dev-weu` |
| Container App Env | `cae-` | `cae-zetdo-dev-weu` |
| Static Web App | `stapp-` | `stapp-zetdo-dev-weu` |
| CosmosDB | `cosmos-` | `cosmos-zetdo-dev-weu` |
| Log Analytics | `log-` | `log-zetdo-dev-weu` |
| Managed Identity | `id-` | `id-zetdo-dev-weu` |
| Storage Account | `stzetdo` | `stzetdotfstateweu` (no hyphens) |
| Key Vault | `kv-` | `kv-zetdo-dev-weu` |
| Container Registry | `crzetdo` | `crzetdoweu` (no hyphens) |

## Environment Mapping

| Environment | Trigger | Branch/Tag |
|-------------|---------|------------|
| dev | Push to dev | `refs/heads/dev` |
| sit | Push to master | `refs/heads/master` |
| prod | Tag release-* | `refs/tags/release-*` |

## Key Commands

```bash
# Bootstrap (one-time, local)
cd bootstrap && terraform init && terraform plan -var-file=terraform.tfvars

# Environment operations
cd environments/dev && terraform init && terraform plan -var-file=terraform.tfvars

# Format & validate
terraform fmt -recursive
terraform validate
```

## Multi-Subscription Setup

- Bootstrap: `subscription_ids` map `{ dev, sit, prod }`
- Environments: `subscription_id` (own) + `shared_subscription_id` (dev, for state backend)
- Cross-subscription ACR pull: aliased provider `azurerm.shared` + role assignment at environment level
- CI/CD `ARM_SUBSCRIPTION_ID` always points to dev subscription

## Module Patterns

When creating new modules, follow these conventions:
- Use `resource "azurerm_*" "this"` for the primary resource
- Standard variables: `environment`, `location`, `location_short`, `resource_group_name`, `tags`
- Tags passed from parent: `local.tags = { project = "zetdo", environment = var.environment, managed_by = "terraform" }`
- Output resource id, name, and relevant URLs
- Mark sensitive outputs with `sensitive = true`
- Environment-level variables use `{module_prefix}_{attribute}` naming (e.g., `static_web_app_sku_tier`)

## Critical Constraints

- CosmosDB free tier: only 1 per subscription (assigned to dev)
- CosmosDB access: managed identity (no keys), `Cosmos DB Built-in Data Contributor` role at environment level
- Container App image: managed externally, protected by `lifecycle { ignore_changes }`
- Key Vault: RBAC authorization, purge protection enabled for prod only
- Static Web App: deployed externally via `api_key` deployment token
- ACR: shared Basic SKU in dev subscription
- Providers in environments use `resource_provider_registrations = "none"` (SP has RG-level Contributor only)
- `Microsoft.App` and `Microsoft.KeyVault` explicitly registered in seed script; `Microsoft.Web` auto-registered by AzureRM provider
- GitHub repo: `ramonbrbs/zetdo-infra`

## GitHub Secrets

- **Repo-level**: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SHARED_SUBSCRIPTION_ID`, `ACR_LOGIN_SERVER`
- **Environment-level**: `AZURE_ENV_SUBSCRIPTION_ID` (per env)
- **Angular repo**: `AZURE_STATIC_WEB_APPS_API_TOKEN_{ENV}` (per env, from Terraform output)

## Instructions
Update documentation after doing relevant changes to the infrastructure.