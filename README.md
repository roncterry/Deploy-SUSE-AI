# Deploy-SUSE-AI

Scripts used to automate the deployment of the SUSE AI stack.

The starting point for these scripts is:

* One or more downstream AI cluster nodes that have a SLES (or SL Micro?) OS installed on them 
* The NVIDIA drivers installed on the nodes with GPUs
  * If the OS is SLES install the NVIDIA-Compute module
  * If the OS is SL Micro follow the instructions to install the NVIDIA drivers -[Installing NVIDIA GPU Drivers on SUSE Linux Micro](https://documentation.suse.com/suse-ai/1.0/html/NVIDIA-GPU-driver-on-SL-Micro/index.html)
* Rancher Manager installed on your management cluster
* DNS/hostname resolution configured to resolve the cluster name (aicluster01.example.com) to the first control plane node's IP address, or if you have an HA K8s cluster, round-robin resolving to all of the control plane nodes' IP addresses or to a VIP that has been configured for the cluster

## Install the SUSE AI Stack

Do the following to deploy the SUSE AI stack:

1) Deploy the RKE2 cluster on the Downstream AI Cluster
   
   a) On the first cluster node, the one that will be the (1st) control plan node, run the script: `01a-install_first_rke2_server.sh`   
   
   b) On the cluster nodes that will be worker nodes run the script: `01b-install_rke2_agent.sh`

   c) If you want an HA cluster, on the other control plane nodes, run the script: `01c-install_additional_rke2_server.sh`

3) Import the Downstream AI Cluster into Rancher Manager (optional at this point, can be done later)
   
   a) Log into the Rancher Manager Web UI as an admin user
   
   b) From the navigation pane on the left select: **Cluster Management**
   
   c) On the **Clusters** screen, in the top right corner, click: **Import Existing**
   
   d) On the **Cluster: Import** screen click on: **Generic**
   
   e) On the **Cluster : Import Generic** screen enter the cluster name and optionally a description and then in the bottom right corner click: **Create**
   
   f) Copy the command to be run (probably the one that bypasses SSL conformation for clusters with a self-signed certificates) and run it on your management machine or a cluster node that has the `kubectl` command installed


4) Install the NVIDIA GPU Operator
   
   a) On the cluster nodes that have NVIDIA GPUs, to ensure the NVIDIA compute utils are installed, run the script: `02-install_nvidia_compute_utils.sh`
  
   b) On your management machine, or any of the downstream AI cluster nodes that have the `kubectl` and `helm` commands installed, run the script: `03-install_nvidia_gpu_operator.sh`


5) Install SUSE Storage (Longhorn)
   
   On your management machine, or any of the downstream AI cluster nodes that have the `kubectl` and `helm` commands installed, run the script: `04-install_longhorn.sh`


6) Install SUSE Observability (StackState)
   
   On your management machine, or any of the downstream AI cluster nodes that have the `kubectl` and `helm` commands installed, run the script: `05-install_observability.sh`


7) Install SUSE Security (NueVector)
   
   On your management machine, or any of the downstream AI cluster nodes that have the `kubectl` and `helm` commands installed, run the script:


8) Configure Access to the SUSE Rancher Application Collection
   
   On your management machine, or any of the downstream AI cluster nodes that have the `kubectl` and `helm` commands installed, run the script: `10-connect_to_app_collection.sh`


At this point the base set of applications is installed on the downstream AI cluster. You can now use the following scripts to deploy the AI stack applications. These scripts can be run on your management machine or any of the downstream AI cluster nodes that have the `kubectl` and `helm` commands installed.

`21-install_milvus.sh` : This installs Milvus on the AI cluster. Do this if you want to use the Milvus vector database in conjunction with Open WebUI.

`22-install_ollama.sh` : This installs only Ollama with a single model. Do this if you want to deploy the AI stack in a more modular fashion or are not going to use Open WebUI. You must supply one of the following arguments to the script:

* `without_gpu` (installs Ollama without GPU support - you probably don't want this)
* `with_gpu`  (Installs Ollama with GPU support)
* `with_gpu_and_ingress`  (Installs Ollama with GPU support and configures an ingress allowing direct communication with Ollama)

`25-install_open-webui_with_ollama.sh` : This installs Ollama and then Open WebUI. (You do not need to install Ollama before running this because this chart will install both Ollama and Open WebUI.) You must supply one of the following arguments to the script:

* `without_gpu` (installs Ollama without GPU support and a single model and installs Open WebUI - you probably don't want this)
* `with_gpu ` (Installs Ollama with GPU support and a single model and installs Open WebUI)
* `with_gpu_and_milvus`  (Installs Ollama with GPU support and configures Ollaman and Open WebUI to use Milvus)

## Uninstall the SUSE AI Stack

To wipe everything out so that you can start again from scratch, two scripts are provided to completely remove the K8s cluster:

* `99a-uninstall_rke2_server.sh` : Completely uninstalls RKE2 from a server (control plane) node.

* `99b-uninstall_rke2_agent.sh` : Completely uninstalls RKE2 from an agent (worker) node.

Some additional scripts are provided to help clean up after certain applications' helm chart uninstalls where not everything is cleaned up.

* `91-clean_up_milvus_PVCs.sh` : Removes the PVCs and therefore the PV that were created by the Milvus Helm chart install but were not removed by the uninstall.
