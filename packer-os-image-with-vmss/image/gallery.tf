# Create a resource group
resource "azurerm_resource_group" "gallery" {
  name     = "ImageGallery"
  location = "West Europe"
}

resource "azurerm_shared_image_gallery" "gallery" {
  name                = "ImageGallery"
  resource_group_name = azurerm_resource_group.gallery.name
  location            = azurerm_resource_group.gallery.location
}

resource "azurerm_shared_image" "shared_image" {
  name                = "squid-proxy"
  gallery_name        = azurerm_shared_image_gallery.gallery.name
  resource_group_name = azurerm_resource_group.gallery.name
  location            = azurerm_resource_group.gallery.location
  os_type             = "Linux"

  identifier {
    publisher = "bmt-publisher"
    offer     = "squid-proxy"
    sku       = "5.2"
  }
}