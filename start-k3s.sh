#!/bin/bash

# Install k3s
export INSTALL_K3S_SKIP_DOWNLOAD=true
export INSTALL_K3S_CHANNEL=latest

# shellcheck disable=SC2154
/usr/local/bin/install-k3s.sh \
    --container-runtime-endpoint=/var/run/containerd/containerd.sock \
    --write-kubeconfig-mode 400 \
    --disable=servicelb,traefik
