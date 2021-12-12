packer {
  required_plugins {
    windows-update = {
      version = "0.14.0"
      source = "github.com/rgl/windows-update"
    }
    ansible = {
      version = "1.0.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

variable "disk_size" {
  type    = string
  default = "61440"
}

variable "iso_url" {
  type    = string
  default = "https://software-download.microsoft.com/download/sg/20348.169.210806-2348.fe_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:4f1457c4fe14ce48c9b2324924f33ca4f0470475e6da851b39ccbf98f44e7852"
}

variable "hyperv_switch_name" {
  type    = string
  default = env("HYPERV_SWITCH_NAME")
}

variable "hyperv_vlan_id" {
  type    = string
  default = env("HYPERV_VLAN_ID")
}

variable "vagrant_box" {
  type = string
}

source "qemu" "windows-2022-amd64" {
  accelerator = "kvm"
  cpus        = 2
  memory      = 4096
  qemuargs = [
    ["-cpu", "host"],
    ["-soundhw", "hda"],
    ["-device", "piix3-usb-uhci"],
    ["-device", "usb-tablet"],
    ["-device", "virtio-scsi-pci,id=scsi0"],
    ["-device", "scsi-hd,bus=scsi0.0,drive=drive0"],
    ["-device", "virtio-net,netdev=user.0"],
    ["-vga", "qxl"],
    ["-device", "virtio-serial-pci"],
    ["-chardev", "socket,path=/tmp/{{ .Name }}-qga.sock,server,nowait,id=qga0"],
    ["-device", "virtserialport,chardev=qga0,name=org.qemu.guest_agent.0"],
    ["-chardev", "spicevmc,id=spicechannel0,name=vdagent"],
    ["-device", "virtserialport,chardev=spicechannel0,name=com.redhat.spice.0"],
    ["-spice", "unix,addr=/tmp/{{ .Name }}-spice.socket,disable-ticketing"],
  ]
  disk_interface = "virtio-scsi"
  disk_cache     = "unsafe"
  disk_discard   = "unmap"
  disk_size      = var.disk_size
  floppy_files = [
    "windows-2022/autounattend.xml",
    "winrm.ps1",
    "provision-openssh.ps1",
    "drivers/vioserial/2k19/amd64/*.cat",
    "drivers/vioserial/2k19/amd64/*.inf",
    "drivers/vioserial/2k19/amd64/*.sys",
    "drivers/viostor/2k19/amd64/*.cat",
    "drivers/viostor/2k19/amd64/*.inf",
    "drivers/viostor/2k19/amd64/*.sys",
    "drivers/vioscsi/2k19/amd64/*.cat",
    "drivers/vioscsi/2k19/amd64/*.inf",
    "drivers/vioscsi/2k19/amd64/*.sys",
    "drivers/NetKVM/2k19/amd64/*.cat",
    "drivers/NetKVM/2k19/amd64/*.inf",
    "drivers/NetKVM/2k19/amd64/*.sys",
    "drivers/qxldod/2k19/amd64/*.cat",
    "drivers/qxldod/2k19/amd64/*.inf",
    "drivers/qxldod/2k19/amd64/*.sys",
  ]
  format           = "qcow2"
  headless         = true
  http_directory   = "."
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  shutdown_command = "shutdown /s /t 0 /f /d p:4:1 /c \"Packer Shutdown\""
  communicator     = "winrm"
  winrm_username   = "vagrant"
  winrm_password   = "vagrant"
  winrm_timeout    = "4h"
}

source "virtualbox-iso" "windows-2022-amd64" {
  cpus      = 2
  memory    = 4096
  disk_size = var.disk_size
  floppy_files = [
    "windows-2022/autounattend.xml",
    "winrm.ps1",
    "provision-openssh.ps1",
  ]
  guest_additions_interface = "sata"
  guest_additions_mode      = "attach"
  guest_os_type             = "Windows2019_64"
  hard_drive_interface      = "sata"
  headless                  = true
  iso_url                   = var.iso_url
  iso_checksum              = var.iso_checksum
  iso_interface             = "sata"
  shutdown_command          = "shutdown /s /t 0 /f /d p:4:1 /c \"Packer Shutdown\""
  vboxmanage = [
    ["storagectl", "{{ .Name }}", "--name", "IDE Controller", "--remove"],
    ["modifyvm", "{{ .Name }}", "--vrde", "off"],
    ["modifyvm", "{{ .Name }}", "--graphicscontroller", "vboxsvga"],
    ["modifyvm", "{{ .Name }}", "--vram", "128"],
    ["modifyvm", "{{ .Name }}", "--accelerate3d", "on"],
    ["modifyvm", "{{ .Name }}", "--usb", "on"],
    ["modifyvm", "{{ .Name }}", "--mouse", "usbtablet"],
    ["modifyvm", "{{ .Name }}", "--audio", "none"],
    ["modifyvm", "{{ .Name }}", "--nictype1", "82540EM"],
    ["modifyvm", "{{ .Name }}", "--nictype2", "82540EM"],
    ["modifyvm", "{{ .Name }}", "--nictype3", "82540EM"],
    ["modifyvm", "{{ .Name }}", "--nictype4", "82540EM"],
  ]
  communicator = "ssh"
  ssh_username = "vagrant"
  ssh_password = "vagrant"
  ssh_timeout  = "4h"
}

source "hyperv-iso" "windows-2022-amd64" {
  cpus         = 2
  memory       = 4096
  generation   = 2
  boot_command = ["<up><wait><up><wait><up><wait><up><wait><up><wait>"]
  boot_order   = ["SCSI:0:0"]
  boot_wait    = "1s"
  cd_files = [
    "windows-2022-uefi/autounattend.xml",
    "winrm.ps1",
    "provision-openssh.ps1",
  ]
  disk_size         = var.disk_size
  first_boot_device = "DVD"
  headless          = true
  iso_url           = var.iso_url
  iso_checksum      = var.iso_checksum
  switch_name       = var.hyperv_switch_name
  temp_path         = "tmp"
  vlan_id           = var.hyperv_vlan_id
  shutdown_command  = "shutdown /s /t 0 /f /d p:4:1 /c \"Packer Shutdown\""
  communicator      = "ssh"
  ssh_username      = "vagrant"
  ssh_password      = "vagrant"
  ssh_timeout       = "4h"
}

build {
  sources = [
    "source.qemu.windows-2022-amd64",
    "source.virtualbox-iso.windows-2022-amd64",
    "source.hyperv-iso.windows-2022-amd64",
  ]

  provisioner "powershell" {
    script = "disable-windows-updates.ps1"
  }

  provisioner "powershell" {
    inline = ["Uninstall-WindowsFeature Windows-Defender"]
  }

  provisioner "powershell" {
    only   = ["virtualbox-iso.windows-2022-amd64"]
    script = "virtualbox-prevent-vboxsrv-resolution-delay.ps1"
  }

  provisioner "powershell" {
    only   = ["qemu.windows-2022-amd64"]
    script = "provision-guest-tools-qemu-kvm.ps1"
  }

  provisioner "windows-restart" {
  }

  provisioner "powershell" {
    script = "provision.ps1"
  }

  provisioner "ansible" {
    use_proxy = false
    user = "vagrant"
    command = "./ansible-playbook.sh"
    extra_arguments = [
      "-v",
      "-e", "ansible_connection=psrp",
      "-e", "ansible_psrp_protocol=http",
      "-e", "ansible_psrp_message_encryption=never",
      "-e", "ansible_psrp_auth=credssp",
    ]
    playbook_file = "playbook.yml"
  }

  provisioner "powershell" {
    script = "enable-remote-desktop.ps1"
  }

  provisioner "powershell" {
    script = "provision-cloudbase-init.ps1"
  }

  provisioner "powershell" {
    script = "eject-media.ps1"
  }

  provisioner "powershell" {
    script = "optimize.ps1"
  }

  post-processor "vagrant" {
    output               = var.vagrant_box
    vagrantfile_template = "Vagrantfile.template"
  }
}
