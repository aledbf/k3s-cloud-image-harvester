#!/bin/bash

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

IMAGE_URL="https://cloud-images.ubuntu.com/hirsute/current/hirsute-server-cloudimg-amd64.img"
CLOUD_IMAGE="${SCRIPT_DIRECTORY}/hirsute-server-cloudimg-amd64.img"

VM_IMAGE="${SCRIPT_DIRECTORY}/ubuntu-21.04-amd64.img"

echo "downloading Ubuntu cloud-image..."
curl -C - -sSL -o "${CLOUD_IMAGE}" "${IMAGE_URL}"

cp "${CLOUD_IMAGE}" "${VM_IMAGE}"

echo "increasing image disk size..."
qemu-img resize --preallocation=off "${VM_IMAGE}" +20G

echo "customizing image..."
virt-customize -a "${VM_IMAGE}" --run-command 'apt-get install cloud-guest-utils'
virt-customize -a "${VM_IMAGE}" --run-command 'growpart /dev/sda 1'
virt-customize -a "${VM_IMAGE}" --run-command 'mkdir -p /etc/containerd/'
virt-customize -a "${VM_IMAGE}" --upload "${SCRIPT_DIRECTORY}/containerd.toml:/etc/containerd/config.toml"
virt-customize -a "${VM_IMAGE}" --upload "${SCRIPT_DIRECTORY}/setup.sh:/setup.sh"
virt-customize -a "${VM_IMAGE}" --upload "${SCRIPT_DIRECTORY}/start-k3s.sh:/start-k3s.sh"

virt-customize -a "${VM_IMAGE}" --run-command 'echo "[Network]\nDHCP=ipv4" > /etc/systemd/network/20-dhcp.network'
virt-customize -a "${VM_IMAGE}" --run-command '/setup.sh'
virt-customize -a "${VM_IMAGE}" --run-command 'rm /etc/systemd/network/20-dhcp.network'
virt-customize -a "${VM_IMAGE}" --run-command '/start-k3s.sh'
virt-customize -a "${VM_IMAGE}" --run-command 'rm -rf /setup.sh /start-k3s.sh'

echo "freeing space..."
virt-sparsify --in-place "${VM_IMAGE}"
