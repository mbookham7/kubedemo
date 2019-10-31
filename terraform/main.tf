##########################
# Variables              #
##########################
variable "location" {
  default = "northeurope"
}
variable "kubernetesgroup" {
  default = "KubenetesRMGroup"
}
variable "tag" {
  default = "Kubernetes Demo"
}
##########################
# Data Lookups           #
##########################

# reference a custom image
data "azurerm_image" "kubernetesimage" {
  name                = "Kubernetes_Ubuntu_v3"
  resource_group_name = "mb_Kubernetes_Packer_Images"
}

##########################
# Resources              #
##########################

# create resource group
resource "azurerm_resource_group" "kubernetesgroup" {
    name     = "${var.kubernetesgroup}"
    location = "${var.location}"

    tags {
        environment = "${var.tag}"
    }
}
# create a azure workspace
resource "azurerm_log_analytics_workspace" "kubeworkspace" {
  name                = "kube-workspace-0284524-8981123"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.kubernetesgroup.name}"
  sku                 = "Free"
}

# add Containers Log Solution to the azure workspace
resource "azurerm_log_analytics_solution" "test" {
  solution_name         = "Containers"
  location              = "${var.location}"
  resource_group_name   = "${azurerm_resource_group.kubernetesgroup.name}"
  workspace_resource_id = "${azurerm_log_analytics_workspace.kubeworkspace.id}"
  workspace_name        = "${azurerm_log_analytics_workspace.kubeworkspace.name}"

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Containers"
  }
}

# create a network
resource "azurerm_virtual_network" "kubernetesnetwork" {
    name                = "KubernetesVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.kubernetesgroup.name}"

    tags {
        environment = "${var.tag}"
    }
}

# create a subnet
resource "azurerm_subnet" "kubernetessubnet" {
    name                 = "KubernetesSubnet"
    resource_group_name  = "${azurerm_resource_group.kubernetesgroup.name}"
    virtual_network_name = "${azurerm_virtual_network.kubernetesnetwork.name}"
    address_prefix       = "10.0.2.0/24"
}
# create a public ip address
resource "azurerm_public_ip" "kubernetespublicip" {
    name                         = "KubernetesPublicIP"
    location                     = "${var.location}"
    resource_group_name          = "${azurerm_resource_group.kubernetesgroup.name}"
    allocation_method            = "Dynamic"

    tags {
        environment = "${var.tag}"
    }
}

# create a security group
resource "azurerm_network_security_group" "kubernetesnsg" {
    name                = "KubernetesNetworkSecurityGroup"
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.kubernetesgroup.name}"
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "Port_8080"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "8080"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags {
        environment = "${var.tag}"
    }
}

# create a NIC
resource "azurerm_network_interface" "kubernetesnic" {
    name                = "KubernetesNIC"
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.kubernetesgroup.name}"
    network_security_group_id = "${azurerm_network_security_group.kubernetesnsg.id}"

    ip_configuration {
        name                          = "KubernetesNicConfiguration"
        subnet_id                     = "${azurerm_subnet.kubernetessubnet.id}"
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = "${azurerm_public_ip.kubernetespublicip.id}"
    }

    tags {
        environment = "${var.tag}"
    }
}
