#!/bin/bash

NVIDIA_DRV_FAMILY=G06

SLE_NVIDIA_DRV_PREFIX=nvidia-driver-${NVIDIA_DRV_FAMILY}
MICRO_NVIDIA_DRV_PREFIX=nvidia-open-driver-${NVIDIA_DRV_FAMILY}

SLE_NVIDIA_DRV_NAME=${SLE_DRV_PREFIX}-kmp
MICRO_NVIDIA_DRV_NAME=${MICRO_DRV_PREFIX}-signed-kmp

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

install_nvidia_compute_utils() {
  source /etc/os-release

  if lspci | grep -i nvidia | grep -qi vga
  then
    echo "NVIDIA VGA device found, checking for nvidia-compute-utils package ..."
    if ! zypper se nvidia-compute-untils-${NVIDIA_DRV_FAMILY} | grep -q ^i
    then
      case ${NAME} in
        SLES)
          if zypper se ${SLE_NVIDIA_DRV_PREFIX} | grep -q ${SLE_NVIDIA_DRV_NAME}
          then 
            if ! zypper se ${SLE_NVIDIA_DRV_PREFIX} | grep -q ^i
            then
              echo "Installing ${SLE_NVIDIA_DRV_NAME} and nvidia-compute-utils-${NVIDIA_DRV_FAMILY}..."
              echo "COMMAND: ${SUDO_CMD} zypper install -y --auto-agree-with-licenses ${SLE_NVIDIA_DRV_NAME} nvidia-compute-utils-${NVIDIA_DRV_FAMILY}"
              ${SUDO_CMD} zypper install -y --auto-agree-with-licenses ${SLE_NVIDIA_DRV_NAME} nvidia-compute-utils-${NVIDIA_DRV_FAMILY}
            else
              echo "Installing nvidia-compute-utils-${NVIDIA_DRV_FAMILY} ..."
              echo "COMMAND: ${SUDO_CMD} zypper install -y --auto-agree-with-licenses nvidia-compute-utils-${NVIDIA_DRV_FAMILY}"
              ${SUDO_CMD} zypper install -y --auto-agree-with-licenses nvidia-compute-utils-${NVIDIA_DRV_FAMILY}
            fi
          else
            echo "ERROR: Cannot find the ${SLE_NVIDIA_DRV_NAME} package."
            echo "       Please ensure the NVIDIA_Compute_Module has been added and enabled."
            echo "       Exiting."
            echo
            exit
          fi
          echo
        ;;
        SL-Micro)
          if zypper se ${MICRO_NVIDIA_DRV_PREFIX} | grep -q ${MICRO_NVIDIA_DRV_NAME}
          then 
            local NVIDIA_DRV_VER=$(zypper se -s nvidia-open-driver | grep nvidia-open-driver- | sed "s/.* package | //g" | sed "s/\s.*//g" | sort | head -n 1 | sed "s/[-_].*//g")

            if ! zypper se ${MICRO_NVIDIA_DRV_PREFIX} | grep -q ^i
            then
              echo "Installing ${MICRO_NVIDIA_DRV_NAME} and nvidia-compute-utils-${NVIDIA_DRV_FAMILY}..."
              echo "COMMAND: ${SUDO_CMD} transactional-update run zypper install -y --auto-agree-with-licenses ${MICRO_NVIDIA_DRV_NAME}=${NVIDIA_DRV_VER} nvidia-compute-utils-${NVIDIA_DRV_FAMILY}=${NVIDIA_DRV_VER}"
              ${SUDO_CMD} transactional-update run zypper install -y --auto-agree-with-licenses ${MICRO_NVIDIA_DRV_NAME}=${NVIDIA_DRV_VER} nvidia-compute-utils-${NVIDIA_DRV_FAMILY}=${NVIDIA_DRV_VER}
              REBOOT=Y
            else
              echo "Installing nvidia-compute-utils-G06 ..."
              echo "COMMAND: ${SUDO_CMD} transactional-update run zypper install -y --auto-agree-with-licenses nvidia-compute-utils-${NVIDIA_DRV_FAMILY}=${NVIDIA_DRV_VER}"
              ${SUDO_CMD} transactional-update run zypper install -y --auto-agree-with-licenses nvidia-compute-utils-${NVIDIA_DRV_FAMILY}=${NVIDIA_DRV_VER}
              REBOOT=Y
            fi
          else
            echo "ERROR: Cannot find the ${MICRO_NVIDIA_DRV_NAME} package."
            echo "       Please ensure the repository has been added and is enabled."
            echo "       Exiting."
            echo
            exit
          fi
          echo
        ;;
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
        fi
  
        if ! grep -q ^PATH /etc/default/rke2-server
        then
          echo "COMMAND: ${SUDO_CMD} echo PATH=${PATH} >> /etc/default/rke2-server"
          ${SUDO_CMD} echo PATH=${PATH} >> /etc/default/rke2-server
          echo
        fi
      ;;
    esac
  fi
}

##############################################################################

install_nvidia_compute_utils

case ${REBOOT} in
  Y|y|YES|Yes|yes)
    echo "Packages installed in a transactional-update. Rebooting now ..."
    sleep 5
    reboot
  ;;
esac

