# =============================================================================
# CosmosDB Account
# =============================================================================
resource "azurerm_cosmosdb_account" "this" {
  name                = "cosmos-zetdo-${var.environment}-${var.location_short}"
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  free_tier_enabled = var.free_tier_enabled

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  # Serverless capability (for sit/prod - cheapest pay-per-use)
  dynamic "capabilities" {
    for_each = var.enable_serverless ? [1] : []
    content {
      name = "EnableServerless"
    }
  }

  public_network_access_enabled         = true
  network_acl_bypass_for_azure_services = true
  local_authentication_disabled         = false

  tags = var.tags
}

# =============================================================================
# Consolidated Database (single_database_mode = true)
# All containers share one database to stay within free tier RU/s allowance.
# =============================================================================
resource "azurerm_cosmosdb_sql_database" "consolidated" {
  count               = var.single_database_mode ? 1 : 0
  name                = "ZetdoDB"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name

  throughput = var.enable_serverless ? null : var.throughput
}

# =============================================================================
# CosmosDB SQL Database - UserDB (multi-database mode only)
# =============================================================================
resource "azurerm_cosmosdb_sql_database" "this" {
  count               = var.single_database_mode ? 0 : 1
  name                = "UserDB"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name

  # Do NOT set throughput when using serverless - it will error.
  # For free tier (provisioned), use 400 RU/s (minimum).
  throughput = var.enable_serverless ? null : var.throughput
}

# =============================================================================
# CosmosDB SQL Container - UserProfiles
# =============================================================================
resource "azurerm_cosmosdb_sql_container" "user_profiles" {
  name                = "UserProfiles"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = var.single_database_mode ? azurerm_cosmosdb_sql_database.consolidated[0].name : azurerm_cosmosdb_sql_database.this[0].name
  partition_key_paths = ["/id"]
}

# =============================================================================
# CosmosDB SQL Database - CompanyDB (multi-database mode only)
# =============================================================================
resource "azurerm_cosmosdb_sql_database" "company_db" {
  count               = var.single_database_mode ? 0 : 1
  name                = "CompanyDB"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name

  throughput = var.enable_serverless ? null : var.throughput
}

# =============================================================================
# CosmosDB SQL Container - Companies (single-container design)
# Stores Company and CompanyUser documents co-located by companyId.
# Partition key: /companyId
#   - Company docs:     companyId == id (self-referential)
#   - CompanyUser docs: companyId == parent company id
# Discriminator field: /type ("Company" | "CompanyUser")
# =============================================================================
resource "azurerm_cosmosdb_sql_container" "companies" {
  name                = "Companies"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = var.single_database_mode ? azurerm_cosmosdb_sql_database.consolidated[0].name : azurerm_cosmosdb_sql_database.company_db[0].name
  partition_key_paths = ["/companyId"]

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    excluded_path {
      path = "/_etag/?"
    }

    composite_index {
      index {
        path  = "/companyId"
        order = "ascending"
      }
      index {
        path  = "/type"
        order = "ascending"
      }
    }
  }
}

# =============================================================================
# CosmosDB SQL Database - CustomerDB (multi-database mode only)
# =============================================================================
resource "azurerm_cosmosdb_sql_database" "customer_db" {
  count               = var.single_database_mode ? 0 : 1
  name                = "CustomerDB"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name

  throughput = var.enable_serverless ? null : var.throughput
}

# =============================================================================
# CosmosDB SQL Container - Customers (single-container design)
# Stores Customer documents partitioned by companyId.
# Partition key: /companyId
#   - Customer docs: companyId == owning company id
# Discriminator field: /type ("Customer")
# =============================================================================
resource "azurerm_cosmosdb_sql_container" "customers" {
  name                = "Customers"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = var.single_database_mode ? azurerm_cosmosdb_sql_database.consolidated[0].name : azurerm_cosmosdb_sql_database.customer_db[0].name
  partition_key_paths = ["/companyId"]

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    excluded_path {
      path = "/_etag/?"
    }

    composite_index {
      index {
        path  = "/companyId"
        order = "ascending"
      }
      index {
        path  = "/type"
        order = "ascending"
      }
    }

    composite_index {
      index {
        path  = "/createdAt"
        order = "descending"
      }
      index {
        path  = "/type"
        order = "ascending"
      }
    }
  }
}

# =============================================================================
# CosmosDB SQL Database - OfferingDB (multi-database mode only)
# =============================================================================
resource "azurerm_cosmosdb_sql_database" "offering_db" {
  count               = var.single_database_mode ? 0 : 1
  name                = "OfferingDB"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name

  throughput = var.enable_serverless ? null : var.throughput
}

# =============================================================================
# CosmosDB SQL Container - Offerings (single-container design)
# Stores Service, Product, and UnitOfMeasure documents partitioned by companyId.
# Partition key: /companyId
#   - Service docs: companyId == owning company id
#   - Product docs: companyId == owning company id
#   - UnitOfMeasure docs: companyId == owning company id
# Discriminator field: /type ("Service" | "Product" | "UnitOfMeasure")
# =============================================================================
resource "azurerm_cosmosdb_sql_container" "offerings" {
  name                = "Offerings"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = var.single_database_mode ? azurerm_cosmosdb_sql_database.consolidated[0].name : azurerm_cosmosdb_sql_database.offering_db[0].name
  partition_key_paths = ["/companyId"]

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    excluded_path {
      path = "/_etag/?"
    }

    composite_index {
      index {
        path  = "/companyId"
        order = "ascending"
      }
      index {
        path  = "/type"
        order = "ascending"
      }
    }

    composite_index {
      index {
        path  = "/createdAt"
        order = "descending"
      }
      index {
        path  = "/type"
        order = "ascending"
      }
    }
  }
}

# =============================================================================
# CosmosDB SQL Database - SaleDB (multi-database mode only)
# =============================================================================
resource "azurerm_cosmosdb_sql_database" "sale_db" {
  count               = var.single_database_mode ? 0 : 1
  name                = "SaleDB"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name

  throughput = var.enable_serverless ? null : var.throughput
}

# =============================================================================
# CosmosDB SQL Container - Sales (single-container design)
# Stores Sale documents partitioned by companyId.
# Partition key: /companyId
#   - Sale docs: companyId == owning company id
# Discriminator field: /type ("Sale")
# =============================================================================
resource "azurerm_cosmosdb_sql_container" "sales" {
  name                = "Sales"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = var.single_database_mode ? azurerm_cosmosdb_sql_database.consolidated[0].name : azurerm_cosmosdb_sql_database.sale_db[0].name
  partition_key_paths = ["/companyId"]

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    excluded_path {
      path = "/_etag/?"
    }

    composite_index {
      index {
        path  = "/companyId"
        order = "ascending"
      }
      index {
        path  = "/type"
        order = "ascending"
      }
    }

    composite_index {
      index {
        path  = "/createdAt"
        order = "descending"
      }
      index {
        path  = "/status"
        order = "ascending"
      }
    }

    composite_index {
      index {
        path  = "/scheduledDate"
        order = "ascending"
      }
      index {
        path  = "/status"
        order = "ascending"
      }
    }
  }
}

# =============================================================================
# CosmosDB SQL Database - CalendarDB (multi-database mode only)
# =============================================================================
resource "azurerm_cosmosdb_sql_database" "calendar_db" {
  count               = var.single_database_mode ? 0 : 1
  name                = "CalendarDB"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name

  throughput = var.enable_serverless ? null : var.throughput
}

# =============================================================================
# CosmosDB SQL Container - Calendars (single-container design)
# Stores Calendar documents partitioned by companyId.
# Partition key: /companyId
#   - Calendar docs: companyId == owning company id
# Discriminator field: /type ("Calendar")
# =============================================================================
resource "azurerm_cosmosdb_sql_container" "calendars" {
  name                = "Calendars"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = var.single_database_mode ? azurerm_cosmosdb_sql_database.consolidated[0].name : azurerm_cosmosdb_sql_database.calendar_db[0].name
  partition_key_paths = ["/companyId"]

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    excluded_path {
      path = "/_etag/?"
    }

    composite_index {
      index {
        path  = "/companyId"
        order = "ascending"
      }
      index {
        path  = "/type"
        order = "ascending"
      }
    }

    composite_index {
      index {
        path  = "/isDefault"
        order = "descending"
      }
      index {
        path  = "/name"
        order = "ascending"
      }
    }
  }
}

# =============================================================================
# CosmosDB SQL Database - StockDB (multi-database mode only)
# =============================================================================
resource "azurerm_cosmosdb_sql_database" "stock_db" {
  count               = var.single_database_mode ? 0 : 1
  name                = "StockDB"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name

  throughput = var.enable_serverless ? null : var.throughput
}

# =============================================================================
# CosmosDB SQL Container - Stock (single-container design)
# Stores Stock documents with embedded StockOperation history,
# partitioned by companyId.
# Partition key: /companyId
#   - Stock docs: companyId == owning company id
# Discriminator field: /type ("Stock")
# =============================================================================
resource "azurerm_cosmosdb_sql_container" "stock" {
  name                = "Stock"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = var.single_database_mode ? azurerm_cosmosdb_sql_database.consolidated[0].name : azurerm_cosmosdb_sql_database.stock_db[0].name
  partition_key_paths = ["/companyId"]

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    excluded_path {
      path = "/_etag/?"
    }

    # Base composite index: companyId + type discriminator
    composite_index {
      index {
        path  = "/companyId"
        order = "ascending"
      }
      index {
        path  = "/type"
        order = "ascending"
      }
    }

    # Stock list query: filter by type + isDeleted, sort/search by productName
    composite_index {
      index {
        path  = "/companyId"
        order = "ascending"
      }
      index {
        path  = "/type"
        order = "ascending"
      }
      index {
        path  = "/isDeleted"
        order = "ascending"
      }
      index {
        path  = "/productName"
        order = "ascending"
      }
    }

    # Stock list with negative filter
    composite_index {
      index {
        path  = "/companyId"
        order = "ascending"
      }
      index {
        path  = "/type"
        order = "ascending"
      }
      index {
        path  = "/isDeleted"
        order = "ascending"
      }
      index {
        path  = "/isNegative"
        order = "ascending"
      }
      index {
        path  = "/productName"
        order = "ascending"
      }
    }

    # Stock by product ID lookup
    composite_index {
      index {
        path  = "/companyId"
        order = "ascending"
      }
      index {
        path  = "/type"
        order = "ascending"
      }
      index {
        path  = "/productId"
        order = "ascending"
      }
      index {
        path  = "/isDeleted"
        order = "ascending"
      }
    }
  }
}
