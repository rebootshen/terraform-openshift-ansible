# can separate into backend.tf
terraform {
  required_version = ">= 1.1.0"
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = ">= 2.9.14"
    }
  }

  backend "local" {
  }
}

# can separate into provider.tf
provider "proxmox" {
  pm_tls_insecure     = true
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret

  pm_log_enable = true
  pm_log_file   = "terraform-plugin-proxmox.log"
  pm_debug      = false
  pm_log_levels = {
    _default    = "warn"
    _capturelog = ""
  }
}

locals {
  vm_settings0 = {
    "ocp-bastion" = { macaddr = "42:8F:8D:9D:03:7B", cores = 4, ram = 16384, vmid = 700, os = "ocp-centos-template", boot = true }
  }
  vm_settings = {
    "master01"      = { macaddr = "C6:A1:86:52:B8:D8", cores = 4, ram = 16384, vmid = 701, os = "pxe-client", boot = false },
    "master02"      = { macaddr = "42:A4:27:90:1F:EF", cores = 4, ram = 16384, vmid = 702, os = "pxe-client", boot = false },
    "master03"      = { macaddr = "DE:33:A3:03:E4:FA", cores = 4, ram = 16384, vmid = 703, os = "pxe-client", boot = false },
    "worker01"      = { macaddr = "7E:27:C0:51:46:42", cores = 4, ram = 8192, vmid = 704, os = "pxe-client", boot = false },
    "worker02"      = { macaddr = "9E:56:08:AD:5E:32", cores = 4, ram = 8192, vmid = 705, os = "pxe-client", boot = false },
    "worker03"      = { macaddr = "22:D7:CF:46:24:70", cores = 4, ram = 8192, vmid = 706, os = "pxe-client", boot = false },
    "bootstrap"     = { macaddr = "16:61:92:B5:49:65", cores = 4, ram = 16384, vmid = 707, os = "pxe-client", boot = false }
  }
  bridge = "vmbr1"
  vlan   = 2
  lxc_settings = {
  }
}

# can separate into oc-master.tf
# Create a new VM from a Full-Clone
resource "proxmox_vm_qemu" "ocp-bastion" {
  for_each    = local.vm_settings0
  name        = each.key
  desc        = "Openshift Share Services"
  target_node = var.proxmox_host
  vmid        = each.value.vmid

  clone       = each.value.os  
  full_clone  = true
  os_type     = "cloud-init"

  #os_type    = "Linux"
  #qemu_os    = "other"
  #pxe        = true
  
  boot       = "order=scsi0;ide2;net0" # "c" by default, which renders the coreos35 clone non-bootable. "cdn" is HD, DVD and Network
  oncreate   = each.value.boot           # start once created
  #onboot     = each.value.boot           # boot on pve start

  # show network ip
  agent   = 1

  cores    = each.value.cores
  #sockets  = 2
  cpu      = "host"
  memory   = each.value.ram
  scsihw   = "virtio-scsi-pci"
  bootdisk = "scsi0"
  hotplug  = 0

  disk {
    slot    = 0
    size    = "80G"
    type    = "scsi"
    storage = "oc"
    # 1 will cause error "Error: VM 100 already running"
    #iothread = 0
  }

  network {
    model  = "virtio"
    bridge = local.bridge
    #tag     = local.vlan
    macaddr = each.value.macaddr
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
    #tag     = local.vlan
  }

  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  ipconfig0 = "ip=192.168.100.250/24,gw=192.168.100.1"
  ipconfig1 = "ip=192.168.8.10/24"

  ciuser     = var.ciuser
  cipassword = var.cipassword
  sshkeys    = <<EOF
  ${var.ssh_key}
  EOF
}

resource "proxmox_vm_qemu" "ocp-pxe-nodes" {
  for_each    = local.vm_settings
  name = each.key
  desc = "Openshift OCP VM"
  target_node = var.proxmox_host
  vmid        = each.value.vmid

  #clone      = each.value.os   #pxe-client not exist, can be empty?
  #full_clone = true
  #os_type = "cloud-init"
  #os_type  = "ubuntu"
  os_type    = "Linux"
  qemu_os    = "other"

  pxe        = true
  
  boot       = "order=scsi0;net0" # "c" by default, which renders the coreos35 clone non-bootable. "cdn" is HD, DVD and Network
  oncreate   = each.value.boot           # start once created
  #onboot     = each.value.boot           # boot on pve start

  # show network ip
  agent   = 0


  cores    = each.value.cores
  #sockets  = 2
  cpu      = "host"
  memory   = each.value.ram
  scsihw   = "virtio-scsi-pci"
  bootdisk = "scsi0"
  hotplug  = 0

  disk {
    slot    = 0
    size    = "80G"
    type    = "scsi"
    storage = "oc"
    # 1 will cause error "Error: VM 100 already running"
    #iothread = 0
  }

  network {
    model  = "virtio"
    bridge = local.bridge
    #tag     = local.vlan
    macaddr = each.value.macaddr
  }

  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  # ciuser     = var.ciuser
  # cipassword = var.cipassword
  # sshkeys    = <<EOF
  # ${var.ssh_key}
  # EOF
}
