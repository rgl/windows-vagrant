#!/usr/bin/env bash
set -euo pipefail

# see https://docs.fedoraproject.org/en-US/quick-docs/creating-windows-virtual-machines-using-virtio-drivers/index.html
# see https://github.com/virtio-win/virtio-win-guest-tools-installer
# see https://github.com/virtio-win/virtio-win-pkg-scripts
u='https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.285-1/virtio-win-0.1.285.iso'
f="$(basename "$u")"

if [ ! -f "drivers/$f" ]; then
	rm -rf drivers drivers.tmp
	mkdir -p drivers.tmp
	wget --progress=dot:giga -P drivers.tmp "$u"
	7z x -odrivers.tmp drivers.tmp/virtio-win-*.iso
	mv drivers.tmp drivers
fi
