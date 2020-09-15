module "aks" {
  source = "../modules/aks"
  prefix= var.PREFIX
  MY_RG= var.MY_RG
  k8s_clustername= var.K8S_CLUSTERNAME
  location = var.LOCATION
  ssh_user = var.SSH_USER
  public_ssh_key_path = var.SSH_USER_PUB_KEY_PATH
  ARM_CLIENT_ID=var.ARM_CLIENT_ID
  ARM_CLIENT_SECRET=var.ARM_CLIENT_SECRET
  ARM_SUBSCRIPTION_ID=var.ARM_SUBSCRIPTION_ID
  ARM_TENANT_ID=var.ARM_TENANT_ID
  my_tags = {
          env = "dev"
          owner = "ppresto"
      }
}

module "consul" {
  source = "../modules/consul"
  k8sloadconfig = "false"
  aks_fqdn = module.aks.fqdn
  aks_ca = module.aks.cluster_ca_certificate
  aks_client_cert = module.aks.client_certificate
  aks_client_key = module.aks.client_key
  ARM_CLIENT_SECRET=var.ARM_CLIENT_SECRET
}

output "aks-fqdn" {
  value = module.aks.fqdn
}

output "azure_aks_cluster_name" {
  value = module.aks.azurerm_kubernetes_cluster_name
}

output "resource_group_name" {
  value = module.aks.resource_group_name
}

output "key_vault_name" {
  value = module.aks.key_vault_name
}

output "key_vault_key_name" {
  value = module.aks.key_vault_key_name
}

output "helm-status" {
  value = module.consul.status
}
output "helm-chart-name" {
  value = module.consul.name
}
output "helm-chart-version" {
  value = module.consul.version
}
output "helm-values" {
  value = module.consul.values
}