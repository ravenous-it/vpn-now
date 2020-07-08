#!/usr/bin/bash

if [ "$EUID" -ne 0 ]
then
	echo "vpn_client.sh must be run as root."
	exit
fi

if [ -z "$1" ]
then
	echo "Usage: vpn_client.sh <ClientName>"
	echo
	echo "   Example: vpn_client.sh MyPhone"
	echo
	exit
fi

CLIENT=$1
PUBIP=$(dig @resolver1.opendns.com ANY myip.opendns.com +short)

EASYRSADIR=/usr/share/easy-rsa/3
CLIENTDIR=/etc/openvpn/client/
SERVERDIR=/etc/openvpn/server/
OVPN=$CLIENTDIR/$CLIENT.ovpn
RANDDIR=$RANDOM
SERVEDIR=/var/www/html/$RANDDIR
DOWNLOAD_PORT=1194

echo "
" > /tmp/enter.input

echo "yes
" > /tmp/yes.input

cd $EASYRSADIR

rm -f pki/private/$CLIENT.key
rm -f pki/issued/$CLIENT.crt

echo "QUICKVPN: Generating $CLIENT VPN Client Certificate"
./easyrsa gen-req $CLIENT nopass < /tmp/enter.input

echo "QUICKVPN: Signing $CLIENT VPN Client Certificate"
./easyrsa sign-req client $CLIENT < /tmp/yes.input

echo "QUICKVPN: Copying $CLIENT Certifacte and Key to $CLIENTDIR"
cp pki/private/$CLIENT.key $CLIENTDIR
cp pki/issued/$CLIENT.crt $CLIENTDIR

echo "client
dev tun
proto udp
remote $PUBIP
port 1194
resolv-retry infinite
persist-key
persist-tun
key-direction 1
verb 3
topology subnet
remote-cert-tls server
<ca>" > $OVPN

cat $SERVERDIR/ca.crt >> $OVPN

echo "</ca>
<cert>" >> $OVPN

cat $CLIENTDIR/$CLIENT.crt >> $OVPN

echo "</cert>
<key>" >> $OVPN

cat $CLIENTDIR/$CLIENT.key >> $OVPN

echo "</key>
<tls-auth>" >> $OVPN

cat $SERVERDIR/ta.key >> $OVPN

echo "</tls-auth>" >> $OVPN

mkdir -p $SERVEDIR

cp $OVPN $SERVEDIR

cd $SERVEDIR/..
firewall-cmd --zone=public --add-port=$DOWNLOAD_PORT/tcp
firewall-cmd --zone=public --add-port=443/tcp
systemctl start httpd
echo "systemctl stop httpd; firewall-cmd --zone=public --remove-ports=$DOWNLOAD_PORT/tcp; firewall-cmd --zone=public --remove-ports=443/tcp" |
	at -M now + 15 minutes

echo "Your client configuration has been generated and is available for download.

Direct the browser on your device to one of the following addresses to download your VPN
client configuration:

   http://$PUBIP:$DOWNLOAD_PORT/$RANDDIR/$CLIENT.ovpn
   https://$PUBIP/$RANDDIR/$CLIENT.ovpn

   Note: If using the HTTPS URL, you may need to ignore the trust warnings.

   The above URLs will only function for 15 minutes or until you press <ENTER>

"

echo
read -p "Press <ENTER> when you have completed the download"

systemctl stop httpd
firewall-cmd --zone=public --remove-port=$DOWNLOAD_PORT/tcp
firewall-cmd --zone=public --remove-port=443/tcp
rm -Rf $SERVEDIR

echo "QUICKVPN: Cleanup complete.  Your client configuration is no longer available
          for download."


