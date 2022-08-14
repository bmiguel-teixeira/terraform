# Create a resource group
resource "azurerm_resource_group" "scaleset" {
  name     = "scaleset"
  location = "West Europe"
}

resource "azurerm_public_ip" "pip" {
  name                = "acceptanceTestPublicIp1"
  resource_group_name = azurerm_resource_group.scaleset.name
  location            = azurerm_resource_group.scaleset.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = "Production"
  }
}

resource "azurerm_lb" "lb" {
  name                = "lb"
  location            = azurerm_resource_group.scaleset.location
  resource_group_name = azurerm_resource_group.scaleset.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.pip.id
  }

}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "probe" {
  loadbalancer_id     = azurerm_lb.lb.id
  name                = "tcp-probe"
  protocol            = "Tcp"
  port                = 8080
  interval_in_seconds = 5
  number_of_probes    = 1
}

resource "azurerm_lb_rule" "lbrule1" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 8080
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = azurerm_lb_probe.probe.id
  enable_tcp_reset = true
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.bpepool.id]
  depends_on = [
    azurerm_lb_probe.probe
  ]
}

data "template_file" "script" {
  template = file("cloudinit.cfg")
}

data "template_cloudinit_config" "config" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "cloudinit.cfg"
    content_type = "text/cloud-config"
    content      = "${data.template_file.script.rendered}"
  }
}


resource "azurerm_virtual_machine_scale_set" "vmss" {
  name                = "mytestscaleset-1"
  location            = azurerm_resource_group.scaleset.location
  resource_group_name = azurerm_resource_group.scaleset.name

  automatic_os_upgrade = false
  upgrade_policy_mode  = "Manual"
  overprovision        = false

  health_probe_id = azurerm_lb_probe.probe.id
  depends_on = [
    azurerm_lb_probe.probe,
    azurerm_lb_rule.lbrule1
  ]

  sku {
    name     = "Standard_B1s"
    tier     = "Standard"
    capacity = 1
  }

  storage_profile_image_reference   {
    id = "/subscriptions/d48c850e-e7a3-4bb3-ba77-1607e0175732/resourceGroups/ImageGallery/providers/Microsoft.Compute/galleries/ImageGallery/images/squid-proxy/versions/1.0.0"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name_prefix = "squid"
    admin_username       = "myuser"
    custom_data          = "${data.template_cloudinit_config.config.rendered}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/myuser/.ssh/authorized_keys"
      key_data = file("rsa.pub")
    }
  }

  network_profile {
    name    = "terraformnetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "TestIPConfiguration"
      primary                                = true
      subnet_id                              = azurerm_subnet.subnet1.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool.id]
    }
  }
}