
Slurm Cluster
============================

The design for the slurm cluster is as follows:

1. One control or head node (node1)
2. One login node (node2)
3. Three compute nodes (node3, node4, node5)
4. Two Storage nodes (node6, node7)

Initial packages to install on all nodes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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


    sudo beegfs node list --mgmtd-addr node1:8010





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

    cd /opt/beegfs/sbin/
    ./beegfs-setup-meta -p /BeeGFS/metadata/ -s 1 -m node1

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

    sudo beegfs node list --mgmtd-addr node1:8010 --node-type meta

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

    cd /opt/beegfs/sbin/
    sudo ./beegfs-setup-storage -p /storage/stor1 -s 1 -i 101 -m node1
    sudo ./beegfs-setup-storage -p /storage/stor2 -s 1 -i 102 -m node1

* `-p /storage/stor1` : Specifies the storage target path.
* `-s 1` : Assigns the storage server ID.
* `-i 101` : Sets a unique storage target index (should be unique across all storage targets).
* `-m node1`: Specifies the BeeGFS management node.

On the second storage node this will be:

.. code-block:: bash

    cd /opt/beegfs/sbin/
    sudo ./beegfs-setup-storage -p /storage/stor1 -s 2 -i 201 -m node1
    sudo ./beegfs-setup-storage -p /storage/stor2 -s 2 -i 202 -m node1




By convention, the target index begins with the storage server ID, followed by a unique number.
Start the BeeGFS Storage Service:


.. code-block:: bash
    
    sudo systemctl start beegfs-storage
    sudo systemctl status beegfs-storage



Repeat this process on all storage servers. Then, on the management node, verify that the 
storage servers are correctly registered.

.. code-block:: bash

    sudo beegfs node list --mgmtd-addr node1:8010 --node-type storage

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

































