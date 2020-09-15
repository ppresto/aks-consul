
data "azurerm_client_config" "current" {
}

resource "azurerm_resource_group" "aks" {
  name     = "${var.prefix}-${var.MY_RG}"
  location = var.location
}

resource "azurerm_route_table" "example" {
  name                = "${var.prefix}-routetable"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name

  route {
    name                   = "default"
    address_prefix         = "10.100.0.0/14"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.10.1.1"
  }
}

resource "azurerm_virtual_network" "example" {
  name                = "${var.prefix}-network"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "example" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.aks.name
  address_prefix       = "10.1.0.0/22"
  virtual_network_name = "${azurerm_virtual_network.example.name}"
}

resource "azurerm_subnet_route_table_association" "example" {
  subnet_id      = "${azurerm_subnet.example.id}"
  route_table_id = "${azurerm_route_table.example.id}"
}

resource "azurerm_kubernetes_cluster" "example" {
  name                = var.k8s_clustername
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = var.k8s_clustername

  linux_profile {
    admin_username = var.ssh_user

    ssh_key {
      key_data = "${file(var.public_ssh_key_path)}"
      #key_data = file(var.public_ssh_key_path)
    }
  }

  default_node_pool {
    name            = "agentpool"
    #count           = "2"
    vm_size         = "Standard_DS2_v2"
    #os_type         = "Linux"
    os_disk_size_gb = 30
    node_count      = 3


    # Required for advanced networking
    vnet_subnet_id = "${azurerm_subnet.example.id}"
  }


  service_principal {
    client_id     = data.azurerm_client_config.current.client_id
    client_secret = var.ARM_CLIENT_SECRET
  }

  network_profile {
    network_plugin = "azure"
    #dns_service_ip =
    #docker_bridge_cidr =
    #service_cidr = 
  }

  tags = var.my_tags
}