# Running Vagrant with Custom CIDR Range

## Prerequisites

Before you begin, ensure you have the following installed:

- **Ansible**: 
  - Version: core 2.16.1
  - Python version: 3.10.12
  - Jinja version: 3.0.3
  - pip install passlib

- **Vagrant**: 
  - Version: 2.3.7

## Setting Up Vagrant

1. **Install Vagrant**:
   If Vagrant is not already installed, download and install it from [Vagrant's official website](https://www.vagrantup.com/downloads).

2. **Configure Network with Custom CIDR**:
   To set a specific CIDR range, configure the network in the /etc/vbox/networks.conf

3. **Launch Vagrant Box**:
   Run the following command to start and provision the Vagrant box:
   ```bash
   vagrant up
   ```
4. **Accessing the Vagrant Box**:
   Once the box is up and running, you can access it with:
   ```bash
   vagrant ssh
   ```

# Ansible Playbook for Docker and WordPress on AlmaLinux 8

This Ansible playbook is designed to automate the installation of Docker and WordPress on AlmaLinux 8 (version 8.8.20230606). It also includes functionality for creating backups of the WordPress instance.

## Features

- **Docker Installation**: Installs and configures Docker on AlmaLinux 8.
- **WordPress Deployment**: Deploys WordPress within a Docker container.
- **Backup Creation**: Automates the creation of backups for WordPress.

## Prerequisites

- Ansible environment set up on the control machine.
- Target servers running AlmaLinux 8.

## Inventory Setup

Define the target server(s) in the Ansible inventory. Specify the IP address and necessary SSH details for each server. Example inventory setup:

```yaml
all:
  children:
    servers:
      vars:
        firewall_services:
          - http
          - ssh
        user_name: xitest
        ssh_public_keys:
          - "ssh-ed25519 AAAA... marek@GUADALAJARA-WSL"
          - "ssh-ed25519 AAAA...tkuba"
      hosts:
        192.168.100.23:
          ansible_user: vagrant
          ansible_ssh_private_key_file: ~/.ssh/id_rsa
          ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
```


## Running the Playbook
To execute the playbook:

1. Navigate to the playbook directory.

- Secrets are stored in the `secrets.yaml` file.
- The password for decrypting the secrets file is "password".
- When running the playbook, use the following command to provide the vault password:
  ```bash
  ansible-playbook xitee_homework.yaml -i inventory/inventory.yaml --ask-vault-pass
  ```

## Accessing WordPress
Once the playbook execution is complete, WordPress will be accessible via the IP address of the virtual machine (e.g., `http://192.168.100.23`).

## Backup Management
- The playbook includes tasks for setting up automatic backups of the WordPress database.
- Backups are stored in a specified directory within the virtual machine.

