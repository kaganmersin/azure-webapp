terraform {
  required_version = "= 1.2.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.37.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

data "azurerm_subscription" "subscription" {
}

# ------------------
# Resource Group
# ------------------
resource "azurerm_resource_group" "rg_main" {
  name     = "rg-${var.prefix}-${var.environment}-state"
  location = var.location
}

resource "azurerm_management_lock" "rg_main" {
  name       = "rg-lock-${var.prefix}-${var.environment}-state"
  scope      = azurerm_resource_group.rg_main.id
  lock_level = "CanNotDelete"
  notes      = "Locked for compliance"
}


# ------------------
# Storage
# ------------------
resource "azurerm_storage_account" "state" {
  name                     = "st${var.prefix}${var.environment}state"
  resource_group_name      = azurerm_resource_group.rg_main.name
  location                 = azurerm_resource_group.rg_main.location
  account_kind             = "BlobStorage"
  account_tier             = "Standard"
  account_replication_type = "GRS"
  min_tls_version          = "TLS1_2"

  identity {
    type = "SystemAssigned"
  }

  blob_properties {
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }
}

resource "azurerm_storage_container" "content" {
  name                 = "stc${var.prefix}${var.environment}state"
  storage_account_name = azurerm_storage_account.state.name
  depends_on           = [azurerm_storage_account.state]
}