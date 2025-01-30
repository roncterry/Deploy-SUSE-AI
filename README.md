# Deploy-SUSE-AI

Scripts used to automate the deployment of the SUSE AI stack.

The starting point for these scripts is:

* One or more downstream AI cluster nodes that have a SLES (or SL Micro?) OS installed on them (***Note**: These scripts have been tested on SLES but not SL Micro*)
* The NVIDIA drivers installed on the nodes with GPUs
  * If the OS is SLES install the NVIDIA-Compute module
  * If the OS is SL Micro follow the instructions to install the NVIDIA drivers -[Installing NVIDIA GPU Drivers on SUSE Linux Micro](https://documentation.suse.com/suse-ai/1.0/html/NVIDIA-GPU-driver-on-SL-Micro/index.html)
  * Insure the open-iscsi package is installed on the cluster nodes in preparation for SUSE Storage (Longhorn) deployment
* DNS/hostname resolution configured to resolve the cluster name (aicluster01.example.com) to the first control plane node's IP address, or if you have an HA K8s cluster, round-robin resolving to all of the control plane nodes' IP addresses or to a VIP that has been configured for the cluster
* Rancher Manager installed on your management cluster (this can be donw using the scripts in the **Pre-work: Install the Rancher and Observability Clusters** section below)
* SUSE Observability installed on its own cluster (this can also be done using the scripts in the **Pre-work: Install the Rancher and Observability Clusters** section below)

## Pre-work: Install the Rancher and Observability Clusters

If you do not already have Rancher Manager deployed into a management cluster and/or SUSE Observability deployed into another downstream cluster, do the following to deploy them:

Note: SLES (or SL Micro?) must be installed on the cluster nodes for these clusters before running these scripts though the NVIDIA drivers do not need to be installed on these cluster nodes.

1) Deploy the Rancher Manager Cluster

   a) On the first Rancher Manager cluster node, the one that will be the (1st) control plan node, run the script: `01-install_first_rke2_server-rancher_cluster.sh` 

2) Deploy Rancher Manager onto the Rancher Manager Cluster

   a) On the first Rancher Manager cluster node run the script: `02-deploy_rancher_with_helm.sh`
  
3) Deploy the SUSE Observability Cluster

   a) View/edit the common observability deployment config file (`deploy_suse_observability.cfg`) and make any changes needed such as the number of replicas counts (for single node clusters leave all of the replica counts at `1`)

   b) On the first SUSE Observability cluster node, the one that will be the (1st) control plan node, run the script: `03-install_first_rke2_server-observability_cluster.sh`
   
4) Import the Downstream SUSE Observability Cluster into Rancher Manager
   
   a) Log into the Rancher Manager Web UI as an admin user
   
   b) From the navigation pane on the left select: **Cluster Management**
   
   c) On the **Clusters** screen, in the top right corner, click: **Import Existing**
   
   d) On the **Cluster: Import** screen click on: **Generic**
   
   e) On the **Cluster : Import Generic** screen enter the cluster name and optionally a description and then in the bottom right corner click: **Create**
   
   f) Copy the command to be run (probably the one that bypasses SSL conformation for clusters with a self-signed certificates) and run it on your management machine or a cluster node in the SUSE Observability cluster that has the `kubectl` command installed
   
5) Deploy SUSE Storage (Longhorn) into the Observability Cluster

   a) On the first SUSE Observability cluster node run the script: `04-install_longhorn-observability_cluster.sh`

      ***Note 1:** Ensure that the open-iscsi pacakge is installed on the cluster node(s) before deploying SUSE Storage Longhorn.*
   
      ***Note 2:** SUSE Storage (Longhorn) can also be deployed onto the SUSE Observability cluster using Rancher Manager. Make sure you modify the values to change the replicas counts to `1` if it is a single node cluster when it is deployed. You can use the documentation in the common config file for reference.*
   
7) Deploy SUSE Observability into the SUSE Observability Cluster
   
   a) On the first SUSE Observability cluster node run the script: `05-install_observability.sh`
   
   b) Retrieve the admin password from the last line of the `suse-observability-values/templates/baseConfig_values.yaml` file
   
   c) In a web browser go to the SUSE Observability web UI and log in as the "admin" user with the password retrieved from the file in the previous step

   d) Follow the steps here in the section titled **Accessing SUSE Observability** [here](https://docs.stackstate.com/get-started/k8s-suse-rancher-prime) to integrate SUSE Observability with Rancher Manager

## Install the SUSE AI Stack

Do the following to deploy the SUSE AI stack:

1) View/edit the common SUSE AI deployment config file (`deploy_suse_ai.cfg`) and make any changes needed such as replica counts (for single node clusters leave all of the replica counts at `1`)

2) Ensure the NVIDIA Compute Utils are Installed on the Nodes with a GPU

   a) On the cluster nodes that have NVIDIA GPUs, to ensure the NVIDIA compute utils are installed, run the script: `10-install_nvidia_compute_utils.sh`
   
3) Deploy the RKE2 cluster on the Downstream AI Cluster
   
   a) On the first cluster node, the one that will be the (1st) control plan node, run the script: `11a-install_first_rke2_server.sh`   
   
   b) If you want an HA cluster, on the other control plane nodes, run the script: `11b-install_additional_rke2_server.sh`

   c) On the cluster nodes that will be worker nodes run the script: `11c-install_rke2_agent.sh`

   d) To retrieve the `kubectl` command and the kubeconfig file from the AI cluster and install them onto your management machine, on the management machine run the script: `12-retrieve_kubectl_and_kubeconfig_from_rke2.sh`

4) Import the Downstream AI Cluster into Rancher Manager (optional at this point, can be done later)
   
   a) Log into the Rancher Manager Web UI as an admin user
   
   b) From the navigation pane on the left select: **Cluster Management**
   
   c) On the **Clusters** screen, in the top right corner, click: **Import Existing**
   
   d) On the **Cluster: Import** screen click on: **Generic**
   
   e) On the **Cluster : Import Generic** screen enter the cluster name and optionally a description and then in the bottom right corner click: **Create**
   
   f) Copy the command to be run (probably the one that bypasses SSL conformation for clusters with a self-signed certificates) and run it on your management machine or a cluster node that has the `kubectl` command installed

5) Install the NVIDIA GPU Operator
   
   a) On your management machine, or any of the downstream AI cluster nodes that have the `kubectl` and `helm` commands installed, run the script: `21-install_nvidia_gpu_operator.sh`

6) Install SUSE Storage (Longhorn)
   
   On your management machine, or any of the downstream AI cluster nodes that have the `kubectl` and `helm` commands installed, run the script: `22-install_longhorn.sh`

   ***Note 1:** Ensure that the open-iscsi pacakge is installed on the cluster node(s) before deploying SUSE Storage Longhorn.*

   ***Note 2:** SUSE Storage (Longhorn) can also be deployed onto the AI cluster using Rancher Manager. Make sure you modify the values to change the replicas counts to `1` if it is a single node cluster when it is deployed. You can use the documentation in the common config file for reference.*

7) Install SUSE Security (NueVector)
   
   On your management machine, or any of the downstream AI cluster nodes that have the `kubectl` and `helm` commands installed, run the script: `25-install_suse_security.sh`

   ***Note:** SUSE Security (NeuVector) can also be deployed onto the AI cluster using Rancher Manager. Make sure you modify the values to change the replicas counts to `1` if it is a single node cluster when it is deployed. You can use the documentation in the common config file for reference.*

8) Install the SUSE Observability Agent into the AI Cluster

   Follow the instructions in the section titled **Installing the SUSE Observability Agent** [here](https://docs.stackstate.com/get-started/k8s-suse-rancher-prime)
9) Configure Access to the SUSE Rancher Application Collection
   
   On your management machine, or any of the downstream AI cluster nodes that have the `kubectl` and `helm` commands installed, run the script: `29-connect_to_app_collection.sh`

At this point the base set of applications is installed on the downstream AI cluster. You can now use the following scripts to deploy the AI stack applications. These scripts can be run on your management machine or any of the downstream AI cluster nodes that have the `kubectl` and `helm` commands installed.

|   Script   | Description |
-------------|-------------|
|`31-install_milvus.sh` | This installs Milvus on the AI cluster. Do this if you want to use the Milvus vector database in conjunction with Open WebUI. (*Note: The script `91-clean_up_milvus_PVCs.sh` can be used if you uninstall the Milvus deployment using Helm and want to remove the volumes that were created - they don't get removed automatically when uninstalling the deployment.*) |
|`32-install_ollama.sh` | This installs only Ollama. Do this if you want to deploy the AI stack in a more modular fashion or are not going to use Open WebUI. You must supply one of the following arguments to the script: `without_gpu` (installs Ollama without GPU support - you probably don't want this), `with_gpu`  (Installs Ollama with GPU support), `with_gpu_and_ingress`  (Installs Ollama with GPU support and configures an ingress allowing direct communication with Ollama) |
|`35-install_open-webui_with_ollama.sh` | This installs Ollama and then Open WebUI. (You do not need to install Ollama before running this because this chart will install both Ollama and Open WebUI.) You must supply one of the following arguments to the script: `without_gpu` (installs Ollama without GPU support and a single model and installs Open WebUI - you probably don't want this), `with_gpu ` (Installs Ollama with GPU support and a single model and installs Open WebUI),`with_gpu_and_milvus`  (Installs Ollama with GPU support and configures Ollaman and Open WebUI to use Milvus) |

## Uninstall the SUSE AI Stack

To wipe everything out so that you can start again from scratch, two scripts are provided to completely remove the K8s cluster:

|    Script    | Description |
|--------------|-------------|
|`99a-uninstall_rke2_server.sh`| Completely uninstalls RKE2 from a server (control plane) node.|
|`99b-uninstall_rke2_agent.sh` | Completely uninstalls RKE2 from an agent (worker) node.|

Some additional scripts are provided to help clean up after certain applications' helm chart uninstalls where not everything is cleaned up.

|    Script    | Description |
|--------------|-------------|
|`91-clean_up_milvus_PVCs.sh`| Removes the PVCs and therefore the PV that were created by the Milvus Helm chart install but were not removed by the uninstall.|
