terraform {
  required_version = "= 1.2.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.35.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-tm-poc-state"
    storage_account_name = "sttmpocstate"
    container_name       = "stctmpocstate"
    key                  = "web_app.tfstate"
    snapshot             = true
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

resource "azurerm_resource_group" "rg_poc" {
  name     = "rg-${var.application_name}-${var.environment}-${var.location_short}"
  location = var.location
}

resource "azurerm_key_vault" "keyvault" {
  name                        = "kv-${var.application_name}-${var.environment}-${var.location_short}"
  tenant_id                   = var.tenant_id
  location                    = azurerm_resource_group.rg_poc.location
  resource_group_name         = azurerm_resource_group.rg_poc.name
  sku_name                    = "standard"
  enabled_for_disk_encryption = false
}

resource "azurerm_key_vault_access_policy" "keyvault_policy" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = var.tenant_id
  object_id    = azurerm_linux_web_app.app_poc.identity.0.principal_id

  secret_permissions = [
    "Get"
  ]
}

resource "azurerm_key_vault_access_policy" "keyvault_policy_terraform" {
  key_vault_id = azurerm_key_vault.keyvault.id
  tenant_id    = var.tenant_id
  object_id    = "3e7b8ae9-b412-4f80-a8c0-049c066b9c4c"

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Recover",
    "Backup",
    "Purge"
  ]
}

resource "azurerm_key_vault_secret" "secret" {
  depends_on = [
    azurerm_key_vault_access_policy.keyvault_policy_terraform
  ]
  name         = "key"
  value        = "value"
  key_vault_id = azurerm_key_vault.keyvault.id
}


resource "azurerm_service_plan" "asp_poc" {
  name                = "asp-${var.application_name}-${var.environment}-${var.location_short}"
  resource_group_name = azurerm_resource_group.rg_poc.name
  location            = azurerm_resource_group.rg_poc.location
  os_type             = var.sp_os_type
  sku_name            = var.sp_sku_name
}

resource "azurerm_linux_web_app" "app_poc" {
  name                = "app-${var.application_name}-${var.environment}-${var.location_short}"
  resource_group_name = azurerm_resource_group.rg_poc.name
  location            = azurerm_service_plan.asp_poc.location
  service_plan_id     = azurerm_service_plan.asp_poc.id
  https_only          = true

  identity {
    type = "SystemAssigned"
  }

  site_config {

    application_stack {
      python_version = "3.10"
    }
  }

}

resource "random_id" "server" {
  keepers = {
    azi_id = 1
  }

  byte_length = 8
}


resource "azurerm_linux_web_app_slot" "main_slot" {
  name           = random_id.server.hex
  app_service_id = azurerm_linux_web_app.app_poc.id

  site_config {

    application_stack {
      python_version = "3.10"
    }
  }

  app_settings = {
    "secret" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.secret.versionless_id})"
  }
}

resource "azurerm_app_service_source_control" "sourcecontrol" {
  app_id                 = azurerm_linux_web_app.app_poc.id
  repo_url               = "https://github.com/Azure-Samples/msdocs-python-flask-webapp-quickstart"
  branch                 = "master"
  use_manual_integration = true
  use_mercurial          = false
  rollback_enabled       = true
}

resource "azurerm_web_app_active_slot" "active_slot" {
  slot_id = azurerm_linux_web_app_slot.main_slot.id

}

resource "azurerm_monitor_autoscale_setting" "autoscale" {
  name                = "scale-${var.application_name}-${var.environment}-${var.location_short}"
  resource_group_name = azurerm_resource_group.rg_poc.name
  location            = azurerm_resource_group.rg_poc.location
  target_resource_id  = azurerm_service_plan.asp_poc.id

  profile {
    name = "AppServiceMemoryCpuScale"

    capacity {
      default = 2
      minimum = 2
      maximum = 6
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.asp_poc.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
        dimensions {
          name     = "AppName"
          operator = "Equals"
          values   = ["App1"]
        }
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.asp_poc.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 20
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "MemoryPercentage"
        metric_resource_id = azurerm_service_plan.asp_poc.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 75
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "MemoryPercentage"
        metric_resource_id = azurerm_service_plan.asp_poc.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = true
      send_to_subscription_co_administrator = true
      custom_emails                         = ["kagan.mersin@gmail.com"]
    }
  }
}

