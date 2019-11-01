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

    tags = {
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

    tags = {
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

    tags = {
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

    tags = {
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

    tags = {
        environment = "${var.tag}"
    }
}
# create a VM
resource "azurerm_virtual_machine" "kubernetesvm" {
    name                  = "KubernetesVM"
    location              = "${var.location}"
    resource_group_name   = "${azurerm_resource_group.kubernetesgroup.name}"
    network_interface_ids = ["${azurerm_network_interface.kubernetesnic.id}"]
    vm_size               = "Standard_B2s"

    storage_os_disk {
        name              = "KubernetesOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        id = "${data.azurerm_image.kubernetesimage.id}"
    }

    os_profile {
        computer_name  = "kubemaster"
        admin_username = "kubeuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/kubeuser/.ssh/authorized_keys"
            key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAsoz68oEV52euWKC4LjJXGglQCxE1syUBlEBwmhqZ8KRBeKF2Wu3beX/knhAJP0H0oglI8+FuB4fISPyw6SeMc2vsHQjmEUGJ+UMxVb4vIICj99l5YZU/2Fh2ReoNgVB2cU9Ld7+BawRVRN2bpLEbWq8NDv8i5JYSEGzOiaSD5ydcC3pgAIlhFyV9w+t6q0RzydfPp/AGmdxF0XjHdd5yKPTtNfagSrJry7VZBj+qV6yrJmnxmrGJ7z2RQB0zwORMafl3MZtqQ5nZ5NpShJf0yS+fFct6EN/cETDPcnqr8pVgDWl/OnUxbL6viuvZyZGWJh+rs7DD5RaHtRk+SrMgww== rsa-key-20190423"
        }
    }

    tags = {
        environment = "${var.tag}"
    }
}