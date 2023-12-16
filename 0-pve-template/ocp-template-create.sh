#!/bin/bash

set -x

##############################################################################
# things to double-check:
# 1. user directory
# 2. your SSH key location
# 3. which bridge you assign with the create line (currently set to vmbr100)
# 4. which storage is being utilized (script uses local-zfs)
##############################################################################

# prepare authentication API token
#pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt"
#pveum user add terraform-sam@pve --password sam@pve
#pveum aclmod / -user terraform-sam@pve -role TerraformProv
#pveum user token add terraform-sam@pve terraform-token --privsep=0

# cp to NAS iso folder
#(tf-py310) samshen terraform-pve  (main)(pve-k8s:argocd)$ 
#scp ubuntu-2204-cloud-init-create-ChatGPT.sh root@192.168.8.140:/mnt/pve/NAS/template/iso
#scp ~/.ssh/id_rsa.pub root@192.168.8.140:/mnt/pve/NAS/template/iso
#apt-get install libguestfs-tools

#DISK_IMAGE="jammy-server-cloudimg-amd64.img"
#IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/$DISK_IMAGE"
#DISK_IMAGE="ubuntu-22.04-server-cloudimg-amd64.img"
#IMAGE_URL="https://cloud-images.ubuntu.com/releases/jammy/release/$DISK_IMAGE"
#wget -q "$IMAGE_URL"

#failed to ssh or login, giveup
#DISK_IMAGE="rhcos-live.x86_64.iso"

#init failed, need hook-script
#DISK_IMAGE="ocp-bastion-server.qcow2"
DISK_IMAGE="CentOS-Stream-GenericCloud-9-20231204.0.x86_64.qcow2"
ZFS_DATASET="oc"
VM_ID="9020"
TEMPLATE_NAME="ocp-centos-template"

virt-customize -a "$DISK_IMAGE" --install qemu-guest-agent
virt-customize -a "$DISK_IMAGE" --ssh-inject root:file:/mnt/pve/NAS/template/iso/id_rsa.pub

if qm list | grep -qw "$VM_ID"; then
    qm destroy "$VM_ID"
fi

qm create "$VM_ID" --name "$TEMPLATE_NAME" --memory 4096 --sockets 2 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk "$VM_ID" "$DISK_IMAGE" "$ZFS_DATASET"
qm set "$VM_ID" --scsihw virtio-scsi-pci --scsi0 "$ZFS_DATASET":vm-"$VM_ID"-disk-0
qm resize "$VM_ID" scsi0 32G
qm set "$VM_ID" --boot c --bootdisk scsi0
qm set "$VM_ID" --ide2 "$ZFS_DATASET":cloudinit
qm set "$VM_ID" --serial0 socket --vga serial0
qm set "$VM_ID" --agent enabled=1
qm template "$VM_ID"

echo "Next up, clone VM, then expand the disk"
echo "You also still need to copy ssh keys to the newly cloned VM"