# CosmosDB Module

Provisions an Azure CosmosDB account with SQL API databases and containers for the Zetdo application.

## Resources Created

- **CosmosDB Account** (`cosmos-zetdo-{env}-{region}`) — SQL API, Session consistency
- **Databases & Containers:**
  - `UserDB` → `UserProfiles` (partition key: `/id`)
  - `CompanyDB` → `Companies` (partition key: `/companyId`)
  - `CustomerDB` → `Customers` (partition key: `/customerId`)
  - `OfferingDB` → `Offerings` (partition key: `/offeringId`)
  - `SaleDB` → `Sales` (partition key: `/saleId`)

All domain containers use a single-container design with a `/type` discriminator field and composite indexes on `(partitionKey, type)`.

## Capacity Modes

| Variable | Description |
|---|---|
| `free_tier_enabled` | Enables CosmosDB free tier (only 1 per Azure subscription) |
| `enable_serverless` | Enables serverless pay-per-request (cannot combine with free tier) |
| `throughput` | RU/s per database in provisioned mode (ignored when serverless) |

### Single Database Mode

When `single_database_mode = true`, all containers are placed under a single `ZetdoDB` database instead of 5 separate databases. This is a cost optimization for environments using provisioned throughput with free tier.

**Why:** CosmosDB free tier includes 1,000 RU/s. With 5 databases at the minimum 400 RU/s each (2,000 RU/s total), only half is covered by the free allowance. Consolidating into one database reduces total throughput to 400 RU/s — fully covered by free tier.

**Impact on outputs:** When enabled, all database name outputs (`database_name`, `company_database_name`, etc.) return `ZetdoDB`. The application must be configured to use this single database name.

| Mode | Databases | Total RU/s | Free Tier Covers |
|---|---|---|---|
| `single_database_mode = false` | 5 × 400 RU/s | 2,000 | 1,000 (paying for 1,000) |
| `single_database_mode = true` | 1 × 400 RU/s | 400 | 400 (fully covered, $0) |

### Recommended Configuration Per Environment

| Environment | Free Tier | Serverless | Single DB Mode | Rationale |
|---|---|---|---|---|
| dev | `true` | `false` | `true` | Maximize free tier savings |
| sit | `false` | `true` | `false` | Pay-per-request, low traffic |
| prod | `false` | `true` | `false` | Pay-per-request, variable load |

## Variables

| Name | Type | Default | Description |
|---|---|---|---|
| `environment` | `string` | — | Environment name (dev, sit, prod) |
| `location` | `string` | — | Azure region |
| `location_short` | `string` | — | Short region code for naming |
| `resource_group_name` | `string` | — | Target resource group |
| `free_tier_enabled` | `bool` | `false` | Enable free tier (1 per subscription) |
| `enable_serverless` | `bool` | `true` | Enable serverless capability |
| `throughput` | `number` | `400` | RU/s per database (provisioned mode only) |
| `single_database_mode` | `bool` | `false` | Consolidate all containers into one database |
| `tags` | `map(string)` | `{}` | Resource tags |

## Outputs

| Name | Description |
|---|---|
| `account_id` | CosmosDB account resource ID |
| `account_name` | CosmosDB account name |
| `endpoint` | CosmosDB account endpoint |
| `primary_key` | Primary key (deprecated — use managed identity) |
| `primary_sql_connection_string` | Connection string (deprecated — use managed identity) |
| `database_name` | UserDB database name (or ZetdoDB in single database mode) |
| `company_database_name` | CompanyDB database name (or ZetdoDB in single database mode) |
| `customer_database_name` | CustomerDB database name (or ZetdoDB in single database mode) |
| `offering_database_name` | OfferingDB database name (or ZetdoDB in single database mode) |
