#!/bin/bash

# usage:
#       ./setup-wireguard-server-debian.sh serverip [subnet]
#
#        serverip   =   remote server with ssh enabled
#        subnet     =   first 3 octets of IPv4 subnet
#                       for example 10.10.10 (will be converted to 10.10.10.0/24)
#
# example:
#       ./setup-wireguard-server-debian.sh 11.22.33.44 10.10.5
#       
#       this will connect to ssh server on 11.22.33.44 and 
#       install and configure a wireguard server with local ip 10.10.5.1
#       
# dependencies:
#       ssh client
#       GNU netcat
#       wireguard-tools

set -e
source colors.sh

[[ -n "$2" ]] && wg_subnet="$2" || wg_subnet="10.10.10"
CONFIRM "Confirm wireguard subnet: ${WHITE}${wg_subnet}.0/24"
read -n 1

INFO "Checking dependencies"
[[ $(nc --help | grep "GNU netcat") ]] || depfail=1
[[ $(which ssh) ]]                     || depfail=1
[[ $(which wg) ]]                      || depfail=1
if [[ "$depfail" = "1" ]]; then
    exit 1;
fi

INFO "Switching debian repos to testing"
ssh root@$1 'cp {/etc/apt/sources.list,/etc/apt/sources.list.prewg}; sed -e "s/buster/testing/g" -e "s/.*security.*//g" -e "s/.*updates.*//g" -e "s/#.*//g" -i /etc/apt/sources.list'

INFO "Updating server packages"
ssh root@$1 'yes | apt-get update'
ssh root@$1 'yes | apt-get -y dist-upgrade'
ssh root@$1 'yes | apt-get -y upgrade'

ssh_port=$(ssh root@$1 'echo $SSH_CONNECTION' | awk '{print $4}')
ssh root@$1 reboot

INFO "Waiting for server to boot up"
while [[ ! $(echo test | nc -w 3 $1 $ssh_port | grep SSH) ]]; do
    sleep 1;
done

INFO "Installing wireguard"
ssh root@$1 'apt-get install -y wireguard wireguard-tools'

INFO "Configuring wireguard"
client_privkey=$(wg genkey)
client_pubkey=$(echo "$client_privkey" | wg pubkey)

server_privkey=$(wg genkey)
server_pubkey=$(echo "$server_privkey" | wg pubkey)
server_port=$((10000 + RANDOM % 65534))

cat <<EOF | ssh root@$1 tee /etc/wireguard/wg0.conf
[Interface]
PrivateKey = $server_privkey
ListenPort = $server_port
SaveConfig = false
Address = ${wg_subnet}.1/24
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# peer
[Peer]
PublicKey = $client_pubkey
AllowedIPs = ${wg_subnet}.2

EOF

# enable ip forwarding
ssh root@$1 'echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/50-ip-forwarding.conf && sysctl -p'
# enable wg
ssh root@$1 'systemctl enable --now wg-quick@wg0.service && reboot'

SUCCESS "Done!"
SUCCESS "Save your client configuration:"

cat <<EOF
[Interface]
Address = ${wg_subnet}.2/24
PrivateKey = $client_privkey

[Peer]
PublicKey = $server_pubkey
AllowedIPs = ${wg_subnet}.0/24
#AllowedIPs = 0.0.0.0/0
Endpoint = $1:$server_port
EOF
