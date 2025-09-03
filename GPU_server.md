# GPU AWS Instance

Create a multi-GPU AWS instance 
* AMI: Deep Learning OSS Nvidia Driver AMI GPU PyTorch 2.7 (Ubuntu 22.04) 20250602
* AMI id: ami-05ee60afff9d0a480
* Instance: p4d.24xlarge
* Firewall (security groups)
  - Allow SSH traffic from -Anywhere
  - Allow HTTPS traffic from the internet
  - Allow HTTP traffic from the internet
* Configure storage  - 300 GiB

## Verify OS

```bash
lsb_release -a
```

## Verify CPU

```bash
lscpu | grep "Vendor ID"
```

## Verify nvidia devices

```bash
lspci | grep -i nvidia
```

## Create directories

```bash
sudo mkdir /apps
sudo chown -R $(whoami):$(whoami) /apps
```

## Clone spack

```bash
cd /apps
git clone -c feature.manyFiles=true --depth=2 https://github.com/spack/spack.git
. spack/share/spack/setup-env.sh
```

## Find a spack compilers

```bash
spack list
spack compiler find
spack compilers
```

## Install cuda

```bash
spack install cuda@12.3 
spack find
spack load cuda@12.3.2
which nvcc
```

## Test a cuda program

```c
#include <iostream>
#include <cuda_runtime.h>

int main() {
    int deviceCount = 0;
    cudaError_t err = cudaGetDeviceCount(&deviceCount);

    if (err != cudaSuccess) {
        std::cerr << "Error detecting CUDA devices: " << cudaGetErrorString(err) << std::endl;
        return 1;
    }

    std::cout << "Number of CUDA-capable GPUs: " << deviceCount << std::endl;
    return 0;
}

```

```bash
nvcc count.cu
./a.out
```



# Enable MIG in each GPU

```bash
for i in {0..7}; do
  sudo nvidia-smi -i $i -mig 1
done
```


```bash
sudo reboot
```

## MIG each GPU

To find the MIG options available

```bash
 nvidia-smi mig -lgip -i 0
```

We need only 3 MIGs per GPU so we are going with 2g.20gb

```bash
for gpu in {0..7}; do
  for _ in {1..3}; do
    sudo nvidia-smi mig -cgi 14 -C -i $gpu
  done
done
```

## Count GPU again

```bash
nvcc count.cu
./a.out
```

It should give you 24 GPUs.

## Set spack environment activation for all users

```bash
sudo nano /etc/profile.d/spack.sh

export SPACK_ROOT=/apps/spack
. $SPACK_ROOT/share/spack/setup-env.sh

sudo chmod a+r /etc/profile.d/spack.sh
```

logout and login

```bash
spack --help
```

## Create the spackadmin user group

```bash
sudo groupadd spackadmin
getent group spackadmin
sudo usermod -aG spackadmin $USER
```

logout and login

```bash
groups
```

### Set Permisions

```bash
sudo chown -R root:spackadmin /apps
sudo chmod -R g+rwX /apps
sudo chmod g+s /apps
sudo find /apps -type d -exec chmod g+s {} \;
sudo chmod -R o=rx /apps
```



## Create cuda user group

```bash
sudo groupadd cudausers
```

Set read and execute permisison for /apps

```bash
sudo apt install acl

sudo setfacl -R -m g:cudausers:rx /apps
sudo setfacl -R -d -m g:cudausers:rx /apps
getfacl /apps
```

### Create non-sudo users

```bash
sudo adduser user1
sudo adduser user2
.
.
.
sudo adduser user24
```



## Add all users to cudausers

```bash
sudo usermod -aG cudausers user1
sudo usermod -aG cudausers user2
```

