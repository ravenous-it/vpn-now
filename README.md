# vpn-now
Tools for setting up a personal VPN on and AWS EC2 Instance

These tools provide support for a very narrow, though common, use case:
  The need for a personal consumer VPN.

These tools will build a self-contained VPN server and associated client configurations.
It also makes it easy for a novice to get the requisite client configuration to the
target device.

Usage:
   init_vpn.sh:
     This command will install OpenVPN, set up a CA, create a server certificate,
	 make required system configuration changes, generate a working OpenVPN
	 configuration, and start the OpenVPN server.

	 Note: This should only be run once.

   vpn_client.sh:
     This command will generate a client certificate and OpenVPN client configuration
	 file (ovpn), then set up a temporary HTTPS server to allow the user to download
	 the ovpn file on the intended device.

