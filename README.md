# OpenShift Deployment Guide
This guide provides instructions for deploying OpenShift using Terraform, Ansible, and Proxmox.

## Table of Contents

- [Prepare](#prepare)
- [API Token Setup](#api-token-setup)
- [VM Deployment](#vm-deployment)
- [OKD Deployment](#okd-deployment)
- [OCP Deployment](#ocp-deployment)
- [Issues and Fixes](#issues-and-fixes)

## Prepare

- Initialize Terraform
```sh
terraform init --upgrade
terraform fmt
terraform validate
```

- Generate a Plan
```sh
terraform plan -out oc-master.tfplan
# terraform plan -var-file="credentials.tfvars"
```

- Deploy the VMs
```sh
terraform apply
# terraform apply -parallelism=1 -auto-approve oc-master.tfplan
# -parallelism=n - Limit the number of concurrent operations as Terraform walks the graph. Defaults to 10.
```

- Cleanup
```sh
# terraform destroy
# terraform plan -destroy -out k8s-master.destroy.tfplan
# terraform apply k8s-master.destroy.tfplan
terraform state list
```


## API token
ssh root@192.168.8.x

login Proxmox host maching, run command below to create related role,user and token

```bash
pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt"

pveum user add terraform-sam@pve --password sam@pve
pveum aclmod / -user terraform-sam@pve -role TerraformProv
# Alternatively, assign Administrator role
#pveum aclmod / -user terraform-sam@pve -role Administrator

pveum user token add terraform-sam@pve terraform-token --privsep=0

# Example output:
# +--------------+--------------------------------------+
# | key          | value                                |
# +==============+======================================+
# | full-tokenid | terraform-sam@pve!terraform-token    |
# +--------------+--------------------------------------+
# | info         | {"privsep":"0"}                      |
# +--------------+--------------------------------------+
# | value        | 3aa9f5d9-0769-44f4-b744-1a2cc4cab759 |
# +--------------+--------------------------------------+

exit

# Set the Proxmox API secret
export PROXMOX_API_SECRET="3aa9f5d9-0769-44f4-b744-1a2cc4cab759"

```

## VM Deployment
Transfer Scripts and Keys

```bash
scp ubuntu-2204-cloud-init-create-ChatGPT.sh root@192.168.8.x:/mnt/pve/template/iso
scp id_rsa.pub root@192.168.8.x:/mnt/pve/template/iso

ssh root@192.168.8.x
#apt-get install libguestfs-tools
cd /mnt/pve/template/iso
./ubuntu-2204-cloud-init-create-ChatGPT.sh 

exit
```


## OKD Deployment

### 1-okd-vm-terraform
```bash
cd 1-okd-vm-terraform
terraform init
terraform plan
terraform apply
```

### 2-okd-bastion-ansible
```bash
cd 2-okd-bastion-ansible
ansible-playbook playbook-services.yaml
```

### Start bootstrap and master nodes
Start the bootstrap node until the login screen appears, then start the master nodes.

```bash
# ssh into bastion at same time
# service bastion server
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

```

### Approve Pending CSRs
```bash
oc get csr | grep Pending
oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs --no-run-if-empty oc adm certificate approve
```

### Remove bootstrap and start worker nodes
```bash
sudo vi /etc/haproxy/haproxy.cfg  # comment out all lines that contain the word bootstrap
#server      bootstrap 192.168.2.189:6443 check
#server      bootstrap 192.168.2.189:22623 check
sudo systemctl restart haproxy.service

#start the workers # ssh into bastion at same time
#service bastion server
ssh oc@192.168.8.11
openshift-install --dir=install_dir/ wait-for install-complete --log-level=info

#start another terminal
ssh oc@192.168.8.11
export KUBECONFIG=~/install_dir/auth/kubeconfig
```

### Approve CSRs for Worker Nodes
```bash
#Aftert 2 or 3 reboots, the worker nodes will appear to get stuck
#sometimes during master node up, also need approve csr
oc get csr | grep Pending
oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs --no-run-if-empty oc adm certificate approve

#wait for all cluster operators to be properly started
watch -n 5 oc get co
```

### Access OpenShift Console by browser
```bash
export KUBECONFIG=~/install_dir/auth/kubeconfig
oc get nodes

# Add to /etc/hosts on macbook
192.168.8.11 console-openshift-console.apps.okd.example.com
192.168.8.11 oauth-openshift.apps.okd.example.com
192.168.8.11 superset-openshift-operators.apps.okd.example.com
192.168.8.11 api.okd.example.com

# Login
https://console-openshift-console.apps.okd.example.com
kubeadmin : Jd8vx-xI5tC-pBTmY-i6K6T

https://oauth-openshift.apps.okd.example.com/
```


### Check certificate expired date and waiting 24 hours for renew
```bash
[oc@okd-bastion ~]

oc get secret -A -o json | jq -r ' .items[] | select( .metadata.annotations."auth.openshift.io/certificate-not-after" | .!=null and fromdateiso8601<='$( date --date='+1year' +%s )') | "expiration: \( .metadata.annotations."auth.openshift.io/certificate-not-after" ) \( .metadata.namespace ) \( .metadata.name )" ' | sort | column -t

expiration:  2023-12-18T00:21:35Z  openshift-kube-apiserver                    aggregator-client
expiration:  2023-12-18T00:21:35Z  openshift-kube-apiserver-operator           aggregator-client-signer
expiration:  2023-12-18T00:21:37Z  openshift-kube-controller-manager-operator  csr-signer
expiration:  2023-12-18T00:21:37Z  openshift-kube-controller-manager-operator  csr-signer-signer

4 will expire in 24 hours
```

### Openshift OKD changes
```bash
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
```

## OCP Deployment

### 1. ocp-vm-terraform
```bash
cd 3-ocp-vm-terraform
terraform init
#terraform destroy
terraform plan
terraform apply
```

### 2. ocp-bastion-ansible
```bash
cd 4-ocp-bastion-ansible
ansible-playbook playbook-services-ocp.yaml

##if error then fix dns, 8.53 to 8.1
ssh oc@192.168.8.10
ping www.google.com
cat /etc/resolv.conf
[oc@localhost ~]$ cat /etc/resolv.conf 
nameserver 192.168.8.53
nameserver 192.168.8.1
search veganmm.com
```

### 3. Start Bootstrap and Master Nodes
```bash
ssh oc@192.168.8.10
openshift-install --dir=install_dir/ wait-for bootstrap-complete --log-level=info

# SSH into bootstrap
ssh oc@192.168.8.10
ssh core@192.168.100.10
journalctl -b -f -u release-image.service -u bootkube.service

# SSH into master nodes
ssh oc@192.168.8.10
ssh core@192.168.100.11
journalctl -f
```

### 4. Wait for Master Nodes to be Ready
```bash
core@bootstrap(100.10) <-- oc@192.168.8.10  (bastion)
[core@bootstrap ~]$ journalctl -b -f -u release-image.service -u bootkube.service
Dec 17 13:35:34 bootstrap.ocp4.example.com bootkube.sh[7843]: bootkube.service complete
Dec 17 13:35:34 bootstrap.ocp4.example.com systemd[1]: bootkube.service: Deactivated successfully.
Dec 17 13:35:34 bootstrap.ocp4.example.com systemd[1]: bootkube.service: Consumed 7.536s CPU time.

core@master02 <-- oc@192.168.8.10  (bastion)
ssh oc@192.168.8.10 == ssh core@192.168.100.12
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
```

### 5. Delete Bootstrap Node
```bash
sudo vi /etc/haproxy/haproxy.cfg
# Comment out bootstrap lines
# server bootstrap 192.168.100.10:6443 check
# server bootstrap 192.168.100.10:22623 check
sudo systemctl restart haproxy.service

# Shutdown bootstrap VM
pve shutdown bootstrap vm
```
### 6. Start Worker Nodes
```bash
openshift-install --dir=install_dir/ wait-for install-complete --log-level=info

# SSH into worker nodes
ssh oc@192.168.8.10
ssh core@192.168.100.21
journalctl -f

# Approve CSRs
oc get csr | grep Pending
oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs --no-run-if-empty oc adm certificate approve

# Verify nodes
oc get nodes

# wait for all cluster operators to be properly started
watch -n 5 oc get co
```


### 7. Access OpenShift Console
```bash
https://console-openshift-console.apps.ocp4.example.com
https://oauth-openshift.apps.ocp4.example.com/login
kubeadmin : yaIbq-WuzLP-5wkPR-5JPNi


# Add to /etc/hosts on macbook
192.168.8.10 console-openshift-console.apps.ocp4.example.com
192.168.8.10 oauth-openshift.apps.ocp4.example.com
192.168.8.10 superset-openshift-operators.apps.ocp4.example.com
192.168.8.10 api.ocp4.example.com

# setup language
https://console-openshift-console.apps.ocp4.example.com/user-preferences/language
English
```

### 8. Check Certificate Expiration Dates 
```bash
# 24 hours for renew
[oc@ocp-bastion ~]

oc get secret -A -o json | jq -r ' .items[] | select( .metadata.annotations."auth.openshift.io/certificate-not-after" | .!=null and fromdateiso8601<='$( date --date='+1year' +%s )') | "expiration: \( .metadata.annotations."auth.openshift.io/certificate-not-after" ) \( .metadata.namespace ) \( .metadata.name )" ' | sort | column -t

expiration:  2023-12-18T12:53:36Z  openshift-kube-apiserver                    aggregator-client
expiration:  2023-12-18T12:53:36Z  openshift-kube-apiserver-operator           aggregator-client-signer
expiration:  2023-12-18T12:53:38Z  openshift-kube-controller-manager-operator  csr-signer
expiration:  2023-12-18T12:53:38Z  openshift-kube-controller-manager-operator  csr-signer-signer
```
### 9. 24 hours later checking certificate expiration date
```bash
[oc@ocp-bastion ~]$ 
oc get secret -A -o json | jq -r ' .items[] | select( .metadata.annotations."auth.openshift.io/certificate-not-after" | .!=null and fromdateiso8601<='$( date --date='+1year' +%s )') | "expiration: \( .metadata.annotations."auth.openshift.io/certificate-not-after" ) \( .metadata.namespace ) \( .metadata.name )" ' | sort | column -t
expiration:  2024-01-16T13:21:38Z  openshift-config-managed                    kube-controller-manager-client-cert-key
expiration:  2024-01-16T13:21:38Z  openshift-kube-apiserver                    external-loadbalancer-serving-certkey
expiration:  2024-01-16T13:21:38Z  openshift-kube-apiserver                    localhost-serving-cert-certkey
expiration:  2024-01-16T13:21:38Z  openshift-kube-apiserver                    service-network-serving-certkey
expiration:  2024-01-16T13:21:38Z  openshift-kube-controller-manager           kube-controller-manager-client-cert-key
expiration:  2024-01-16T13:21:39Z  openshift-kube-apiserver                    kubelet-client
expiration:  2024-01-16T13:21:51Z  openshift-kube-apiserver                    check-endpoints-client-cert-key
expiration:  2024-01-16T13:21:58Z  openshift-config-managed                    kube-scheduler-client-cert-key
expiration:  2024-01-16T13:21:58Z  openshift-kube-scheduler                    kube-scheduler-client-cert-key
expiration:  2024-01-16T13:21:59Z  openshift-kube-apiserver                    control-plane-node-admin-client-cert-key
expiration:  2024-01-16T13:21:59Z  openshift-kube-apiserver                    internal-loadbalancer-serving-certkey
expiration:  2024-01-17T08:05:39Z  openshift-kube-apiserver                    aggregator-client
expiration:  2024-01-17T08:05:39Z  openshift-kube-apiserver-operator           aggregator-client-signer
expiration:  2024-01-17T08:11:26Z  openshift-kube-controller-manager-operator  csr-signer
expiration:  2024-02-16T08:06:26Z  openshift-kube-controller-manager-operator  csr-signer-signer

Then you can shut down whole cluster
```

### 10. Install argocd operator
```bash
https://console-openshift-console.apps.ocp4.example.com/operatorhub/all-namespaces?keyword=argocd

Install argocd in openshift
1. Home == Projects == Create Project == argocd
2. Operators == OperatorHub == Argo CD == Install
https://console-openshift-console.apps.ocp4.example.com/operatorhub/ns/argocd?keyword=argocd
3. Operators == Installed Operators == Operator details == Argo CD == Argo CD == argocd-sample
https://console-openshift-console.apps.ocp4.example.com/k8s/ns/argocd/operators.coreos.com~v1alpha1~ClusterServiceVersion/argocd-operator.v0.8.0

4. get admin password
Installed Operators == argocd-operator.v0.8.0 == ArgoCD details
secret:argocd-sample-cluster :
     admin.password: NmF1QnpkWXBYZjJKUXlGR1YxSTVrOHJNaEFLRWxaTG4=
###################
echo NmF1QnpkWXBYZjJKUXlGR1YxSTVrOHJNaEFLRWxaTG4= | base64 -d
6auBzdYpXf2JQyFGV1I5k8rMhAKElZLn


Command # 1 --------- 
- Add cluster role to user 
- oc adm policy add-cluster-role-to-user cluster-admin -z openshift-gitops-argocd-application-controller -n openshift-gitops 

Command # 2 --------- 
- Get Argo password 
- argoPass=$(oc get secret/openshift-gitops-cluster -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d)
- echo $argoPass 


argoPass=$(oc get secret/argocd -n argocd  -o jsonpath='{.data.admin\.password}' | base64 -d) && echo $argoPass 

5. login
Networking ==  Routes == argocd-server
https://argocd-sample-server-argocd.apps.ocp4.example.com/
admin: 6auBzdYpXf2JQyFGV1I5k8rMhAKElZLn

add to /etc/hosts of macbook:
192.168.8.10 argocd-sample-server-argocd.apps.ocp4.example.com/

[oc@ocp-bastion ~]$ oc get route -n argocd
NAME                   HOST/PORT                                           PATH   SERVICES               PORT    TERMINATION            WILDCARD
argocd-sample-server   argocd-sample-server-argocd.apps.ocp4.example.com          argocd-sample-server   https   passthrough/Redirect   None

6. authenticate with openshift (reinsall). failed!


oc adm groups new argocdadmins
oc adm groups add-users argocdadmins admin


The spec.dex parameter in the ArgoCD CR is no longer supported from Red Hat OpenShift GitOps v1.10.0 onwards. Consider using the .spec.sso parameter instead.
Operators == Installed Operators == Operator details == Argo CD == Argo CD == argocd-sample

  server:
    resources:
      limits:
        cpu: 500m
        memory: 256Mi
      requests:
        cpu: 125m
        memory: 128Mi
    route:
      enabled: true
  sso:
    dex:
      openShiftOAuth: true
      resources:
        limits:
          cpu: 500m
          memory: 256Mi
        requests:
          cpu: 250m
          memory: 128Mi
    provider: dex

  rbac:
    policy: |
      g, argocdadmins, role:admin
    scopes: '[groups]'

works !

https://oauth-openshift.apps.ocp4.example.com/login
kubeadmin : yaIbq-WuzLP-5wkPR-5JPNi

Username: kube:admin

Issuer: https://argocd-sample-server-argocd.apps.ocp4.example.com/api/dex

Groups:

system:authenticated
system:cluster-admins
```



## Issues and Fixes
### certificate issue:
```bash
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
```