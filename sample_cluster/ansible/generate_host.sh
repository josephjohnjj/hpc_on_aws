#!/bin/bash

# Ensure script runs in bash
if [ -z "$BASH_VERSION" ]; then
  echo "Please run this script with bash: bash generate_host.sh"
  exit 1
fi

# Fetch the raw Terraform output
RAW_OUTPUT=$(terraform -chdir=.. output instance_public_ips 2>/dev/null)

# Clean and normalize: remove brackets, quotes, spaces, and blank lines
CLEANED_OUTPUT=$(echo "$RAW_OUTPUT" | tr -d '[]" ' | tr ',' '\n' | sed '/^$/d')

# Check if the cleaned output is empty
if [ -z "$CLEANED_OUTPUT" ]; then
  echo "Error: Failed to retrieve valid IPs from Terraform output."
  exit 1
fi

# Write Ansible inventory file
echo "[ec2]" > host.ini
while IFS= read -r ip; do
  echo "$ip ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/terraform-user" >> host.ini
done <<< "$CLEANED_OUTPUT"

echo "Ansible inventory 'host.ini' created with the following IPs:"
echo "$CLEANED_OUTPUT"
