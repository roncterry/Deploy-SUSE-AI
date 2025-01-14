# Deploy-SUSE-AI

Scripts used to automate the deployment of the SUSE AI stack.

The starting point for these scripts is:

* One or more downstream AI cluster nodes that have a SLES (or SL Micro?) OS installed on them 
* The NVIDIA drivers installed on the nodes with GPUs
* Rancher Manager installed on your management cluster

Do the following to deploy the SUSE AI stack:

1) Deploy the RKE2 cluster on the Downstream AI Cluster
   
   a) On the first cluster node, the one that will be the control plan node, run the script: `01a-install_first_rke2_server.sh`   
   
   b) On the other cluster nodes that will be worker nodes run the script: `01b-install_rke2_agent.sh`

2) Import the Downstream AI Cluster into Rancher Manager (optional at this point, can be done later)
   
   a) Log into the Rancher Manager Web UI as an admin user
   
   b) From the navigation pane on the left select: **Cluster Management**
   
   c) On the **Clusters** screen, in the top right cornet, click: **Import Existing**
   
   d) On the **Cluster: Import** screen click on: **Generic**
   
   e) On the **Cluster : Import Generic** screen enter the cluster name and optionally a description and then in the bottom right corner click: Create
   
   f) Copy the command to be run (probably the one that bypasses SSL conformation for clusters with a self-signed certificate) and run it on you management machine or a cluster node that has the `kubectl` command installed


3) Install the NVIDIA GPU Operator
   
   a) On the cluster nodes that have NVIDIA GPUs, to ensure the compute utils are installed, run the script: `02-install_nvidia_compute_utils.sh`
  
   b) On your management machine, or any of the downstream AI cluster nodes that have the `kubectl` and `helm` commands installed, run the script: `03-install_nvidia_gpu_operator.sh`


4) Install the SUSE Storage (Longhorn)
   
   On your management machine, or any of the downstream AI cluster nodes that have the `kubectl` and `helm` commands installed, run the script: `04-install_longhorn.sh`


5) Install SUSE Observability (StackState)
   
   On your management machine, or any of the downstream AI cluster nodes that have the `kubectl` and `helm` commands installed, run the script: `05-install_observability.sh`


6) Install SUSE Security (NueVector)
   
   On your management machine, or any of the downstream AI cluster nodes that have the `kubectl` and `helm` commands installed, run the script:


7) Configure Access to the SUSE Rancher Application Collection
   
   On your management machine, or any of the downstream AI cluster nodes that have the `kubectl` and `helm` commands installed, run the script: `10-connect_to_app_collection.sh`


At this point the base set of applications is installed on the downstream AI cluster. You can now use the following scripts to deploy the AI stack applications. These scripts can be run on our management machine or any of the downstream AI cluster nodes that have the `kubectl` and `helm` commands installed.

`21-install_milvus.sh` : This installs Milvus on the AI cluster. Do this if you want to use the Milvus vector database in conjunction with Open WebUI.

`22-install_ollama.sh` : This installs only Ollama with a single model. Do this if you want to deploy the AI stack in a ore modular fashion or are not going to use Open WebUI. You must supply of of the following arguments to the script:

* `without_gpu` (installs Ollama without GPU support - you probably don't want this)
* `with_gpu`  (Installs Ollama with GP support and a single model)
* `with_gpu_and_ingress`  (Installs Ollama with GPU support and configures an ingress allowing direct communication with Ollama)

`25-install_open-webui_with_ollama.sh` : This installs Ollama and then Open WebUI. You must supply of of the following arguments to the script:

* `without_gpu` (installs Ollama without GPU support and a single model and installs Open WebUI - you probably don't want this)
* `with_gpu ` (Installs Ollama with GPU support and a single model and installs Open WebUI)
* `with_gpu_and_milvus`  (Installs Ollama with GPU support and configures Ollaman and Open WebUI to use Milvus)
