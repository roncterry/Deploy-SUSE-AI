#!/bin/bash

# You can either source in the variables from a common config file or
# set them in this script.

CONFIG_FILE=deploy_suse_ai.cfg

if ! [ -z ${CONFIG_FILE} ]
then
  if [ -e ${CONFIG_FILE} ]
  then
    source ${CONFIG_FILE}
  fi
else
  K8S_DISTRO=rke2
  K8S_DISTRO_CHANNEL=v1.30
  CLUSTER_NAME=aicluster01
  CLUSTER_TOKEN=${CLUSTER_NAME}
  DOMAIN_NAME=example.com
  DISABLED_BUILTIN_SERVICE_LIST=
  INSTALL_EXTERNAL_INGRESS_CONTROLLER=false
  EXTERNAL_INGRESS_CONTROLLER_NAMESPACE=kube-system
  EXTERNAL_INGRESS_CONTROLLER_KIND=DaemonSet
  EXTERNAL_INGRESS_CONTROLLER_REPLICAS=1
  INSTALL_KUBEVIP=false
  RKE2_CLUSTER_VIP=
fi

#------------------------------------------------------------------------------

# The NODE_TYPE variable must be set in this script.
# Options: server, agent
#
NODE_TYPE=agent

# The FIRST_SERVER must be set to 'true' for the initial server node and 
# 'false' for all other server nodes. This variable must be set in this script.
# This is ignored if NODE_TYPE=agent
#
FIRST_SERVER=true

###############################################################################
#   Functions
###############################################################################

check_for_helm() {
  if ! echo $* | grep -q force
  then
   if ! which helm > /dev/null
   then
     echo
     echo "ERROR: This must be run on a machine with the helm command installed."
     echo "       Run this script on a control plane node or management machine."
     echo
     echo "       Exiting."
     echo
     exit
   fi
  fi
}

install_k8s_distro() {
  echo "Downloading ${K8S_DISTRO} installer ..."
  echo "COMMAND: curl -sfL https://get.${K8S_DISTRO}.io --output /root/${K8S_DISTRO}-install.sh"
  curl -sfL https://get.${K8S_DISTRO}.io --output /root/${K8S_DISTRO}-install.sh

  echo "COMMAND: chmod +x /root/${K8S_DISTRO}-install.sh"
  chmod +x /root/${K8S_DISTRO}-install.sh
  echo

  echo "COMMAND: mkdir -p /etc/rancher/${K8S_DISTRO}"
  mkdir -p /etc/rancher/${K8S_DISTRO}
  echo

  echo "Writing out /etc/rancher/${K8S_DISTRO}/config.yaml file ..."
  case ${NODE_TYPE} in
    server)
      case ${FIRST_SERVER} in
        true)
          echo "token: ${CLUSTER_TOKEN}" > /etc/rancher/${K8S_DISTRO}/config.yaml
          echo "tls-san:" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          #echo "- ${HOSTNAME}" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          echo "- ${CLUSTER_NAME}.${DOMAIN_NAME}" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          if ! [ -z ${RKE2_CLUSTER_VIP} ]
          then
            echo "- $(echo ${RKE2_CLUSTER_VIP} | cut -d / -f 1)" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          fi
          echo "write-kubeconfig-mode: 600" >> /etc/rancher/${K8S_DISTRO}/config.yaml
        ;;
        *)
          echo "server: https://${CLUSTER_NAME}.${DOMAIN_NAME}:9345" > /etc/rancher/${K8S_DISTRO}/config.yaml
          echo "token: ${CLUSTER_TOKEN}" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          echo "tls-san:" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          #echo "- ${HOSTNAME}" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          echo "- ${CLUSTER_NAME}.${DOMAIN_NAME}" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          if ! [ -z ${RKE2_CLUSTER_VIP} ]
          then
            echo "- $(echo ${RKE2_CLUSTER_VIP} | cut -d / -f 1)" >> /etc/rancher/${K8S_DISTRO}/config.yaml
          fi
          echo "write-kubeconfig-mode: 600" >> /etc/rancher/${K8S_DISTRO}/config.yaml
        ;;
      esac

      if ! [ -z ${DISABLED_BUILTIN_SERVICE_LIST} ]
      then
        echo "disabled:" >> /etc/rancher/${K8S_DISTRO}/config.yaml
        for DISABLED_SERVICE in ${DISABLED_BUILTIN_SERVICE_LIST}
        do
          echo "- ${DISABLED_SERVICE}" >> /etc/rancher/${K8S_DISTRO}/config.yaml
        done
      fi
    ;;
    agent)
      echo "server: https://${CLUSTER_NAME}.${DOMAIN_NAME}:9345" > /etc/rancher/${K8S_DISTRO}/config.yaml
      echo "token: ${CLUSTER_TOKEN}" >> /etc/rancher/${K8S_DISTRO}/config.yaml
    ;;
  esac
  echo
  cat /etc/rancher/${K8S_DISTRO}/config.yaml
  echo

  echo "COMMAND: INSTALL_RKE2_TYPE=${NODE_TYPE} INSTALL_RKE2_CHANNEL=${K8S_DISTRO_CHANNEL} /root/${K8S_DISTRO}-install.sh"
  INSTALL_RKE2_TYPE=${NODE_TYPE} INSTALL_RKE2_CHANNEL=${K8S_DISTRO_CHANNEL} /root/${K8S_DISTRO}-install.sh
  echo

  echo "COMMAND: systemctl enable --now ${K8S_DISTRO}-${NODE_TYPE}.service"
  systemctl enable --now ${K8S_DISTRO}-${NODE_TYPE}.service
  echo
}

copy_kubeconfig_file_and_kubectl() {
  case ${NODE_TYPE} in
    server)
      echo "COMMAND: mkdir ~/.kube"
      mkdir ~/.kube
      echo

      echo "COMMAND: cp /etc/rancher/${K8S_DISTRO}/${K8S_DISTRO}.yaml ~/.kube/config"
      cp /etc/rancher/${K8S_DISTRO}/${K8S_DISTRO}.yaml ~/.kube/config
      echo

      echo "COMMAND: ln -s /var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/"
      ln -s /var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/
      echo

      echo "COMMAND: kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null"
      kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
      echo
    ;;
    agent)
      echo "COMMAND: mkdir ~/.kube"
      mkdir ~/.kube
      echo

      echo "COMMAND: scp ${CLUSTER_NAME}.${DOMAIN_NAME}:/etc/rancher/${K8S_DISTRO}/${K8S_DISTRO}.yaml ~/.kube/config"
      scp ${CLUSTER_NAME}.${DOMAIN_NAME}:/etc/rancher/${K8S_DISTRO}/${K8S_DISTRO}.yaml ~/.kube/config
      echo

      echo "COMMAND: sed -i \"s/127.0.0.1:6443/${CLUSTER_NAME}.${DOMAIN_NAME}:6443/g\" ~/.kube/config"
      sed -i "s/127.0.0.1:6443/${CLUSTER_NAME}.${DOMAIN_NAME}:6443/g" ~/.kube/config
      echo

      echo "COMMAND: scp ${CLUSTER_NAME}.${DOMAIN_NAME}:/var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/"
      scp ${CLUSTER_NAME}.${DOMAIN_NAME}:/var/lib/rancher/${K8S_DISTRO}/bin/kubectl /usr/local/bin/
      echo

      echo "COMMAND: chmod +x /usr/local/bin/kubectl"
      chmod +x /usr/local/bin/kubectl
      echo

      if ! zypper se bash-completion | grep open-iscsi | grep -q ^i
      then
        echo "Installing bash-completion ..."
        echo "COMMAND: ${SUDO_CMD} zypper install -y --auto-agree-with-licenses bash-completion"
        ${SUDO_CMD} zypper install -y --auto-agree-with-licenses bash-completion
        echo
      fi

      echo "COMMAND: kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null"
      kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
      echo
    ;;
  esac
}

wait_for_node_to_be_ready() {
  case ${NODE_TYPE} in
    server)
      echo -n "Waiting for node to be ready "
      until kubectl get nodes | grep -q " Ready"
      do
        echo -n "."
        sleep 2
      done
      echo "."
      echo

      echo "COMMAND: kubectl get nodes"
      kubectl get nodes
      echo
    ;;
  esac
}
 
wait_for_essential_cluster_services_to_be_ready() {
  echo -n "Waiting for the ingress controller to be ready "

  case ${NODE_TYPE} in
    server)
      if [ "${INSTALL_EXTERNAL_INGRESS_CONTROLLER}" == true ] && [ "${EXTERNAL_INGRESS_CONTROLLER_TYPE}" == Deployment ]
      then
        local INGRESS_CONTROLLER_NAMESPACE=${EXTERNAL_INGRESS_CONTROLLER_NAMESPACE}
        until kubectl -n ${INGRESS_CONTROLLER_NAMESPACE} get deployment | grep -v ^NAME | grep ingress | awk '{ print $6 }' | grep -q [1-9]
        do
          echo -n "."
          sleep 2
        done
        echo "."
        echo
      elif [ "${INSTALL_EXTERNAL_INGRESS_CONTROLLER}" == true ] && [ "${EXTERNAL_INGRESS_CONTROLLER_TYPE}" == DaemonSet ]
      then
        local INGRESS_CONTROLLER_NAMESPACE=${EXTERNAL_INGRESS_CONTROLLER_NAMESPACE}
        until kubectl -n ${INGRESS_CONTROLLER_NAMESPACE} get daemonset | grep -v ^NAME | grep ingress | awk '{ print $6 }' | grep -q [1-9]
        do
          echo -n "."
          sleep 2
        done
        echo "."
        echo
      else
        until kubectl -n kube-system get daemonset | grep -v ^NAME | grep ingress | awk '{ print $6 }' | grep -q [1-9]
        do
          echo -n "."
          sleep 2
        done
        echo "."
        echo
      fi
 
      echo -n "Waiting for coredns to be ready "
      until kubectl -n kube-system get deployment | grep coredns | grep -v autoscaler | awk '{ print $4 }' | grep -q [1-9]
      do
        echo -n "."
        sleep 2
      done
      echo "."
      echo
    ;;
  esac
}

install_external_ingress_controller() {
  local INGRESS_HELM_REPO_URL=https://kubernetes.github.io/ingress-nginx

  case ${EXTERNAL_INGRESS_CONTROLLER_KIND} in
    Deployment|deployment)
      local EXT_ING_CONT_KIND_ARGS="--set controller.kind=Deployment --set controller.replicaCount=${EXTERNAL_INGRESS_CONTROLLER_REPLICAS}"
    ;;
    DaemonSet|daemonset|daemonSet)
      local EXT_ING_CONT_KIND_ARGS="--set controller.kind=DaemonSet"
    ;;
  esac

  echo "Installing external ingress controller ..."
  echo
  if ! kubectl get all -A | grep ingress | grep -qE '(daemonset|deployment)'
  then
    echo "COMMANDS: helm repo add ingress-nginx ${INGRESS_HELM_REPO_URL}
            helm repo update"
    helm repo add ingress-nginx ${INGRESS_HELM_REPO_URL}
    helm repo update
    echo
 
    echo "COMMAND: helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx  --namespace ${EXTERNAL_INGRESS_CONTROLLER_NAMESPACE} --create-namespace --set rbac.create=true ${EXT_ING_CONT_KIND_ARGS} --set ingressClassResource.default=true"
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx  --namespace ${EXTERNAL_INGRESS_CONTROLLER_NAMESPACE} --create-namespace --set rbac.create=true ${EXT_ING_CONT_KIND_ARGS} --set ingressClassResource.default=true
    echo
  else
    echo "(external ingress controller already installed)"
    echo
  fi
}

install_kubevip() {
  local KUBEVIP_HELM_REPO_URL=https://kube-vip.github.io/helm-charts

  echo "Installing kube-vip ..."
  echo
  if ! kubectl get pod -A | grep -q kube-vip
  then
    echo "COMMANDS: helm repo add kube-vip ${KUBEVIP_HELM_REPO_URL}
            helm repo update"
    helm repo add kube-vip ${KUBEVIP_HELM_REPO_URL}
    helm repo update
    echo
 
    echo "COMMAND: helm upgrade --install kube-vip kube-vip/kube-vip --namespace kube-system"
    helm upgrade --install kube-vip kube-vip/kube-vip --namespace kube-system
    echo
 
    echo "COMMAND: helm upgrade --install kube-vip-cloud-provider kube-vip/kube-vip-cloud-provider --namespace kube-system --set cm.data.cidr-${EXTERNAL_INGRESS_CONTROLLER_NAMESPACE}=${RKE2_CLUSTER_VIP}"
    helm upgrade --install kube-vip-cloud-provider kube-vip/kube-vip-cloud-provider --namespace kube-system --set cm.data.cidr-${EXTERNAL_INGRESS_CONTROLLER_NAMESPACE}=${RKE2_CLUSTER_VIP}
    echo
  else
    echo "(kube-vip already installed)"
    echo
  fi
}

###############################################################################
#   Main Code Body
###############################################################################

install_k8s_distro
copy_kubeconfig_file_and_kubectl
wait_for_node_to_be_ready

case ${INSTALL_EXTERNAL_INGRESS_CONTROLLER} in
  true)
    check_for_helm
    install_external_ingress_controller
  ;;
esac

wait_for_essential_cluster_services_to_be_ready

case ${INSTALL_KUBEVIP} in
  true)
    check_for_helm
    install_kubevip
  ;;
esac
 
echo "-----  The cluster is installed and running  -----"
echo
