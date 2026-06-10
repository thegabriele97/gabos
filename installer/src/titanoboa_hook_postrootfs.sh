#!/usr/bin/env bash

set -exo pipefail
source /etc/os-release

# Load base bootc image in local containers-storage
#
# Policy permissiva
cat > /etc/containers/policy.json <<'EOF'
{"default": [{"type": "insecureAcceptAnything"}]}
EOF

podman load -i /tmp/base-image.oci.tar
#skopeo copy \
#	--insecure-policy \
#	--dest-storage-opt ignore_chown_errors=true \
#	docker-archive:/tmp/base-image.oci.tar  \
#	containers-storage:localhost/image-template:latest \

# Prune unused data, keep loaded image
podman system prune -f
# rm -f /tmp/base-image.oci.tar

echo "================================================================================"
podman images
echo "================================================================================"

# Installa Anaconda
dnf5.real install -qy --allowerasing anaconda-live libblockdev-{btrfs,lvm,dm}
mkdir -p /var/lib/rpm-state

# Kickstart base
cat <<EOF >> /usr/share/anaconda/interactive-defaults.ks
ostreecontainer --url=localhost/image-template:latest --transport=containers-storage --no-signature-verification
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
