#!/bin/bash

apt -y install pwgen
apt -y install gpw
apt -y install sudo
apt -y install tor
apt -y install python

#Включаем модули iptables
modprobe ip_gre
modprobe ip_nat_pptp



networkinterface=$(ip link | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}')

wan=$(ip -f inet -o addr show $networkinterface|cut -d\  -f 7 | cut -d/ -f 1)
wlan=$(ip -f inet -o addr show wlan0|cut -d\  -f 7 | cut -d/ -f 1)
ppp1=$(/sbin/ip route | awk '/default/ { print $3 }')
ip=$(dig +short myip.opendns.com @resolver1.opendns.com)

# Installing pptpd
echo "Installing PPTPD"
sudo apt-get install pptpd -y

# edit DNS
echo "Setting Google DNS"
sudo echo "ms-dns 208.67.220.220" >> /etc/ppp/pptpd-options
sudo echo "ms-dns 208.67.222.222" >> /etc/ppp/pptpd-options



# Edit PPTP Configuration
echo "Editing PPTP Configuration"
remote="$ppp1"
remote+="00-200"
sudo echo "localip $ppp1" >> /etc/pptpd.conf
sudo echo "remoteip $remote" >> /etc/pptpd.conf

# Enabling IP forwarding in PPTP server
echo "Enabling IP forwarding in PPTP server"
sudo echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sudo sysctl -p

# Tinkering in Firewall
echo "Tinkering in Firewall"
if [ -z "$wan" ]
	then
		sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE && iptables-save
		sudo iptables --table nat --append POSTROUTING --out-interface ppp0 -j MASQUERADE
		$("sudo iptables -I INPUT -s $ip/8 -i ppp0 -j ACCEPT")
		sudo iptables --append FORWARD --in-interface wlan0 -j ACCEPT
	else
		sudo iptables -t nat -A POSTROUTING -o $networkinterface -j MASQUERADE && iptables-save
		sudo iptables --table nat --append POSTROUTING --out-interface ppp0 -j MASQUERADE
		$("sudo iptables -I INPUT -s $ip/8 -i ppp0 -j ACCEPT")
		sudo iptables --append FORWARD --in-interface $networkinterface -j ACCEPT
    iptables -A FORWARD -p gre -j ACCEPT
    iptables -A FORWARD -i $networkinterface -p tcp --dport 1723 -j ACCEPT
    
fi

clear

#Automatic Adding VPN Users
username=$(gpw 1 5)
password=$(pwgen 6 1)

# Mannual Adding VPN Users
#echo "Set username:"
#read username
#echo "Set Password:"
#read password

sudo echo "$username * $password *" >> /etc/ppp/chap-secrets

# Restarting Service 
sudo service pptpd restart

echo "All done!"
echo "Save your connect - $username : $password !"

cd
git clone https://github.com/debihard/toriptables2.git
cd toriptables2/
python toriptables2.py -l
