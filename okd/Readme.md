sudo apt update
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager libvirt-dev
lsmod | grep kvm

sudo apt-get purge vagrant-libvirt
sudo apt-mark hold vagrant-libvirt
sudo apt-get install -y qemu libvirt-daemon-system libvirt-dev ebtables libguestfs-tools
sudo apt-get install -y vagrant ruby-fog-libvirt
vagrant plugin install vagrant-libvirt

curl -O https://raw.githubusercontent.com/vagrant-libvirt/vagrant-libvirt-qa/main/scripts/install.bash
chmod a+x ./install.bash
./install.bash

sudo apt-get build-dep vagrant ruby-libvirt
sudo apt-get install -y qemu libvirt-daemon-system ebtables libguestfs-tools \
  libxslt-dev libxml2-dev zlib1g-dev ruby-dev
vagrant plugin install vagrant-libvirt

qemu permmision not allowed

sudo setfacl -m user:$USER:rw /var/run/libvirt/libvirt-sock
Exit the session and again logged in then,

sudo systemctl enable libvirtd
sudo systemctl start libvirtd

#!/bin/bash

# Function to add DNS A and PTR records for a given VM
AddOCPDNS() {
    local VMName=$1
    local DNSName=$2
    local AddPTRRecord=$3
    local Zone="ocp.adam.lab"  # Define your DNS zone name here
    local ReverseZone="192.168.122.101.in-addr.arpa"  # Define your reverse DNS zone name here

    # Get MAC address of VM
    local MacAddr=$(virsh dumpxml $VMName | grep "mac address" | awk -F"'" '{print $2}')
    
    # Find IP address using ARP
    local IP=$(arp -an | grep $MacAddr | awk '{print $2}' | sed 's/[()]//g')

    # Add A record to DNS zone file
    echo "$DNSName    IN    A    $IP" >> /var/named/$Zone.zone
    
    if [[ "$AddPTRRecord" == "true" ]]; then
        # Add PTR record
        local LastDigit=$(echo $IP | cut -d. -f4)
        echo "$LastDigit    IN    PTR    $DNSName.$Zone." >> /var/named/$ReverseZone.zone
    fi

    # Reload BIND to apply changes
    systemctl reload named
}

# Usage example:
# AddOCPDNS "VMName" "examplednsname" true
