help:
	@echo for Windows 2012 R2 type make build-windows-2012-r2-libvirt or make build-windows-2012-r2-virtualbox
	@echo for Windows 2016 type make build-windows-2016-libvirt or make build-windows-2016-virtualbox
	@echo for Windows 2019 type make build-windows-2019-libvirt or make build-windows-2019-virtualbox
	@echo for Windows 10 type make build-windows-10-libvirt or make build-windows-10-virtualbox

build-windows-2012-r2-virtualbox: windows-2012-r2-amd64-virtualbox.box
build-windows-2012-r2-libvirt: windows-2012-r2-amd64-libvirt.box

build-windows-2016-libvirt: windows-2016-amd64-libvirt.box
build-windows-2016-virtualbox: windows-2016-amd64-virtualbox.box

build-windows-2019-virtualbox: windows-2019-amd64-virtualbox.box
build-windows-2019-libvirt: windows-2019-amd64-libvirt.box

build-windows-server-core-1709-libvirt: windows-server-core-1709-amd64-libvirt.box
build-windows-server-core-1709-virtualbox: windows-server-core-1709-amd64-virtualbox.box

build-core-insider-libvirt: windows-core-insider-2016-amd64-libvirt.box
build-core-insider-virtualbox: windows-core-insider-2016-amd64-virtualbox.box

build-windows-10-libvirt: windows-10-amd64-libvirt.box
build-windows-10-virtualbox: windows-10-amd64-virtualbox.box

windows-2012-r2-amd64-libvirt.box: windows-2012-r2.json windows-2012-r2/autounattend.xml Vagrantfile.template *.ps1 drivers
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=windows-2012-r2-amd64-libvirt-packer.log \
		packer build -only=windows-2012-r2-amd64-libvirt -on-error=abort windows-2012-r2.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f windows-2012-r2-amd64 $@

windows-2012-r2-amd64-virtualbox.box: windows-2012-r2.json windows-2012-r2/autounattend.xml Vagrantfile.template *.ps1 drivers
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=windows-2012-r2-amd64-virtualbox-packer.log \
		packer build -only=windows-2012-r2-amd64-virtualbox -on-error=abort windows-2012-r2.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f windows-2012-r2-amd64 $@

windows-2016-amd64-libvirt.box: windows-2016.json autounattend.xml Vagrantfile.template *.ps1 drivers
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=windows-2016-amd64-libvirt-packer.log \
		packer build -only=windows-2016-amd64-libvirt -on-error=abort windows-2016.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f windows-2016-amd64 $@

windows-2016-amd64-virtualbox.box: windows-2016.json autounattend.xml Vagrantfile.template *.ps1 drivers
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=windows-2016-amd64-virtualbox-packer.log \
		packer build -only=windows-2016-amd64-virtualbox -on-error=abort windows-2016.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f windows-2016-amd64 $@

windows-2019-amd64-libvirt.box: windows-2019.json windows-2019/autounattend.xml Vagrantfile.template *.ps1 drivers
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=windows-2019-amd64-libvirt-packer.log \
		packer build -only=windows-2019-amd64-libvirt -on-error=abort windows-2019.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f windows-2019-amd64 $@

windows-2019-amd64-virtualbox.box: windows-2019.json windows-2019/autounattend.xml Vagrantfile.template *.ps1 drivers
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=windows-2019-amd64-virtualbox-packer.log \
		packer build -only=windows-2019-amd64-virtualbox -on-error=abort windows-2019.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f windows-2019-amd64 $@

windows-server-core-1709-amd64-libvirt.box: windows-server-core-1709.json windows-server-core-1709/autounattend.xml Vagrantfile.template *.ps1 drivers
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=windows-server-core-1709-amd64-libvirt-packer.log \
		packer build -only=windows-server-core-1709-amd64-libvirt -on-error=abort windows-server-core-1709.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f windows-server-core-1709-amd64 $@

windows-server-core-1709-amd64-virtualbox.box: windows-server-core-1709.json windows-server-core-1709/autounattend.xml Vagrantfile.template *.ps1 drivers
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=windows-server-core-1709-amd64-virtualbox-packer.log \
		packer build -only=windows-server-core-1709-amd64-virtualbox -on-error=abort windows-server-core-1709.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f windows-server-core-1709-amd64 $@

windows-core-insider-2016-amd64-libvirt.box: windows-core-insider-2016.json windows-core-insider-2016/autounattend.xml Vagrantfile.template *.ps1 drivers
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=windows-core-insider-2016-amd64-libvirt-packer.log \
		packer build -only=windows-core-insider-2016-amd64-libvirt -on-error=abort windows-core-insider-2016.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f windows-core-insider-2016-amd64 $@

windows-core-insider-2016-amd64-virtualbox.box: windows-core-insider-2016.json windows-core-insider-2016/autounattend.xml Vagrantfile.template *.ps1 drivers
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=windows-core-insider-2016-amd64-virtualbox-packer.log \
		packer build -only=windows-core-insider-2016-amd64-virtualbox -on-error=abort windows-core-insider-2016.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f windows-core-insider-2016-amd64 $@

windows-10-amd64-libvirt.box: windows-10.json windows-10/autounattend.xml Vagrantfile.template *.ps1 drivers
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=windows-10-amd64-libvirt-packer.log \
		packer build -only=windows-10-amd64-libvirt -on-error=abort windows-10.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f windows-10-amd64 $@

windows-10-amd64-virtualbox.box: windows-10.json windows-10/autounattend.xml Vagrantfile.template *.ps1 drivers
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=windows-10-amd64-virtualbox-packer.log \
		packer build -only=windows-10-amd64-virtualbox -on-error=abort windows-10.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f windows-10-amd64 $@

drivers:
	rm -rf drivers.tmp
	mkdir -p drivers.tmp
	@# see https://fedoraproject.org/wiki/Windows_Virtio_Drivers
	wget -P drivers.tmp https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.160-1/virtio-win-0.1.160.iso
	7z x -odrivers.tmp drivers.tmp/virtio-win-*.iso
	7z a drivers.tmp/virtio-2012-r2.zip drivers.tmp/Balloon/2k12R2/amd64 drivers.tmp/vioserial/2k12R2/amd64
	7z a drivers.tmp/virtio-10.zip drivers.tmp/Balloon/w10/amd64
	7z a drivers.tmp/virtio-2016.zip drivers.tmp/Balloon/2k16/amd64
	7z a drivers.tmp/virtio-2019.zip drivers.tmp/Balloon/2k16/amd64
	mv drivers.tmp drivers
