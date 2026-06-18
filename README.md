# GabOS

[![CI](https://github.com/thegabriele97/gabos/actions/workflows/ci.yml/badge.svg)](https://github.com/thegabriele97/gabos/actions/workflows/ci.yml)
[![Build ISO](https://github.com/thegabriele97/gabos/actions/workflows/build-iso.yml/badge.svg)](https://github.com/thegabriele97/gabos/actions/workflows/build-iso.yml)
[![GHCR](https://img.shields.io/badge/ghcr.io-thegabriele97%2Fgabos-blue?logo=github)](https://github.com/thegabriele97/gabos/pkgs/container/gabos)
[![GHCR](https://img.shields.io/badge/ghcr.io-thegabriele97%2Fgabos--nvidia-blue?logo=github)](https://github.com/thegabriele97/gabos/pkgs/container/gabos-nvidia)

A personal, opinionated Linux desktop distribution built on top of [RakuOS](https://github.com/RakuOS/rakuos), using [bootc](https://github.com/bootc-dev/bootc) / OSTree image-based updates. GabOS ships a curated stack centered around the **Niri** Wayland compositor and **DankMaterialShell (DMS)**, with a focus on developer tooling, containerized workflows, and an immutable system that stays reproducible across updates.

Images are built and published daily via GitHub Actions to the GitHub Container Registry.

---

## Variants

| Image | Base | Description |
|-------|------|-------------|
| `ghcr.io/thegabriele97/gabos:latest` | `quay.io/rakuos/rakuos-base:latest` | Standard variant |
| `ghcr.io/thegabriele97/gabos-nvidia:latest` | `quay.io/rakuos/rakuos-base-nvidia:latest` | Includes proprietary NVIDIA drivers |

---

## What's included

### Desktop

- **[Niri](https://github.com/YaLTeR/niri)** — scrollable-tiling Wayland compositor
- **[DankMaterialShell (DMS)](https://github.com/dankMaterialShell/dms)** via [quickshell](https://quickshell.outfoxxed.me/) — shell UI layer
- **[greetd](https://git.sr.ht/~kennylevinsen/greetd)** + **dms-greeter** as display manager
- **Bibata** cursor theme

### Terminal & Shell

- [fish](https://fishshell.com/) — default shell
- [kitty](https://sw.kovidgoyal.net/kitty/) — terminal emulator (also registered as Nautilus default via `nautilus-open-any-terminal`)
- `lsd`, `bat`, `bat-extras`, `fzf`, `delta`, `ripgrep` — modern CLI replacements
- [yazi](https://yayachit.github.io/yazi/) — terminal file manager
- [fastfetch](https://github.com/fastfetch-cli/fastfetch), `lolcat`

### Editor

- [Neovim](https://neovim.io/) pre-configured with [AstroNvim](https://astronvim.com/) template
- `vim`

### Apps

- Firefox, Nautilus, file-roller, Loupe, Totem, Papers, GNOME Calculator
- [gamescope](https://github.com/ValveSoftware/gamescope) for gaming sessions

### Container & Dev

- [Podman](https://podman.io/) (socket enabled at boot)
- [Distrobox](https://distrobox.it/) for mutable container environments
- `git`, `curl`, `jq`

### System

- Plymouth with `spinner` theme
- `os-release` set to `NAME="GabOS"`, `ID=fedora`, `PRETTY_NAME="GabOS 44 <YYYYMMDD>"`
- GHCR registry (`ghcr.io/thegabriele97`) pre-configured as trusted in `/etc/containers/policy.json`
- `dnf5` tuned with `max_parallel_downloads=10`

---

## Installation

### Option 1 — Rebase from an existing Fedora Atomic system

If you're already running a bootc/OSTree-based Fedora distribution (Silverblue, Kinoite, RakuOS, etc.):

```bash
# Standard variant
sudo bootc switch ghcr.io/thegabriele97/gabos:latest

# NVIDIA variant
sudo bootc switch ghcr.io/thegabriele97/gabos-nvidia:latest
```

Then reboot. bootc will apply the new image on the next boot.

### Option 2 — ISO

ISOs can be generated on demand via the **Build ISO** GitHub Actions workflow (manual dispatch). The workflow builds an installer image using [titanoboa](https://github.com/ublue-os/titanoboa) and uploads the result to the configured storage endpoint.

To trigger a build, go to **Actions → Build ISO → Run workflow** and select which variant(s) to build.

---

## CI/CD

The pipeline runs on **GitHub Actions** and is split into focused reusable workflows:

| Workflow | Trigger | Description |
|----------|---------|-------------|
| `ci.yml` | Push to `main`, daily @ 10:05 UTC, PR | Orchestrates the full build |
| `build.yml` | Called by `ci.yml` | Builds and pushes an OCI image to GHCR with date tag (`YYYYMMDD`) + `latest` |
| `package_diff.yml` | Called by `ci.yml` after each build | Diffs RPM package lists between the two most recent date-tagged builds and uploads a Markdown report as a workflow artifact |
| `build-iso.yml` | Manual dispatch | Triggers ISO builds for one or both variants |
| `build-iso-reusable.yml` | Called by `build-iso.yml` | Builds the installer image via titanoboa and uploads the ISO |

PRs are built but **not pushed** to the registry.

---

## Local development

The repo ships a `Justfile` for common tasks. Requires [just](https://just.systems/).

```bash
just          # list all available recipes

just build            # build the gabos image locally
just run-vm           # build and run in a QEMU VM (qcow2)
just clean            # remove build artifacts

just check            # check Justfile/just syntax
just fix              # auto-format Justfile/just syntax
```

---

## Based on

- [RakuOS](https://github.com/RakuOS/rakuos) — Fedora Atomic base image
- [Universal Blue](https://universal-blue.org/) — tooling and GitHub Actions infrastructure
- [bootc](https://github.com/bootc-dev/bootc) — image-based system updates
- [titanoboa](https://github.com/ublue-os/titanoboa) — ISO generation
