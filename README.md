# k3s-cloud-image-harvester
Custom Ubuntu cloud-image with k3s - VM template for https://harvesterhci.io

[0-prepare-image.sh](0-prepare-image.sh) create a custom cloud-image with:
- k3s
- nerdctl with stargz support
- kernel v5.15
- cgroups v2
- calico as CNI provider

[1-start-vm.sh](1-start-vm.sh) start a QEMU VM using the created image.
