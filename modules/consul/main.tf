provider "azurerm" {
  features {}
}

provider "helm" {
  kubernetes {
    load_config_file = var.k8sloadconfig != "" ? var.k8sloadconfig : "true"
    host     = var.aks_fqdn
    client_certificate     = base64decode(var.aks_client_cert)
    client_key             = base64decode(var.aks_client_key)
    cluster_ca_certificate = base64decode(var.aks_ca)
  }
}

data "azurerm_client_config" "current" {}

resource "helm_release" "consul" {
  name       = "consul"
  repository = "https://helm.releases.hashicorp.com" 
  chart      = "consul"
  wait       = true
  timeout    = "120"
  namespace  = "default"

  set {
    name  = "global.image"
    value = "consul:1.8.0"
  }
  set {
    name  = "global.imageEnvoy"
    value = "envoyproxy/envoy:v1.13.1"
  }
  set {
  name  = "global.domain"
  value = "consul"
  }
  set {
  name  = "global.datacenter"
  value = "dc-west1"
  }
  set {
  name  = "server.replicas"
  value = "3"
  }
  set {
  name  = "server.bootstrapExpect"
  value = "3"
  }
  set {
  name  = "ui.enabled"
  value = "true"
  }
  set {
  name  = "ui.service.type"
  value = "LoadBalancer"
  }
  set {
  name  = "connectInject.enabled"
  value = "-"
  }
  set {
  name  = "connectInject.default"
  value = "true"
  }
  set {
  name  = "connectInject.centralConfig.defaultProtocol"
  value = "http"
  }
  set {
    name  = "connectInject.centralConfig.proxyDefaults"
    value = jsonencode(
    {
      "envoy_dogstatsd_url": "udp://127.0.0.1:9125"
    })
  }
}