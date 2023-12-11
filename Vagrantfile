# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV["VAGRANT_NO_PARALLEL"] = "yes"

VAGRANT_BOX = "almalinux/8" # Use the AlmaLinux 8 box
VAGRANT_BOX_VERSION = "8.8.20230606" # Use the latest version of the box

CPUS = 2
MEMORY = 2048

Vagrant.configure(2) do |config|
  config.vm.define "almalinux-8" do |node|
    node.vm.box = VAGRANT_BOX
    node.vm.box_version = VAGRANT_BOX_VERSION

    node.vm.network "private_network", type: "dhcp" # Use DHCP for IP assignment

    node.vm.provider :virtualbox do |v|
      v.name = "almalinux-8"
      v.memory = MEMORY
      v.cpus = CPUS
    end
  end
end
