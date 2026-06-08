#!/usr/bin/env bash

set -exo pipefail
source /etc/os-release

# Installa Anaconda
dnf5.real install -qy --allowerasing anaconda-live libblockdev-{btrfs,lvm,dm}
mkdir -p /var/lib/rpm-state

# Kickstart base
cat <<EOF >> /usr/share/anaconda/interactive-defaults.ks
ostreecontainer --url=localhost/gabos_installer:latest --transport=containers-storage --no-signature-verification
EOF

cat > /usr/share/applications/liveinst.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Install to Hard Drive
Comment=Install the system to disk
Exec=pkexec liveinst
Icon=anaconda
Terminal=false
Categories=System;
Keywords=install;anaconda;
EOF
