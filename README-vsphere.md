Download the latest `packer-builder-vsphere-iso.exe` release from [jetbrains-infra/packer-builder-vsphere](https://github.com/jetbrains-infra/packer-builder-vsphere/releases) and place it inside your `%APPDATA%\packer.d\plugins` directory.

Download the Windows Evaluation iso (you can find the full iso URL in the [windows-2016.json](windows-2016.json) file) and place it inside the datastore as defined by the `vsphere_iso_url` user variable that is inside the [packer template](windows-2016-vsphere.json).

Download the VMware Tools zip and extract the `windows.iso` file into the datastore defined by the `vsphere_tools_iso_url` user variable that is inside the [packer template](windows-2016-vsphere.json).

Build the base box with:

```bash
make build-vsphere
```

**NB** the generated template will include a reference to the extra iso images that were used to create the template, which is a bummer. 

**NB** these errors are expected (should be fixed when https://github.com/jetbrains-infra/packer-builder-vsphere/pull/82 is release):
```
==> windows-2016-amd64-vsphere: error removing floppy: The operation is not supported on the object.
==> windows-2016-amd64-vsphere: error removing cdroms: The operation is not supported on the object.
```

