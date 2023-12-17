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

## 01-okd-vm-terraform
https://github.com/stratokumulus/proxmox-openshift-setup/blob/main/Readme.md

terraform init
terraform plan
terraform apply

## 02-okd-bastion-ansible
ansible-playbook playbook-services.yaml

## start bootstrap and master nodes
start the bootstrap  # till login screen, then start master
start the masters  # ssh into bastion at same time

#service bastion server
ssh oc@192.168.8.11
openshift-install --dir=install_dir/ wait-for bootstrap-complete --log-level=info

'''
INFO Waiting up to 20m0s (until 7:47PM) for the Kubernetes API at https://api.okd.example.com:6443... 
INFO API v1.25.0-2653+a34b9e9499e6c3-dirty up     
INFO Waiting up to 30m0s (until 7:57PM) for bootstrapping to complete... 
INFO It is now safe to remove the bootstrap resources 
INFO Time elapsed: 18m8s 
'''

#ssh into bootstrap at same time

[Macbook]
ssh oc@192.168.8.11
[oc@okd-bastion ~]$ 
ssh core@192.168.2.189
[core@bootstrap ~]$
journalctl -b -f -u release-image.service -u bootkube.service
'''
Dec 16 23:44:43 bootstrap bootkube.sh[8264]: bootkube.service complete
Dec 16 23:44:43 bootstrap systemd[1]: bootkube.service: Deactivated successfully.
Dec 16 23:44:43 bootstrap systemd[1]: bootkube.service: Consumed 7.037s CPU time.
'''

## if master hit issue:

oc get csr | grep Pending
oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs --no-run-if-empty oc adm certificate approve

######
ssh oc@192.168.8.11
[oc@okd-bastion ~]$ openshift-install --dir=install_dir/ wait-for bootstrap-complete --log-level=info

ssh oc@192.168.8.11
[oc@okd-bastion ~]$ ssh core@192.168.2.189
[core@bootstrap ~]$ journalctl -b -f -u release-image.service -u bootkube.service

[oc@okd-bastion ~]$ ssh core@192.168.2.190
[core@master0 ~]$ journalctl -f

[oc@okd-bastion ~]$ cat /etc/resolv.conf 
search example.com okd.example.com
nameserver 192.168.2.196
nameserver 192.168.8.53
[oc@okd-bastion ~]$ 

[core@master0 ~]$ cat /etc/resolv.conf 
nameserver 192.168.2.196
search okd.example.com

[core@master0 ~]$ ping www.google.com
PING www.google.com (172.217.24.100) 56(84) bytes of data.
64 bytes from sin10s07-in-f100.1e100.net (172.217.24.100): icmp_seq=1 ttl=113 time=31.7 ms


[oc@okd-bastion ~]
export KUBECONFIG=~/install_dir/auth/kubeconfig
oc get nodes
oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs oc adm certificate approve


## remove bootstrap and start worker nodes
#Once I get the bootstrap successful message
sudo vi /etc/haproxy/haproxy.cfg  # comment out all lines that contain the word bootstrap
#server      bootstrap 192.168.2.189:6443 check
#server      bootstrap 192.168.2.189:22623 check
sudo systemctl restart haproxy.service

start the workers # ssh into bastion at same time

#service bastion server
ssh oc@192.168.8.11
openshift-install --dir=install_dir/ wait-for install-complete --log-level=info

#start another terminal
ssh oc@192.168.8.11
export KUBECONFIG=~/install_dir/auth/kubeconfig

#Aftert 2 or 3 reboots, the worker nodes will appear to get stuck
#sometimes during master node up, also need approve csr
oc get csr | grep Pending
oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs --no-run-if-empty oc adm certificate approve

#wait for all cluster operators to be properly started
watch -n 5 oc get co

#command openshift-install wait-for install-complete ... to finish, as it will give you the info you need to connect to your cluster (like the random password for the kubeadmin account).

[oc@lab-valet ~]$ openshift-install --dir=install_dir/ wait-for install-complete --log-level=info
INFO Waiting up to 40m0s (until 10:42PM) for the cluster at https://api.okd.example.com:6443 to initialize... 
INFO Checking to see if there is a route at openshift-console/console... 
INFO Install complete!                                                       
INFO To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/home/oc/install_dir/auth/kubeconfig' 
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.okd.example.com 
INFO Login to the console with user: "kubeadmin", and password: "vI9en-xsM3p-F3fUt-5oZvM" 
INFO Time elapsed: 6s 

## Access by browser
macbook:
sudo vi /etc/hosts
192.168.8.11 console-openshift-console.apps.okd.example.com
192.168.8.11 oauth-openshift.apps.okd.example.com
192.168.8.11 superset-openshift-operators.apps.okd.example.com

192.168.8.11 api.okd.example.com


https://console-openshift-console.apps.okd.example.com 
kubeadmin :  Jd8vx-xI5tC-pBTmY-i6K6T

https://oauth-openshift.apps.okd.example.com/

## check certificate expired date and waiting 24 hours for renew
[oc@okd-bastion ~]

oc get secret -A -o json | jq -r ' .items[] | select( .metadata.annotations."auth.openshift.io/certificate-not-after" | .!=null and fromdateiso8601<='$( date --date='+1year' +%s )') | "expiration: \( .metadata.annotations."auth.openshift.io/certificate-not-after" ) \( .metadata.namespace ) \( .metadata.name )" ' | sort | column -t

expiration:  2023-12-18T00:21:35Z  openshift-kube-apiserver                    aggregator-client
expiration:  2023-12-18T00:21:35Z  openshift-kube-apiserver-operator           aggregator-client-signer
expiration:  2023-12-18T00:21:37Z  openshift-kube-controller-manager-operator  csr-signer
expiration:  2023-12-18T00:21:37Z  openshift-kube-controller-manager-operator  csr-signer-signer

4 will expire in 24 hours

# OCP
## Download URLs
Manual install:
    rhcos-live.x86_64.iso

For PXE
  client: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
  install: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-install-linux.tar.gz
  kernel: https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/rhcos-live-kernel-x86_64
  rootfs: https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/rhcos-live-rootfs.x86_64.img
  initramfs: https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/rhcos-live-initramfs.x86_64.img
  

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
## start bootstrap and master nodes

ssh oc@192.168.8.10
[oc@ocp-bastion ~]$ openshift-install --dir=install_dir/ wait-for bootstrap-complete --log-level=info

ssh oc@192.168.8.10
[oc@ocp-bastion ~]$ ssh core@192.168.100.10
[core@bootstrap ~]$ journalctl -b -f -u release-image.service -u bootkube.service

[oc@ocp-bastion ~]$ ssh core@192.168.100.11
[core@master01 ~]$ journalctl -f

[oc@ocp-bastion ~]$ cat /etc/resolv.conf 
search example.com ocp4.example.com
nameserver 192.168.100.250
nameserver 192.168.8.53

[core@bootstrap ~]$ cat /etc/resolv.conf 
#Generated by NetworkManager
search ocp4.example.com example.com
nameserver 192.168.100.250

[core@master01 ~]$ cat /etc/resolv.conf 
#Generated by NetworkManager
search ocp4.example.com example.com
nameserver 192.168.100.250


## wait master nodes ok
core@bootstrap <-- oc@192.168.8.10  (bastion)
[core@bootstrap ~]$ journalctl -b -f -u release-image.service -u bootkube.service
Dec 17 13:35:34 bootstrap.ocp4.example.com bootkube.sh[7843]: bootkube.service complete
Dec 17 13:35:34 bootstrap.ocp4.example.com systemd[1]: bootkube.service: Deactivated successfully.
Dec 17 13:35:34 bootstrap.ocp4.example.com systemd[1]: bootkube.service: Consumed 7.536s CPU time.

core@master02 <-- oc@192.168.8.10  (bastion)
[core@master02 ~]$ journalctl -x -f


[oc@ocp-bastion ~]$ openshift-install --dir=install_dir/ wait-for bootstrap-complete --log-level=info
INFO Waiting up to 20m0s (until 8:55AM EST) for the Kubernetes API at https://api.ocp4.example.com:6443... 
INFO API v1.27.8+4fab27b up                       
INFO Waiting up to 30m0s (until 9:05AM EST) for bootstrapping to complete... 
INFO It is now safe to remove the bootstrap resources 
INFO Time elapsed: 0s  

Verify:
[oc@ocp-bastion ~]$ export KUBECONFIG=~/install_dir/auth/kubeconfig
[oc@ocp-bastion ~]$ oc get nodes
 NAME                        STATUS   ROLES                  AGE   VERSION
master01.ocp4.example.com   Ready    control-plane,master   22m   v1.27.8+4fab27b
master02.ocp4.example.com   Ready    control-plane,master   22m   v1.27.8+4fab27b
master03.ocp4.example.com   Ready    control-plane,master   22m   v1.27.8+4fab27b
[oc@ocp-bastion ~]$ 

## Delete bootstrap

sudo vi /etc/haproxy/haproxy.cfg 
/bootstrap
wq

sudo systemctl restart haproxy.service

## start worker nodes

Start worker nodes

[oc@ocp-bastion ~]$ openshift-install --dir=install_dir/ wait-for install-complete --log-level=info

Approve csr

[oc@ocp-bastion ~]$ export KUBECONFIG=~/install_dir/auth/kubeconfig
[oc@ocp-bastion ~]$ oc get nodes
NAME                        STATUS   ROLES                  AGE   VERSION
master01.ocp4.example.com   Ready    control-plane,master   51m   v1.27.8+4fab27b
master02.ocp4.example.com   Ready    control-plane,master   52m   v1.27.8+4fab27b
master03.ocp4.example.com   Ready    control-plane,master   52m   v1.27.8+4fab27b
[oc@ocp-bastion ~]$ oc get csr|grep Pending
csr-6db5r                                        15m   kubernetes.io/kube-apiserver-client-kubelet   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper         <none>              Pending
csr-6mztk                                        15m   kubernetes.io/kube-apiserver-client-kubelet   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper         <none>              Pending
csr-7gzjc                                        14m   kubernetes.io/kube-apiserver-client-kubelet   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper         <none>              Pending
csr-qbzts                                        15m   kubernetes.io/kube-apiserver-client-kubelet   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper         <none>              Pending
csr-qqbhh                                        15m   kubernetes.io/kube-apiserver-client-kubelet   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper         <none>              Pending
csr-vknfp                                        33s   kubernetes.io/kube-apiserver-client-kubelet   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper         <none>              Pending
csr-vx9cf                                        15m   kubernetes.io/kube-apiserver-client-kubelet   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper         <none>              Pending
csr-wndhn                                        15s   kubernetes.io/kube-apiserver-client-kubelet   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper         <none>              Pending
[oc@ocp-bastion ~]$ oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs oc adm certificate approve
certificatesigningrequest.certificates.k8s.io/csr-6db5r approved
certificatesigningrequest.certificates.k8s.io/csr-6mztk approved
certificatesigningrequest.certificates.k8s.io/csr-7gzjc approved
certificatesigningrequest.certificates.k8s.io/csr-jl2nv approved
certificatesigningrequest.certificates.k8s.io/csr-qbzts approved
certificatesigningrequest.certificates.k8s.io/csr-qqbhh approved
certificatesigningrequest.certificates.k8s.io/csr-vknfp approved
certificatesigningrequest.certificates.k8s.io/csr-vx9cf approved
certificatesigningrequest.certificates.k8s.io/csr-wndhn approved
[oc@ocp-bastion ~]$ oc get nodes
NAME                        STATUS     ROLES                  AGE   VERSION
master01.ocp4.example.com   Ready      control-plane,master   53m   v1.27.8+4fab27b
master02.ocp4.example.com   Ready      control-plane,master   53m   v1.27.8+4fab27b
master03.ocp4.example.com   Ready      control-plane,master   53m   v1.27.8+4fab27b
worker01.ocp4.example.com   NotReady   worker                 9s    v1.27.8+4fab27b
worker02.ocp4.example.com   NotReady   worker                 13s   v1.27.8+4fab27b
worker03.ocp4.example.com   NotReady   worker                 10s   v1.27.8+4fab27b


[oc@ocp-bastion ~]$ oc get nodes
NAME                        STATUS   ROLES                  AGE   VERSION
master01.ocp4.example.com   Ready    control-plane,master   70m   v1.27.8+4fab27b
master02.ocp4.example.com   Ready    control-plane,master   70m   v1.27.8+4fab27b
master03.ocp4.example.com   Ready    control-plane,master   70m   v1.27.8+4fab27b
worker01.ocp4.example.com   Ready    worker                 17m   v1.27.8+4fab27b
worker02.ocp4.example.com   Ready    worker                 17m   v1.27.8+4fab27b
worker03.ocp4.example.com   Ready    worker                 17m   v1.27.8+4fab27b

#wait for all cluster operators to be properly started
[oc@ocp-bastion ~]$ watch -n 5 oc get co

## Install done
[oc@ocp-bastion ~]$ openshift-install --dir=install_dir/ wait-for install-complete --log-level=info
INFO Waiting up to 40m0s (until 10:03AM EST) for the cluster at https://api.ocp4.example.com:6443 to initialize... 
INFO Checking to see if there is a route at openshift-console/console... 
INFO Install complete!                            
INFO To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/home/oc/install_dir/auth/kubeconfig' 
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.ocp4.example.com 
INFO Login to the console with user: "kubeadmin", and password: "5dpAI-qDn6p-oq3q5-ehHoh" 
INFO Time elapsed: 1m18s 


## OCP login
https://console-openshift-console.apps.ocp4.example.com
kubeadmin : 5dpAI-qDn6p-oq3q5-ehHoh

https://oauth-openshift.apps.ocp4.example.com/login

need add to macbook /etc/hosts
192.168.8.10 console-openshift-console.apps.ocp4.example.com
192.168.8.10 oauth-openshift.apps.ocp4.example.com
192.168.8.10 superset-openshift-operators.apps.ocp4.example.com

192.168.8.10 api.ocp4.example.com

## check certificate expired date and waiting 24 hours for renew
[oc@ocp-bastion ~]

oc get secret -A -o json | jq -r ' .items[] | select( .metadata.annotations."auth.openshift.io/certificate-not-after" | .!=null and fromdateiso8601<='$( date --date='+1year' +%s )') | "expiration: \( .metadata.annotations."auth.openshift.io/certificate-not-after" ) \( .metadata.namespace ) \( .metadata.name )" ' | sort | column -t

expiration:  2023-12-18T12:53:36Z  openshift-kube-apiserver                    aggregator-client
expiration:  2023-12-18T12:53:36Z  openshift-kube-apiserver-operator           aggregator-client-signer
expiration:  2023-12-18T12:53:38Z  openshift-kube-controller-manager-operator  csr-signer
expiration:  2023-12-18T12:53:38Z  openshift-kube-controller-manager-operator  csr-signer-signer


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

### User change:
1. openshift/terraform-openshift-ansible/1-okd-vm-terraform/terraform.tfvars
ciuser     = "oc"
2. openshift/terraform-openshift-ansible/2-okd-bastion-ansible/vars/main.yaml
user:
  name: oc
  home: /home/oc
3. openshift/terraform-openshift-ansible/2-okd-bastion-ansible/ansible.cfg
[defaults]
inventory = inventory/hosts.ini
remote_user = oc

#################

### Domain change:
1. openshift/terraform-openshift-ansible/2-okd-bastion-ansible/vars/main.yaml
dns:
  domain: example.com
  clusterid: okd
2. macbook /etc/hosts
#192.168.8.11 console-openshift-console.apps.okd.homelab.local 
#192.168.8.11 oauth-openshift.apps.okd.homelab.local
#192.168.8.11 superset-openshift-operators.apps.okd.homelab.local
#192.168.8.11 api.okd.homelab.local

192.168.8.11 console-openshift-console.apps.okd.example.com
192.168.8.11 oauth-openshift.apps.okd.example.com
192.168.8.11 superset-openshift-operators.apps.okd.example.com
192.168.8.11 api.okd.example.com

##################

### Bastion Ip change:
1. openshift/terraform-openshift-ansible/2-okd-bastion-ansible/inventory/hosts.ini
[service]
192.168.8.11 new_hostname=lab-valet

2. fpSenseFW
Firewall/ NAT/ Port Forward
WAN TCP * * 192.168.8.11 22      192.168.2.196 443       ansible ssh access

3. macbook /etc/hosts
192.168.8.11 console-openshift-console.apps.okd.example.com
192.168.8.11 oauth-openshift.apps.okd.example.com
192.168.8.11 superset-openshift-operators.apps.okd.example.com
192.168.8.11 api.okd.example.com

### Bastion hostname change:
1. openshift/terraform-openshift-ansible/2-okd-bastion-ansible/vars/main.yaml
valet:
  name: okd-bastion
  ip: 192.168.2.196
  macaddr: 7A:00:00:00:03:08

2. openshift/terraform-openshift-ansible/2-okd-bastion-ansible/inventory/hosts.ini
[service]
192.168.8.11 new_hostname=okd-bastion


# Issues:
## certificate issue:
[core@worker01 ~]$ journalctl -x -f

Dec 17 14:25:17 worker01.ocp4.example.com kubenswrapper[2309]: I1217 14:25:17.571689    2309 log.go:194] http: TLS handshake error from 192.168.100.23:47900: no serving certificate available for the kubelet
Dec 17 14:25:17 worker01.ocp4.example.com kubenswrapper[2309]: I1217 14:25:17.969384    2309 log.go:194] http: TLS handshake error from 192.168.100.23:47906: no serving certificate available for the kubelet
Dec 17 14:25:18 worker01.ocp4.example.com kubenswrapper[2309]: I1217 14:25:18.978130    2309 log.go:194] http: TLS handshake error from 192.168.100.22:45252: no serving certificate available for the kubelet
Dec 17 14:25:21 worker01.ocp4.example.com kubenswrapper[2309]: I1217 14:25:21.003346    2309 log.go:194] http: TLS handshake error from 192.168.100.13:47484: no serving certificate available for the kubelet
Dec 17 14:25:21 worker01.ocp4.example.com kubenswrapper[2309]: I1217 14:25:21.410693    2309 log.go:194] http: TLS handshake error from 192.168.100.23:50050: no serving certificate available for the kubelet
Dec 17 14:25:23 worker01.ocp4.example.com kubenswrapper[2309]: I1217 14:25:23.404572    2309 log.go:194] http: TLS handshake error from 192.168.100.22:45858: no serving certificate available for the kubelet

fix:
approve pending csr
[oc@ocp-bastion ~]$ oc get csr | head
NAME                                             AGE     SIGNERNAME                                    REQUESTOR                                                                         REQUESTEDDURATION   CONDITION
csr-2x6fj                                        24m     kubernetes.io/kubelet-serving                 system:node:worker01.ocp4.example.com                                             <none>              Pending
csr-42hc8                                        12m     kubernetes.io/kube-apiserver-client           system:node:worker01.ocp4.example.com                                             24h                 Approved,Issued
csr-4g97t                                        66m     kubernetes.io/kube-apiserver-client           system:node:master01.ocp4.example.com                                             24h                 Approved,Issued
csr-6db5r                                        39m     kubernetes.io/kube-apiserver-client-kubelet   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper         <none>              Approved,Issued
csr-6mztk                                        40m     kubernetes.io/kube-apiserver-client-kubelet   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper         <none>              Approved,Issued
csr-6qskc                                        77m     kubernetes.io/kube-apiserver-client-kubelet   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper         <none>              Approved,Issued
csr-7gzjc                                        39m     kubernetes.io/kube-apiserver-client-kubelet   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper         <none>              Approved,Issued
csr-8hs72                                        66m     kubernetes.io/kube-apiserver-client           system:node:master03.ocp4.example.com                                             24h                 Approved,Issued
csr-8n8s6                                        77m     kubernetes.io/kubelet-serving                 system:node:master03.ocp4.example.com                                             <none>              Approved,Issued
[oc@ocp-bastion ~]$ oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs oc adm certificate approve
certificatesigningrequest.certificates.k8s.io/csr-2x6fj approved
certificatesigningrequest.certificates.k8s.io/csr-jm5fc approved
certificatesigningrequest.certificates.k8s.io/csr-mms6w approved
certificatesigningrequest.certificates.k8s.io/csr-mrg88 approved
certificatesigningrequest.certificates.k8s.io/csr-rpv4l approved
certificatesigningrequest.certificates.k8s.io/csr-wxshx approved