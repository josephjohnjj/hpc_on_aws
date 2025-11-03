
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

Passwordless SSH is configured between all nodes in the cluster. There are some complications
when using AWS. This has to be specifically removed in the configuration file
`/etc/ssh/sshd_config.d/60-cloudimg-settings.conf`.

BeeGFS Installation
----------------------------

The first important thing here is to make sure that the OS is compatible with the BeeGFS versions
we are using. Or else this could cause issues when installing the BeeGFS client.

Directory setup
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Management node should have a `/BeeGFS` directory. 

.. code-block:: bash

    sudo mkdir /BeeGFS


It should have a disk available to it, usually `/dev/nvme1n1`. You can check the available disks
using `lsblk` command.

Format the disk and mount it to `/BeeGFS`.

.. code-block:: bash

    sudo mkfs.xfs /dev/nvme1n1
    sudo mount /dev/nvme1n1 /BeeGFS
    sudo systemctl daemon-reload

Once loaded you can check the mount using `df -h` command. Craete  a directory `management` inside
`/BeeGFS` to hold the management server data.

.. code-block:: bash
    
    sudo mkdir /BeeGFS/management

On the storage nodes, create a `/BeeGFS` directory as well. 

.. code-block:: bash
    
    sudo mkdir /BeeGFS

Mount a disk to `/BeeGFS` on each storage node similar to the management node. 

.. code-block:: bash

    sudo mkfs.xfs /dev/nvme1n1
    sudo mount /dev/nvme1n1 /BeeGFS
    sudo systemctl daemon-reload


In this design the metadata server is co-located with the storage server.

.. code-block:: bash
    
    sudo mkdir /BeeGFS/metadata


We also have two storage targets per storage node. 

.. code-block:: bash
    
    sudo mkdir /storage
    sudo mkdir /storage/stor1
    sudo mkdir /storage/stor2

In this design each storage node has two additional disks, usually `/dev/nvme2n1` and
`/dev/nvme3n1`. Format and mount them to `/storage/stor1` and `/storage/stor2` respectively.


.. code-block:: bash

    sudo mkfs.xfs /dev/nvme2n1
    sudo mkfs.xfs /dev/nvme3n1

    sudo mount /dev/nvme2n1 /storage/stor1
    sudo mount /dev/nvme3n1 /storage/stor2

    sudo systemctl daemon-reload


Do this on both storage nodes.


Configure Management Node
~~~~~~~~~~~~~~~~~~~~~~~~~~~~


Install BeeGFS Management Service

.. code-block:: bash

    sudo dnf install beegfs-mgmtd

Setup BeeGFS Management Service. The `sbin` directory contains the executables needed for 
setting up and managing BeeGFS.

.. code-block:: bash

    cd /opt/beegfs/sbin/
    sudo ./beegfs-setup-mgmtd -p /BeeGFS/management/


This initializes the BeeGFS management service and sets the management directory.

Configure Authentication and Settings.

.. code-block:: bash

    cd /etc/beegfs/
    sudo vi AuthFile

The `AuthFile` is used to authenticate other BeeGFS services with the management service.
This ensures that only authorized services can connect to the management service. In this
add the secret key `ach123!` to the AuthFile. And this should be the same across all nodes.

This is a necesaary step on you will run into errors when starting the services.

Edit the `beegfs-mgmtd.conf` file to set the configuration parameters for the management service.
Set the the parameter `connAuthFile`.  

.. code-block:: bash

    sudo vi beegfs-mgmtd.conf
    connAuthFile = /etc/beegfs/AuthFile

Restart and Verify the Service

.. code-block:: bash

    sudo systemctl start beegfs-mgmtd
    sudo systemctl status beegfs-mgmtd


You can also check the logs for any errors.

.. code-block:: bash

    less /var/log/beegfs-mgmtd.log


Ensure the firewall allows necessary ports for BeeGFS communication.

Configure Metadata server
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

There are two metadata servers (node 6 and node7) in this design. The metadata server is
co-located with the storage server.

 Install BeeGFS Metadata Service

.. code-block:: bash

    sudo dnf install beegfs-meta

Installs the BeeGFS metadata service, responsible for managing file system metadata.
Setup BeeGFS Metadata Service:

.. code-block:: bash

    cd /opt/beegfs/sbin/
    ./beegfs-setup-meta -p /BeeGFS/metadata/ -s 1 -m node1

* `-p /BeeGFS/metadata/`` : Specifies the metadata storage path.

* `-s 1` : Assigns the metadata storage target ID 1.

* `-m node1`: Specifies the BeeGFS management node.

In the second node use `-s 2` to assign the metadata storage target ID 2.

A metadata target is the logical storage location managed by a single beegfs-meta server.
A single beegfs-meta server can only manage one target. 
You can run multiple beegfs-meta servers on the same physical node as long as each server 
manages a different target (backed by a different partition).


Configure Authentication File

.. code-block:: bash

    sudo vi beegfs-mgmtd.conf
    connAuthFile = /etc/beegfs/AuthFile


Edit the `beegfs-meta.conf` file to set the configuration parameters for the metadata service.
Set the the parameter `connAuthFile`.  

Start and Check Metadata Service

.. code-block:: bash

    sudo systemctl start beegfs-meta
    sudo systemctl status beegfs-meta

This should be done on both metadata servers.

Storage Server Configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Install BeeGFS Storage Service

.. code-block:: bash

    sudo dnf install beegfs-storage

In this case we first set the configuration file before running the setup script. In fact 
you can do this for all services.

Set the AuthFile:


.. code-block:: bash

    cd /etc/beegfs
    sudo vi beegfs-storage.conf

Key parameters to configure:

* `storeStorageDirectory`: Defines the storage location (`storeStorageDirectory = /storage/stor1,/storage/stor2`).
* `logLevel`:  Adjusts logging verbosity.
* `tuneTargetChooser`: Controls how new storage targets are assigned.
* `sysMgmtdHost`:  Specifies the BeeGFS management node hostname (`sysMgmtdHost = node1`).
* `connAuthFile` : Path to the authentication file that enables secure communication between nodes (`connAuthFile = /etc/beegfs/AuthFile`).



Setup Storage Targets:

The storage targets behave a bit differently from metadata targets in BeeGFS. 
Each BeeGFS storage daemon (beegfs-storage) manages one or more storage targets.
In this case each daemon has two storage targets. 

.. code-block:: bash

    cd /opt/beegfs/sbin/
    ./beegfs-setup-storage -p /storage/stor1 -s 1 -i 101 -m node1
    ./beegfs-setup-storage -p /storage/stor1 -s 1 -i 102 -m node1

* `-p /storage/stor1` : Specifies the storage target path.
* `-s 1` : Assigns the storage server ID.
* `-i 101` : Sets a unique storage target index (should be unique across all storage targets).
* `-m node1`: Specifies the BeeGFS management node.

On the second storage node this will be:

.. code-block:: bash

    cd /opt/beegfs/sbin/
    ./beegfs-setup-storage -p /storage/stor2 -s 2 -i 201 -m node1
    ./beegfs-setup-storage -p /storage/stor2 -s 2 -i 202 -m node1


It is a convention for the target index to start with the storage server ID followed by a 
unique number.

Start the BeeGFS Storage Service

.. code-block:: bash
    
    sudo systemctl start beegfs-storage
    sudo systemctl status beegfs-storage

This should be done for all storage servers.




























