# Prod Environment Configuration
subscription_id        = "YOUR_PROD_SUBSCRIPTION_ID"
shared_subscription_id = "YOUR_DEV_SUBSCRIPTION_ID"
environment            = "prod"
location_short         = "weu"

# ACR (shared, in dev subscription) - values from bootstrap output
acr_id           = "YOUR_ACR_RESOURCE_ID"
acr_login_server = "crzetdoweu.azurecr.io"

# Container App - low config (upgrade later as needed)
container_image        = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
container_cpu          = 0.25
container_memory       = "0.5Gi"
container_min_replicas = 0
container_max_replicas = 3
container_target_port  = 80
log_retention_days     = 90

# CosmosDB - SERVERLESS (pay-per-use)
cosmosdb_free_tier_enabled = false
cosmosdb_enable_serverless = true
cosmosdb_throughput        = 400
