# Landing Page Deployment Runbook

Provisions and deploys the production landing page at **`https://zetdo.com`**.

The landing-page source lives in a separate repository (`ramonbrbs/Zetdo.Landing`, Astro). Infrastructure (Azure Static Web App + custom domain binding) is managed from `Zetdo.Infra` via the `landing` Terraform environment.

Single environment (production). No staging. Lives in the **dev Azure subscription** — there is no dedicated landing subscription.

---

## Architecture

| Component | Where | Source |
| --- | --- | --- |
| Resource Group `rg-zetdo-landing-weu` | dev subscription | `scripts/seed.sh` |
| Terraform state container `tfstate-landing` | `stzetdotfstateweu` (dev subscription) | `scripts/seed.sh` |
| OIDC federated credential `github-zetdo-landing-env` | App registration `zetdo-github-actions` | `scripts/seed.sh` |
| Static Web App `stapp-zetdo-landing-weu` (Standard tier) | `rg-zetdo-landing-weu` | `environments/landing/` |
| Custom domain binding `zetdo.com` | Same SWA | `environments/landing/` |
| Site content (Astro `dist/`) | Azure SWA blob | `Zetdo.Landing` repo, `.github/workflows/deploy.yml` |

---

## One-time setup (in order)

### 1. Seed Azure resources

Run locally (any operator with subscription owner rights):

```bash
cd Infra
export DEV_SUBSCRIPTION_ID="..."
export SIT_SUBSCRIPTION_ID="..."
export PROD_SUBSCRIPTION_ID="..."
./scripts/seed.sh
```

The script is idempotent. It now creates:
- The `rg-zetdo-landing-weu` resource group in the dev subscription.
- The `tfstate-landing` blob container in `stzetdotfstateweu`.
- The federated OIDC credential `github-zetdo-landing-env` (subject `repo:ramonbrbs/Zetdo.Infra:environment:landing`).
- Contributor role assignment on the landing RG for the GitHub Actions service principal.

### 2. Create the GitHub Actions environment

In `ramonbrbs/Zetdo.Infra` → **Settings → Environments → New environment**:

- Name: `landing`
- Required reviewers: (optional, production gate)
- Environment secrets: none required (landing reuses `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SHARED_SUBSCRIPTION_ID` from repo-level secrets; the dev subscription ID is hard-coded into `environments/landing/terraform.tfvars`).

### 3. Merge `environments/landing/` to master

First push to `master` triggers `.github/workflows/terraform-landing.yml` → plan → apply → SWA created. The `apply` job prints:

```
Outputs:
  custom_domain_validation_token = "..."     # publish as TXT
  static_web_app_default_host_name = "<random>.azurestaticapps.net"
  static_web_app_url = "https://<random>.azurestaticapps.net"
  static_web_app_api_key = <sensitive>
```

The custom-domain resource will be `Pending` until DNS validates.

### 4. Configure DNS for `zetdo.com`

At the DNS provider for `zetdo.com`, add **two** records:

| Type | Host | Value |
| --- | --- | --- |
| `TXT` | `@` (root) | The `custom_domain_validation_token` Terraform output |
| `ALIAS` / `ANAME` / `A` | `@` (root) | `static_web_app_default_host_name` (or the IP shown in the SWA **Custom domains** blade) |

Apex domains (no subdomain) cannot use `CNAME`; if your DNS provider lacks ALIAS/ANAME support, use the A record IP that Azure shows in the Portal.

Re-run the workflow (`workflow_dispatch`) or wait for the next push to confirm the binding flips to `Ready`. Browse `https://zetdo.com` — should serve the SWA's default placeholder until step 6 deploys real content.

### 5. Wire the deployment token into the landing repo

Extract the token:

```bash
cd Infra/environments/landing
terraform output -raw static_web_app_api_key
```

In `ramonbrbs/Zetdo.Landing` → **Settings → Secrets and variables → Actions → New repository secret**:

- Name: `AZURE_STATIC_WEB_APPS_API_TOKEN`
- Value: (the token above)

### 6. Commit the landing deploy workflow

The workflow file `landing-page/.github/workflows/deploy.yml` is already authored in this repo. Copy/push it to the `Zetdo.Landing` repository's `master` branch. The first push triggers the build-and-deploy job; subsequent pushes redeploy automatically.

---

## Recurring operations

- **Update landing content** → push to `master` on `ramonbrbs/Zetdo.Landing`. The deploy workflow runs `npm ci && npm run build` then uploads `dist/` via `Azure/static-web-apps-deploy@v1`.
- **Update landing infra** → push to `master` on `ramonbrbs/Zetdo.Infra` touching `environments/landing/**` or `modules/static_web_app/**`. PRs run plan-only; merge to master runs apply.
- **Rotate the deployment token** → in the Portal: SWA → **Manage deployment token → Reset**. Re-extract via `terraform refresh && terraform output` and update the landing repo secret.

---

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `terraform plan` fails on `azurerm_static_web_app_custom_domain` with `validation_token` not yet known | TXT record not yet published | Step 4 — add TXT then re-run |
| Custom domain stuck in `Validating` | TXT record not propagated | `dig TXT zetdo.com +short` should return the token; wait for DNS TTL then re-apply |
| Deploy job logs `Deployment Failed: No matching Static Web App found` | Wrong `AZURE_STATIC_WEB_APPS_API_TOKEN` in landing repo | Re-extract and re-set the secret (step 5) |
| `npm ci` fails on the deploy runner | Lockfile drift | Commit a fresh `package-lock.json` to the landing repo |

---

## Rollback

- Content rollback: revert the offending commit on `ramonbrbs/Zetdo.Landing` master — the next push redeploys the prior version.
- Custom domain rollback: comment out `custom_domain_name` in `environments/landing/terraform.tfvars` and apply; the binding is destroyed, the SWA still serves on its default `*.azurestaticapps.net` hostname.
- Full teardown: `terraform destroy` in `environments/landing/` followed by `az group delete --name rg-zetdo-landing-weu --subscription <dev-sub>`. The state container `tfstate-landing` can also be deleted from `stzetdotfstateweu`.
