# Disable builtin rules and variables since they aren't used
# This makes the output of "make -d" much easier to follow and speeds up evaluation
# NB you can use make --print-data-base --dry-run to troubleshoot this Makefile.
MAKEFLAGS+= --no-builtin-rules
MAKEFLAGS+= --no-builtin-variables

# uncomment the next two lines to use the local development version of the
# windows-update packer plugin. you probably want to change the path too.
#export PACKER_CONFIG_DIR:= $(HOME)/Projects/packer-plugin-windows-update/dist/test
#export PACKER_PLUGIN_PATH:= $(HOME)/Projects/packer-plugin-windows-update/dist/test/plugins

# ensure the temporary files are created in the tmp local directory; instead
# of a small tmpfs, like in ubuntu 26.04.
export TMPDIR?= ${PWD}/tmp

# NB execute windows-evaluation-isos-update.sh to update windows-evaluation-isos.json.
WINDOWS_11_ISO_URL?= $(shell jq -r '.["windows-11"].url' windows-evaluation-isos.json)
WINDOWS_11_ISO_CHECKSUM?= sha256:$(shell jq -r '.["windows-11"].checksum' windows-evaluation-isos.json)
WINDOWS_11_IOT_ISO_URL?= $(shell jq -r '.["windows-11-iot"].url' windows-evaluation-isos.json)
WINDOWS_11_IOT_ISO_CHECKSUM?= sha256:$(shell jq -r '.["windows-11-iot"].checksum' windows-evaluation-isos.json)
WINDOWS_2022_ISO_URL?= $(shell jq -r '.["windows-2022"].url' windows-evaluation-isos.json)
WINDOWS_2022_ISO_CHECKSUM?= sha256:$(shell jq -r '.["windows-2022"].checksum' windows-evaluation-isos.json)
WINDOWS_2025_ISO_URL?= $(shell jq -r '.["windows-2025"].url' windows-evaluation-isos.json)
WINDOWS_2025_ISO_CHECKSUM?= sha256:$(shell jq -r '.["windows-2025"].checksum' windows-evaluation-isos.json)

export WINDOWS_11_ISO_URL:= $(WINDOWS_11_ISO_URL)
export WINDOWS_11_ISO_CHECKSUM:= $(WINDOWS_11_ISO_CHECKSUM)
export WINDOWS_11_IOT_ISO_URL:= $(WINDOWS_11_IOT_ISO_URL)
export WINDOWS_11_IOT_ISO_CHECKSUM:= $(WINDOWS_11_IOT_ISO_CHECKSUM)
export WINDOWS_2022_ISO_URL:= $(WINDOWS_2022_ISO_URL)
export WINDOWS_2022_ISO_CHECKSUM:= $(WINDOWS_2022_ISO_CHECKSUM)
export WINDOWS_2025_ISO_URL:= $(WINDOWS_2025_ISO_URL)
export WINDOWS_2025_ISO_CHECKSUM:= $(WINDOWS_2025_ISO_CHECKSUM)

# libvirt images.
IMAGES+= windows-2022-uefi
IMAGES+= windows-2025-uefi
IMAGES+= windows-11-24h2-uefi
IMAGES+= windows-11-iot-24h2-uefi

# Proxmox images.
PROXMOX_IMAGES+= windows-2022-uefi
PROXMOX_IMAGES+= windows-2025-uefi
PROXMOX_IMAGES+= windows-11-24h2-uefi
PROXMOX_IMAGES+= windows-11-iot-24h2-uefi

# Hyper-V images.
HYPERV_IMAGES+= windows-2022-uefi
HYPERV_IMAGES+= windows-2025-uefi
HYPERV_IMAGES+= windows-11-24h2-uefi
HYPERV_IMAGES+= windows-11-iot-24h2-uefi

# vSphere images.
VSPHERE_IMAGES+= windows-2022-uefi
VSPHERE_IMAGES+= windows-2025-uefi
VSPHERE_IMAGES+= windows-11-24h2-uefi
VSPHERE_IMAGES+= windows-11-iot-24h2-uefi

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

%-uefi-amd64-hyperv.box: %-uefi.pkr.hcl tmp/%-uefi/autounattend.xml Vagrantfile-uefi.template *.ps1
	rm -f $@
	sed -E '/<DriverPaths>/,/<\/DriverPaths>/d' -i tmp/$*-uefi/autounattend.xml
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$*-uefi-amd64-hyperv-packer-init.log \
		packer init $*-uefi.pkr.hcl
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$*-uefi-amd64-hyperv-packer.log PKR_VAR_vagrant_box=$@ \
		packer build -only=hyperv-iso.$*-uefi-amd64 -on-error=abort $*-uefi.pkr.hcl
	./get-windows-updates-from-packer-log.sh \
		$*-uefi-amd64-hyperv-packer.log \
		>$*-uefi-amd64-hyperv-windows-updates.log
	@./box-metadata.sh hyperv $*-uefi-amd64 $@

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
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$*-uefi-amd64-proxmox-packer-init.log \
		packer init $*-uefi.pkr.hcl
	CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=$*-uefi-amd64-proxmox-packer.log PKR_VAR_vagrant_box=$@ \
		packer build -only=proxmox-iso.$*-uefi-amd64 -on-error=abort $*-uefi.pkr.hcl
	./get-windows-updates-from-packer-log.sh \
		$*-uefi-amd64-proxmox-packer.log \
		>$*-uefi-amd64-proxmox-windows-updates.log

tmp/%-vsphere/autounattend.xml: %/autounattend.xml always
	mkdir -p "$$(dirname $@)"
	sed -E '/<DriverPaths>/,/<\/DriverPaths>/d' $< >$@
	if [ -n '${PKR_VAR_windows_product_key}' ]; then \
		sed -E 's,<!--<Key>.+</Key>-->,<Key>${PKR_VAR_windows_product_key}</Key>,g' -i $@; \
	fi

tmp/%/autounattend.xml: %/autounattend.xml always
	mkdir -p "$$(dirname $@)"
	cp -f $< $@
	if [ -n '${PKR_VAR_windows_product_key}' ]; then \
		sed -E 's,<!--<Key>.+</Key>-->,<Key>${PKR_VAR_windows_product_key}</Key>,g' -i $@; \
	fi

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
	cp Vagrantfile-uefi.template tmp/$@-contents/Vagrantfile
	tar cvf $@ -C tmp/$@-contents .
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f $*-uefi-amd64 $@

.PHONY: drivers
drivers:
	./provision-drivers.sh

clean:
	rm -rf *.log *.box
