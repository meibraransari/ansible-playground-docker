#!/bin/bash
###################################
# Author: Ibrar Ansari
# Date: 03-11-2024
# Version: 1
#
# This is Ansible Playground script
###################################

# Set Variables
containers=3
base_container_name="server"
ssh_user="ibrar_ansari"
ssh_pass="your_secure_password"
base_ssh_port=2023
container_image="ibraransaridocker/ubuntu-ssh-enabled:latest"
key_path="$HOME/.ssh/ansible_id_rsa_key.pub"
hostname=$(hostname -I | awk '{print $1}')
config_file="$HOME/.ansible.cfg"
inventory_file="inventory.ini"


# Function to pull Docker image
pull_docker_image() {
    docker pull ibraransaridocker/ubuntu-ssh-enabled:latest
    echo "Image pulled successfully"
}

# Function to generate SSH key if not already generated
generate_ssh_key() {
    if [ ! -f "$HOME/.ssh/ansible_id_rsa_key" ]; then
        ssh-keygen -t rsa -f "$HOME/.ssh/ansible_id_rsa_key" -b 4096 -C "This is used for ansible" -N ""
        ls -alsh "$HOME/.ssh/"
    fi
}

# Function to run Docker containers
run_docker_containers() {
    for i in $(seq 1 $containers); do
        local container_name="${base_container_name}_${i}"
        local ssh_port=$((base_ssh_port + i))
        docker run -itd --name="$container_name" -p "$ssh_port:22" \
            -e SSH_USERNAME="$ssh_user" -e PASSWORD="$ssh_pass" \
            -e AUTHORIZED_KEYS="$(cat "$key_path")" "$container_image" > /dev/null 2>&1
        echo "${container_name} created successfully."            
    done
}

# Function to test SSH connectivity
test_ssh_connectivity() {
    for i in $(seq 1 $containers); do
        local ssh_port=$((base_ssh_port + i))
        ssh -o StrictHostKeyChecking=no -i "$HOME/.ssh/ansible_id_rsa_key" -p "$ssh_port" "$ssh_user@$hostname" "echo Connected to $hostname on port $ssh_port"
    done
}

# Function to generate Ansible inventory file in the desired format
generate_inventory_file() {
    > "$inventory_file"  # Clear the inventory file if it exists
    for i in $(seq 1 $containers); do
        local ssh_port=$((base_ssh_port + i))
        echo "[server_$i]" >> "$inventory_file"
        #echo "$ssh_user@$hostname ansible_port=$ssh_port ansible_ssh_private_key_file=$HOME/.ssh/ansible_id_rsa_key" >> "$inventory_file"
        echo "container_$i ansible_host=$hostname ansible_user=$ssh_user ansible_port=$ssh_port ansible_ssh_private_key_file=$HOME/.ssh/ansible_id_rsa_key" >> "$inventory_file"
        echo "" >> "$inventory_file"  # Add a blank line for readability
    done
    echo ""
    echo "Inventory file created at: $inventory_file"
}

# Setting a Global Python Interpreter
create_ansible_config() {
    # Create or overwrite the ansible.cfg file
    cat << EOF > "$config_file"
[defaults]
interpreter_python = /usr/bin/python3.10
EOF
    echo ""
    echo "Ansible configuration file created at $config_file with global Python interpreter set."
}

# Countdown timer function
# Set the countdown time (in seconds)
COUNTDOWN_TIME=10
countdown() {
    local seconds=$COUNTDOWN_TIME
    while [ $seconds -gt 0 ]; do
        echo -ne "$seconds\033[0K\r"
        sleep 1
        ((seconds--))
    done
    echo ""  # Move to the next line after countdown finishes
}

wait () {
    # Now, when you're ready for the countdown
    echo "Waiting for containers up and running... "
    countdown
}


# Function to ping servers using Ansible
ping_servers() {
    echo ""
    for i in $(seq 1 $containers); do
        ansible "server_$i" -i "$inventory_file" -m ping
    done
}

# Main function to execute all steps
main() {
    pull_docker_image
    generate_ssh_key
    run_docker_containers
    wait
    test_ssh_connectivity
    generate_inventory_file
    create_ansible_config
    ping_servers 
}

# Execute the main function
main