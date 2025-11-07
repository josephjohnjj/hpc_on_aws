
Slurm Cluster
============================

The design for the slurm cluster is as follows:

1. One control or head node (node1)
2. One login node (node2)
3. Three compute nodes (node3, node4, node5)
4. Two Storage nodes (node6, node7)

Initial packages to install on all nodes
------------------------------------------

Make sure the following packages are installed on all nodes:

.. code-block:: bash

    sudo dnf install -y wget vim gcc gcc-c++ make
    sudo dnf install -y "kernel-devel-{{ ansible_kernel }}" 
    sudo dnf install -y "kernel-headers-{{ ansible_kernel }}"

    sudo wget -O https://www.beegfs.io/release/beegfs_8.2/dists/beegfs-rhel10.repo  \ 
            https://www.beegfs.io/release/beegfs_8.2/dists/beegfs-rhel10.repo

Passwordless SSH
----------------------------

Passwordless SSH is set up across all nodes in the cluster. However, on AWS, there can be 
complications. To address this, the relevant settings must be explicitly disabled in 
the configuration file: `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf`.

BeeGFS Installation
----------------------------

The first crucial step is to ensure that the operating system is compatible with the BeeGFS 
version being used. Incompatibility may lead to issues when installing the BeeGFS client.
For this setup, we are using:

* BeeGFS version: 8.2.x

* Operating System: RHEL 10

Disk and Directory setup
~~~~~~~~~~~~~~~~~~~~~~~~~~~~



Management node must have a `/BeeGFS` directory.

.. code-block:: bash

    sudo mkdir /BeeGFS


A disk should be assigned to the management node, typically `/dev/nvme1n1`. You can list 
available disks using the `lsblk` command. Format the disk and mount it to `/BeeGFS`.


.. code-block:: bash

    sudo mkfs.xfs /dev/nvme1n1
    sudo mount /dev/nvme1n1 /BeeGFS
    sudo systemctl daemon-reload



Once the disk is mounted, you can verify it using the `df -h` command. Next, create a directory 
called `management` within `/BeeGFS` to store the management server data.


.. code-block:: bash
    
    sudo mkdir /BeeGFS/management



On each storage node, create a `/BeeGFS` directory:

.. code-block:: bash


    sudo mkdir /BeeGFS


Mount a disk to `/BeeGFS` on every storage node, following the same procedure used for the 
management node.


.. code-block:: bash

    sudo mkfs.xfs /dev/nvme1n1
    sudo mount /dev/nvme1n1 /BeeGFS
    sudo systemctl daemon-reload




In this design, the metadata server is co-located with the storage server.

.. code-block:: bash


    sudo mkdir /BeeGFS/metadata


Each storage node also has two storage targets:

.. code-block:: bash


    sudo mkdir /storage
    sudo mkdir /storage/stor1
    sudo mkdir /storage/stor2


In this setup, each storage node has two additional disks, typically `/dev/nvme2n1` and 
`/dev/nvme3n1`. Format and mount them to `/storage/stor1` and `/storage/stor2`, respectively.



.. code-block:: bash

    sudo mkfs.xfs /dev/nvme2n1
    sudo mkfs.xfs /dev/nvme3n1

    sudo mount /dev/nvme2n1 /storage/stor1
    sudo mount /dev/nvme3n1 /storage/stor2

    sudo systemctl daemon-reload


Do this on all the storage nodes.



Configuration of BeeGFS Services in the new version 8.x is a bit different from the older
versions. Below are the steps to configure the newer version of BeeGFS. 


Configure Management Node
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Install BeeGFS utilities on all nodes (management, storage, and client nodes):


Install BeeGFS Management Service

.. code-block:: bash

    sudo dnf install beegfs-mgmtd






A secret key is used to authenticate other BeeGFS services with the management service, ensuring 
that only authorized services can connect. By default, the connection file is located at 
`/etc/beegfs/conn.auth`. Add the secret key `ach123!` (or any other) to this AuthFile, 
and make sure it is identical on all nodes.



The management configurations are stored in `/etc/beegfs/beegfs-mgmtd.toml`. The management 
service uses a dedicated database (SQLite) for enhanced robustness and to enable advanced 
features. The current command to initialize the BeeGFS management service is:


.. code-block:: bash

    sudo /opt/beegfs/sbin/beegfs-mgmtd --init

To ensure secure communication between BeeGFS services, it is necessary to create a 
TLS certificate. This certificate enables encrypted connections, preventing unauthorized 
access and protecting data integrity. You can generate the certificate using the 
following command:

.. code-block:: bash

    sudo mkdir -p /etc/beegfs
    sudo openssl req -x509 -newkey rsa:4096 -nodes -sha256   -keyout key.pem -out cert.pem  \ 
        -days 3650   -subj "/CN=node1"   \ 
        -addext "subjectAltName=DNS:node1,IP:$(hostname -I | awk '{print $1}')"

    sudo chmod 600 /etc/beegfs/key.pem
    sudo chmod 644 /etc/beegfs/cert.pem
    sudo chown root:root /etc/beegfs/key.pem /etc/beegfs/cert.pem



Make sure to copy this key and certificate to all other nodes in the cluster.
In the `beegfs-mgmtd.toml` configuration file, set the following parameters:

.. code-block:: bash


    tls-cert-file = "/etc/beegfs/cert.pem"
    tls-key-file = "/etc/beegfs/key.pem"
    auth-file = "/etc/beegfs/conn.auth"


After updating the configuration, start the BeeGFS Management Service:

.. code-block:: bash


    sudo systemctl start beegfs-mgmtd
    sudo systemctl status beegfs-mgmtd




You can review the logs to check for any errors:

.. code-block:: bash


    less /var/log/beegfs-mgmtd.log


*Make sure the firewall permits the necessary ports required for BeeGFS communication*.

Verify that the management service is running properly and without errors:

.. code-block:: bash


    sudo /opt/beegfs/sbin/beegfs node list --mgmtd-addr node1:8010





Configure Metadata server
~~~~~~~~~~~~~~~~~~~~~~~~~~~~


In this design, there are two metadata servers (node6 and node7), each co-located with a 
storage server.

Install the BeeGFS Metadata Service:

.. code-block:: bash


    sudo dnf install beegfs-meta


This installs the BeeGFS metadata service, which is responsible for managing the file system 
metadata.

Set up the BeeGFS Metadata Service:


.. code-block:: bash

    /opt/beegfs/sbin/beegfs-setup-meta -p /BeeGFS/metadata/ -s 1 -m node1

* `-p /BeeGFS/metadata/`` : Specifies the metadata storage path.

* `-s 1` : Assigns the metadata storage target ID 1.

* `-m node1`: Specifies the BeeGFS management node.

In the second metadata node use `-s 2` to assign the metadata storage target ID 2.


A metadata target is a logical storage location managed by a single `beegfs-meta` server. 
Each `beegfs-meta` server can manage only one target. It is possible to run multiple 
`beegfs-meta` servers on the same physical node, provided that each server manages a 
separate target backed by a different partition.


Next, edit the `/etc/beegfs/beegfs-meta.conf` file to configure the metadata service.


.. code-block:: bash

    connAuthFile = /etc/beegfs/conn.auth
    sysMgmtdHost = node1




Start and check Metadata Service:

.. code-block:: bash

    sudo systemctl start beegfs-meta
    sudo systemctl status beegfs-meta



This step must be performed on both metadata servers. Ensure that each metadata server is
properly registered with the management server.

.. code-block:: bash

    sudo /opt/beegfs/sbin/beegfs node list --mgmtd-addr node1:8010 --node-type meta

Storage Server Configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Install the BeeGFS Storage Service:

.. code-block:: bash

    sudo dnf install beegfs-storage



Next, configure the storage service by editing the file `/etc/beegfs/beegfs-storage.conf`:
The key parameters to configure are:

.. code-block:: bash

    storeStorageDirectory = /storage/stor1,/storage/stor2`
    sysMgmtdHost = node1
    connAuthFile = /etc/beegfs/conn.auth.





Storage targets in BeeGFS differ from metadata targets. Each `beegfs-storage` daemon can 
manage one or more storage targets. In this setup, each storage daemon is configured with 
two storage targets.


.. code-block:: bash

    sudo /opt/beegfs/sbin/beegfs-setup-storage -p /storage/stor1 -s 1 -i 101 -m node1
    sudo /opt/beegfs/sbin/beegfs-setup-storage -p /storage/stor2 -s 1 -i 102 -m node1

* `-p /storage/stor1` : Specifies the storage target path.
* `-s 1` : Assigns the storage server ID.
* `-i 101` : Sets a unique storage target index (should be unique across all storage targets).
* `-m node1`: Specifies the BeeGFS management node.

On the second storage node this will be:

.. code-block:: bash

    sudo /opt/beegfs/sbin/beegfs-setup-storage -p /storage/stor1 -s 2 -i 201 -m node1
    sudo /opt/beegfs/sbin/beegfs-setup-storage -p /storage/stor2 -s 2 -i 202 -m node1




By convention, the target index begins with the storage server ID, followed by a unique number.
Start the BeeGFS Storage Service:


.. code-block:: bash
    
    sudo systemctl start beegfs-storage
    sudo systemctl status beegfs-storage



Repeat this process on all storage servers. Then, on the management node, verify that the 
storage servers are correctly registered.

.. code-block:: bash

    sudo /opt/beegfs/sbin/beegfs node list --mgmtd-addr node1:8010 --node-type storage

Install BeeGFS Client and Dependencies
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Install the BeeGFS Client on all client nodes (including login and compute nodes):

.. code-block:: bash

    sudo dnf install beegfs-client kernel-devel



Set the following parameters in the `/etc/beegfs/beegfs-client.conf` file:

.. code-block:: bash


    sysMgmtdHost  = node1
    connAuthFile  = /etc/beegfs/conn.auth


Set the following parameters in the `/etc/beegfs/beegfs-mounts.conf` file:

.. code-block:: bash


    /scratch /etc/beegfs/beegfs-client.conf



1. `/etc/beegfs/beegfs-mounts.conf` defines the filesystems that the client should automatically 
mount, along with their configuration. `/scratch` is the mount point on the local client node, 
where the BeeGFS filesystem will appear in the directory tree. You must create this directory 
first:

.. code-block:: bash

    mkdir -p /scratch
 

2. `/etc/beegfs/beegfs-client.conf` specifies the path to the client configuration file for 
this mount. This tells the client which management server to contact and other necessary 
configuration details.




Start the BeeGFS Client Service:

.. code-block:: bash

    sudo systemctl start beegfs-client
    sudo systemctl status beegfs-client


Repeat the same in other client nodes. Then check if the clinets are registered with the 
management server.

.. code-block:: bash

    sudo beegfs node list --mgmtd-addr node1:8010 --node-type client




Finally, to verify that everything is working correctly, create a test file in the 
`/scratch` directory from any client node and check whether it is visible from the other 
client nodes.


.. code-block:: bash

    ssh node3
    touch /scratch/testfile_from_node3.txt
    ssh node4
    ls /scratch/


OpenLDAP Server and SSSD Client Integration
----------------------------


The OpenLDAP server is on a control node and and LDAP clients are on login and compute nodes.

OpenLDAP Server (Control Node)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Install LDAP packages:

.. code-block:: bash

    sudo dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm -y
    sudo dnf install epel-release -y
    sudo dnf install openldap-servers openldap-clients -y
    sudo dnf install vim -y


Enable and start LDAP service: 

.. code-block:: bash

    sudo systemctl enable --now slapd
    sudo systemctl status slapd


Load standard schemas:


.. code-block:: bash

    sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/core.ldif
    sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
    sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
    sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif


Generate admin password hash:

.. code-block:: bash

    slappasswd


Copy the hash for the next step (example: `{SSHA}bS9h9bbVyVyccwYhO9Xt2Jz9JepWZc5E`).

Configure database suffix, root DN, and password:

Create `/root/db_config.ldif`:

.. code-block:: bash


    dn: olcDatabase={2}mdb,cn=config
    changetype: modify
    replace: olcSuffix
    olcSuffix: dc=ncitraininf,dc=local
    -
    replace: olcRootDN
    olcRootDN: cn=admin,dc=ncitraininf,dc=local
    -
    replace: olcRootPW
    olcRootPW: {SSHA}bS9h9bbVyVyccwYhO9Xt2Jz9JepWZc5E


Apply:

.. code-block:: bash

    sudo ldapmodify -Y EXTERNAL -H ldapi:/// -f /root/db_config.ldif


Create base domain `/root/domain.ldif`:

.. code-block:: bash

    dn: dc=ncitraininf,dc=local
    objectClass: top
    objectClass: dcObject
    objectClass: organization
    o: NCI Training
    dc: ncitraininf


Add:


.. code-block:: bash

    ldapadd -x -D "cn=admin,dc=ncitraininf,dc=local" -W -f /root/domain.ldif


Create organizational units `/root/base.ldif`:

.. code-block:: bash

    dn: ou=People,dc=ncitraininf,dc=local
    objectClass: organizationalUnit
    ou: People

    dn: ou=Groups,dc=ncitraininf,dc=local
    objectClass: organizationalUnit
    ou: Groups



Add:

.. code-block:: bash

    ldapadd -x -D "cn=admin,dc=ncitraininf,dc=local" -W -f /root/base.ldif


and `/root/people.ldif`:

.. code-block:: bash

    dn: ou=People,dc=ncitraininf,dc=local
    objectClass: organizationalUnit
    ou: People


Add:

.. code-block:: bash

    sudo ldapadd -x -D "cn=admin,dc=ncitraininf,dc=local" -W -f /root/people.ldif


Add a test group `/root/group.ldif`:

.. code-block:: bash

    dn: cn=training,ou=Groups,dc=ncitraininf,dc=local
    objectClass: posixGroup
    cn: training
    gidNumber: 10000


Add:

.. code-block:: bash

    ldapadd -x -D "cn=admin,dc=ncitraininf,dc=local" -W -f /root/group.ldif


Add a test user `/root/user.ldif`:

.. code-block:: bash

    dn: uid=john,ou=People,dc=ncitraininf,dc=local
    objectClass: inetOrgPerson
    objectClass: posixAccount
    objectClass: shadowAccount
    cn: John
    sn: Doe
    uid: john
    uidNumber: 10000
    gidNumber: 10000
    homeDirectory: /home/john
    loginShell: /bin/bash
    userPassword: {SSHA}<hash-from-slappasswd>


Add:

.. code-block:: bash

    ldapadd -x -D "cn=admin,dc=ncitraininf,dc=local" -W -f /root/user.ldif


Verify entries

.. code-block:: bash

    ldapsearch -x -b dc=ncitraininf,dc=local




LDAP Clients (Login / Compute Nodes)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Install SSSD and tools

.. code-block:: bash

    sudo dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm
    sudo dnf install epel-release -y
    sudo dnf install sssd sssd-ldap sssd-tools oddjob-mkhomedir -y


Create `/etc/sssd/sssd.conf`

.. code-block:: bash

    [sssd]
    services = nss, pam
    domains = ldap

    [domain/ldap]
    id_provider = ldap
    auth_provider = ldap
    ldap_uri = ldap://10.0.1.170
    ldap_search_base = dc=ncitraininf,dc=local
    ldap_default_bind_dn = cn=admin,dc=ncitraininf,dc=local
    ldap_default_authtok_type = password
    ldap_default_authtok = ldappassword
    cache_credentials = True
    enumerate = True
    fallback_homedir = /home/%u
    ldap_tls_reqcert = never
    ldap_id_use_start_tls = False
    debug_level = 9

    ldap_schema = rfc2307
    ldap_user_object_class = inetOrgPerson
    ldap_group_object_class = posixGroup
    ldap_user_search_base = dc=ncitraininf,dc=local
    ldap_group_search_base = dc=ncitraininf,dc=local
    ldap_user_search_filter = (objectClass=inetOrgPerson)
    ldap_group_search_filter = (objectClass=posixGroup)

Set permissions:

.. code-block:: bash

    sudo chmod 600 /etc/sssd/sssd.conf
    sudo chown root:root /etc/sssd/sssd.conf


Configure Name Service Switch:

Edit `/etc/nsswitch.conf`:

.. code-block:: bash

    # Generated by authselect
    # Do not modify this file manually, use authselect instead. Any user changes will be overwritten.
    # You can stop authselect from managing your configuration by calling 'authselect opt-out'.
    # See authselect(8) for more details.

    # In order of likelihood of use to accelerate lookup.

    passwd:     files sss
    shadow:     files sss
    group:      files sss
    hosts:      files dns myhostname
    services:   files
    netgroup:   files
    automount:  files

    aliases:    files
    ethers:     files
    gshadow:    files
    networks:   files dns
    protocols:  files
    publickey:  files
    rpc:        files


Enable automatic home directories

.. code-block:: bash

    sudo authselect enable-feature with-mkhomedir
    sudo authselect apply-changes


Clear old SSSD cache:

.. code-block:: bash

    sudo systemctl stop sssd
    sudo sss_cache -E


Enable and start SSSD

.. code-block:: bash

    sudo systemctl enable --now sssd
    sudo systemctl status sssd


Test LDAP connectivity and user lookup

.. code-block:: bash

    getent passwd john
    ldapsearch -x -H ldap://<LDAP_SERVER_IP> -D "cn=admin,dc=ncitraininf,dc=local" -W -b dc=ncitraininf,dc=local



PBS Installation and Configuration
----------------------------

The PBS server is installed on the control node, while the PBS clients are installed on the
login and compute nodes.


Install the following on all nodes:

.. code-block:: bash

    sudo dnf update -y
    sudo dnf config-manager --set-enabled crb
    sudo dnf install -y epel-release
    sudo dnf groupinstall -y "Development Tools"
    sudo dnf install -y libedit-devel libical-devel ncurses-devel 
    sudo dnf install make cmake gcc gcc-c++
    sudo dnf install -y libX11-devel libXt-devel libXext-devel libXmu-devel
    sudo dnf install -y tcl-devel tk-devel
    sudo dnf install -y postgresql-devel postgresql-server postgresql-contrib 
    sudo dnf install -y python3 python3-devel perl
    sudo dnf install -y expat-devel
    sudo dnf install -y libedit-devel
    sudo dnf install -y hwloc-devel
    sudo dnf install -y libical-devel
    sudo dnf install java-21-openjdk-devel
    sudo dnf install -y cjson-devel
    sudo dnf install -y swig swig-doc
    sudo dnf install -y vim


Then build OpenPBS from source all nodes:

.. code-block:: bash

    sudo git clone https://github.com/openpbs/openpbs.git
    cd openpbs
    sudo ./autogen.sh
    sudo ./configure --prefix=/opt/pbs
    sudo make -j$(nproc)
    sudo make install
    echo "export PATH=/opt/pbs/bin:/opt/pbs/sbin:\$PATH" | sudo tee /etc/profile.d/pbs.sh
    source /etc/profile.d/pbs.sh


Once installed, configure PBS by editing the configuration file. Edit the file `sudo vim /etc/pbs.conf`
On the head node, set the following parameters:

.. code-block:: bash

    PBS_SERVER=node1
    PBS_START_SERVER=1
    PBS_START_SCHED=1
    PBS_START_COMM=1
    PBS_START_MOM=0
    PBS_EXEC=/opt/pbs
    PBS_HOME=/var/spool/pbs
    PBS_CORE_LIMIT=unlimited
    PBS_SCP=/bin/scp


on the compute nodes, set:

.. code-block:: bash

    PBS_SERVER=node1
    PBS_START_SERVER=0
    PBS_START_SCHED=0
    PBS_START_COMM=0
    PBS_START_MOM=1
    PBS_HOME=/var/spool/pbs
    PBS_EXEC=/opt/pbs

on the login node, set:

.. code-block:: bash

    PBS_SERVER=node1
    PBS_START_SERVER=0
    PBS_START_SCHED=0
    PBS_START_COMM=0
    PBS_START_MOM=0
    PBS_HOME=/var/spool/pbs
    PBS_EXEC=/opt/pbs


Create the required directories and set permissions on the head node:

.. code-block:: bash

    sudo mkdir -p /var/spool/pbs/server_priv/security
    sudo chown root:root /var/spool/pbs/server_priv/security
    sudo chmod 700 /var/spool/pbs/server_priv/security

run this on all nodes **This is very important**:

.. code-block:: bash

    sudo chmod 4755 /opt/pbs/sbin/pbs_iff /opt/pbs/sbin/pbs_rcp


On all nodes

.. code-block:: bash

    sudo sh -c 'echo "node1" > /var/spool/pbs/server_name'

On the head node, initialize the PBS server:

.. code-block:: bash

    sudo /opt/pbs/libexec/pbs_postinstall



Then enable and start PBS services on all nodes:

.. code-block:: bash

    sudo systemctl start pbs
    sudo systemctl enable pbs
    sudo systemctl status pbs

The add the comptue nodes to the PBS server. Do this on the head node:

.. code-block:: bash

    sudo /opt/pbs/bin/qmgr -c "create node node3"
    sudo /opt/pbs/bin/qmgr -c "create node node4"
    sudo /opt/pbs/bin/qmgr -c "create node node5"


Then verify the nodes are added:

.. code-block:: bash


    sudo /opt/pbs/bin/qmgr -c "list server"


Verify PBS is reachable from the login node:

.. code-block:: bash
    
    sudo /opt/pbs/bin/qstat -B





























