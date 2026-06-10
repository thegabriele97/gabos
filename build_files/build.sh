#!/bin/bash

set -ouex pipefail

## DNF5 Speedup
sed -i '/^\[main\]/a max_parallel_downloads=10' /etc/dnf/dnf.conf


### Install packages
dnf5.real -y install \
    jq

### BASE PACKAGES
dnf5.real -y install \
    fish \
    vim \
    neovim \
    firefox \
    nautilus \
    file-roller \
    loupe \
    totem

dnf5.real -y install \
    kitty \
    fastfetch \
    lolcat lsd bat fzf 

dnf5.real -y install \
    rakuos-software-qt

# Nautilus open any terminal extension
curl -Lo /etc/yum.repos.d/nautilus-open-any-terminal.repo \
  https://copr.fedorainfracloud.org/coprs/monkeygold/nautilus-open-any-terminal/repo/fedora-$(rpm -E %fedora)/monkeygold-nautilus-open-any-terminal-fedora-$(rpm -E %fedora).repo

dnf5.real install -y \
    nautilus-open-any-terminal

glib-compile-schemas /usr/share/glib-2.0/schemas
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal kitty

### DESKTOP ENVIRONMENT

# Niri
dnf5.real -y install niri bibata-cursor-theme

# Dank Linux Shell
sudo curl --output-dir "/etc/yum.repos.d/" --remote-name "https://copr.fedorainfracloud.org/coprs/avengemedia/dms/repo/fedora-$(rpm -E %fedora)/avengemedia-dms-fedora-$(rpm -E %fedora).repo"
dnf5.real -y install quickshell dms greetd dms-greeter --allowerasing 

mkdir -p /etc/greetd/
cat > /etc/greetd/config.toml << EOF
[terminal]
vt = 1
[default_session]
user = "greeter"
command = "dms-greeter --command niri"
EOF

rm -f /etc/systemd/system/display-manager.service
ln -s /usr/lib/systemd/system/greetd.service /etc/systemd/system/display-manager.service
systemctl enable --force greetd.service

mkdir -p /etc/skel/.config/systemd/user/graphical-session.target.wants
ln -s /usr/lib/systemd/user/dms.service /etc/skel/.config/systemd/user/graphical-session.target.wants/

## USER FILES (DOT FILES)
mkdir -p /etc/skel/.config
# cp -rf /ctx/dot_config/* /etc/skel/.config/
cp -rf /usr/share/gabos/gdots/dot_config/* /etc/skel/.config/

# Neovim
git clone --depth 1 https://github.com/AstroNvim/template /etc/skel/.config/nvim
rm -rf /etc/skel/.config/nvim/.git

# Accept this repo as insecure for bootc pull
jq '.transports.docker["ghcr.io/thegabriele97"] = [{"type": "insecureAcceptAnything"}]' \
    /etc/containers/policy.json > /tmp/policy.json
mv /tmp/policy.json /etc/containers/policy.json

dnf5.real -y remove \
    waybar


# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
# dnf5 install -y tmux 

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket

# Plymouth
plymouth-set-default-theme spinner

# mkdir -p /usr/lib/bootc/kargs.d/
# cat > /usr/lib/bootc/kargs.d/00-splash.toml << 'EOF'
# kargs = ["quiet", "rhgb"]
# EOF

## CLEAN UP
dnf5.real -y clean all
rm -rf /run/dnf /run/selinux-policy
rm -rf /var/lib/dnf

