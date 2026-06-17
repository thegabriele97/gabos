#!/bin/bash

set -ouex pipefail

dnf5.real -y install \
    nvidia-driver-cuda




## CLEAN UP
dnf5.real -y clean all
rm -rf /run/dnf /run/selinux-policy
rm -rf /var/lib/dnf
