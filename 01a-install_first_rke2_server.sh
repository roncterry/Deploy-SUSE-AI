#!/bin/bash

# You can either source in the variables from a common config file or
# uncomment the following variables to set them in this script.

source deploy_suse_ai.cfg

#K8S_DISTRO=rke2
#CLUSTER_NAME=aicluster01

# The NODE_TYPE variable must be set in this script.
NODE_TYPE=server

#########################################
#  Deploy RKE2
#########################################

curl -sfL https://get.${K8S_DISTRO}.io --output /root/${K8S_DISTRO}-install.sh
chmod +x /root/${K8S_DISTRO}-install.sh

mkdir -p /etc/rancher/${K8S_DISTRO}

case ${NODE_TYPE} in
  server)
    echo "token: ${CLUSTER_NAME}" >> /etc/rancher/${K8S_DISTRO}/config.yaml
    echo "tls-san:" >> /etc/rancher/${K8S_DISTRO}/config.yaml
    echo "  - ${CLUSTER_NAME}.example.com" >> /etc/rancher/${K8S_DISTRO}/config.yaml
    echo "write-kubeconfig-mode: 600" >> /etc/rancher/${K8S_DISTRO}/config.yaml
  ;;
  agent)
    echo "server: https://${CLUSTER_NAME}.example.com:9345" >> /etc/rancher/${K8S_DISTRO}/config.yaml
    echo "token: ${CLUSTER_NAME}" >> /etc/rancher/${K8S_DISTRO}/config.yaml
  ;;
esac

INSTALL_RKE2_TYPE=${NODE_TYPE} /root/${K8S_DISTRO}-install.sh

systemctl enable --now ${K8S_DISTRO}-${NODE_TYPE}.service

case ${NODE_TYPE} in
  server)
    echo "COMMAND: mkdir ~/.kube"
    mkdir ~/.kube
    echo "COMMAND: ln -s /etc/rancher/${K8S_DISTRO}/${K8S_DISTRO}.yaml ~/.kube/config"
    ln -s /etc/rancher/${K8S_DISTRO}/${K8S_DISTRO}.yaml ~/.kube/config
    echo "COMMAND: ln -s /var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/"
    ln -s /var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/
    echo "COMMAND: kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null"
    kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
  ;;
  agent)
    echo "COMMAND: mkdir ~/.kube"
    mkdir ~/.kube
    echo "COMMAND: scp ${CLUSTER_NAME}.example.com:/etc/rancher/${K8S_DISTRO}/${K8S_DISTRO}.yaml ~/.kube/config"
    scp ${CLUSTER_NAME}.example.com:/etc/rancher/${K8S_DISTRO}/${K8S_DISTRO}.yaml ~/.kube/config
    echo "COMMAND: sed -i \"s/127.0.0.1:6443/${CLUSTER_NAME}.example.com:6443/g\" ~/.kube/config"
    sed -i "s/127.0.0.1:6443/${CLUSTER_NAME}.example.com:6443/g" ~/.kube/config
    echo "COMMAND: scp ${CLUSTER_NAME}.example.com:/var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/"
    scp ${CLUSTER_NAME}.example.com:/var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/
    echo "COMMAND: chmod +x /usr/local/bin/kubectl"
    chmod +x /usr/local/bin/kubectl
    echo "COMMAND: kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null"
    kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
  ;;
esac

