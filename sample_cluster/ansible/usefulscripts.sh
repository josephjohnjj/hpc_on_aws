terraform output -json > terraform_outputs.json

ansible-playbook -i hosts mount_efs.yaml --extra-vars "@terraform_outputs.json"

ansible-playbook -i host.ini ansible_setup_file_system/10_efs.yml -e @../tf_outputs.json


ssh -i ~/.ssh/terraform-user \
    -o 'ProxyCommand=ssh -i ~/.ssh/terraform-user -W %h:%p ubuntu@54.242.193.249' \
    ubuntu@10.0.1.157


# Control Node
ssh -i /home/joseph/.ssh/terraform-user ubuntu@100.25.168.223

# Login Node
ssh -i /home/joseph/.ssh/terraform-user ubuntu@54.242.193.249


# Node 3
ssh -i /home/joseph/.ssh/terraform-user \
  -o ProxyCommand='ssh -i /home/joseph/.ssh/terraform-user -W %h:%p -q ubuntu@54.242.193.249' \
  ubuntu@10.0.1.157

# Node 4
ssh -i /home/joseph/.ssh/terraform-user \
  -o ProxyCommand='ssh -i /home/joseph/.ssh/terraform-user -W %h:%p -q ubuntu@54.242.193.249' \
  ubuntu@10.0.1.150

# Node 5
ssh -i /home/joseph/.ssh/terraform-user \
  -o ProxyCommand='ssh -i /home/joseph/.ssh/terraform-user -W %h:%p -q ubuntu@54.242.193.249' \
  ubuntu@10.0.1.165



  terraform output -json > tf_outputs.json

  aws efs describe-mount-targets --file-system-id fs-00076011c2d467488