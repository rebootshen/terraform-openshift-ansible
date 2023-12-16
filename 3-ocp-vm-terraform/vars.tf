variable "ciuser" {
  type = string
  #default = "ubuntu"
}

variable "cipassword" {
  type      = string
  sensitive = true
}

variable "ssh_key" {
  type = string
}

variable "proxmox_host" {
  type    = string
  default = "pve"
}

variable "template_name" {
  type    = string
  #default = "ocp-centos-template"
}

variable "pm_api_url" {
  type = string
}

variable "pm_api_token_id" {
  type = string
}

variable "pm_api_token_secret" {
  type      = string
  sensitive = true
}