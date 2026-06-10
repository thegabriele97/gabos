export image_name := env("IMAGE_NAME", "image-template") # output image name, usually same as repo name, change as needed
export default_tag := env("DEFAULT_TAG", "latest")
export bib_image := env("BIB_IMAGE", "quay.io/centos-bootc/bootc-image-builder:latest")

installer_dir   := justfile_directory() / "installer"
installer_image := "localhost/gabos_installer:latest"
titanoboa_dir   := justfile_directory() / ".titanoboa"
iso_out         := justfile_directory() / "output" / "output.iso"

alias build-vm := build-qcow2
alias rebuild-vm := rebuild-qcow2
alias run-vm := run-vm-qcow2

[private]
default:
    @just --list

# Check Just Syntax
[group('Just')]
check:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt -f Justfile || { exit 1; }

# Clean Repo
[group('Utility')]
clean:
    #!/usr/bin/bash
    set -eoux pipefail
    touch _build
    find *_build* -exec rm -rf {} \;
    rm -f previous.manifest.json
    rm -f changelog.md
    rm -f output.env
    rm -rf output/

# Sudo Clean Repo
[group('Utility')]
[private]
sudo-clean:
    just sudoif just clean

# sudoif bash function
[group('Utility')]
[private]
sudoif command *args:
    #!/usr/bin/bash
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            /usr/bin/sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            /usr/bin/sudo "$@" || exit 1
        else
            exit 1
        fi
    }
    sudoif {{ command }} {{ args }}

# Build the image using the specified parameters
build $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash

    BUILD_ARGS=()
    if [[ -z "$(git status -s)" ]]; then
        BUILD_ARGS+=("--build-arg" "SHA_HEAD_SHORT=$(git rev-parse --short HEAD)")
    fi

    podman build \
        "${BUILD_ARGS[@]}" \
        --pull=newer \
        --tag "${target_image}:${tag}" \
        .

# Copia immagine dallo store utente a quello root
_rootful_load_image $target_image=image_name $tag=default_tag:
    #!/usr/bin/bash
    set -eoux pipefail

    if [[ -n "${SUDO_USER:-}" || "${UID}" -eq "0" ]]; then
        echo "Already root or running under sudo, no need to load image from user podman."
        exit 0
    fi

    set +e
    resolved_tag=$(podman inspect -t image "${target_image}:${tag}" | jq -r '.[].RepoTags.[0]')
    return_code=$?
    set -e

    USER_IMG_ID=$(podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")

    if [[ $return_code -eq 0 ]]; then
        ID=$(just sudoif podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")
        if [[ "$ID" != "$USER_IMG_ID" ]]; then
            COPYTMP=$(mktemp -p "${PWD}" -d -t _build_podman_scp.XXXXXXXXXX)
            just sudoif TMPDIR=${COPYTMP} podman image scp ${UID}@localhost::"${target_image}:${tag}" root@localhost::"${target_image}:${tag}"
            rm -rf "${COPYTMP}"
        fi
    else
        just sudoif podman pull "${target_image}:${tag}"
    fi

# Build a bootc bootable image using Bootc Image Builder (BIB)
_build-bib $target_image $tag $type $config: (_rootful_load_image target_image tag)
    #!/usr/bin/env bash
    set -euo pipefail

    args="--type ${type} "
    args+="--use-librepo=True "
    args+="--rootfs=btrfs"

    BUILDTMP=$(mktemp -p "${PWD}" -d -t _build-bib.XXXXXXXXXX)

    sudo podman run \
      --rm \
      -it \
      --privileged \
      --pull=newer \
      --net=host \
      --security-opt label=type:unconfined_t \
      -v $(pwd)/${config}:/config.toml:ro \
      -v $BUILDTMP:/output \
      -v /var/lib/containers/storage:/var/lib/containers/storage \
      "${bib_image}" \
      ${args} \
      "${target_image}:${tag}"

    mkdir -p output
    sudo mv -f $BUILDTMP/* output/
    sudo rmdir $BUILDTMP
    sudo chown -R $USER:$USER output/

_rebuild-bib $target_image $tag $type $config: (build target_image tag) && (_build-bib target_image tag type config)

# Clona Titanoboa se non presente
[private]
_titanoboa-clone:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -d "{{ titanoboa_dir }}/.git" ]; then
        echo "→ Cloning Titanoboa..."
        git clone --depth=1 https://github.com/ublue-os/titanoboa "{{ titanoboa_dir }}"
    fi

# Aggiorna Titanoboa all'ultima versione di main
titanoboa-update: _titanoboa-clone
    git -C "{{ titanoboa_dir }}" fetch --depth=1 origin main
    git -C "{{ titanoboa_dir }}" reset --hard origin/main

# Build QCOW2
[group('Build Virtual Machine Image')]
build-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "qcow2" "disk_config/disk.toml")

# Build RAW
[group('Build Virtual Machine Image')]
build-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "raw" "disk_config/disk.toml")

# Build ISO via bootc-image-builder (upstream bloccato, preferire build-iso-live)
[group('Build Virtual Machine Image')]
build-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "iso" "disk_config/iso.toml")

# Build ISO live via Titanoboa:
# 1) builda image-template
# 2) salva oci-archive in installer/
# 3) carica nel root store + builda gabos_installer
# 4) rimuove il dump
# 5) genera la ISO in output/
[group('Build Virtual Machine Image')]
build-iso-live tag=default_tag compression="squashfs" kargs="NONE": _titanoboa-clone (build image_name tag)
    #!/usr/bin/env bash
    set -euo pipefail

    # Step 1: salva immagine pulita come oci-archive per l'installer
    echo "→ [1/4] Salvo image-template in installer/base-image.oci.tar..."
    podman save --format oci-archive \
        "localhost/{{ image_name }}:{{ tag }}" \
        -o "{{ installer_dir }}/base-image.oci.tar"

    # Step 2: carica oci-archive nel root store + build gabos_installer
    echo "→ [2/4] Carico nel root store e build gabos_installer..."
    sudo podman load -i "{{ installer_dir }}/base-image.oci.tar"

    # Step 3: remove image from user store to avoid confusion, since installer will load it again from root store
    podman rmi "localhost/{{ image_name }}:{{ tag }}" || true

    # Step 4: builda installer con l'oci-archive già presente nel root store
    sudo podman build \
        --cap-add sys_admin \
        --security-opt label=disable \
        --squash \
        -t "{{ installer_image }}" \
        "{{ installer_dir }}"

    # Step 3: rimuovi il dump ora che non serve più
    echo "→ [3/4] Rimuovo base-image.oci.tar..."
    rm -f "{{ installer_dir }}/base-image.oci.tar"

    # Step 4: build ISO con titanoboa
    echo "→ [4/4] Build ISO con Titanoboa..."
    cd "{{ titanoboa_dir }}"
    sudo TITANOBOA_CTR_IMAGE="{{ installer_image }}" ./main.sh

    mkdir -p "{{ justfile_directory() }}/output"
    if [ -f "{{ titanoboa_dir }}/output.iso" ]; then
        mv "{{ titanoboa_dir }}/output.iso" "{{ iso_out }}"
        echo "✓ ISO pronta: {{ iso_out }}"
        ls -lh "{{ iso_out }}"
    else
        echo "✗ output.iso non trovata in {{ titanoboa_dir }}" >&2
        exit 1
    fi

# Testa l'ISO in QEMU
test-iso iso=iso_out: _titanoboa-clone
    #!/usr/bin/env bash
    cd "{{ titanoboa_dir }}"
    just vm "{{ iso }}"

# Pulisce solo la work/ dir di Titanoboa (conserva l'ISO)
clean-iso-work: _titanoboa-clone
    #!/usr/bin/env bash
    cd "{{ titanoboa_dir }}"
    sudo just clean
    echo "✓ Work dir ripulita"

# Rimuove tutto: work/ + ISO finale
clean-iso: clean-iso-work
    rm -f "{{ iso_out }}"
    echo "✓ ISO rimossa"

# Rebuild QCOW2
[group('Build Virtual Machine Image')]
rebuild-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "qcow2" "disk_config/disk.toml")

# Rebuild RAW
[group('Build Virtual Machine Image')]
rebuild-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "raw" "disk_config/disk.toml")

# Rebuild ISO
[group('Build Virtual Machine Image')]
rebuild-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "iso" "disk_config/iso.toml")

# Run VM
_run-vm $target_image $tag $type $config:
    #!/usr/bin/bash
    set -eoux pipefail

    image_file="output/${type}/disk.${type}"
    if [[ $type == iso ]]; then
        image_file="output/bootiso/install.iso"
    fi

    if [[ ! -f "${image_file}" ]]; then
        just "build-${type}" "$target_image" "$tag"
    fi

    port=8006
    while grep -q :${port} <<< $(ss -tunalp); do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"

    run_args=()
    run_args+=(--rm --privileged)
    run_args+=(--pull=newer)
    run_args+=(--publish "127.0.0.1:${port}:8006")
    run_args+=(--env "CPU_CORES=4")
    run_args+=(--env "RAM_SIZE=8G")
    run_args+=(--env "DISK_SIZE=64G")
    run_args+=(--env "TPM=Y")
    run_args+=(--env "GPU=Y")
    run_args+=(--device=/dev/kvm)
    run_args+=(--volume "${PWD}/${image_file}":"/boot.${type}")
    run_args+=(docker.io/qemux/qemu)

    (sleep 30 && xdg-open http://localhost:"$port") &
    podman run "${run_args[@]}"

[group('Run Virtual Machine')]
run-vm-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "qcow2" "disk_config/disk.toml")

[group('Run Virtual Machine')]
run-vm-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "raw" "disk_config/disk.toml")

[group('Run Virtual Machine')]
run-vm-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "iso" "disk_config/iso.toml")

# Run VM con systemd-vmspawn
[group('Run Virtual Machine')]
spawn-vm rebuild="0" type="qcow2" ram="6G":
    #!/usr/bin/env bash
    set -euo pipefail

    [ "{{ rebuild }}" -eq 1 ] && echo "Rebuilding the ISO" && just build-vm {{ rebuild }} {{ type }}

    systemd-vmspawn \
      -M "bootc-image" \
      --console=gui \
      --cpus=2 \
      --ram=$(echo {{ ram }}| /usr/bin/numfmt --from=iec) \
      --network-user-mode \
      --vsock=false --pass-ssh-key=false \
      -i ./output/**/*.{{ type }}

# Lint scripts con shellcheck
lint:
    #!/usr/bin/env bash
    set -eoux pipefail
    if ! command -v shellcheck &> /dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    /usr/bin/find . -iname "*.sh" -type f -exec shellcheck "{}" ';'

# Format scripts con shfmt
format:
    #!/usr/bin/env bash
    set -eoux pipefail
    if ! command -v shfmt &> /dev/null; then
        echo "shfmt could not be found. Please install it."
        exit 1
    fi
    /usr/bin/find . -iname "*.sh" -type f -exec shfmt --write "{}" ';'