#!/bin/bash

set -ouex pipefail

dnf5.real -y install \
    nvidia-driver-cuda
