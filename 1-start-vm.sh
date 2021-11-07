#!/bin/bash

SCRIPT_DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

VM_IMAGE="${SCRIPT_DIRECTORY}/ubuntu-21.04-amd64.img"

echo "creating user-data..."

cat > user-data.img <<EOF
#cloud-config
password: password
chpasswd: { expire: False }
ssh_pwauth: True
EOF

cloud-localds user-data.img user-data.yaml

echo "starting vm..."
qemu-system-x86_64 \
  -name amd64 \
  -machine q35,accel=kvm \
  -cpu host \
  -smp 8 \
  -m 16g \
  -nographic \
  -drive if=pflash,file=firmware-code-amd64.fd,format=raw,readonly=on \
  -drive if=pflash,file=firmware-vars-amd64.fd,format=raw,readonly=on \
  -drive if=virtio,file="${VM_IMAGE}",format=qcow2 \
  -drive file=user-data.img,format=raw \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0
