#!/usr/bin/env bash
set -euo pipefail

# see https://docs.fedoraproject.org/en-US/quick-docs/creating-windows-virtual-machines-using-virtio-drivers/index.html
# see https://github.com/virtio-win/virtio-win-guest-tools-installer
# see https://github.com/virtio-win/virtio-win-pkg-scripts
u='https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.302-1/virtio-win-0.1.302.iso'
f="$(basename "$u")"

if [ ! -f "drivers/$f" ]; then
	rm -rf drivers
	mkdir -p drivers.tmp
	# keep the iso from a previous run (e.g. one that failed to extract it),
	# but remove everything else, like an older iso or a partial extraction.
	find drivers.tmp -mindepth 1 -maxdepth 1 ! -name "$f" -exec rm -rf {} +
	wget --progress=dot:giga --continue -P drivers.tmp "$u"
	7z x -y -odrivers.tmp "drivers.tmp/$f"
	mv drivers.tmp drivers
fi
