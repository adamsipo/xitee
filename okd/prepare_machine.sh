#!/usr/bin/env bash

echo " [TASK 1] Updating system and installing required packages"
sudo dnf update -y > /dev/null 2>&1
sudo dnf install -y git bind bind-utils haproxy dhcp-server > /dev/null 2>&1

echo " [TASK 2] Cloning the repository"
git clone https://github.com/ryanhay/ocp4-metal-install > /dev/null 2>&1

echo " [TASK 3] Updating vim settings"
cat <<EOT >> ~/.vimrc
syntax on
set nu et ai sts=0 ts=2 sw=2 list hls
EOT

echo " [TASK 5] Restarting network interface"
sudo nmcli con mod "System eth1" ipv4.addresses 192.168.22.1/24
sudo nmcli con mod "System eth1" ipv4.method manual
sudo nmcli con mod "System eth1" ipv4.dns 127.0.0.1
sudo nmcli con mod "System eth1" ipv4.dns-search ocp.lan
sudo nmcli con mod "System eth1" ipv4.never-default yes
sudo nmcli con mod "System eth1" connection.autoconnect yes

sudo nmcli con down "System eth1"
sudo nmcli con up "System eth1"

echo " [TASK 8] Setting firewall zones and rules"
sudo nmcli connection modify "System eth1" connection.zone internal
sudo nmcli connection modify "System eth0" connection.zone external
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --zone=external --add-masquerade --permanent
sudo firewall-cmd --zone=internal --add-masquerade --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --list-all --zone=internal
sudo firewall-cmd --list-all --zone=external

echo " [TASK 9] Enabling IP forwarding"
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward > /dev/null

echo " [TASK 10] Configuring BIND"
cat <<EOT | sudo tee /etc/named.conf > /dev/null
//
// named.conf
//
// Provided by Red Hat bind package to configure the ISC BIND named(8) DNS
// server as a caching only nameserver (as a localhost DNS resolver only).
//
// See /usr/share/doc/bind*/sample/ for example named configuration files.
//
// See the BIND Administrator's Reference Manual (ARM) for details about the
// configuration located in /usr/share/doc/bind-{version}/Bv9ARM.html

options {
	listen-on port 53 { 127.0.0.1; 192.168.22.1; };
#	listen-on-v6 port 53 { ::1; };
	directory 	"/var/named";
	dump-file 	"/var/named/data/cache_dump.db";
	statistics-file "/var/named/data/named_stats.txt";
	memstatistics-file "/var/named/data/named_mem_stats.txt";
	recursing-file  "/var/named/data/named.recursing";
	secroots-file   "/var/named/data/named.secroots";
	allow-query     { localhost; 192.168.22.0/24; };

	/*
	 - If you are building an AUTHORITATIVE DNS server, do NOT enable recursion.
	 - If you are building a RECURSIVE (caching) DNS server, you need to enable
	   recursion.
	 - If your recursive DNS server has a public IP address, you MUST enable access
	   control to limit queries to your legitimate users. Failing to do so will
	   cause your server to become part of large scale DNS amplification
	   attacks. Implementing BCP38 within your network would greatly
	   reduce such attack surface
	*/
	recursion yes;

	dnssec-enable yes;
	dnssec-validation yes;

	# Using Google DNS
	forwarders {
                8.8.8.8;
                8.8.4.4;
        };

	/* Path to ISC DLV key */
	bindkeys-file "/etc/named.root.key";

	managed-keys-directory "/var/named/dynamic";

	pid-file "/run/named/named.pid";
	session-keyfile "/run/named/session.key";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

zone "." IN {
	type hint;
	file "named.ca";
};

# Include ocp zones

zone "ocp.lan" {
    type master;
    file "/etc/named/zones/db.ocp.lan"; # zone file path
};

zone "22.168.192.in-addr.arpa" {
    type master;
    file "/etc/named/zones/db.reverse";  # 192.168.22.0/24 subnet
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
EOT

sudo mkdir -p /etc/named/zones

echo " [TASK 10] Configuring BIND"
cat <<EOT | sudo tee /etc/named/zones/db.ocp.lan > /dev/null
\$TTL    604800
@       IN      SOA     ocp-svc.ocp.lan. contact.ocp.lan (
                  1     ; Serial
             604800     ; Refresh
              86400     ; Retry
            2419200     ; Expire
             604800     ; Minimum
)
        IN      NS      ocp-svc

ocp-svc.ocp.lan.          IN      A       192.168.22.1

; Temp Bootstrap Node
ocp-bootstrap.lab.ocp.lan.        IN      A      192.168.22.200

; Control Plane Nodes
ocp-cp-1.lab.ocp.lan.         IN      A      192.168.22.201
ocp-cp-2.lab.ocp.lan.         IN      A      192.168.22.202
ocp-cp-3.lab.ocp.lan.         IN      A      192.168.22.203

; Worker Nodes
ocp-w-1.lab.ocp.lan.        IN      A      192.168.22.211
ocp-w-2.lab.ocp.lan.        IN      A      192.168.22.212

; OpenShift Internal - Load balancer
api.lab.ocp.lan.        IN    A    192.168.22.1
api-int.lab.ocp.lan.    IN    A    192.168.22.1
*.apps.lab.ocp.lan.     IN    A    192.168.22.1

; ETCD Cluster
etcd-0.lab.ocp.lan.    IN    A     192.168.22.201
etcd-1.lab.ocp.lan.    IN    A     192.168.22.202
etcd-2.lab.ocp.lan.    IN    A     192.168.22.203

; OpenShift Internal SRV records (cluster name = lab)
_etcd-server-ssl._tcp.lab.ocp.lan.    86400     IN    SRV     0    10    2380    etcd-0.lab
_etcd-server-ssl._tcp.lab.ocp.lan.    86400     IN    SRV     0    10    2380    etcd-1.lab
_etcd-server-ssl._tcp.lab.ocp.lan.    86400     IN    SRV     0    10    2380    etcd-2.lab

oauth-openshift.apps.lab.ocp.lan.     IN     A     192.168.22.1
console-openshift-console.apps.lab.ocp.lan.     IN     A     192.168.22.1
EOT

echo " [TASK 11] Configuring BIND"
cat <<EOT | sudo tee /etc/named/zones/db.reverse > /dev/null
\$TTL    604800
@       IN      SOA     ocp-svc.ocp.lan. contact.ocp.lan (
                  1     ; Serial
             604800     ; Refresh
              86400     ; Retry
            2419200     ; Expire
             604800     ; Minimum
)

  IN      NS      ocp-svc.ocp.lan.

1      IN    PTR    ocp-svc.ocp.lan.
1      IN    PTR    api.lab.ocp.lan.
1      IN    PTR    api-int.lab.ocp.lan.
;
200    IN    PTR    ocp-bootstrap.lab.ocp.lan.
;
201    IN    PTR    ocp-cp-1.lab.ocp.lan.
202    IN    PTR    ocp-cp-2.lab.ocp.lan.
203    IN    PTR    ocp-cp-3.lab.ocp.lan.
;
211    IN    PTR    ocp-w-1.lab.ocp.lan.
212    IN    PTR    ocp-w-2.lab.ocp.lan.
EOT

echo " [TASK 12] Setup eth0 to use"
# Define the configuration file path
ETH0="/etc/sysconfig/network-scripts/ifcfg-eth0"
# Delete the row containing DNS2
sed -i '/^DNS2=/d' $ETH0
# Change the DNS1 value to 127.0.0.1
sed -i 's/^DNS1=.*/DNS1=127.0.0.1/' $ETH0
# Add the row PEERDNS=no if it doesn't exist
grep -q '^PEERDNS=' $ETH0 || echo 'PEERDNS=no' >> $ETH0


echo " [TASK 13] Opening firewall ports for BIND"
sudo firewall-cmd --add-port=53/udp --zone=internal --permanent
# For OCP 4.9 and later 53/tcp is required
sudo firewall-cmd --add-port=53/tcp --zone=internal --permanent
sudo firewall-cmd --reload

echo " [TASK 14] Enabling and starting named service"
sudo systemctl enable named
sudo systemctl start named
sudo systemctl status named

echo " [TASK 15] Setting DNS for the network connection"
sudo nmcli connection modify "System eth0" ipv4.dns "127.0.0.1" ipv4.ignore-auto-dns "yes"
sudo systemctl restart NetworkManager


echo "[TASK 15] Installing Apache"
sudo dnf install httpd -y
sudo sed -i 's/Listen 80/Listen 0.0.0.0:8080/' /etc/httpd/conf/httpd.conf
sudo firewall-cmd --add-port=8080/tcp --zone=internal --permanent
# sudo firewall-cmd --add-port=8080/tcp --zone=external --permanent #optional
sudo firewall-cmd --reload
sudo systemctl enable httpd
sudo systemctl start httpd
sudo systemctl status httpd

echo " [TASK 16] Configure HAProxy"
cat <<EOT | sudo tee /etc/haproxy/haproxy.cfg > /dev/null
# Global settings
#---------------------------------------------------------------------
global
    maxconn     20000
    log         /dev/log local0 info
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    user        haproxy
    group       haproxy
    daemon

    # turn on stats unix socket
    stats socket /var/lib/haproxy/stats

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    log                     global
    mode                    http
    option                  httplog
    option                  dontlognull
    option http-server-close
    option redispatch
    option forwardfor       except 127.0.0.0/8
    retries                 3
    maxconn                 20000
    timeout http-request    10000ms
    timeout http-keep-alive 10000ms
    timeout check           10000ms
    timeout connect         40000ms
    timeout client          300000ms
    timeout server          300000ms
    timeout queue           50000ms

# Enable HAProxy stats
listen stats
    bind :9000
    stats uri /stats
    stats refresh 10000ms

# Kube API Server
frontend k8s_api_frontend
    bind :6443
    default_backend k8s_api_backend
    mode tcp

backend k8s_api_backend
    mode tcp
    balance source
    server      ocp-bootstrap 192.168.22.200:6443 check
    server      ocp-cp-1 192.168.22.201:6443 check
    server      ocp-cp-2 192.168.22.202:6443 check
    server      ocp-cp-3 192.168.22.203:6443 check

# OCP Machine Config Server
frontend ocp_machine_config_server_frontend
    mode tcp
    bind :22623
    default_backend ocp_machine_config_server_backend

backend ocp_machine_config_server_backend
    mode tcp
    balance source
    server      ocp-bootstrap 192.168.22.200:22623 check
    server      ocp-cp-1 192.168.22.201:22623 check
    server      ocp-cp-2 192.168.22.202:22623 check
    server      ocp-cp-3 192.168.22.203:22623 check

# OCP Ingress - layer 4 tcp mode for each. Ingress Controller will handle layer 7.
frontend ocp_http_ingress_frontend
    bind :80
    default_backend ocp_http_ingress_backend
    mode tcp

backend ocp_http_ingress_backend
    balance source
    mode tcp
    server      ocp-w-1 192.168.22.211:80 check
    server      ocp-w-2 192.168.22.212:80 check

frontend ocp_https_ingress_frontend
    bind *:443
    default_backend ocp_https_ingress_backend
    mode tcp

backend ocp_https_ingress_backend
    mode tcp
    balance source
    server      ocp-w-1 192.168.22.211:443 check
    server      ocp-w-2 192.168.22.212:443 check
EOT

sudo firewall-cmd --add-port=6443/tcp --zone=internal --permanent # kube-api-server on control plane nodes
sudo firewall-cmd --add-port=6443/tcp --zone=external --permanent # kube-api-server on control plane nodes
sudo firewall-cmd --add-port=22623/tcp --zone=internal --permanent # machine-config server
sudo firewall-cmd --add-service=http --zone=internal --permanent # web services hosted on worker nodes
sudo firewall-cmd --add-service=http --zone=external --permanent # web services hosted on worker nodes
sudo firewall-cmd --add-service=https --zone=internal --permanent # web services hosted on worker nodes
sudo firewall-cmd --add-service=https --zone=external --permanent # web services hosted on worker nodes
sudo firewall-cmd --add-port=9000/tcp --zone=external --permanent # HAProxy Stats
sudo firewall-cmd --reload

setsebool -P haproxy_connect_any 1 # SELinux name_bind access
systemctl enable haproxy
systemctl start haproxy
systemctl status haproxy

dnf install nfs-utils -y

mkdir -p /shares/registry
chown -R nobody:nobody /shares/registry
chmod -R 777 /shares/registry
echo "/shares/registry  192.168.22.0/24(rw,sync,root_squash,no_subtree_check,no_wdelay)" > /etc/exports
exportfs -rv

firewall-cmd --zone=internal --add-service mountd --permanent
firewall-cmd --zone=internal --add-service rpc-bind --permanent
firewall-cmd --zone=internal --add-service nfs --permanent
firewall-cmd --reload

systemctl enable nfs-server rpcbind
systemctl start nfs-server rpcbind nfs-mountd

ssh-keygen -t rsa -b 2048 -C "openshift-cluster" -N "" -f /root/.ssh/id_rsa
mkdir -p /root/ocp-install

SSH_PUB_KEY=$(cat /root/.ssh/id_rsa.pub)

cat <<EOT | sudo tee /root/ocp-install/install-config.yaml > /dev/null
apiVersion: v1
baseDomain: ocp.lan
compute:
  - hyperthreading: Enabled
    name: worker
    replicas: 0 # Must be set to 0 for User Provisioned Installation as worker nodes will be manually deployed.
controlPlane:
  hyperthreading: Enabled
  name: master
  replicas: 3
metadata:
  name: lab # Cluster name
networking:
  clusterNetwork:
    - cidr: 10.128.0.0/14
      hostPrefix: 23
  networkType: OVNKubernetes
  serviceNetwork:
    - 172.30.0.0/16
platform:
  none: {}
fips: false
pullSecret: '{"auths":{"cloud.openshift.com":{"auth":"b3BlbnNoaWZ0LXJlbGVhc2UtZGV2K29jbV9hY2Nlc3NfMDc4NmNmYTVkNWY1NDk3YThhNGUyNzU1NGUwMDVkY2M6Q1VPUVFJU1RPWDZKVE5ONzg0Q1pBMlRXOTRFNk9DMjMxUk5LWVYyWFAwVkJVSTlaVEFSUkZPNFQzVDQ4N1k1VQ==","email":"adam.sipos.work@gmail.com"},"quay.io":{"auth":"b3BlbnNoaWZ0LXJlbGVhc2UtZGV2K29jbV9hY2Nlc3NfMDc4NmNmYTVkNWY1NDk3YThhNGUyNzU1NGUwMDVkY2M6Q1VPUVFJU1RPWDZKVE5ONzg0Q1pBMlRXOTRFNk9DMjMxUk5LWVYyWFAwVkJVSTlaVEFSUkZPNFQzVDQ4N1k1VQ==","email":"adam.sipos.work@gmail.com"},"registry.connect.redhat.com":{"auth":"fHVoYy1wb29sLWQyNzAyMzdmLWNiMDYtNDk5YS05ZTk0LWEzZjgxYTMxMmU3MjpleUpoYkdjaU9pSlNVelV4TWlKOS5leUp6ZFdJaU9pSTBNbVJoTUdVMFpEQXlPRFEwTlRZMVlqRTVZekUyWVdRMFpUVTRNV1psT0NKOS5aeGVwU3YzdjRwcDZzZU9mNVhvSkpKOEpKQ0s3LWpjX0htZlF5MUwzbWRTMzdsdVJVWEFHaC1RQlRNOHBiMW9fMGpsN0Rmcm5wV0RiV2pGbDd6b21UNlFHWVJPQ2c3UTdrUDc2Z1Y0X1BzOVdfNnRNQXZnazN3ZEVFcExxaEw4QUp1YTJKNGZJamp0RlE1NGtQLUxTdTU1NkFCWlk2WHlQTVJCbGE3RjRUS3ZKamFUV2ZRdnZ0NTJFRVVBN3oxeGpGZEVDWUNLS2NRRUYtYjlvYm0zQnFxNTFvc1ZUMUtzQjl0REJxX0dnNV8xbmdKUTBNTnFIQ0k3encwUlhsYlplc3o5bk9UVE5OcHZ2ZlIzRlF6OXNFeWpwaHUwNjVyckY3YjJGb01Ia2N6NVNHN0k0OWdDSlRlTlM2cnJHZUtlLVdCZHZ6TENTOFI4dVlwTHpvVFhGQTRNN09JbEhPVjQ5SXY3RHFRSWdNOEhVTlo0MjNOSWdZSXR2eTZFOHVmRUl1WWxwMWszUFN0SVphTU04MVBPa0FVbGtGMFpPMEljdHV6cTZ6c20tQ2otMnZBaERNd1NzMzZwWFQ4V25GbURTVktiaEs4azJON09hVzZ5OWhLNEtUMHo1bUJJMjM0WExWSHFPakJhQ25XZmhmay1BOXFZb1JTcDVQaG9wdUg4V3RGSDhDU0hET21uaVdnbTZSWU5mTGUwbVloMU00eHRHV1hMdTkwMDZ4aWtjcTNjZ0RFcWg0R1pDOERZYThGSlZoU05aYXdqTnlIQXRuYW1GMWE5RTNVUWJlWk5OdEZHQWg0NjFLSTBlRmRPVWp0WHpOZUR4TlFocWhTcEdhNXRObkVkOV9SbHJvaEhvQzVHVTBpWHlTQjlEck9uVHVYai1lbVFXZkE5YzE2Zw==","email":"adam.sipos.work@gmail.com"},"registry.redhat.io":{"auth":"fHVoYy1wb29sLWQyNzAyMzdmLWNiMDYtNDk5YS05ZTk0LWEzZjgxYTMxMmU3MjpleUpoYkdjaU9pSlNVelV4TWlKOS5leUp6ZFdJaU9pSTBNbVJoTUdVMFpEQXlPRFEwTlRZMVlqRTVZekUyWVdRMFpUVTRNV1psT0NKOS5aeGVwU3YzdjRwcDZzZU9mNVhvSkpKOEpKQ0s3LWpjX0htZlF5MUwzbWRTMzdsdVJVWEFHaC1RQlRNOHBiMW9fMGpsN0Rmcm5wV0RiV2pGbDd6b21UNlFHWVJPQ2c3UTdrUDc2Z1Y0X1BzOVdfNnRNQXZnazN3ZEVFcExxaEw4QUp1YTJKNGZJamp0RlE1NGtQLUxTdTU1NkFCWlk2WHlQTVJCbGE3RjRUS3ZKamFUV2ZRdnZ0NTJFRVVBN3oxeGpGZEVDWUNLS2NRRUYtYjlvYm0zQnFxNTFvc1ZUMUtzQjl0REJxX0dnNV8xbmdKUTBNTnFIQ0k3encwUlhsYlplc3o5bk9UVE5OcHZ2ZlIzRlF6OXNFeWpwaHUwNjVyckY3YjJGb01Ia2N6NVNHN0k0OWdDSlRlTlM2cnJHZUtlLVdCZHZ6TENTOFI4dVlwTHpvVFhGQTRNN09JbEhPVjQ5SXY3RHFRSWdNOEhVTlo0MjNOSWdZSXR2eTZFOHVmRUl1WWxwMWszUFN0SVphTU04MVBPa0FVbGtGMFpPMEljdHV6cTZ6c20tQ2otMnZBaERNd1NzMzZwWFQ4V25GbURTVktiaEs4azJON09hVzZ5OWhLNEtUMHo1bUJJMjM0WExWSHFPakJhQ25XZmhmay1BOXFZb1JTcDVQaG9wdUg4V3RGSDhDU0hET21uaVdnbTZSWU5mTGUwbVloMU00eHRHV1hMdTkwMDZ4aWtjcTNjZ0RFcWg0R1pDOERZYThGSlZoU05aYXdqTnlIQXRuYW1GMWE5RTNVUWJlWk5OdEZHQWg0NjFLSTBlRmRPVWp0WHpOZUR4TlFocWhTcEdhNXRObkVkOV9SbHJvaEhvQzVHVTBpWHlTQjlEck9uVHVYai1lbVFXZkE5YzE2Zw==","email":"adam.sipos.work@gmail.com"}}}'
sshKey: "$SSH_PUB_KEY"
EOT