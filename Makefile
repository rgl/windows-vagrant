# Disable builtin rules and variables since they aren't used
# This makes the output of "make -d" much easier to follow and speeds up evaluation
# NB you can use make --print-data-base --dry-run to troubleshoot this Makefile.
MAKEFLAGS+= --no-builtin-rules
MAKEFLAGS+= --no-builtin-variables

# uncomment the next two lines to use the local development version of the
# windows-update packer plugin. you probably want to change the path too.
#export PACKER_CONFIG_DIR:= $(HOME)/Projects/packer-plugin-windows-update/dist/test
#export PACKER_PLUGIN_PATH:= $(HOME)/Projects/packer-plugin-windows-update/dist/test/plugins

# libvirt images.
IMAGES+= windows-2022
IMAGES+= windows-2022-uefi
IMAGES+= windows-11-23h2
IMAGES+= windows-11-23h2-uefi

# Proxmox images.
PROXMOX_IMAGES+= windows-2022
PROXMOX_IMAGES+= windows-2022-uefi
PROXMOX_IMAGES+= windows-11-23h2
PROXMOX_IMAGES+= windows-11-23h2-uefi

# Hyper-V images.
HYPERV_IMAGES+= windows-2022
HYPERV_IMAGES+= windows-11-23h2

# vSphere images.
VSPHERE_IMAGES+= windows-2022
VSPHERE_IMAGES+= windows-2022-uefi

# Generate the build-* targets.
LIBVIRT_BUILDS= $(addsuffix -libvirt,$(addprefix build-,$(IMAGES)))
PROXMOX_BUILDS= $(addsuffix -proxmox,$(addprefix build-,$(PROXMOX_IMAGES)))
HYPERV_BUILDS= $(addsuffix -hyperv,$(addprefix build-,$(HYPERV_IMAGES)))
VSPHERE_BUILDS= $(addsuffix -vsphere,$(addprefix build-,$(VSPHERE_IMAGES)))

.PHONY: help always $(LIBVIRT_BUILDS) $(PROXMOX_BUILDS) $(VSPHERE_BUILDS)

help:
	@echo Type one of the following commands to build a specific windows box.
	@echo
	@echo libvirt targets:
	@$(addprefix echo make ,$(addsuffix ;,$(LIBVIRT_BUILDS)))
	@echo
	@echo Proxmox targets:
	@$(addprefix echo make ,$(addsuffix ;,$(PROXMOX_BUILDS)))
	@echo
	@echo Hyper-V targets:
	@$(addprefix echo make ,$(addsuffix ;,$(HYPERV_BUILDS)))
	@echo
	@echo vSphere targets:
	@$(addprefix echo make ,$(addsuffix ;,$(VSPHERE_BUILDS)))

# Target specific pattern rules for build-* targets.
$(LIBVIRT_BUILDS): build-%-libvirt: %-amd64-libvirt.box
$(PROXMOX_BUILDS): build-%-proxmox: %-amd64-proxmox.box
$(HYPERV_BUILDS): build-%-hyperv: %-amd64-hyperv.box
$(VSPHERE_BUILDS): build-%-vsphere: %-amd64-vsphere.box

%-amd64-libvirt.box: %.pkr.hcl tmp/%/autounattend.xml Vagrantfile.template *.ps1 drivers
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$*-amd64-libvirt-packer-init.log \
		packer init $*.pkr.hcl
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$*-amd64-libvirt-packer.log PKR_VAR_vagrant_box=$@ \
		packer build -only=qemu.$*-amd64 -on-error=abort $*.pkr.hcl
	./get-windows-updates-from-packer-log.sh \
		$*-amd64-libvirt-packer.log \
		>$*-amd64-libvirt-windows-updates.log
	@./box-metadata.sh libvirt $*-amd64 $@

%-amd64-proxmox.box: %.pkr.hcl tmp/%/autounattend.xml Vagrantfile.template *.ps1 drivers
	rm -f $@
	sed -E 's,<Path>A:\\</Path>,<Path>D:\\</Path>,g' -i tmp/$*/autounattend.xml
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$*-amd64-proxmox-packer-init.log \
		packer init $*.pkr.hcl
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$*-amd64-proxmox-packer.log PKR_VAR_vagrant_box=$@ \
		packer build -only=proxmox-iso.$*-amd64 -on-error=abort $*.pkr.hcl
	./get-windows-updates-from-packer-log.sh \
		$*-amd64-proxmox-packer.log \
		>$*-amd64-proxmox-windows-updates.log

%-amd64-hyperv.box: %.pkr.hcl tmp/%-uefi/autounattend.xml Vagrantfile.template *.ps1
	rm -f $@
	sed -E 's,<Path>A:\\</Path>,<Path>D:\\</Path>,g' -i tmp/$*/autounattend.xml
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$*-amd64-hyperv-packer-init.log \
		packer init $*.pkr.hcl
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$*-amd64-hyperv-packer.log PKR_VAR_vagrant_box=$@ \
		packer build -only=hyperv-iso.$*-amd64 -on-error=abort $*.pkr.hcl
	./get-windows-updates-from-packer-log.sh \
		$*-amd64-hyperv-packer.log \
		>$*-amd64-hyperv-windows-updates.log
	@./box-metadata.sh hyperv $*-amd64 $@

%-uefi-amd64-libvirt.box: %-uefi.pkr.hcl tmp/%-uefi/autounattend.xml Vagrantfile-uefi.template *.ps1 drivers
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$*-uefi-amd64-libvirt-packer-init.log \
		packer init $*-uefi.pkr.hcl
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$*-uefi-amd64-libvirt-packer.log PKR_VAR_vagrant_box=$@ \
		packer build -only=qemu.$*-uefi-amd64 -on-error=abort $*-uefi.pkr.hcl
	./get-windows-updates-from-packer-log.sh \
		$*-uefi-amd64-libvirt-packer.log \
		>$*-uefi-amd64-libvirt-windows-updates.log
	@./box-metadata.sh libvirt $*-uefi-amd64 $@

%-uefi-amd64-proxmox.box: %-uefi.pkr.hcl tmp/%-uefi/autounattend.xml Vagrantfile-uefi.template *.ps1 drivers
	rm -f $@
	sed -E 's,<Path>A:\\</Path>,<Path>D:\\</Path>,g' -i tmp/$*-uefi/autounattend.xml
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$*-uefi-amd64-proxmox-packer-init.log \
		packer init $*-uefi.pkr.hcl
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$*-uefi-amd64-proxmox-packer.log PKR_VAR_vagrant_box=$@ \
		packer build -only=proxmox-iso.$*-uefi-amd64 -on-error=abort $*-uefi.pkr.hcl
	./get-windows-updates-from-packer-log.sh \
		$*-uefi-amd64-proxmox-packer.log \
		>$*-uefi-amd64-proxmox-windows-updates.log

tmp/%-vsphere/autounattend.xml: %/autounattend.xml always
	mkdir -p "$$(dirname $@)"
	@# add the vmware tools iso to the drivers search path.
	@# NB we cannot have this in the main autounattend.xml because windows
	@#    will fail to install when the guest additions iso is in E:
	@#    with the error message:
	@#        Windows Setup could not install one or more boot-critical drivers.
	@#        To install Windows, make sure that the drivers are valid, and
	@#        restart the installation.
	sed -E 's,(.+)</DriverPaths>,\1    <PathAndCredentials wcm:action="add" wcm:keyValue="3"><Path>E:\\</Path></PathAndCredentials>\n\0,g' $< >$@
	if [ -n '${PKR_VAR_windows_product_key}' ]; then \
		sed -E 's,<!--<Key>.+</Key>-->,<Key>${PKR_VAR_windows_product_key}</Key>,g' -i $@; \
	fi

tmp/%/autounattend.xml: %/autounattend.xml always
	mkdir -p "$$(dirname $@)"
	cp -f $< $@
	if [ -n '${PKR_VAR_windows_product_key}' ]; then \
		sed -E 's,<!--<Key>.+</Key>-->,<Key>${PKR_VAR_windows_product_key}</Key>,g' -i $@; \
	fi

%-amd64-vsphere.box: %-vsphere.pkr.hcl tmp/%-vsphere/autounattend.xml Vagrantfile.template *.ps1
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$*-amd64-vsphere-packer-init.log \
		packer init $*.pkr.hcl
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$*-amd64-vsphere-packer.log PKR_VAR_vagrant_box=$@ \
		packer build -only=vsphere-iso.$*-amd64 -on-error=abort $*-vsphere.pkr.hcl
	./get-windows-updates-from-packer-log.sh \
		$*-amd64-vsphere-packer.log \
		>$*-amd64-vsphere-windows-updates.log
	@echo 'Removing all cd-roms (except the first)...'
	govc device.ls "-vm.ipath=$$VSPHERE_TEMPLATE_IPATH" \
		| grep ^cdrom- \
		| tail -n+2 \
		| awk '{print $$1}' \
		| xargs -L1 govc device.remove "-vm.ipath=$$VSPHERE_TEMPLATE_IPATH"
	@echo 'Converting to template...'
	govc vm.markastemplate "$$VSPHERE_TEMPLATE_IPATH"
	@echo 'Creating the local box file...'
	rm -rf tmp/$@-contents
	mkdir -p tmp/$@-contents
	echo '{"provider":"vsphere"}' >tmp/$@-contents/metadata.json
	cp Vagrantfile.template tmp/$@-contents/Vagrantfile
	tar cvf $@ -C tmp/$@-contents .
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f $*-amd64 $@

%-uefi-amd64-vsphere.box: %-uefi-vsphere.pkr.hcl tmp/%-uefi-vsphere/autounattend.xml Vagrantfile-uefi.template *.ps1
	rm -f $@
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$*-uefi-amd64-vsphere-packer-init.log \
		packer init $*-uefi-vsphere.pkr.hcl
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$*-uefi-amd64-vsphere-packer.log PKR_VAR_vagrant_box=$@ \
		packer build -only=vsphere-iso.$*-uefi-amd64 -on-error=abort $*-uefi-vsphere.pkr.hcl
	./get-windows-updates-from-packer-log.sh \
		$*-uefi-amd64-vsphere-packer.log \
		>$*-uefi-amd64-vsphere-windows-updates.log
	@echo 'Removing all cd-roms (except the first)...'
	govc device.ls "-vm.ipath=$$VSPHERE_TEMPLATE_IPATH" \
		| grep ^cdrom- \
		| tail -n+2 \
		| awk '{print $$1}' \
		| xargs -L1 govc device.remove "-vm.ipath=$$VSPHERE_TEMPLATE_IPATH"
	@echo 'Converting to template...'
	govc vm.markastemplate "$$VSPHERE_TEMPLATE_IPATH"
	@echo 'Creating the local box file...'
	rm -rf tmp/$@-contents
	mkdir -p tmp/$@-contents
	echo '{"provider":"vsphere"}' >tmp/$@-contents/metadata.json
	cp Vagrantfile.template tmp/$@-contents/Vagrantfile
	tar cvf $@ -C tmp/$@-contents .
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f $*-uefi-amd64 $@

drivers:
	rm -rf drivers.tmp
	mkdir -p drivers.tmp
	@# see https://docs.fedoraproject.org/en-US/quick-docs/creating-windows-virtual-machines-using-virtio-drivers/index.html
	@# see https://github.com/virtio-win/virtio-win-guest-tools-installer
	@# see https://github.com/virtio-win/virtio-win-pkg-scripts
	wget -P drivers.tmp https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.248-1/virtio-win-0.1.248.iso
	7z x -odrivers.tmp drivers.tmp/virtio-win-*.iso
	@# see https://github.com/virtio-win/virtio-win-guest-tools-installer/issues/25
	@# see https://github.com/virtio-win/virtio-win-pkg-scripts/issues/76#issuecomment-2103185076
	wget -O drivers.tmp/spice-guest-tools.exe https://www.spice-space.org/download/windows/spice-guest-tools/spice-guest-tools-0.141/spice-guest-tools-0.141.exe
	mv drivers.tmp drivers

clean:
	rm -rf *.log *.box
