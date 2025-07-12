#!/bin/bash
set -e

OUTPUTS=$(terraform -chdir=.. output -json)

CONTROL_PUB=$(echo "$OUTPUTS" | jq -r '.control_node_public_ip.value')
LOGIN_PUB=$(echo "$OUTPUTS" | jq -r '.login_node_public_ips.value[0]')
COMPUTE_PUBS=($(echo "$OUTPUTS" | jq -r '.compute_node_public_ips.value[]'))

# Expand ~ to full home directory path
SSH_KEY="/home/joseph/.ssh/terraform-user"

# Start writing host.ini
cat <<EOF > host.ini
[control]
node1 ansible_host=$CONTROL_PUB ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY

[login]
node2 ansible_host=$LOGIN_PUB ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY

[compute]
EOF

count=3
for ip in "${COMPUTE_PUBS[@]}"; do
  echo "node$count ansible_host=$ip ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY" >> host.ini
  ((count++))
done

cat <<EOF >> host.ini

[all:children]
control
login
compute
EOF

echo "✅ Generated host.ini:"
cat host.ini
