# Dev Environment Configuration
subscription_id        = "YOUR_DEV_SUBSCRIPTION_ID"
shared_subscription_id = "YOUR_DEV_SUBSCRIPTION_ID"
environment            = "dev"
location_short         = "weu"

# ACR (shared, in dev subscription) - values from bootstrap output
acr_id           = "YOUR_ACR_RESOURCE_ID"
acr_login_server = "crzetdoweu.azurecr.io"

# Container App - minimal for dev
container_image        = "mcr.microsoft.com/k8s/demo/hello-app:latest"
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
