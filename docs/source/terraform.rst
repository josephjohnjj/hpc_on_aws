Terraform
============================


Configure AWS
----------------

Make sure you have an IAM access key and configure AWS.

.. code-block:: bash
    :linenos:

    aws configure --profile terraform-user

    AWS Access Key ID [None]: A*********************T
    AWS Secret Access Key [None]: 7************************4             
    Default region name [None]: us-east-1
    Default output format [None]: yaml

Where ``terraform-user`` is the IAM user you have created, with the access key id ``A*********************T``
and access key ``7************************4``.  

.. code-block:: bash
    :linenos:

    aws configure list
    aws sts get-caller-identity

 
Sample configuration
---------------------

The set of files used to describe infrastructure in Terraform is known as a Terraform configuration. 
You will write your first configuration to define a single AWS EC2 instance.


.. important::

    Each Terraform configuration must be in its own working directory. 

.. code-block:: hcl
    :linenos:

    terraform {
        required_providers {
            aws = {
              source  = "hashicorp/aws"
              version = "~> 4.16"
            }
        }

        required_version = ">= 1.2.0"
    }

    provider "aws" {
      region  = "us-west-2"
    }

    resource "aws_instance" "app_server" {
      ami           = "ami-830c94e3"
      instance_type = "t2.micro"

      tags = {
        Name = "ExampleAppServerInstance"
      }
    }

Terraform Block
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The ``terraform {}`` block contains Terraform settings, including the required providers Terraform will use to provision your infrastructure. 
For each provider, the source attribute defines an optional hostname, a namespace, and the provider type. 

* Terraform installs providers from the Terraform Registry by default. 
* In this example configuration, the aws provider's source is defined as hashicorp/aws, which is shorthand for ``registry.terraform.io/hashicorp/aws``.


Privider Block
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The provider block configures the specified provider, in this case ``aws``. A provider is a plugin that Terraform uses to create and manage your resources.
You can use multiple provider blocks in your Terraform configuration to manage resources from different providers. You can even use different providers 
together. 


Resource Blocks
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Resource blocks to define components of your infrastructure. A resource might be a physical or virtual component such as an EC2 instance, 
or it can be a logical resource such as a Heroku application.

Resource blocks have two strings before the block: the resource type and the resource name. In this example, 

* The resource type is aws_instance and the name is app_server. 
* The prefix of the type maps to the name of the provider. 
* In the example configuration, Terraform manages the aws_instance resource with the aws provider. 
* Together, the resource type and resource name form a unique ID for the resource. 
* For example, the ID for your EC2 instance is aws_instance.app_server.



Initialize the directory
---------------------------------

When you create a new configuration  you need to initialize the directory with terraform init.
Initializing a configuration directory downloads and installs the providers defined in the configuration, which in this case is the aws provider.


.. code-block:: bash
    :linenos:

    terraform init

Format and validate the configuration
---------------------------------

The terraform fmt command automatically updates configurations in the current directory for readability and consistency.

.. code-block:: bash
    :linenos:

    terraform fmt


You can also make sure your configuration is syntactically valid and internally consistent by using the terraform validate command.

.. code-block:: bash
    :linenos:

    terraform validate


Create infrastructure
---------------------------------

Apply the configuration now with the terraform apply command. Terraform will print output similar to what is shown below. We have truncated some
of the output to save space.

.. code-block:: bash
    :linenos:

    terraform apply


Inspect state
----------------

Terraform writes ist data into a file called ``terraform.tfstate``. Terraform stores the IDs and 
properties of the resources it manages in this file, so that it can update or destroy those 
resources going forward.


.. code-block:: bash
    :linenos:

    terraform show

When Terraform created this EC2 instance, it also gathered the resource's metadata from the AWS 
provider and wrote the metadata to the state file. 

List all the resources using

.. code-block:: bash
    :linenos:
    
    terraform state list


Changing configuration
-------------------------

You can change the configuration. For instance you can change the AMI. When you do this the old
instance is deleted and a new one created. You can the apply the changes using

.. code-block:: bash
    :linenos:
    
    terraform apply


* ``-/+`` in the outputs  means that Terraform will destroy and recreate the resource, rather than updating it in-place.
* ``~`` indicates that the resources are updated in-place. 

Destroy resources
---------------------


The ``terraform destroy`` command terminates resources managed by your Terraform project. 
This command is the inverse of terraform apply in that it terminates all the resources specified in 
your Terraform state. 

.. important::

    It does not destroy resources running elsewhere that are not managed by the current Terraform project.

Configuration variables
--------------------------

Terraform variables allow you to write configuration that is flexible and easier to re-use.

Here we are creating a file called ``variable.tf`` that has following code.

.. code-block:: bash
    :linenos:

    variable "instance_name" {
        description = "Value of the Name tag for the EC2 instance"
        type        = string
        default     = "ExampleAppServerInstance"
    }

The ``instance_name`` variable block will default to its default value unless you declare a different value.

.. important::
    
    Terraform loads all files in the current directory ending in .tf, so you can name your configuration files however you choose.

``main.tf`` is changes to:

.. code-block:: bash
    :linenos:

    tags = {
        Name = var.instance_name
    }

Now apply the configuration again, this time overriding the default instance name by passing in a 
variable using the ``-var`` flag. Terraform will update the instance's Name tag with the new name.


.. code-block:: bash
    :linenos:

    apply -var "instance_name=TestInstance"


Assign values with a file
--------------------

Entering variable values manually is time consuming and error prone. Instead, you can capture variable 
values in a file.

Create a file named ``varfile.tfvars`` with the following contents.

.. code-block:: bash
    :linenos:

    instance_name = "PersistantValues"


Terraform automatically loads all files in the current directory with the exact name ``terraform.tfvars``.
You can also use the ``-var-file`` flag to specify other files by name.

Output instance configuration
-------------------------------

Create a file called outputs.tf in your learn-terraform-aws-instance directory. Add the configuration
below to outputs.tf to define outputs for your EC2 instance's ID and IP address.

.. code-block:: bash
    :linenos:

    output "instance_id" {
        description = "ID of the EC2 instance"
        value       = aws_instance.app_server.id
    }

    output "instance_public_ip" {
      description = "Public IP address of the EC2 instance"
      value       = aws_instance.app_server.public_ip
    }


Onece you execute ``terraform apply`` it prints output values to the screen. You can also query the
outputs with the ``terraform output`` command.



Output instance configuration
-------------------------------

Create a file called outputs.tf in your learn-terraform-aws-instance directory. Add the configuration
below to outputs.tf to define outputs for your EC2 instance's ID and IP address.

.. code-block:: bash
    :linenos:

    output "instance_id" {
        description = "ID of the EC2 instance"
        value       = aws_instance.app_server.id
    }

    output "instance_public_ip" {
      description = "Public IP address of the EC2 instance"
      value       = aws_instance.app_server.public_ip
    }


Onece you execute ``terraform apply`` it prints output values to the screen. You can also query the
outputs with the ``terraform output`` command.



HCP Terraform
--------------------

Use the tutorial given below:

https://developer.hashicorp.com/terraform/tutorials/cloud-get-started/cloud-login

