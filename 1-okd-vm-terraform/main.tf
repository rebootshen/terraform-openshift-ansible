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
    "okd-bastion" = { macaddr = "7A:00:00:00:03:08", cores = 4, ram = 16384, vmid = 800, os = "ocp-centos-template", boot = true }
  }
  vm_settings = {
    "master0"      = { macaddr = "7A:00:00:00:03:01", cores = 4, ram = 16384, vmid = 801, os = "pxe-client", boot = false },
    "master1"      = { macaddr = "7A:00:00:00:03:02", cores = 4, ram = 16384, vmid = 802, os = "pxe-client", boot = false },
    "master2"      = { macaddr = "7A:00:00:00:03:03", cores = 4, ram = 16384, vmid = 803, os = "pxe-client", boot = false },
    "worker0"      = { macaddr = "7A:00:00:00:03:04", cores = 2, ram = 16384, vmid = 804, os = "pxe-client", boot = false },
    "worker1"      = { macaddr = "7A:00:00:00:03:05", cores = 2, ram = 16384, vmid = 805, os = "pxe-client", boot = false },
    "worker2"      = { macaddr = "7A:00:00:00:03:06", cores = 2, ram = 16384, vmid = 806, os = "pxe-client", boot = false },
    "bootstrap"    = { macaddr = "7A:00:00:00:03:07", cores = 4, ram = 16384, vmid = 807, os = "pxe-client", boot = false }
  }
  bridge = "vmbr2"
  vlan   = 2
  lxc_settings = {
  }
}

# can separate into oc-master.tf
# Create a new VM from a Full-Clone
resource "proxmox_vm_qemu" "okd-bastion" {
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
    size    = "100G"
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

  ipconfig0 = "ip=192.168.2.196/24,gw=192.168.2.1"
  ipconfig1 = "ip=192.168.8.11/24"

  ciuser     = var.ciuser
  cipassword = var.cipassword
  sshkeys    = <<EOF
  ${var.ssh_key}
  EOF
}

resource "proxmox_vm_qemu" "okd-pxe-nodes" {
  for_each    = local.vm_settings
  name = each.key
  desc = "Openshift OKD VM"
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
    size    = "100G"
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
