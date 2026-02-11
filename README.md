# Zetdo Infrastructure

Terraform infrastructure-as-code for the Zetdo SaaS application on Microsoft Azure.

## Architecture Overview

```
                    +------------------+
                    |  GitHub Actions  |
                    |  (OIDC Auth)     |
                    +--------+---------+
                             |
              +--------------+--------------+
              |              |              |
    +---------v--------+  +--v-----------+  +-v--------------+
    | Dev Subscription |  | SIT Subscription|  | Prod Subscription|
    +--------+---------+  +-------+--------+  +-------+---------+
             |                    |                    |
    +--------+--+        +-------+---+        +-------+---+
    | Container  |        | Container  |        | Container  |
    | App        |        | App        |        | App        |
    +------------+        +------------+        +------------+
    | Static     |        | Static     |        | Static     |
    | Web App    |        | Web App    |        | Web App    |
    | (Free)     |        | (Free)     |        | (Standard) |
    +------------+        +------------+        +------------+
    | CosmosDB   |        | CosmosDB   |        | CosmosDB   |
    | (Free Tier)|        | (Serverless)|        | (Serverless)|
    +------------+        +------------+        +------------+
```

### Shared Resources (Dev Subscription)
- **Azure Container Registry** (Basic SKU) - shared across all environments
- **Storage Account** - Terraform remote state with per-environment containers
- **Azure AD Application** - Single Service Principal with OIDC federated credentials

### Multi-Subscription Model
Each environment deploys to its own Azure subscription. Shared resources (state storage, ACR, service principal) reside in the dev subscription. Cross-subscription ACR pull is handled via role assignments with an aliased provider.

## Environments

| Environment | Trigger | Branch/Tag | CosmosDB Mode | Static Web App SKU |
|-------------|---------|------------|---------------|--------------------|
| dev | Push to `dev` | `refs/heads/dev` | Free Tier (400 RU/s provisioned) | Free |
| sit | Push to `master` | `refs/heads/master` | Serverless (pay-per-use) | Free |
| prod | Tag `release-*` | `refs/tags/release-*` | Serverless (pay-per-use) | Standard |

## Prerequisites

- Azure CLI installed and authenticated
- Terraform >= 1.5.0
- One Azure subscription per environment (or a single subscription for all three)
- **Owner** or **User Access Administrator** role on each subscription
- A GitHub repository (`ramonbrbs/zetdo-infra`)

## Quick Start

### 1. Seed (one-time setup)

The seed script creates chicken-and-egg infrastructure using Azure CLI: state storage, OIDC identity, resource groups, and role assignments. It's idempotent and safe to re-run.

```bash
# Set subscription IDs
export DEV_SUBSCRIPTION_ID="your-dev-subscription-id"
export SIT_SUBSCRIPTION_ID="your-sit-subscription-id"
export PROD_SUBSCRIPTION_ID="your-prod-subscription-id"

# Run the seed script
./scripts/seed.sh

# Note the outputs - you'll need them for GitHub secrets
```

### 2. Configure GitHub Secrets

From the seed script output, add **repository-level secrets** (Settings > Secrets and variables > Actions):

| Secret (Repository-level) | Value Source |
|----------------------------|-------------|
| `AZURE_CLIENT_ID` | `AZURE_CLIENT_ID` from seed output |
| `AZURE_TENANT_ID` | `AZURE_TENANT_ID` from seed output |
| `AZURE_SHARED_SUBSCRIPTION_ID` | `AZURE_SHARED_SUBSCRIPTION_ID` from seed output (dev subscription) |
| `ACR_LOGIN_SERVER` | `ACR_LOGIN_SERVER` from seed output |

### 3. Configure GitHub Environments

Create four **GitHub Environments** (Settings > Environments):

| Environment | Protection Rules |
|-------------|-----------------|
| `shared` | None |
| `dev` | None |
| `sit` | Optional: require reviewers |
| `prod` | **Required: add at least 1 reviewer** |

Add an **environment-level secret** to each environment:

| Secret (Per Environment) | Value |
|--------------------------|-------|
| `AZURE_ENV_SUBSCRIPTION_ID` | The Azure subscription ID for that specific environment |

This allows each environment to deploy to its own subscription while sharing the same service principal.

### 4. Update terraform.tfvars

Update each environment's `terraform.tfvars` with actual values from the seed script output:
- `environments/dev/terraform.tfvars`
- `environments/sit/terraform.tfvars`
- `environments/prod/terraform.tfvars`

Each file requires:
- `subscription_id` - the environment's own Azure subscription ID
- `shared_subscription_id` - the dev subscription ID (where ACR and state live)
- `acr_id` - the full resource ID of the container registry
- `acr_login_server` - the ACR login server

### 5. Deploy

```bash
# Initialize git and push to trigger CI/CD
git init
git remote add origin git@github.com:ramonbrbs/zetdo-infra.git

# Deploy dev environment
git checkout -b dev
git add -A
git commit -m "Initial infrastructure setup"
git push -u origin dev

# Deploy sit environment
git checkout -b master
git push -u origin master

# Deploy prod environment
git tag release-1.0.0
git push origin release-1.0.0
```

## Deploying the Angular Frontend

The Angular frontend is hosted on **Azure Static Web Apps**. Each environment has its own Static Web App resource (`stapp-zetdo-{env}-weu`). Deployment is managed from the Angular application repository using the deployment token.

### Setup in the Angular repo

1. After `terraform apply`, retrieve the deployment token:
   ```bash
   cd environments/dev
   terraform output -raw static_web_app_api_key
   ```

2. Add it as a GitHub secret in your Angular repo (e.g., `AZURE_STATIC_WEB_APPS_API_TOKEN_DEV`)

3. Use the `Azure/static-web-apps-deploy` GitHub Action:
   ```yaml
   - uses: Azure/static-web-apps-deploy@v1
     with:
       azure_static_web_apps_api_token: ${{ secrets.AZURE_STATIC_WEB_APPS_API_TOKEN_DEV }}
       app_location: "/"
       output_location: "dist/your-app-name/browser"
   ```

Repeat for each environment (sit, prod) with their respective tokens.

## Updating the Application Container

The application container image is managed by a **separate application repository**. The Container App starts with a placeholder image and is updated externally.

### Option A: Repository Dispatch (automated from app repo CI/CD)

Add this step to your application repository's CI/CD pipeline after pushing the image to ACR:

```bash
curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/ramonbrbs/zetdo-infra/dispatches" \
  -d '{
    "event_type": "update-container-image",
    "client_payload": {
      "environment": "dev",
      "image_tag": "sha-abc1234"
    }
  }'
```

### Option B: Manual (workflow_dispatch)

Go to **Actions > "Update Container Image" > Run workflow**, and provide the environment and image tag.

### Image Promotion Pattern

To promote an image across environments, trigger the update workflow with the same tag but different environment:

1. Update dev: `environment=dev`, `image_tag=v1.2.3`
2. Test in dev
3. Update sit: `environment=sit`, `image_tag=v1.2.3`
4. Test in sit
5. Update prod: `environment=prod`, `image_tag=v1.2.3`

## Project Structure

```
.
├── .github/workflows/          # CI/CD pipelines
│   ├── terraform.yml           # Main orchestrator (dev/sit/prod)
│   ├── terraform-shared.yml    # Shared infrastructure workflow
│   ├── _terraform-plan.yml     # Reusable plan workflow
│   ├── _terraform-apply.yml    # Reusable apply workflow
│   └── update-container-image.yml
├── scripts/
│   └── seed.sh                 # Idempotent Azure CLI seed script (one-time setup)
├── modules/                    # Reusable Terraform modules
│   ├── resource_group/         # Resource group data source
│   ├── container_app/          # Container App + Environment + Logging + Identity
│   ├── static_web_app/         # Azure Static Web App for Angular frontend
│   └── cosmosdb/               # CosmosDB account + database
├── environments/               # Per-environment configurations
│   ├── shared/                 # Shared infrastructure (ACR) - CI/CD managed
│   ├── dev/
│   ├── sit/
│   └── prod/
├── CLAUDE.md                   # Claude Code project skills
└── README.md
```

## CI/CD Pipeline Flow

### Pull Request (plan only)
```
PR opened targeting dev/master
  → Resolve target environment (dev or sit)
  → terraform fmt -check
  → terraform init → validate → plan
  → Post plan as PR comment
```

### Push to Branch / Tag (plan + apply)
```
Push to dev/master or tag release-*
  → Resolve environment (dev/sit/prod)
  → terraform plan → upload artifact
  → terraform apply (using saved plan)
  → Output results
```

Production deployments require reviewer approval via GitHub Environment protection rules.

## Resource Naming Conventions

| Resource | Pattern | Example |
|----------|---------|---------|
| Resource Group | `rg-zetdo-{env}-{region}` | `rg-zetdo-dev-weu` |
| Container App Environment | `cae-zetdo-{env}-{region}` | `cae-zetdo-dev-weu` |
| Container App | `ca-zetdo-{env}-{region}` | `ca-zetdo-dev-weu` |
| CosmosDB Account | `cosmos-zetdo-{env}-{region}` | `cosmos-zetdo-dev-weu` |
| Log Analytics | `log-zetdo-{env}-{region}` | `log-zetdo-dev-weu` |
| Managed Identity | `id-zetdo-{env}-{region}` | `id-zetdo-dev-weu` |
| Static Web App | `stapp-zetdo-{env}-{region}` | `stapp-zetdo-dev-weu` |
| Storage Account | `stzetdotfstate{region}` | `stzetdotfstateweu` |
| Container Registry | `crzetdo{region}` | `crzetdoweu` |

## Cost Optimization

| Component | Configuration | Estimated Monthly Cost |
|-----------|---------------|----------------------|
| Container App (per env) | 0.25 CPU, 0.5Gi, scale to 0 | ~$15-25 |
| CosmosDB (dev) | Free tier (400 RU/s, 25GB) | $0 |
| CosmosDB (sit/prod) | Serverless (pay-per-use) | ~$0-5 |
| Static Web App (dev/sit) | Free tier | $0 |
| Static Web App (prod) | Standard tier | ~$9 |
| Container Registry | Basic SKU | ~$5 |
| Storage Account | LRS, state only | ~$1 |
| Log Analytics | Per-GB pricing | ~$5-10 |
| **Total (3 envs)** | | **~$60-90/month** |

## Important Notes

- **Multi-Subscription**: Each environment deploys to its own subscription. Shared resources (ACR, state storage, service principal) live in the dev subscription. The `ARM_SUBSCRIPTION_ID` in CI/CD always points to the dev subscription (for Terraform state access), while each environment's provider targets its own subscription via `subscription_id` in tfvars.
- **CosmosDB Free Tier**: Only 1 per Azure subscription. Assigned to dev. If you already have one, set `cosmosdb_free_tier_enabled = false` in dev's tfvars and use serverless instead.
- **Container Image**: Protected by `lifecycle { ignore_changes }` in Terraform. External updates via `az containerapp update` won't be reverted by `terraform apply`.
- **Static Web App**: Deployed externally via the `api_key` (deployment token). Terraform provisions the resource; the Angular repo deploys content. Free tier for dev/sit, Standard for prod.
- **Cross-Subscription ACR Pull**: Each environment's Container App managed identity gets `AcrPull` on the shared ACR via an aliased provider (`azurerm.shared`).
- **No VNet**: Simplified for MVP. Add VNet integration, private endpoints, and NSGs when needed.
- **OIDC Only**: No Azure credentials stored as GitHub secrets. Authentication uses short-lived tokens via federated identity.
- **Single Subscription**: If using one subscription for all environments, set the same subscription ID everywhere (env vars for seed script, `subscription_id` and `shared_subscription_id` in env tfvars, and all GitHub secrets).
