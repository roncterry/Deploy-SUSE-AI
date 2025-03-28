#!/bin/bash

NVIDIA_DRV_FAMILY=G06

SLE_NVIDIA_DRV_PREFIX=nvidia-driver-${NVIDIA_DRV_FAMILY}
MICRO_NVIDIA_DRV_PREFIX=nvidia-open-driver-${NVIDIA_DRV_FAMILY}

SLE_NVIDIA_DRV_NAME=${SLE_DRV_PREFIX}-kmp
MICRO_NVIDIA_DRV_NAME=${MICRO_DRV_PREFIX}-signed-kmp

source /etc/os-release

##############################################################################

case $(whoami) in
  root)
    SUDO_CMD=
  ;;
  *)
    SUDO_CMD=sudo
  ;;
esac

##############################################################################

check_for_nvidia_gpu() {
  if lspci | grep -i nvidia | grep -qi vga 
  then
    HAS_NVIDIA_GPU=yes
  elif echo ${*} | grep -q force
  then
    HAS_NVIDIA_GPU=force
  else
    echo
    echo "NVIDIA VGA device found. Exiting."
    HAS_NVIDIA_GPU=no
    echo
  fi
}

add_nvidia_compute_module() {
  if $(suseconnect -l | grep -q sle-module-NVIDIA-compute)
  then
  echo "Registering/Installing the NVIDIA Compute module ..."
  echo "---------------------------------------------------------------------------"
    echo "COMMAND: ${SUDO_CMD} suseconnect -p sle-module-desktop-applications/${VERSION_ID}/$(uname -m) --gpg-auto-import-keys"
    ${SUDO_CMD} suseconnect -p sle-module-desktop-applications/${VERSION_ID}/$(uname -m) --gpg-auto-import-keys

    echo "COMMAND: ${SUDO_CMD} suseconnect -p sle-module-development-tools/${VERSION_ID}/$(uname -m) --gpg-auto-import-keys"
    ${SUDO_CMD} suseconnect -p sle-module-development-tools/${VERSION_ID}/$(uname -m) --gpg-auto-import-keys

    echo "COMMAND: ${SUDO_CMD} suseconnect -p sle-module-NVIDIA-compute/$(echo ${VERSION_ID} | cut -d . -f 1)/$(uname -m) --gpg-auto-import-keys"
    ${SUDO_CMD} suseconnect -p sle-module-NVIDIA-compute/$(echo ${VERSION_ID} | cut -d . -f 1)/$(uname -m) --gpg-auto-import-keys

    echo
  else
    echo
    echo "ERROR: Cannot find the NVIDIA Compute module ."
    echo "       Please ensure the system has been registered with SCC or an"
    echo "       RMT server that has the sle-module-NVIDIA-compute repo mirrored."
    echo
    echo "       Exiting."
    exit
  fi
}

install_nvidia_driver() {
  echo "Installing ${SLE_NVIDIA_DRV_NAME} and nvidia-compute-utils-${NVIDIA_DRV_FAMILY}..."
  echo "---------------------------------------------------------------------------"
  echo "COMMAND: ${SUDO_CMD} zypper install -y --auto-agree-with-licenses ${SLE_NVIDIA_DRV_NAME} nvidia-compute-utils-${NVIDIA_DRV_FAMILY}"
  ${SUDO_CMD} zypper install -y --auto-agree-with-licenses ${SLE_NVIDIA_DRV_NAME} nvidia-compute-utils-${NVIDIA_DRV_FAMILY}
  echo
}

install_nvidia_compute_utils() {
  echo "Installing nvidia-compute-utils-${NVIDIA_DRV_FAMILY} ..."
  echo "---------------------------------------------------------------------------"
  echo "COMMAND: ${SUDO_CMD} zypper install -y --auto-agree-with-licenses nvidia-compute-utils-${NVIDIA_DRV_FAMILY}"
  ${SUDO_CMD} zypper install -y --auto-agree-with-licenses nvidia-compute-utils-${NVIDIA_DRV_FAMILY}
  echo
}

install_nvidia_driver_and_compute_utils() {
  if [ "${HAS_NVIDIA_GPU}" == yes ] || [ "${HAS_NVIDIA_GPU}" == force ] 
  then
    case ${HAS_NVIDIA_GPU} in
      yes)
        echo
        echo "NVIDIA VGA device found, checking for nvidia-compute-utils package ..."
        echo
      ;;
      force)
        echo
        echo "No NVIDIA VGA device found, checking for nvidia-compute-utils package anyway ..."
        echo
      ;;
    esac

    if ! zypper se nvidia-compute-utils-${NVIDIA_DRV_FAMILY} | grep -q ^i
    then
      case ${NAME} in
        SLES)
          if zypper se ${SLE_NVIDIA_DRV_PREFIX} | grep -q ${SLE_NVIDIA_DRV_NAME}
          then 
            if ! zypper se ${SLE_NVIDIA_DRV_PREFIX} | grep -q ^i
            then
              install_nvidia_driver
            else
              install_nvidia_compute_utils
            fi
          else
            add_nvidia_compute_module
            install_nvidia_driver
            install_nvidia_compute_utils
          fi
          echo
        ;;
#        SL-Micro)
#          if zypper se ${MICRO_NVIDIA_DRV_PREFIX} | grep -q ${MICRO_NVIDIA_DRV_NAME}
#          then 
#            local NVIDIA_DRV_VER=$(zypper se -s nvidia-open-driver | grep nvidia-open-driver- | sed "s/.* package | //g" | sed "s/\s.*//g" | sort | head -n 1 | sed "s/[-_].*//g")
# 
#            if ! zypper se ${MICRO_NVIDIA_DRV_PREFIX} | grep -q ^i
#            then
#              echo "Installing ${MICRO_NVIDIA_DRV_NAME} and nvidia-compute-utils-${NVIDIA_DRV_FAMILY}..."
#              echo "COMMAND: ${SUDO_CMD} transactional-update run zypper install -y --auto-agree-with-licenses ${MICRO_NVIDIA_DRV_NAME}=${NVIDIA_DRV_VER} nvidia-compute-utils-${NVIDIA_DRV_FAMILY}=${NVIDIA_DRV_VER}"
#              ${SUDO_CMD} transactional-update run zypper install -y --auto-agree-with-licenses ${MICRO_NVIDIA_DRV_NAME}=${NVIDIA_DRV_VER} nvidia-compute-utils-${NVIDIA_DRV_FAMILY}=${NVIDIA_DRV_VER}
#              REBOOT=Y
#            else
#              echo "Installing nvidia-compute-utils-G06 ..."
#              echo "COMMAND: ${SUDO_CMD} transactional-update run zypper install -y --auto-agree-with-licenses nvidia-compute-utils-${NVIDIA_DRV_FAMILY}=${NVIDIA_DRV_VER}"
#              ${SUDO_CMD} transactional-update run zypper install -y --auto-agree-with-licenses nvidia-compute-utils-${NVIDIA_DRV_FAMILY}=${NVIDIA_DRV_VER}
#              REBOOT=Y
#            fi
#          else
#            echo "ERROR: Cannot find the ${MICRO_NVIDIA_DRV_NAME} package."
#            echo "       Please ensure the repository has been added and is enabled."
#            echo "       Exiting."
#            echo
#            exit
#          fi
#          echo
#        ;;
      esac
    else
      echo "nvidia-compute-utils-${NVIDIA_DRV_FAMILY} already installed, continuing ..."
      echo
    fi
 
    case ${NAME} in
      SLES)
        if ! [ -e /sbin/ldconfig.real ]
        then
          echo "COMMAND: ${SUDO_CMD} ln -s /sbin/ldconfig /sbin/ldconfig.real"
          ${SUDO_CMD} ln -s /sbin/ldconfig /sbin/ldconfig.real
          echo
        else
          echo
          echo "/sbin/ldconfig.real exists, continuing ..."
          echo
        fi
  
        if ! grep -q "^PATH" /etc/default/rke2-server 2>/dev/null
        then
          echo "COMMAND: ${SUDO_CMD} echo PATH=${PATH} >> /etc/default/rke2-server"
          ${SUDO_CMD} echo PATH=${PATH} >> /etc/default/rke2-server
          echo
        else
          echo
          echo "/etc/default/rke2-server contains a line beginning with PATH, continuing ..."
          echo
        fi
      ;;
    esac
  fi
}

##############################################################################

check_for_nvidia_gpu ${*}
install_nvidia_driver_and_compute_utils

echo
echo "----------  Finished  ----------"
echo

case ${REBOOT} in
  Y|y|YES|Yes|yes)
    echo "Packages installed in a transactional-update. Rebooting now ..."
    sleep 5
    reboot
  ;;
esac

