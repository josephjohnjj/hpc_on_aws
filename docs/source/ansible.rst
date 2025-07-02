Ansible Playbook: EC2 Setup with System Validation, Spack, MIG, and CUDA
=========================================================================


Start instance
---------------------

.. code-block:: bash
    :linenos:

    terraform login
    terraform init
    terraform apply

Start the instance and find the public ip address of the instance

.. code-block:: bash
    :linenos:

    terraform output

This will give you the iP address.

Inventory file (hosts.ini)
----------------------

Using the IP adress (for example 92.29.22.22) update the file `hosts.ini`

.. code-block:: bash
    :linenos:

    98.81.120.13 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/terraform-user

Where ``terraform-user`` is the private key of the key-pair used to create the instance.



Playbook Overview
------------------------

This document explains the key concepts and modules used in a multi-play Ansible playbook
designed to prepare EC2 instances with:

- Ubuntu 22.04
- Intel CPU and NVIDIA GPU validation
- System package installation
- Spack setup
- MIG mode enablement for NVIDIA GPUs
- CUDA installation using Spack
- User and group management with ACLs

Playbook Structure
------------------

Ansible Playbooks are YAML files consisting of *plays*. Each play targets a group of hosts and contains a list of *tasks* to be executed.

Key Concepts Explained
----------------------

**1. Plays and Hosts**

Each play is declared with a ``- name`` and specifies the target hosts via the ``hosts`` field.

.. code-block:: yaml

   - name: Validate system requirements
     hosts: ec2

**2. Privilege Escalation**

.. code-block:: yaml

   become: yes

Enables running tasks with elevated privileges (e.g., via ``sudo``).

**3. Fact Gathering**

.. code-block:: yaml

   gather_facts: yes

Collects system-level facts like OS, distribution version, CPU type, etc., used for conditional logic.

**4. Conditional Execution**

.. code-block:: yaml

   when: ansible_distribution == "Ubuntu" and ansible_distribution_version == "22.04"

Ensures a task only runs under specific conditions.

**5. Task Modules**

Ansible modules are building blocks used to perform specific tasks. Examples:

- ``fail``: Intentionally stops execution with an error.
- ``shell`` and ``command``: Execute shell commands.
- ``apt``: Install Debian/Ubuntu packages.
- ``file``: Manage file or directory state.
- ``git``: Clone a Git repository.
- ``user``, ``group``: Manage users and groups.
- ``copy``: Write content to files.
- ``set_fact``: Define dynamic variables.
- ``debug``: Output debug info.
- ``meta: end_play``: Gracefully stop play execution.

**6. Registering Results**

.. code-block:: yaml

   register: intel_cpu_check

Stores task results (e.g., stdout, exit code) in a variable for later use.

**7. Changed Status Control**

.. code-block:: yaml

   changed_when: false

Overrides Ansible's change detection to mark tasks as unchanged.

**8. Looping with Sequences**

.. code-block:: yaml

   loop: "{{ query('sequence', '0,' ~ (gpu_count - 1)) }}"

Repeats a task multiple times based on GPU count.

**9. Error Handling**

.. code-block:: yaml

   ignore_errors: yes

Allows the playbook to continue even if the task fails.

**10. Environment Setup**

.. code-block:: yaml

   environment:
     SPACK_ROOT: /apps/spack
     PATH: "/apps/spack/bin:{{ ansible_env.PATH }}"

Sets environment variables for tasks requiring custom paths (e.g., Spack).

**11. Retry Mechanism**

.. code-block:: yaml

   retries: 3
   delay: 30
   until: spack_cuda_install.rc == 0

Automatically retries a task until it succeeds or the retry limit is reached.

**12. File and Directory Permissions**

The playbook ensures correct permissions and ownership for shared directories:

- Ownership via ``file`` module
- ACLs via ``setfacl`` command
- ``g+s`` sticky bit via ``chmod`` to enforce group inheritance

**13. Dynamic User Creation**

.. code-block:: yaml

   loop: "{{ query('sequence', 'start=1 end=' + user_count|string) }}"

Creates multiple users like ``user1`` to ``user30`` dynamically.

**14. Modular Design**

Each play is focused on a single purpose:

- System validation
- Package installation
- Cloning Spack
- Enabling MIG
- Creating MIG instances
- Setting up users/groups
- Installing CUDA via Spack

This separation of concerns improves readability, maintainability, and debugging.

Conclusion
----------

This playbook is a complete automation pipeline for preparing a GPU-based EC2 environment using best practices in Ansible, including validation, modular execution, conditional logic, user access controls, and external tool integration (Spack, CUDA).









