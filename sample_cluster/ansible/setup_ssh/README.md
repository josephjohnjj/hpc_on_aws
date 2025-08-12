# SSH Mesh Playbook — Quick Guide

This playbook bootstraps **passwordless SSH** across a virtual cluster in three phases:

1. **ssh_keys** — Generate per-host SSH keys and collect all pubkeys to the control node (`./keys`).
2. **hostnames** — Set predictable hostnames (`node1`, `node2`, …) and update `/etc/hosts`.
3. **ssh_mesh** — Push pubkeys into `authorized_keys`, build `known_hosts`, and test host-to-host SSH.

---

## Prereqs

- Ansible ≥ 2.12 on the control node  
- SSH access to all hosts as `ansible_user` (password or existing key)  
- Python on targets (usually present)  
- Inventory group `all` contains the nodes you want in the mesh

---

## Files & Layout

```
terraform-project/ansible/
├─ setup_ssh/
|    └─ setup_ssh.yml         # the playbook
├─ host.ini                 # inventory
├─ group_vars/
│  └─ all.yml                    # variables 
└─ keys/                         # generated at runtime by Play 1
```

**group_vars/all.yml** (example)
```yaml
target_user: "{{ ansible_user | default('ubuntu') }}"
base_name: node           # node name prefix (node1, node2, ...)
keys_dir: "./keys"
ssh_dir: "/home/{{ target_user }}/.ssh"
ssh_key_path: "{{ ssh_dir }}/id_rsa"
```

**inventory.ini** (example)
```ini
[all]
10.0.0.11
10.0.0.12
10.0.0.13
```

> Prefer `group_vars/all.yml`. Alternatively, use `vars/common.yml` and add `vars_files: - vars/common.yml` to each play.

---

## What It Does

- Creates `~{{ target_user }}/.ssh` with secure perms on each host  
- Generates an RSA 4096-bit key **if missing** (idempotent)  
- Collects each host’s **public key** to `./keys` on the control node (directory recreated once per run)  
- Sets hostnames to `{{ base_name }}N` ordered by inventory  
- Populates `/etc/hosts` with each node’s private IP and hostname  
- Populates `authorized_keys` on every host with **all** pubkeys (passwordless any-to-any)  
- Builds `known_hosts` from peer host keys via `ssh-keyscan`  
- Tests SSH connectivity and prints results

---

## Tags

- `ssh_keys` — key generation and pubkey collection  
- `hostnames` — hostname + `/etc/hosts`  
- `ssh_mesh` — authorized_keys, known_hosts, connectivity test

---

## Usage

Run everything:
```bash
ansible-playbook -i host.ini setup_ssh/setup_ssh.yml
```

Only hostnames:
```bash
ansible-playbook -i host.ini setup_ssh/setup_ssh.yml --tags hostnames
```

Only build the mesh (assuming keys already collected):
```bash
ansible-playbook -i host.ini setup_ssh/setup_ssh.yml --tags ssh_mesh
```

Skip a phase:
```bash
ansible-playbook -i host.ini setup_ssh/setup_ssh.yml --skip-tags hostnames
```


---
