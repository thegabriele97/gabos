#!/usr/bin/env bash

set -exo pipefail
source /etc/os-release

# Load base bootc image in local containers-storage
#
# Policy permissiva
cat > /etc/containers/policy.json <<'EOF'
{"default": [{"type": "insecureAcceptAnything"}]}
EOF

podman load -i /tmp/host_installer/base-image.oci.tar
#skopeo copy \
#	--insecure-policy \
#	--dest-storage-opt ignore_chown_errors=true \
#	docker-archive:/tmp/host_installer/base-image.oci.tar  \
#	containers-storage:localhost/image-template:latest \

# Prune unused data, keep loaded image
podman system prune -f
podman system df 
ls -lh /tmp/host_installer/
rm -f /tmp/host_installer/base-image.oci.tar
ls -lh /tmp/host_installer/
df -h
df -ah

echo "================================================================================"
podman images
echo "================================================================================"

# Installa Anaconda
dnf5.real install -qy --allowerasing anaconda-live libblockdev-{btrfs,lvm,dm}
mkdir -p /var/lib/rpm-state

# Kickstart base
base_image=$(podman images --format "{{.Repository}}:{{.Tag}}" | head -n 1)
echo "Using base image: $base_image"
cat <<EOF >> /usr/share/anaconda/interactive-defaults.ks
ostreecontainer --url=$base_image --transport=containers-storage --no-signature-verification
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
