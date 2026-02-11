# Dev Environment Configuration
subscription_id        = "bb67a95f-185c-4a8b-ae32-9f35da2c9465"
shared_subscription_id = "bb67a95f-185c-4a8b-ae32-9f35da2c9465"
environment            = "dev"
location_short         = "weu"

# ACR (shared, in dev subscription) - values from bootstrap output
acr_id           = "/subscriptions/bb67a95f-185c-4a8b-ae32-9f35da2c9465/resourceGroups/rg-zetdo-shared-weu/providers/Microsoft.ContainerRegistry/registries/crzetdoweu"
acr_login_server = "crzetdoweu.azurecr.io"

# Container App - minimal for dev
container_image        = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
container_cpu          = 0.25
container_memory       = "0.5Gi"
container_min_replicas = 0
container_max_replicas = 2
container_target_port  = 80
log_retention_days     = 30

# CosmosDB - FREE TIER (only 1 per subscription!)
cosmosdb_free_tier_enabled = true
cosmosdb_enable_serverless = false
cosmosdb_throughput        = 400

# Static Web App - Free tier for dev
static_web_app_sku_tier = "Free"
static_web_app_sku_size = "Free"
