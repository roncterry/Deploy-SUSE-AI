#!/bin/bash

##############################################################################

if ! which kubectl > /dev/null
then
  echo
  echo "ERROR: This must be run on a machine with the kubectl and helm commands installed."
  echo "       Run this script on a control plane node or management machine."
  echo
  echo "       Exiting."
  echo
  exit
fi

if ! which helm > /dev/null
then
  echo
  echo "ERROR: This must be run on a machine with the kubectl and helm commands installed."
  echo "       Run this script on a control plane node or management machine."
  echo
  echo "       Exiting."
  echo
  exit
fi

##############################################################################

# You can either source in the variables from a common config file or
# set the them in this script.

CONFIG_FILE=deploy_suse_ai.cfg

if ! [ -z ${CONFIG_FILE} ]
then
  if [ -e ${CONFIG_FILE} ]
  then
    source ${CONFIG_FILE}
  fi
else
  NVIDIA_GPU_OPERATOR_REPO_URL=https://helm.ngc.nvidia.com/nvidia
fi

##############################################################################

deploy_nvidia_gpu_operator_via_the_helm_operator() {
  echo "Writing out nvidia-gpu-operator.yaml ..."
  echo

  echo "
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: gpu-operator
  namespace: kube-system
spec:
  repo: ${NVIDIA_GPU_OPERATOR_REPO_URL}
  chart: gpu-operator
  targetNamespace: gpu-operator
  createNamespace: true
  valuesContent: |-
    driver:
      enabled: false
    toolkit:
      env:
      - name: CONTAINERD_SOCKET
        value: /run/k3s/containerd/containerd.sock
      - name: CONTAINERD_CONFIG
        value: /var/lib/rancher/rke2/agent/etc/containerd/config.toml.tmpl
      - name: CONTAINERD_RUNTIME_CLASS
        value: nvidia
      - name: CONTAINERD_SET_AS_DEFAULT
        value: \"true\"
" > nvidia-gpu-operator.yaml

  cat nvidia-gpu-operator.yaml
  echo

  echo "COMMAND: kubectl apply -f nvidia-gpu-operator.yaml"
  kubectl apply -f nvidia-gpu-operator.yaml
  echo
}

deploy_nvidia_gpu_operator() {
  echo "Writing out nvidia-gpu-operator-values.yaml ..."
  echo

  echo "
driver:
  enabled: false
toolkit:
  env:
  - name: CONTAINERD_SOCKET
    value: /run/k3s/containerd/containerd.sock
  - name: CONTAINERD_CONFIG
    value: /var/lib/rancher/rke2/agent/etc/containerd/config.toml.tmpl
  - name: CONTAINERD_RUNTIME_CLASS
    value: nvidia
  - name: CONTAINERD_SET_AS_DEFAULT
    value: \"true\"
" > nvidia-gpu-operator-values.yaml

  cat nvidia-gpu-operator-values.yaml
  echo

  echo "COMMAND: helm repo add nvidia ${NVIDIA_GPU_OPERATOR_REPO_URL}"
  helm repo add nvidia ${NVIDIA_GPU_OPERATOR_REPO_URL}
  echo

  echo "COMMAND: helm repo update"
  helm repo update
  echo

  echo "COMMAND: helm install gpu-operator -n gpu-operator --create-namespace  -f nvidia-gpu-operator-values.yaml nvidia/gpu-operator"
  helm install gpu-operator -n gpu-operator --create-namespace -f nvidia-gpu-operator-values.yaml nvidia/gpu-operator
  echo
}

show_nvidia_gpu_operator_deployment_status() {
  echo -n "Waiting for namespace to be created "
  until kubectl get namespaces | grep -q gpu-operator
  do
    echo -n "."
    sleep 2
  done
  echo "."
  echo

  echo -n "Waiting for gpu-operator deployment to be started "
  until kubectl -n gpu-operator get deployment | grep -q gpu-operator
  do
    echo -n "."
    sleep 2
  done
  echo "."
  echo

  echo "COMMAND: kubectl -n gpu-operator rollout status deploy/gpu-operator-node-feature-discovery-gc"
  kubectl -n gpu-operator rollout status deploy/gpu-operator-node-feature-discovery-gc
  echo

  echo "COMMAND: kubectl -n gpu-operator rollout status deploy/gpu-operator-node-feature-discovery-master"
  kubectl -n gpu-operator rollout status deploy/gpu-operator-node-feature-discovery-master
  echo

  echo "COMMAND: kubectl -n gpu-operator rollout status deploy/gpu-operator"
  kubectl -n gpu-operator rollout status deploy/gpu-operator
  echo

  echo -n "Waiting for the nvidia-operator-validator pod to become ready "
  until kubectl -n gpu-operator get pods | grep nvidia-operator-validator | grep -q "Running"
  do
    echo -n "."
    sleep 2
  done
  echo "."
  echo

  echo "Waiting for the metadata labels to be created/updated ..."
  sleep 15
  echo
}

verify_nvidia_gpu_operator_deployment() {
  echo
  echo "Verifying nvidia-gpu-operator deployment:"
  for NODE in $(kubectl get nodes | grep -v ^NAME | awk '{ print $1 }')
  do
    echo "---------------------"
    echo "Node: ${NODE}"
    echo "---------------------"
    if kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | jq | grep -q "nvidia.com/gpu.machine"
    then
      echo GPU_NODE=true
      echo

      if ! kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | jq | grep -q "accelerator"
      then
        echo "COMMAND: kubectl label node ${NODE} accelerator=nvidia-gpu"
        kubectl label node ${NODE} accelerator=nvidia-gpu
        echo
      fi

      echo "COMMAND: kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | jq | grep "accelerator""
      kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | jq | grep "accelerator"
      echo
 
      echo "COMMAND: kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | jq | grep "nvidia.com/gpu.machine""
      kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | jq | grep "nvidia.com/gpu.machine"
      echo
 
      echo "COMMAND: kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | jq | grep "nvidia.com/cuda.driver.major""
      kubectl get node ${NODE} -o jsonpath='{.metadata.labels}' | jq | grep "nvidia.com/cuda.driver.major"
      echo
 
      echo "COMMAND: kubectl get node ${NODE} -o jsonpath='{.status.allocatable}' | jq "
      kubectl get node ${NODE} -o jsonpath='{.status.allocatable}' | jq 
      echo

      if hostname | grep -q ${NODE}
      then
        echo "COMMAND: ls /usr/local/nvidia/toolkit/nvidia-container-runtime"
        ls /usr/local/nvidia/toolkit/nvidia-container-runtime
        echo
        echo "COMMAND: grep nvidia /var/lib/rancher/rke2/agent/etc/containerd/config.toml"
        grep nvidia /var/lib/rancher/rke2/agent/etc/containerd/config.toml
      else
        echo "COMMAND: ssh root@${NODE} 'ls /usr/local/nvidia/toolkit/nvidia-container-runtime;grep nvidia /var/lib/rancher/rke2/agent/etc/containerd/config.toml'"
        ssh root@${NODE} 'ls /usr/local/nvidia/toolkit/nvidia-container-runtime;grep nvidia /var/lib/rancher/rke2/agent/etc/containerd/config.toml'
      fi

      #echo "COMMAND: ssh root@${NODE} 'grep nvidia /var/lib/rancher/rke2/agent/etc/containerd/config.toml'"
      #sh root@${NODE} 'grep nvidia /var/lib/rancher/rke2/agent/etc/containerd/config.toml'
      echo
      echo
    else
      echo GPU_NODE=false
      echo
      echo "Note: If you think this is incorrect wait about 10-15 seconds and run"
      echo "      this script again. The metadata labels may not have been updated yet."
      echo
    fi
done
}

##############################################################################

if ! kubectl get pods -A | grep -q nvidia-operator-validator
then
  #deploy_nvidia_gpu_operator_via_the_helm_operator
  deploy_nvidia_gpu_operator
  show_nvidia_gpu_operator_deployment_status
fi

verify_nvidia_gpu_operator_deployment
