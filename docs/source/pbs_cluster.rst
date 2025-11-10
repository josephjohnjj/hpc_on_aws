
PBS Cluster
============================

The design for the pbs cluster is as follows:

1. One control or head node (node1)
2. One login node (node2)
3. Three compute nodes (node3, node4, node5)
4. Two Storage nodes (node6, node7)

Initial packages to install on all nodes
------------------------------------------

Make sure the following packages are installed on all nodes:

.. code-block:: bash

    
    sudo dnf update -y
    sudo dnf clean all 
    sudo dnf makecache
    sudo dnf repolist
    sudo dnf install -y wget vim gcc gcc-c++ make
    sudo dnf install -y "kernel-devel-{{ ansible_kernel }}" 
    sudo dnf install -y "kernel-headers-{{ ansible_kernel }}"

    sudo wget -O https://www.beegfs.io/release/beegfs_8.2/dists/beegfs-rhel9.repo  \ 
            https://www.beegfs.io/release/beegfs_8.2/dists/beegfs-rhel9.repo

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

* Operating System: Rocky Linux 9


In some case the kernel-devel and kernel-headers versions may not match the running kernel version.
To check the versions, run the following commands on the node:

.. code-block:: bash

    uname -r
    rpm -q kernel-headers kernel-devel

If they do not match, you may need to reboot the node after installing the correct versions.
To be safe do this on all nodes after installing the kernel-devel and kernel-headers packages.

.. code-block:: bash

    sudo dnf update -y
    sudo dnf clean all
    sudo dnf makecache
    sudo dnf repolist
    sudo reboot



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




PBS Installation and Configuration
----------------------------

The PBS server is installed on the control node, while the PBS clients are installed on the
login and compute nodes.

First, disable SELinux on all nodes. OpenPBS does not work well with SELinux enabled.

.. code-block:: bash

    sudo setenforce 0




Install the following on all nodes:

.. code-block:: bash

    
    sudo dnf config-manager --set-enabled crb
    sudo dnf update -y
    sudo dnf install -y epel-release 
    sudo dnf install -y  cjson-devel \
        libedit-devel libical-devel ncurses-devel \
        make cmake rpm-build libtool gcc gcc-c++ \
        libX11-devel libXt-devel libXext libXext-devel libXmu-devel \
        tcl-devel tk-devel \
        postgresql-devel postgresql-server postgresql-contrib \
        python3 python3-devel perl expat-devel openssl-devel \
        hwloc-devel java-21-openjdk-devel  \
        swig swig-doc vim sendmail chkconfig autoconf automake git 




Then build OpenPBS from source all nodes:

.. code-block:: bash

    sudo git clone https://github.com/openpbs/openpbs.git && cd openpbs
    sudo ./autogen.sh
    sudo ./configure --prefix=/opt/pbs
    sudo make -j$(nproc) && sudo make install
    echo "export PATH=/opt/pbs/bin:/opt/pbs/sbin:\$PATH" | sudo tee /etc/profile.d/pbs.sh
    source /etc/profile.d/pbs.sh





run this on all nodes:

.. code-block:: bash

    sudo /opt/pbs/libexec/pbs_postinstall

.. code-block:: bash

    sudo chmod 4755 /opt/pbs/sbin/pbs_iff /opt/pbs/sbin/pbs_rcp


If it doesnt alreadt exist - create the required directories and set permissions on the head node:

.. code-block:: bash

    sudo mkdir -p /var/spool/pbs/server_priv/security
    sudo chown root:root /var/spool/pbs/server_priv/security
    sudo chmod 700 /var/spool/pbs/server_priv/security

.. code-block:: bash

    sudo sh -c 'echo "node1" > /var/spool/pbs/server_name'


Once installed, configure PBS by editing the configuration file. 


+--------+-------------------------------+----------------------------------------+-----------------------------------------------------------+-------------------------------------------+
| Option | Host Role                      | Task                                   | Package Contents                                         | Parameters in pbs.conf For Default Start  |
+========+===============================+========================================+===========================================================+===========================================+
| 1      | Server host, headnode, front   | Runs server, scheduler, and            | Server/scheduler/communication/MoM/client commands      | PBS_START_SERVER=1                        |
|        | end machine                    | communication daemons. Optionally      | If using failover, install on both server hosts.        | PBS_START_SCHED=1                         |
|        |                               | runs MoM daemon. Client commands       |                                                           | PBS_START_COMM=1                          |
|        |                               | are included.                          |                                                           | To run MoM, add: PBS_START_MOM=1         |
+--------+-------------------------------+----------------------------------------+-----------------------------------------------------------+-------------------------------------------+
| 2      | Execution host, MoM host       | Runs MoM. Executes job tasks.          | Execution/client commands                                | PBS_START_MOM=1                           |
|        |                               | Client commands are included.          | Install on each execution host.                          |                                           |
+--------+-------------------------------+----------------------------------------+-----------------------------------------------------------+-------------------------------------------+
| 3      | Client host, submit host,      | Users can run PBS commands and view    | Client commands                                          | None                                      |
|        | submission host                | man pages.                             | Install on each client host.                              |                                           |
+--------+-------------------------------+----------------------------------------+-----------------------------------------------------------+-------------------------------------------+




Edit the file `sudo vim /etc/pbs.conf`
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

on the login node, set:

.. code-block:: bash

    PBS_SERVER=node1
    PBS_START_SERVER=0
    PBS_START_SCHED=0
    PBS_START_COMM=0
    PBS_START_MOM=0
    PBS_HOME=/var/spool/pbs
    PBS_EXEC=/opt/pbs


on the compute nodes, set:

.. code-block:: bash

    PBS_SERVER=node1
    PBS_START_SERVER=0
    PBS_START_SCHED=0
    PBS_START_COMM=0
    PBS_START_MOM=1
    PBS_HOME=/var/spool/pbs
    PBS_EXEC=/opt/pbs




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


    sudo /opt/pbs/bin/qmgr -c "list node @active"


Verify PBS is reachable from the login node:

.. code-block:: bash
    
    sudo /opt/pbs/bin/qstat -B

On the head node, set some default server parameters:

.. code-block:: bash

    sudo /opt/pbs/bin/qmgr -c "set server default_queue = workq"
    sudo /opt/pbs/bin/qmgr -c "set server resources_default.select = 1"
    sudo /opt/pbs/bin/qmgr -c "set server flatuid = True"


LDAP Integration
----------------------------

LDAP (Lightweight Directory Access Protocol) is a protocol used for accessing and managing
directory services over a network. It is commonly used for centralized authentication and
authorization in enterprise environments. By integrating LDAP with a PBS cluster, user
authentication and management can be centralized, making it easier to handle user accounts
and permissions across multiple nodes in the cluster.

Head Node LDAP Server Configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~


On the head node, install and configure OpenLDAP server:


.. code-block:: bash

    sudo dnf config-manager --set-enabled plus
    sudo dnf repolist
    sudo dnf install openldap-servers openldap-clients
    sudo systemctl start slapd
    sudo systemctl enable slapd
    sudo systemctl status slapd


Then you will need to set the LDAP admin password. Generate the password hash using `slappasswd`.
In this example we use password **ldappassword**. Then we will create an LDIF file to set the
root password. The file is named `changerootpass.ldif`.

.. code-block:: bash


    dn: olcDatabase={0}config,cn=config
    changetype: modify
    add: olcRootPW
    olcRootPW: {SSHA}UNHjdYvrkQIhD9vRlShjlADjmJF/hhcm


Here the hash is is the same as generated by `slappasswd`. Apply the changes using the 
following command:

.. code-block:: bash


    sudo ldapadd -Y EXTERNAL -H ldapi:/// -f changerootpass.ldif 

The next step is to add the necessary LDAP schemas. The standard schemas are usually
located in the `/etc/openldap/schema/` directory. Add the following schemas:
* cosine.ldif
* nis.ldif
* inetorgperson.ldif

.. code-block:: bash

    sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
    sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif 
    sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif

    sudo systemctl restart slapd


The next step is to set the domain and configure the LDAP database. 
Create a file named `setdomain.ldif` with the following content:

.. code-block:: bash

    # Give local root (UID 0) and Manager read access to the monitor database
    dn: olcDatabase={1}monitor,cn=config
    changetype: modify
    replace: olcAccess
    olcAccess: {0}to * 
      by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" read 
      by dn.base="cn=Manager,dc=cluster,dc=lan" read 
      by * none

    # Set the LDAP database suffix (your domain)
    dn: olcDatabase={2}mdb,cn=config
    changetype: modify
    replace: olcSuffix
    olcSuffix: dc=cluster,dc=lan

    # Define the root DN (admin user for LDAP)
    dn: olcDatabase={2}mdb,cn=config
    changetype: modify
    replace: olcRootDN
    olcRootDN: cn=Manager,dc=cluster,dc=lan

    # Add root password (replace with your own SSHA hash)
    dn: olcDatabase={2}mdb,cn=config
    changetype: modify
    add: olcRootPW
    olcRootPW: {SSHA}UNHjdYvrkQIhD9vRlShjlADjmJF/hhcm

    # Set access control rules for users and the admin
    dn: olcDatabase={2}mdb,cn=config
    changetype: modify
    add: olcAccess
    olcAccess: {0}to attrs=userPassword,shadowLastChange 
      by dn="cn=Manager,dc=cluster,dc=lan" write 
      by anonymous auth 
      by self write 
      by * none
    olcAccess: {1}to dn.base="" by * read
    olcAccess: {2}to * 
      by dn="cn=Manager,dc=cluster,dc=lan" write 
      by * read


The above configuration sets the LDAP domain to `cluster.lan`, defines the admin user,
and establishes access control rules. Apply the configuration using the following commands:


.. code-block:: bash

    sudo ldapmodify -Y EXTERNAL -H ldapi:/// -f setdomain.ldif

Verify the naming contexts to ensure the domain is set correctly:

.. code-block:: bash
    sudo ldapsearch -H ldap:// -x -s base -b "" -LLL "namingContexts"


The next step is to add organizational units (OUs) to the LDAP directory. 
Create a file named `addou.ldif` with the following content:

.. code-block:: bash


    n: dc=cluster,dc=lan
    objectClass: top
    objectClass: dcObject
    objectClass: organization
    o: Cluster Organisation
    dc: cluster

    dn: cn=Manager,dc=cluster,dc=lan
    objectClass: organizationalRole
    cn: Manager
    description: OpenLDAP Manager

    dn: ou=People,dc=cluster,dc=lan
    objectClass: organizationalUnit
    ou: People

    dn: ou=Group,dc=cluster,dc=lan
    objectClass: organizationalUnit
    ou: Group

The  `addou.ldif` file creates the base domain, the Manager entry, and two OUs: `People` and `Group`.
Apply the changes using the following command:


.. code-block:: bash

    sudo ldapadd -x -D cn=Manager,dc=cluster,dc=lan -W -f addou.ldif


Next we add a user calles 'testuser1' to the LDAP directory. First, generate a password hash
using `slappasswd`. 

.. code-block:: bash

    slappasswd

In this example we use password **testuser1**. Then create a file named `user1.ldif` with 
the following content:

.. code-block:: bash


    dn: uid=testuser1,ou=People,dc=cluster,dc=lan
    objectClass: inetOrgPerson
    objectClass: posixAccount
    objectClass: shadowAccount
    cn: testuser1
    sn: user
    userPassword: {SSHA}yJcv+xLWUvgAWu+fdNN/K6V4cdS4PC5E
    loginShell: /bin/bash
    uidNumber: 2001
    gidNumber: 2001
    homeDirectory: /scratch/userhome/testuser1
    shadowLastChange: 0
    shadowMax: 0
    shadowWarning: 0

    dn: cn=testuser1,ou=Group,dc=cluster,dc=lan
    objectClass: posixGroup
    cn: testuser1
    gidNumber: 2001
    memberUid: testuser1

Here the hash is is the same as generated by `slappasswd`. The `uidNumber` and `gidNumber` 
should be unique and not conflict with existing users on the system. 

Apply the changes using the following command:


.. code-block:: bash

    sudo ldapadd -x -D cn=Manager,dc=cluster,dc=lan -W -f user1.ldif

Verify that the user has been added successfully:

.. code-block:: bash

    sudo ldapsearch -x -b "ou=People,dc=cluster,dc=lan"


Next we will enable TLS for secure LDAP communication. First, generate a self-signed TLS 
certificate:

.. code-block:: bash

    sudo openssl req -x509 -nodes -days 365   -newkey rsa:2048   -keyout /etc/pki/tls/ldapserver.key   -out /etc/pki/tls/ldapserver.crt
    sudo chown ldap:ldap /etc/pki/tls/{ldapserver.crt,ldapserver.key}


Then create a file named `tls.ldif` with the following content:

.. code-block:: bash

    dn: cn=config
    changetype: modify
    replace: olcTLSCACertificateFile
    olcTLSCACertificateFile: /etc/pki/tls/ldapserver.crt
    -
    replace: olcTLSCertificateFile
    olcTLSCertificateFile: /etc/pki/tls/ldapserver.crt
    -
    replace: olcTLSCertificateKeyFile
    olcTLSCertificateKeyFile: /etc/pki/tls/ldapserver.key


Here we specify the paths to the TLS certificate and key files. Next apply the TLS 
configuration using the following command:

.. code-block:: bash

    sudo ldapadd -Y EXTERNAL -H ldapi:/// -f tls.ldif


Then make sure the `/etc/openldap/ldap.conf` file is configured to use TLS:

.. code-block:: bash

    TLS_CACERT      /etc/pki/tls/cert.pem
    TLS_REQCERT never




LDAP Client Configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

On the `/scratch` directory create a `userhome` directory to be used as the base home
directory for LDAP users:


.. code-block:: bash

    sudo mkdir -p /scratch/userhome
    sudo chown root:root /scratch/userhome
    sudo chmod 755 /scratch/userhome


On the client nodes, install and configure the LDAP client:

.. code-block:: bash

    sudo dnf config-manager --set-enabled plus
    sudo dnf repolist

    sudo dnf install openldap-clients sssd sssd-ldap oddjob-mkhomedir -y
    sudo authselect select sssd with-mkhomedir --force

Enable and start the `oddjobd` service to support home directory creation:

.. code-block:: bash

    sudo systemctl enable --now oddjobd.service
    sudo systemctl status oddjobd.service
    


Configure the LDAP client by editing the `/etc/openldap/ldap.conf` file:

.. code-block:: bash

    URI ldap://node1/
    BASE dc=cluster,dc=lan

Next, configure SSSD by editing the `/etc/sssd/sssd.conf` file:

.. code-block:: bash

    [domain/default]
    id_provider = ldap
    autofs_provider = ldap
    auth_provider = ldap
    chpass_provider = ldap

    ldap_uri = ldap://node1/
    ldap_search_base = dc=cluster,dc=lan

    ldap_id_use_start_tls = True
    ldap_tls_cacertdir = /etc/openldap/certs
    cache_credentials = True
    ldap_tls_reqcert = allow

    [sssd]
    services = nss, pam, autofs
    domains = default

    [nss]
    homedir_substring = /scratch/userhome/%u


Once the configuration is done, set the appropriate permissions for the `sssd.conf` file:

.. code-block:: bash

    sudo chmod 0600 /etc/sssd/sssd.conf
    sudo systemctl start sssd
    sudo systemctl enable sssd
    sudo systemctl status sssd
    sudo sss_cache -E


Then verify that LDAP users can be resolved:

.. code-block:: bash

    getent passwd testuser1


Try to login to the client node using the LDAP user:

.. code-block:: bash

    su - testuser1


Sometimes SELinux can interfere with LDAP authentication.  Especialy the home directory
creation. If you encounter issues,you may need to temporarily set SELinux to permissive mode 
for testing purposes:

.. code-block:: bash

    sudo setenforce 0

On AWS, to allow password authentication over SSH, you may need to modify the SSHD 
configuration in the file `/etc/ssh/sshd_config.d/50-cloud-init.conf`:

.. code-block:: bash

    PasswordAuthentication yes

Then restart the SSHD service to apply the changes:

.. code-block:: bash

    sudo systemctl restart sshd

Now, you should be able to log in using the LDAP user credentials. Try logging in via SSH:

.. code-block:: bash

    ssh testuser1@<ip of the login node>






































    
































