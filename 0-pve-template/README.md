
# create centos template

oc-template-create.sh

# create network bridge
Add 2 new subnet:
1. pve root
Datacenter/pve == System == Network == create

Name    Type            Active Autostart VLAN aware
enp0s25 Nwtwork Device  Yes  No   No
vmbr0   Linux Bridge    Yes  Yes  No     192.168.8.140/24  192.168.8.1  enp0s25
vmbr1   Linux Bridge    Yes  Yes  No     192.168.100.1/24
vmbr2   Linux Bridge    Yes  Yes  No     192.168.2.1/24

vi /etc/network/interfaces
####
auto lo
iface lo inet loopback

iface enp0s25 inet manual

auto vmbr0
iface vmbr0 inet static
        address 192.168.8.140/24
        gateway 192.168.8.1
        bridge-ports enp0s25
        bridge-stp off
        bridge-fd 0

auto vmbr1
iface vmbr1 inet static
        address 192.168.100.1/24
        bridge-ports none
        bridge-stp off
        bridge-fd 0

auto vmbr2
iface vmbr2 inet static
        address 192.168.2.1/24
        bridge-ports none
        bridge-stp off
        bridge-fd 0

        post-up echo 1 > /proc/sys/net/ipv4/ip_forward
        post-up   iptables -t nat -A POSTROUTING -s '192.168.100.0/24' -o vmbr0 -j MASQUERADE
        post-down iptables -t nat -D POSTROUTING -s '192.168.2.0/24' -o vmbr0 -j MASQUERADE
        post-up   iptables -t nat -A POSTROUTING -s '192.168.2.0/24' -o vmbr0 -j MASQUERADE
        post-down iptables -t nat -D POSTROUTING -s '192.168.100.0/24' -o vmbr0 -j MASQUERADE


systemctl restart networking

# setup pfSenseFW
https://192.168.8.2/
admin:mrch


Assign Interfaces first time to allow web UI access
WAN: vtnet1 192.168.100.2/24
LAN: vtnet0 192.168.8.2/24
At first time need switch LAN to vmbr0, so webui can be accessed from macbook
Switch back After add port forward This Firewall 443  to   192.168.100.2 443 


Interfaces/ Interface Assignments
WAN vtnet0  (VM vmbr0) 192.168.8.2/24
LAN vtnet1  (VM vmbr1) 192.168.100.2/24

Interfaces/ WAN(vtnet0)
WAN     Static IPV4    DHCP6    192.168.8.2    WANGW - 192.168.8.1
LAN     Static IPV4    DHCP6    192.168.100.2  

System/ Routing/ Gatways

Firewall/ NAT/ Port Forward
WAN TCP * * 192.168.8.147 443     192.168.100.250 443     openshift webui
WAN TCP * * 192.168.8.147 6443    192.168.100.250 6443    openshift oc access
WAN TCP * * 192.168.8.241 22      192.168.2.196 443       ansible ssh access
WAN TCP * * This Firewall 443     192.168.100.2 443       firewall webui

Firewall/ Rules/ WAN
IPv4 ICMP(echoreq) * *  Firewall(self)  * * none Allow ping on WAN(LAN2)
IPv4 TCP * *            WAN address     443 * none
IPv4 TCP * *            WAN address     80 * none
#4 NAT rules automaticly added by above nat port forward
IPv4 TCP * *            192.168.100.2       443 * none
IPv4 TCP * *            192.168.100.250     443 * none
IPv4 TCP * *            192.168.100.250     6443 * none
IPv4 TCP * *            192.168.2.196       22 * none

Firewall/ Rules/ LAN
