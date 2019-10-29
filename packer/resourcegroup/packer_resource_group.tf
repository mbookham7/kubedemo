provider "azurerm" {

}


resource "azurerm_resource_group" "kubernetespackerimages" {
    name     = "Kubernetes_Packer_Images"
    location = "northeurope"

    tags {
        environment = "Kubernetes Demo"
    }
}