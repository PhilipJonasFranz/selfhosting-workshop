# 51 - Local AI

Tested with Ubuntu Server 22.04.

```bash
# Check that GPU is present
sudo lspci

# Upgrade system before installing other packages
sudo apt-get upgrade

# Check if nouveau (open source NVIDIA driver) is loaded
sudo dmesg | grep nouveau

# If yes, blacklist to prevent conflicts
echo -e "blacklist nouveau\noptions nouveau modeset=0" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf
sudo update-initramfs -u
sudo reboot

# Install nvidia driver
sudo apt-get install nvidia-driver-550
sudo reboot
nvidia-smi

# Install docker
curl -fsSL https://get.docker.com | sudo bash

# Install nvidia container toolkit
sudo apt-get update && sudo apt-get install -y --no-install-recommends \
   curl \
   gnupg2

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update

export NVIDIA_CONTAINER_TOOLKIT_VERSION=1.18.0-1
  sudo apt-get install -y \
      nvidia-container-toolkit=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      nvidia-container-toolkit-base=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      libnvidia-container-tools=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      libnvidia-container1=${NVIDIA_CONTAINER_TOOLKIT_VERSION}

# Configure docker with nvidia runtime
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Run sample workload to check if GPU is available in docker container
sudo docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi
```

Output should look like this:

```
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 580.95.05              Driver Version: 580.95.05      CUDA Version: 13.0     |
+-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  Tesla P4                       Off |   00000000:01:00.0 Off |                  Off |
| N/A   27C    P8              6W /   75W |       0MiB /   8192MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+

+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|  No running processes found                                                             |
+-----------------------------------------------------------------------------------------+
```

Copy the compose stack over to the server and start it up. Open the Web-UI at `http:<server ip>:8080`, and create an administrator account. Then head to the profile in the top right, `Admin Panel > Settings > Models`. On the top right, click the download button, and enter a model tag to download it to the selected Ollama instance, in this case `http://ollama:11434`. I recommend `qwen3:8b`, but others that fit in the 8GB VRAM limit will work as well.

After the download is completed and you see the confirmation message that the model is ready, you are now ready to start chatting! To verify that the GPU is being used, run `nvidia-smi` while the chat is being generated. You should see a running ollama process listed in the output.

# Scaling Up

The Tesla P4 only has 8GB of video memory, and thus can only fit models of this size. If you want to run larger models, consider using enterprise GPUs, such as the Tesla P100 or Tesla P40, which feature 16 GB and 24GB of GDDR5 memory, respectively. Other models, such as the AMD Instinct MI50 16GB/32GB, are also affordable choices. However, these GPUs require a lot of airflow as they only have a passive cooler, similar to the Tesla P4. Additionally, the GPUs require an extra power connector.

Modern GPUs, such as the 3090, can also be used. Ollama can use multiple GPUs by offloading different layers of the model to other GPUs, effectively adding the video memory of all used GPUs together.