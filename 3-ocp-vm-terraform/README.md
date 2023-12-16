

## API token
https://192.168.8.140:8006/#v1:0:=node%2Fpve:4:5::::::
root:mrch

 ssh root@192.168.8.140
 mrch
#登陆到 Proxmox 宿主机，执行如下命令创建角色、用户以及 API Token


pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt"

pveum user add terraform-sam@pve --password sam@pve
pveum aclmod / -user terraform-sam@pve -role TerraformProv
#我这里权限给得比较大 
#pveum aclmod / -user terraform-sam@pve -role Administrator

pveum user token add terraform-sam@pve terraform-token --privsep=0

+--------------+--------------------------------------+
| key          | value                                |
+==============+======================================+
| full-tokenid | terraform-sam@pve!terraform-token    |
+--------------+--------------------------------------+
| info         | {"privsep":"0"}                      |
+--------------+--------------------------------------+
| value        | 3aa9f5d9-0769-44f4-b744-1a2cc4cab759 |
+--------------+--------------------------------------+


exit

#(tf-py310) samshen terraform-pve  (main)(pve-k8s:argocd)$ 
#scp ubuntu-2204-cloud-init-create-ChatGPT.sh root@192.168.8.140:/mnt/pve/NAS/template/iso
#scp ~/.ssh/id_rsa.pub root@192.168.8.140:/mnt/pve/NAS/template/iso

 ssh root@192.168.8.140
#apt-get install libguestfs-tools
cd /mnt/pve/NAS/template/iso

root@pve:/mnt/pve/NAS/template/iso# 
./ubuntu-2204-cloud-init-create-ChatGPT.sh 

exit

(tf-py310) samshen terraform-pve  (main)(pve-k8s:argocd)$ 

export PROXMOX_API_SECRET="3aa9f5d9-0769-44f4-b744-1a2cc4cab759"

### initialise
terraform init --upgrade
terraform fmt
terraform validate

### generate a plan
terraform plan -out oc-master.tfplan
#terraform plan -var-file="credentials.tfvars"

### deploy the VMs 
terraform apply

#create one by one
#terraform apply -parallelism=1 -auto-approve oc-master.tfplan
#-parallelism=n - Limit the number of concurrent operation as Terraform walks the graph. Defaults to 10.

### cleanup
terraform destroy

#terraform plan -destroy -out k8s-master.destroy.tfplan
#terraform apply k8s-master.destroy.tfplan


terraform state list
#####
proxmox_vm_qemu.proxmox-ubuntu[0]

## Openshift OKD

### Sizing
I faced a number of problems while installing OKD, mostly related to lack of resources.
OKD is greedy. If you can’t affort the minimum resources, just move to a resource friendly Kubernetes ochrestrator such as K3S, RKE or RKE2 from SUSE Rancher.

100 GB disk
4 vCPU
16 GB RAM

you really need those resources, otherwise the installation will fail in unpredictable way as all the pods won’t start (DiskPressure, MemoryPressure, …).

### Sizing for production
The main differences if you plan a production setup :

Run dedicated workers (at least 2, better 5 or more), and make the masters «non-schedulable», but not too many. You need the balance between :
A sufficient number of worker nodes to avoid too many re-balance in case of failure.
But not too many small worker nodes that would make the scheduler unable to schedule a new workload requiring significant resources.
In short, start with 3 or 5 Masters and 5 to 7 Workers, then monitor and grow vCPU and RAM instead of multiplying 16 GB Ram nodes. Only add new Worker nodes when you reach 20-25% RAM & Disk from the underlying hardware.
Budget is finite. IMHO better spend it in high-end servers with plenty of ECC RAM and a bunch of good mid-range direct attached NVMe Disks than on virtualization solutions with high licences and replicated SAN costs. You do not need nor want any «live migration» or «replicated snapshots» here, nor any advanced functionality. Just space, CPU count & performance, high disk I/O, high network I/O, low latencies at each level, and local snapshots before upgrades. Still have budget ? Invest in a low latency network.
If you’re still reading, you probably care about High Availability: 3 equivalent sites, 3 dedicated networks. Keep away from any stretch cluster/network/storage or whatever stretched. Backup only things you cannot rebuild quickly, to the next site or off-site. A DR test is everything but «VM migrations» and should succeed to a power off of each power feed alternatively to validate your power distribution, then power off of the 2 power feeds (total power off) to validate the components fail-over. Sorry, I’ve seen so many «DR» Tests miles away from a «D» and a «R», with reports just good enough to keep the myth alive or to justify unnecessary spendings.

### Prerequisites
An SSH public key
Admin access to the local DNS with reverse DNS (examples for Bind9)
RedHat account to get the Pull Secret, plase the key in a pullSecret.txt file.
This tutorial can be used for OCP as well. In this case you also need the RedHat account to download software and the activation key from the bare-metal user-provisioned download page :
https://cloud.redhat.com/openshift/install/metal/user-provisioned
A Linux workstation (or VM) to run the openshift-install installer. This workstation must also be accessible from the cluster, since you’ll run a web server on it to provide ignition files to the CoreOS and scripts. Preferably in the same network.
Hypervisor for 4-10 VMs