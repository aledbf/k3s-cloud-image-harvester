#!/usr/bin/env bash

set -euo pipefail
set -x

export DEBIAN_FRONTEND=noninteractive

apt update
apt dist-upgrade -y

apt install -y  \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg-agent \
  software-properties-common \
  cloud-initramfs-growroot \
  cloud-guest-utils \
  qemu-guest-agent

# Configure grub
echo "GRUB_GFXPAYLOAD_LINUX=keep" >> /etc/default/grub

# Enable cgroups2
sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1 cgroup_no_v1=all \1"/g' /etc/default/grub
sed -i 's/console=ttyS[^ "]*//g' /etc/default/grub /boot/grub/grub.cfg

apt-add-repository -y "deb http://ppa.launchpad.net/tuxinvader/lts-mainline/ubuntu focal main"
apt update
apt install -y linux-generic-5.15

# Install required packages
apt install -y \
  iptables libseccomp2 socat conntrack ipset \
  jq \
  iproute2 \
  auditd \
  ethtool \
  net-tools \
  parted

mkdir -p /etc/modules-load.d/

# Enable modules
cat <<EOF > /etc/modules-load.d/k8s.conf
ena
overlay
fuse
br_netfilter
EOF

# Disable modules
cat <<EOF > /etc/modprobe.d/kubernetes-blacklist.conf
blacklist dccp
blacklist sctp
EOF

# Install containerd
curl -sSL https://github.com/containerd/nerdctl/releases/download/v0.12.1/nerdctl-full-0.12.1-linux-amd64.tar.gz -o - | tar -xz -C /usr/local

mkdir -p /etc/containerd /etc/containerd/certs.d

cp /usr/local/lib/systemd/system/* /lib/systemd/system/
sed -i 's/--log-level=debug//g' /lib/systemd/system/stargz-snapshotter.service

cp /usr/local/lib/systemd/system/* /lib/systemd/system/
# Disable software irqbalance service
systemctl stop irqbalance.service
systemctl disable irqbalance.service

# Reload systemd
systemctl daemon-reload

mkdir -p /etc/containerd-stargz-grpc/

# Start containerd and stargz
systemctl enable containerd
systemctl enable stargz-snapshotter

systemctl start containerd
systemctl start stargz-snapshotter

# Download k3s tar file to improve initial start time and remove dependency of Internet connection
mkdir -p /var/lib/rancher/k3s/agent/images/
curl -sSL "https://github.com/k3s-io/k3s/releases/download/v1.22.2%2Bk3s2/k3s-airgap-images-amd64.tar" \
  -o /var/lib/rancher/k3s/agent/images/k3s-airgap-images-amd64.tar

# Download k3s binary
curl -sSL "https://github.com/k3s-io/k3s/releases/download/v1.22.2%2Bk3s2/k3s" -o /usr/local/bin/k3s
chmod +x /usr/local/bin/k3s

# Download k3s install script
curl -sSL https://get.k3s.io/ -o /usr/local/bin/install-k3s.sh
chmod +x /usr/local/bin/install-k3s.sh

# Install helm
curl -fsSL https://get.helm.sh/helm-v3.7.0-linux-amd64.tar.gz -o - | tar -xzvC /tmp/ --strip-components=1
cp /tmp/helm /usr/local/bin/helm

# Install calicoctl
curl -sSL -o /usr/local/bin/calicoctl \
  https://github.com/projectcalico/calicoctl/releases/download/v3.20.2/calicoctl
chmod +x /usr/local/bin/calicoctl

mkdir -p /var/lib/rancher/k3s/server/manifests
curl -sSL -o /var/lib/rancher/k3s/server/manifests/calico.yaml \
  https://docs.projectcalico.org/manifests/calico-vxlan.yaml

/usr/local/bin/ctr -n k8s.io image pull docker.io/calico/cni:v3.20.2
/usr/local/bin/ctr -n k8s.io image pull docker.io/calico/kube-controllers:v3.20.2
/usr/local/bin/ctr -n k8s.io image pull docker.io/calico/node:v3.20.2
/usr/local/bin/ctr -n k8s.io image pull docker.io/calico/pod2daemon-flexvol:v3.20.2

# cleanup temporal packages
apt clean -y
apt autoclean
apt autoremove -y

# cleanup journal logs
rm -rf /var/log/journal/*
rm -rf /tmp/*

systemctl disable systemd-resolved.service
systemctl stop systemd-resolved

rm /etc/resolv.conf
touch /etc/resolv.conf
