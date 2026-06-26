#!/bin/bash

set -ouex pipefail

dnf5.real -y install \
    nvidia-driver-cuda


echo -e "options nvidia NVreg_PreserveVideoMemoryAllocations=0\n\
options nvidia NVreg_UseKernelSuspendNotifiers=1\n\
options nvidia NVreg_TemporaryFilePath=/var/tmp" \
    > /etc/modprobe.d/nvidia-pm.conf

## CLEAN UP
dnf5.real -y clean all
rm -rf /run/dnf /run/selinux-policy
rm -rf /var/lib/dnf
