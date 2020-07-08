#!/usr/bin/bash

if [ "$EUID" -ne 0 ]
then
	echo "init_vpn.sh must be run as root."
	exit
fi

EASYRSADIR=/usr/share/easy-rsa/3
VPNCFGDIR=/etc/openvpn/server/
PUBIP=$(dig @resolver1.opendns.com ANY myip.opendns.com +short)

echo "
" > /tmp/enter.input

echo "yes
" > /tmp/yes.input

echo "QUICKVPN: Updating System Packages"
yum update -y

echo "QUICKVPN: Adding Amazon-Controlled Libraries"
amazon-linux-extras install -y epel python3

echo "QUICKVPN: Adding OpenVPN and Dependencies"
yum install -y httpd mod_ssl openvpn easy-rsa firewalld

echo "QUICKVPN: Updating Apache Configuration"
sed -i 's/Listen 80/Listen 1194/g' /etc/httpd/conf/httpd.conf
sed -i 's/Options Indexes FollowSymLinks/Options FollowSymLinks/g' /etc/httpd/conf/httpd.conf
sed -i '/mime.types/a AddType application/octet-stream .ovpn' /etc/httpd/conf/httpd.conf
echo "
LoadModule ssl_module modules/mod_ssl.so

<VirtualHost _default_:443>
    ServerAdmin vpn@localhost
    DocumentRoot "/var/www/html"
    ErrorLog "logs/error_log"
    CustomLog "logs/ssl_access_log" combined
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/https.crt
    SSLCertificateKeyFile /etc/ssl/certs/https.key
</VirtualHost>
" >> /etc/httpd/conf/httpd.conf

echo "QUICKVPN: Generate HTTPS Certificate"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
	-keyout /etc/ssl/certs/https.key \
	-out /etc/ssl/certs/https.crt \
	-subj "/C=US/ST=Local/O=VPN/OU=Personal/CN=$PUBIP"

echo "QUICKVPN: Enabling Network Features"
sysctl -w net.ipv4.ip_forward=1
echo "
net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

systemctl start firewalld
firewall-cmd --add-service openvpn
firewall-cmd --add-masquerade
firewall-cmd --permanent --add-service openvpn
firewall-cmd --permanent --add-masquerade

cd $EASYRSADIR

echo "QUICKVPN: Initializing PKI"
./easyrsa init-pki

echo "QUICKVPN: Creating Local Certificate Authority"
./easyrsa build-ca nopass < /tmp/enter.input

echo "QUICKVPN: Generating VPN Server Certificate"
./easyrsa gen-req vpnserver nopass < /tmp/enter.input

echo "QUICKVPN: Signing VPN Server Certificate"
./easyrsa sign-req server vpnserver < /tmp/yes.input

echo "QUICKVPN: Copying Certificates and Keys to $VPNCFGDIR"
cp pki/ca.crt $VPNCFGDIR
cp pki/private/vpnserver.key $VPNCFGDIR
cp pki/issued/vpnserver.crt $VPNCFGDIR

echo "QUICKVPN: Generating Diffie/Hellman Key"
openssl dhparam -out $VPNCFGDIR/dh.pem 2048

echo "QUICKVPN: Generating TLS Auth Key"
openvpn --genkey --secret $VPNCFGDIR/ta.key

echo "QUICKVPN: Generating OpenVPN Server Configuration"
echo "
port 1194
proto udp
dev tun
ca ca.crt
cert vpnserver.crt
key vpnserver.key
dh dh.pem
tls-auth ta.key 0
server 10.200.0.0 255.255.255.0
push \"redirect-gateway def1 bypass-dhcp\"
push \"dhcp-option DNS 8.8.8.8\"
push \"dhcp-option DNS 8.8.4.4\"
keepalive 10 60
persist-key
persist-tun
user nobody
group nobody
daemon
log-append /var/log/openvpn.log
verb 3
" > $VPNCFGDIR/server.conf

echo "QUICKVPN: Setting Configuration File Ownership"
chown nobody:nobody -R $VPNCFGDIR

echo "QUICKVPN: Starting OpenVPN Server"
systemctl enable openvpn-server@server
systemctl start openvpn-server@server

