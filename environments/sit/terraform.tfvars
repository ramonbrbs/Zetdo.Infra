# SIT (Stage) Environment Configuration
subscription_id        = "YOUR_SIT_SUBSCRIPTION_ID"
shared_subscription_id = "YOUR_DEV_SUBSCRIPTION_ID"
environment            = "sit"
location_short         = "weu"

# ACR (shared, in dev subscription) - values from bootstrap output
acr_id           = "YOUR_ACR_RESOURCE_ID"
acr_login_server = "crzetdoweu.azurecr.io"

# Container App - minimal for sit
container_image        = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
container_cpu          = 0.25
container_memory       = "0.5Gi"
container_min_replicas = 0
container_max_replicas = 2
container_target_port  = 8080
log_retention_days     = 30

# CosmosDB - SERVERLESS (pay-per-use, cheapest for low traffic)
cosmosdb_free_tier_enabled    = false
cosmosdb_enable_serverless    = true
cosmosdb_throughput           = 400
cosmosdb_single_database_mode = true

# Key Vault
key_vault_purge_protection_enabled = false

# Static Web App - Free tier for sit
static_web_app_sku_tier = "Free"
static_web_app_sku_size = "Free"

# Blob Storage
blob_storage_replication_type = "LRS"
