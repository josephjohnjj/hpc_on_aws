Provisioning GPU node on AWS
============================

We are provisioning a GPU node on AWS and this requires three key aspects:

#. AWS setup
#. Terraform setup
#. Ansible setup


This document detail each of the above steps in detail.

AWS Setup
---------------------------

The AWS setup mainly involves two steps:

#. Creating an IAM user with the necessary permissions
#. Installing and configuring the AWS CLI

To provision a GPU node on AWS, you need to create an IAM user with the necessary permissions. Follow these steps:
   
   - Go to the AWS IAM console.
   - Create a new user with programmatic access.
   - Attach the `AmazonEC2FullAccess` policy to the user.
   - Save the access key ID and secret access key.

Here the policy decides what the user can do. The `AmazonEC2FullAccess` policy allows the user to create, modify, and delete EC2 instances.
The acess key ID and secret access key are used to authenticate the user when using the AWS CLI or SDKs.

The next step is to install and configure the AWS CLI. For this you can follow the official AWS documentation on 
`Installing the AWS CLI, NCI <https://docs.aws.amazon.com/cli/v1/userguide/install-linux.html>`_

Once we have the AWS CLI installed, we can configure it with the access key ID and secret access key we created earlier. Run the following 
command:

.. code-block:: bash
    :linenos:

    aws configure --profile terraform-user

    AWS Access Key ID [None]: A*********************T
    AWS Secret Access Key [None]: 7************************4             
    Default region name [None]: us-east-1
    Default output format [None]: yaml

Where ``terraform-user`` is the IAM user you have created, with the access key id ``A*********************T``
and access key ``7************************4``.  

You can verify the configuration by running:

.. code-block:: bash
    :linenos:

    aws configure list
    aws sts get-caller-identity

Where the first command lists the configuration of the AWS CLI, and the second command returns the IAM user details.

Terraform Setup
----------------

In the next step, we will set up Terraform to provision the GPU node on AWS. This involves 

#. Creating a Terraform configuration file that defines the resources we want to create, such as the EC2 instance, security groups, and IAM roles.
#. Initializing Terraform and applying the configuration to create the resources.
#. Configuring HCP (HashiCorp Cloud Platform) to manage the state of the resources.

In the following sections we will define each Terraform configuration file we have used in detail.

`main.tf <../../GPU-server/main.tf>`_
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The ``terraform`` block in a Terraform configuration is used to specify settings that apply to the entire Terraform project 
(working directory). It's typically placed in the root module and controls how Terraform behaves during operations like init, plan, apply.

The ``required_providers`` block specifies which providers are needed for the project and their versions. In this case, we are using the 
AWS provider from HashiCorp's official registry.

The ``provider`` block configures the AWS provider with the region where the resources will be created.

.. important::

    Here we are passing the ``region`` as a variable. 



`ec2.tf <../../GPU-server/ec2.tf>`_
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This file defines the EC2 instance that will be created. It includes the instance type, AMI ID, and other configurations.
The resource block defines an AWS EC2 instance with the specified attributes. 

.. code-block:: hcl
   :linenos:


    resource "aws_key_pair" "hcp_key" {
      key_name = "terraform-user"
      public_key = file("${path.module}/keys/terraform-user.pub")
    }


The ``aws_key_pair`` resource block creates an SSH key pair that will be used to access the EC2 instance. The public key is read from a file
located in the `keys` directory relative to the module path. The key name is set to  ``terraform-user``, which should match the IAM 
user created earlier.

.. important::

    Without this key pair, you won't be able to access the EC2 instance via SSH. Make sure to create the public key file
    `terraform-user.pub` in the `keys` directory before running Terraform.

The ``aws_instance`` resource block defines the EC2 instance itself. The attributes include:
- `ami`: The Amazon Machine Image (AMI) ID to use for the instance. This should be a GPU-enabled AMI.
- `instance_type`: The type of instance to create, such as `p4d.24xlarge` for GPU instances.
- `vpc_security_group_ids`: The security group IDs to associate with the instance.
- `subnet_id`: The ID of the subnet in which to launch the instance.
- `tags`: Tags to apply to the instance for identification and management.
- `associate_public_ip_address`: Whether to associate a public IP address with the instance.
- `root_block_device`: Configuration for the root block device (storage), including volume size and type.
- `instance_market_options`: Specifies the market options for the instance, such as whether it is a spot instance and the maximum price to pay for it.
- `capacity_reservation_specification`: Specifies the capacity reservation for the instance, which can be used to ensure that the instance is launched in a specific capacity reservation.

.. important::

  Both the ``instance_market_options`` and ``capacity_reservation_specification`` blocks are usually optional. But in our case we are using
  the instance type `p4d.24xlarge` which requires a capacity reservation. 


`vpc.tf <../../GPU-server/vpc.tf>`_
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This file defines the VPC (Virtual Private Cloud) and related networking resources needed for the EC2 instance. 

The resource ``aws_vpc`` block defines a Virtual Private Cloud (VPC) in which the EC2 instance will be launched. It includes:

- `cidr_block` : The CIDR block for the VPC, which defines the IP address range.
    - CIDR block of ``10.0.0.0/16`` defines an address range that starts from ``10.0.0.0`` up to ``10.0.255.255``.
    - ``10.0.0.0`` is the starting IP address of the block.
    - ``/16`` – the prefix length, meaning the first 16 bits of the IP address are fixed and define the network.
- `enable_dns_support`:  If ``true`` EC2 instances in the VPC can resolve AWS internal hostnames
- `enable_dns_hostnames`: if ``true``  AWS assigns a DNS hostname (e.g., ec2-54-123-45-67.compute-1.amazonaws.com) to instances with a public IP.

The ressource ``aws_internet_gateway`` block creates an Internet Gateway for the VPC, allowing communication between the VPC and the internet.

It includes:

- `vpc_id`: The ID of the VPC to which the Internet Gateway will be attached.

The resource ``aws_subnet`` block defines a subnet within the VPC. It includes:

- `vpc_id`: The ID of the VPC in which the subnet will be created.
- `cidr_block`: The CIDR block for the subnet, which defines the IP address.
- `map_public_ip_on_launch`: If ``true``, instances launched in this subnet will automatically receive a public IP address.
- `availability_zone`: The availability zone in which the subnet will be created. This is important for high availability and fault tolerance.

The resource ``aws_route_table`` block defines a route table for the VPC. It includes:

- `vpc_id`: The ID of the VPC to which the route table will be associated.
- `route`: A list of routes in the route table. In this case, it includes a route to the internet gateway for all traffic.


The resource ``aws_route_table_association`` block associates the route table with the subnet. It includes:

- `subnet_id`: The ID of the subnet to which the route table will be associated.
- `route_table_id`: The ID of the route table to associate with the subnet.

`security_groups.tf <../../GPU-server/security_groups.tf>`_
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This file defines the security groups for the EC2 instance. Security groups act as virtual firewalls to control inbound and outbound traffic.

- `vpc_id`: The ID of the VPC in which the security group will be created.
- `ingress`: A list of ingress rules that define the allowed inbound traffic. In this case, 
    - ``from_port = 22``: Start of the port range — port 22 is used by SSH
    - ``to_port = 22``: End of the port range — also 22, so this rule applies only to port 22
    - ``protocol = "tcp"``: SSH uses the TCP protocol.
    - ``cidr_blocks = ["0.0.0.0/0"]``:	Allows traffic from any IPv4 address on the internet
    - ``ipv6_cidr_blocks = ["::/0"]``: Allows traffic from any IPv6 address on the internet
- `egress`: A list of egress rules that define the allowed outbound traffic. In this case, it allows all outbound traffic to any destination.
   - ``from_port = 0``:	Starting port (doesn't matter because ``protocol = "-1"``)
   - ``to_port = 0``:	Ending port (doesn't matter because ``protocol = "-1"``)
   - ``protocol = "-1"``:	All protocols (TCP, UDP, ICMP, etc.)
   - ``cidr_blocks = ["0.0.0.0/0"]``:	Allows traffic from any IPv4 address on the internet

`variables.tf <../../GPU-server/variables.tf>`_
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This file defines the variables used in the Terraform configuration. Instead of hardcoding values, we use variables to make the configuration
more flexible and reusable.


.. code-block:: hcl
   :linenos:

    variable "instance_name" {
        type = string
        default = "NCI-GPU-Server"
    }

The `instance_name` variable is defined as a string with a default value of "NCI-GPU-Server". This variable can be used to set the 
name of the EC2 instance.

.. code-block:: hcl
   :linenos:

    variable "instance_type" {
 
        description = "EC2 instance type (e.g., t2.micro, p3.2xlarge)"
        type = string
        default = "t2.micro"
    }

The `instance_type` variable is defined as a string with a default value of "t2.micro". This variable can be used to set the
type of the EC2 instance. You can change the default value to a GPU-enabled instance type like `p4d.24xlarge` or `g4dn.xlarge` depending on
your requirements.

.. code-block:: hcl
   :linenos:

    variable "ami" {

        description = "AMI ID to use for launching the EC2 instance"
        type = string
        default = "ami-020cba7c55df1f615" 
    }

The `ami` variable is defined as a string with a default value of "ami-020cba7c55df1f615". This variable can be used to set the
Amazon Machine Image (AMI) ID for the EC2 instance. You can change the default value to a different AMI ID that is suitable for your use 
case, such as a GPU-enabled AMI. 



.. code-block:: hcl
   :linenos:

    variable "capacity_reservation_id" {
  
        description = "The ID of the existing EC2 Capacity Reservation to use (empty string for none)"
        type = string
        default = ""
    }

The `capacity_reservation_id` variable is defined as a string with a default value of an empty string. This variable can be used to specify
the ID of an existing EC2 Capacity Reservation to use for the instance. If you don't want to use a capacity reservation, you can leave 
this variable as an empty string.



.. code-block:: hcl
   :linenos:

    variable "target_az" {
        description = "Availability Zone to use for resources (must match capacity reservation)"
        type        = string
        default     = "us-east-1"
    }

The `target_az` variable is defined as a string with a default value of ``us-east-1``. This variable can be used to specify the
availability zone in which the resources will be created. 

.. important::

    Ensure that ``target_az`` matches the availability zone of the capacity reservation if one is used.


.. code-block:: hcl
   :linenos:

    variable "aws_region" {
      description = "The AWS region to deploy resources into"
      type        = string
      default     = "us-east-1" 
    }

The `aws_region` variable is defined as a string with a default value of ``us-east-1``. This variable can be used to specify the AWS region.

.. important::

    Ensure that the `aws_region` matches the region where your capacity reservation is located, if one is used.

You can then use each of these variables in your Terraform configuration files by referencing them with the `var` prefix, like so:

.. code-block:: hcl
   :linenos:

    ami = var.ami
    instance_type = var.instance_type
    capacity_reservation_id = var.capacity_reservation_id
    target_az = var.target_az
    aws_region = var.aws_region


.. admonition:: Explanation
   :class: attention

    In some parts of the configuration, you can see codes similar to ``aws_subnet.public.id``. Here
    
    * ``aws_subnet`` - This is the Terraform resource type used to create an Amazon VPC subnet.
    * ``public``- This is the name or label you've given the subnet resource.
    * ``id`` - This accesses the unique identifier assigned by AWS to that subnet (e.g., subnet-0abc123456def7890)

   




       










