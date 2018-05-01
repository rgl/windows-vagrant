This builds a Windows Server 2016 base Vagrant box using [Packer](https://www.packer.io/).


# Usage

Install [VirtualBox](https://www.virtualbox.org/) (or [libvirt](https://libvirt.org/) on Linux based systems), [packer](https://www.packer.io/), [packer-provisioner-windows-update plugin](https://github.com/rgl/packer-provisioner-windows-update) and [vagrant](https://www.vagrantup.com/).
If you are using Windows and [Chocolatey](https://chocolatey.org/), you can install everything with:

```batch
choco install -y virtualbox packer packer-provisioner-windows-update vagrant
```

To build the base box based on the [Windows Server 2016 Evaluation](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2016) ISO run:

```bash
packer build -only=windows-2016-amd64-virtualbox windows-2016.json # or make build-libvirt
```

If you want to use your own ISO, run the following instead:

```bash
packer build -var iso_url=<ISO_URL> -var iso_checksum=<ISO_SHA256_CHECKSUM> -only=windows-2016-amd64-virtualbox windows-2016.json
```

**NB** if the build fails with something like `Post-processor failed: write /tmp/packer073329394/packer-windows-2016-amd64-virtualbox-1505050546-disk001.vmdk: no space left on device` you need to increase your temporary partition size or change its location [as described in the packer TMPDIR/TMP environment variable documentation](https://www.packer.io/docs/other/environment-variables.html#tmpdir).

**NB** if you are having trouble building the base box due to floppy drive removal errors try adding, as a
workaround, `"post_shutdown_delay": "30s",` to the `windows-2016.json` file.

**NB** To troubleshoot, before launching `packer`, you can set the following environment variables:

```bash
export CHECKPOINT_DISABLE=1
export PACKER_LOG=1
export PACKER_LOG_PATH=packer.log
```

You can then add the base box to your local vagrant installation with:

```bash
vagrant box add -f windows-2016-amd64 windows-2016-amd64-virtualbox.box
```

And test this base box by launching an example Vagrant environment:

```bash
cd example
vagrant up --provider=virtualbox # or --provider=libvirt
```

**NB** if you are having trouble running the example with the vagrant libvirt provider check the libvirt logs in the host (e.g. `sudo tail -f /var/log/libvirt/qemu/example_default.log`) and in the guest (inside `C:\Windows\Temp`).

Then test with a more complete example:

```bash
git clone https://github.com/rgl/customize-windows-vagrant
cd customize-windows-vagrant
vagrant up --provider=virtualbox # or --provider=libvirt
```


## libvirt

Build the base box for the [vagrant-libvirt provider](https://github.com/vagrant-libvirt/vagrant-libvirt) with:

```bash
make build-libvirt
```

If you want to access the UI run:

```bash
spicy --uri 'spice+unix:///tmp/packer-windows-2016-amd64-libvirt-spice.socket'
```

**NB** the packer template file defines `qemuargs` (which overrides the default packer qemu arguments), if you modify it, verify if you also need include the default packer qemu arguments (see [builder/qemu/step_run.go](https://github.com/hashicorp/packer/blob/master/builder/qemu/step_run.go) or start packer without `qemuargs` defined to see how it starts qemu).


## WinRM access

You can connect to this machine through WinRM to run a remote command, e.g.:

```batch
winrs -r:localhost:55985 -u:vagrant -p:vagrant "whoami /all"
```

**NB** the exact local WinRM port should be displayed by vagrant, in this case:

```plain
==> default: Forwarding ports...
    default: 5985 (guest) => 55985 (host) (adapter 1)
```


# WinRM and UAC (aka LUA)

This base image uses WinRM. WinRM [poses several limitations on remote administration](http://www.hurryupandwait.io/blog/safely-running-windows-automation-operations-that-typically-fail-over-winrm-or-powershell-remoting),
those were worked around by disabling User Account Control (UAC) (aka Limited User Account (LUA)) in `autounattend.xml`.

If needed, you can later enable it with:

```powershell
Set-ItemProperty -Path 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA -Value 1
Set-ItemProperty -Path 'HKLM:SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA -Value 1
Restart-Computer
```


# Windows Unattended Installation

When Windows boots from the installation media its Setup application loads the `a:\autounattend.xml` file.
It contains all the answers needed to automatically install Windows without any human intervention. For
more information on how this works see [OEM Windows Deployment and Imaging Walkthrough](https://technet.microsoft.com/en-us/library/dn621895.aspx).

`autounattend.xml` was generated with the Windows System Image Manager (WSIM) application that is
included in the Windows Assessment and Deployment Kit (ADK).

## Windows ADK

To create, edit and validate the `a:\autounattend.xml` file you need to install the Deployment Tools that
are included in the [Windows ADK](https://developer.microsoft.com/en-us/windows/hardware/windows-assessment-deployment-kit).

If you are having trouble installing the ADK (`adksetup`) or running WSIM (`imgmgr`) when your
machine is on a Windows Domain and the log has:

```plain
Image path is [\??\C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\wimmount.sys]
Could not acquire privileges; GLE=0x514
Returning status 0x514
```

It means there's a group policy that is restricting your effective permissions, for an workaround,
run `adksetup` and `imgmgr` from a `SYSTEM` shell, something like:

```batch
psexec -s -d -i cmd
adksetup
cd "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\WSIM"
imgmgr
```

For more information see [Error installing Windows ADK](http://blogs.catapultsystems.com/chsimmons/archive/2015/08/17/error-installing-windows-adk/).
