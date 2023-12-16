# Prepare

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

## Redhat pull secret
https://console.redhat.com/openshift/install/pull-secret
Download pull secret



# OKD


https://github.com/stratokumulus/proxmox-openshift-setup/blob/main/Readme.md

terraform init
terraform plan
terraform apply

ansible-playbook playbook-services.yaml

start the bootstrap  # till login screen
start the masters  # ssh into bastion at same time

#service bastion server
ssh ansiblebot@192.168.8.241
openshift-install --dir=install_dir/ wait-for bootstrap-complete --log-level=info

'''
INFO Waiting up to 20m0s (until 7:47PM) for the Kubernetes API at https://api.okd.homelab.local:6443... 
INFO API v1.25.0-2653+a34b9e9499e6c3-dirty up     
INFO Waiting up to 30m0s (until 7:57PM) for bootstrapping to complete... 
INFO It is now safe to remove the bootstrap resources 
INFO Time elapsed: 18m8s 
'''



#Once I get the bootstrap successful message
vi /etc/haproxy/haproxy.cfg  # comment out all lines that contain the word bootstrap
#server      bootstrap 192.168.2.189:6443 check
#server      bootstrap 192.168.2.189:22623 check
systemctl restart haproxy.service

start the workers # ssh into bastion at same time

#service bastion server
ssh ansiblebot@192.168.8.241
openshift-install --dir=install_dir/ wait-for install-complete --log-level=info

#start another terminal
ssh ansiblebot@192.168.8.241
export KUBECONFIG=~/install_dir/auth/kubeconfig

#Aftert 2 or 3 reboots, the worker nodes will appear to get stuck
oc get csr | grep Pending
oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs --no-run-if-empty oc adm certificate approve

#wait for all cluster operators to be properly started
watch -n 5 oc get co

#command openshift-install wait-for install-complete ... to finish, as it will give you the info you need to connect to your cluster (like the random password for the kubeadmin account).

[ansiblebot@lab-valet ~]$ openshift-install --dir=install_dir/ wait-for install-complete --log-level=info
INFO Waiting up to 40m0s (until 10:42PM) for the cluster at https://api.okd.homelab.local:6443 to initialize... 
INFO Checking to see if there is a route at openshift-console/console... 
INFO Install complete!                            
INFO To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/home/ansiblebot/install_dir/auth/kubeconfig' 
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.okd.homelab.local 
INFO Login to the console with user: "kubeadmin", and password: "Jd8vx-xI5tC-pBTmY-i6K6T" 
INFO Time elapsed: 16m1s  

macbook:
sudo vi /etc/hosts
192.168.8.241 console-openshift-console.apps.okd.homelab.local
192.168.8.241 oauth-openshift.apps.okd.homelab.local
192.168.8.241 superset-openshift-operators.apps.okd.homelab.local

192.168.8.241 api.okd.homelab.local


https://console-openshift-console.apps.okd.homelab.local 
kubeadmin :  Jd8vx-xI5tC-pBTmY-i6K6T

https://oauth-openshift.apps.okd.homelab.local/


# OCP
## Download URLs
User-provisioned infrastructure: 可下載 OpenShift Installer、CLI 與 Pull secrets(需要登入 Red Hat 註冊帳號權限)
Public OpenShift 4.13 Mirror: 可下載 OpenShift Installer、CLI 與 OPM。
openshift-client-linux.tar.gz: 包含 oc 與 kubectl CLI 工具。
openshift-install-linux.tar.gz: 包含 openshift-install 工具。用於建立 OpenShift auth、igntion 等設定檔案。
opm-linux.tar.gz: 用於管理 Operator Hub 與 mirror 相關 images。
Public RHCOS 4.13 Mirror: 可下載 RHCOS 4.8 相關 VM images。
若手動安裝以下載 rhcos-live.x86_64.iso 為主。若想要控管使用版本，請選擇有標示版本的 live iso。
FET vSphere 安裝請以這方式進行。
若以 PXE 方式安裝，則下載以下映像檔:
rhcos-live-initramfs.x86_64.img
rhcos-live-kernel-x86_64
rhcos-live-rootfs.x86_64.img

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

## OCP login
https://console-openshift-console.apps.ocp4.example.com

https://oauth-openshift.apps.ocp4.example.com/login?then=%2Foauth%2Fauthorize%3Fclient_id%3Dconsole%26redirect_uri%3Dhttps%253A%252F%252Fconsole-openshift-console.apps.ocp4.example.com%252Fauth%252Fcallback%26response_type%3Dcode%26scope%3Duser%253Afull%26state%3D7d7693f6


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