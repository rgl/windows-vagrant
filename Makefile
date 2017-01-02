windows-2016-amd64-virtualbox.box: windows-2016.json autounattend.xml *.ps1
	rm -f $@
	packer build windows-2016.json
	@echo BOX successfully built!
	@echo to add to local vagrant install do:
	@echo vagrant box add -f windows-2016-amd64 windows-2016-amd64-virtualbox.box
