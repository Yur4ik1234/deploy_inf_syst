
terraform {
  required_version =  " 1.1.0 "
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.30"
    }
  }
}

provider "azurerm" {
  features {}
}

// Creating resource group
resource "azurerm_resource_group" "res-1" {
    name     = "${var.prefix}-resource_group"
    location = "West Europe"
}


// Creating virtual network
resource "azurerm_virtual_network" "vnet-1"{
  name                = "${var.prefix}-vnet" 
  location            = azurerm_resource_group.res-1.location
  resource_group_name = azurerm_resource_group.res-1.name
  address_space       = ["10.0.0.0/16"]
  
  
}
// Creating subnet 
resource "azurerm_subnet" "subnet-1"{
    name              = "${var.prefix}-sub" 
    resource_group_name = azurerm_resource_group.res-1.name
    virtual_network_name = azurerm_virtual_network.vnet-1.name 
    address_prefixes    = ["10.0.0.0/24"]
  }

// Creating nsg for network 
resource "azurerm_network_security_group" "nsg-1"{
  name                = "${var.prefix}-nsg" 
  location            = azurerm_resource_group.res-1.location
  resource_group_name = azurerm_resource_group.res-1.name

// Allowing ssh
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
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

// Adding nsg to subnet
resource "azurerm_subnet_network_security_group_association" "sub-sec" {
  subnet_id                 = azurerm_subnet.subnet-1.id
  network_security_group_id = azurerm_network_security_group.nsg-1.id
}

// Creating public ip for loadbalancer
resource "azurerm_public_ip" "vip" {
  name                = "test"
  location            = azurerm_resource_group.res-1.location
  resource_group_name = azurerm_resource_group.res-1.name
  allocation_method   = "Static"
  

  tags = {
    environment = "staging"
  }
}
// Creating loadbalancer
resource "azurerm_lb" "lb-1" {
  name                = "lb-1"
  location            = azurerm_resource_group.res-1.location
  resource_group_name = azurerm_resource_group.res-1.name
// Adding public ip to loadbalancer
  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.vip.id
  }

}
// Creating backend address pool which will contain our vmss
resource "azurerm_lb_backend_address_pool" "bpepool" {
  loadbalancer_id     = azurerm_lb.lb-1.id
  name                = "BackEndAddressPool"

 
}
// Creating health probe of loadbalancer
resource "azurerm_lb_probe" "hth-1" {
 resource_group_name = azurerm_resource_group.res-1.name
 loadbalancer_id     = azurerm_lb.lb-1.id
 name                = "ssh-running-probe"
 port                = 80

}
// Creating loadbalancer rule which allow trafic to balancer from 80 port
resource "azurerm_lb_rule" "lbnatrule" {
   resource_group_name            = azurerm_resource_group.res-1.name
   loadbalancer_id                = azurerm_lb.lb-1.id
   name                           = "http"
   protocol                       = "Tcp"
   frontend_port                  = 80
   backend_port                   = 80
   backend_address_pool_ids        = [azurerm_lb_backend_address_pool.bpepool.id]
   frontend_ip_configuration_name = "PublicIPAddress"
   probe_id                       = azurerm_lb_probe.hth-1.id
}
// Creating vmss
resource "azurerm_virtual_machine_scale_set" "vmss-1" {
  name                = "example-vmss"
  resource_group_name = azurerm_resource_group.res-1.name
  location            = azurerm_resource_group.res-1.location
  upgrade_policy_mode = "Manual"
  
  // capacity it is number of instaneces in our vmss
  sku {
   name     = "Standard_DS1_v2"
   tier     = "Standard"
   capacity = 2 

 }

storage_profile_image_reference {
   publisher = "Canonical"
   offer     = "UbuntuServer"
   sku       = "18.04-LTS"
   version   = "latest"
 }

 storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

   storage_profile_data_disk {
    lun           = 0
    caching       = "ReadWrite"
    create_option = "Empty"
    disk_size_gb  = 10
  }

   os_profile {
    computer_name_prefix = "testvm"
    admin_username       = "adminuser"
   }

   os_profile_linux_config {
    disable_password_authentication = true

  ssh_keys {
    path     = "/home/adminuser/.ssh/authorized_keys"
    key_data = file("~/.ssh/id_rsa.pub")
  }

   }
 
  network_profile {
    name    = "vmss-net"
    primary = true


    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.subnet-1.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool.id]
      
    // adding public dns label for our instances
   public_ip_address_configuration{
      name = "pip"
      domain_name_label = "deploy-vmsc-ubuntu"
      idle_timeout =  4
      

   }
     
    }
  }
}
