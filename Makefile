help:
	@echo type make build-libvirt or make build-virtualbox

build-libvirt: windows-2016-amd64-libvirt.box

build-virtualbox: windows-2016-amd64-virtualbox.box

build-windows-server-core-1709-libvirt: windows-server-core-1709-amd64-libvirt.box

build-windows-server-core-1709-virtualbox: windows-server-core-1709-amd64-virtualbox.box

build-core-insider-libvirt: windows-core-insider-2016-amd64-libvirt.box

build-core-insider-virtualbox: windows-core-insider-2016-amd64-virtualbox.box

windows-2016-amd64-libvirt.box: windows-2016.json autounattend.xml Vagrantfile.template *.ps1 drivers
	rm -f $@
	packer build -only=windows-2016-amd64-libvirt -on-error=abort windows-2016.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f windows-2016-amd64 $@

windows-2016-amd64-virtualbox.box: windows-2016.json autounattend.xml Vagrantfile.template *.ps1
	rm -f $@
	packer build -only=windows-2016-amd64-virtualbox -on-error=abort windows-2016.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f windows-2016-amd64 $@

windows-server-core-1709-amd64-libvirt.box: windows-server-core-1709.json windows-server-core-1709/autounattend.xml Vagrantfile.template *.ps1 drivers
	rm -f $@
	packer build -only=windows-server-core-1709-amd64-libvirt -on-error=abort windows-server-core-1709.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f windows-server-core-1709-amd64 $@

windows-server-core-1709-amd64-virtualbox.box: windows-server-core-1709.json windows-server-core-1709/autounattend.xml Vagrantfile.template *.ps1
	rm -f $@
	packer build -only=windows-server-core-1709-amd64-virtualbox -on-error=abort windows-server-core-1709.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f windows-server-core-1709-amd64 $@

windows-core-insider-2016-amd64-libvirt.box: windows-core-insider-2016.json windows-core-insider-2016/autounattend.xml Vagrantfile.template *.ps1 drivers
	rm -f $@
	packer build -only=windows-core-insider-2016-amd64-libvirt -on-error=abort windows-core-insider-2016.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f windows-core-insider-2016-amd64 $@

windows-core-insider-2016-amd64-virtualbox.box: windows-core-insider-2016.json windows-core-insider-2016/autounattend.xml Vagrantfile.template *.ps1
	rm -f $@
	packer build -only=windows-core-insider-2016-amd64-virtualbox -on-error=abort windows-core-insider-2016.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f windows-core-insider-2016-amd64 $@

drivers:
	rm -rf drivers.tmp
	mkdir -p drivers.tmp
	@# see https://fedoraproject.org/wiki/Windows_Virtio_Drivers
	wget -P drivers.tmp https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.141-1/virtio-win-0.1.141.iso
	7z x -odrivers.tmp drivers.tmp/virtio-win-*.iso
	mv drivers.tmp drivers
