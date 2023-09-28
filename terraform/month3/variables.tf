variable "rg_location" {
  type        = string
  default     = "eastus"
  description = "Location of the resource group."
}
  
variable "app_name" {
  type        = string
  description = "Name of the Application."
}
 
variable "vm_name" {
  type        = string
  description = "Name of the Virtual Machine."
}
