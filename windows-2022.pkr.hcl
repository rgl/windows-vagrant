packer {
  required_plugins {
    # see https://github.com/hashicorp/packer-plugin-proxmox
    proxmox = {
      version = "1.1.6"
      source  = "github.com/hashicorp/proxmox"
    }
    # see https://github.com/hashicorp/packer-plugin-hyperv
    hyperv = {
      version = "1.1.3"
      source  = "github.com/hashicorp/hyperv"
    }
    # see https://github.com/rgl/packer-plugin-windows-update
    windows-update = {
      version = "0.14.3"
      source  = "github.com/rgl/windows-update"
    }
  }
}

variable "disk_size" {
  type    = string
  default = "61440"
}

variable "iso_url" {
  type    = string
  default = "https://software-static.download.prss.microsoft.com/sg/download/888969d5-f34g-4e03-ac9d-1f9786c66749/SERVER_EVAL_x64FRE_en-us.iso"
}

variable "iso_checksum" {
  type    = string
  default = "sha256:3e4fa6d8507b554856fc9ca6079cc402df11a8b79344871669f0251535255325"
}

variable "proxmox_node" {
  type    = string
  default = env("PROXMOX_NODE")
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
  accelerator  = "kvm"
  machine_type = "q35"
  cpus         = 2
  memory       = 4096
  qemuargs = [
    ["-cpu", "host"],
    ["-device", "qemu-xhci"],
    ["-device", "virtio-tablet"],
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
    "drivers/NetKVM/2k22/amd64/*.cat",
    "drivers/NetKVM/2k22/amd64/*.inf",
    "drivers/NetKVM/2k22/amd64/*.sys",
    "drivers/qxldod/2k22/amd64/*.cat",
    "drivers/qxldod/2k22/amd64/*.inf",
    "drivers/qxldod/2k22/amd64/*.sys",
    "drivers/vioscsi/2k22/amd64/*.cat",
    "drivers/vioscsi/2k22/amd64/*.inf",
    "drivers/vioscsi/2k22/amd64/*.sys",
    "drivers/vioserial/2k22/amd64/*.cat",
    "drivers/vioserial/2k22/amd64/*.inf",
    "drivers/vioserial/2k22/amd64/*.sys",
    "drivers/viostor/2k22/amd64/*.cat",
    "drivers/viostor/2k22/amd64/*.inf",
    "drivers/viostor/2k22/amd64/*.sys",
    "provision-autounattend.ps1",
    "provision-openssh.ps1",
    "provision-psremoting.ps1",
    "provision-pwsh.ps1",
    "provision-winrm.ps1",
    "windows-2022/autounattend.xml",
  ]
  format                   = "qcow2"
  headless                 = true
  net_device               = "virtio-net"
  http_directory           = "."
  iso_url                  = var.iso_url
  iso_checksum             = var.iso_checksum
  shutdown_command         = "shutdown /s /t 0 /f /d p:4:1 /c \"Packer Shutdown\""
  communicator             = "ssh"
  ssh_username             = "vagrant"
  ssh_password             = "vagrant"
  ssh_timeout              = "4h"
  ssh_file_transfer_method = "sftp"
}

source "proxmox-iso" "windows-2022-amd64" {
  template_name            = "template-windows-2022"
  template_description     = "See https://github.com/rgl/windows-vagrant"
  tags                     = "windows-2022;template"
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node
  machine                  = "q35"
  cpu_type                 = "host"
  cores                    = 2
  memory                   = 4096
  vga {
    type   = "qxl"
    memory = 32
  }
  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }
  scsi_controller = "virtio-scsi-single"
  disks {
    type         = "scsi"
    io_thread    = true
    ssd          = true
    discard      = true
    disk_size    = "${var.disk_size}M"
    storage_pool = "local-lvm"
  }
  iso_storage_pool = "local"
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  unmount_iso      = true
  additional_iso_files {
    device           = "ide0"
    unmount          = true
    iso_storage_pool = "local"
    cd_label         = "PROVISION"
    cd_files = [
      "drivers/NetKVM/2k22/amd64/*.cat",
      "drivers/NetKVM/2k22/amd64/*.inf",
      "drivers/NetKVM/2k22/amd64/*.sys",
      "drivers/qxldod/2k22/amd64/*.cat",
      "drivers/qxldod/2k22/amd64/*.inf",
      "drivers/qxldod/2k22/amd64/*.sys",
      "drivers/vioscsi/2k22/amd64/*.cat",
      "drivers/vioscsi/2k22/amd64/*.inf",
      "drivers/vioscsi/2k22/amd64/*.sys",
      "drivers/vioserial/2k22/amd64/*.cat",
      "drivers/vioserial/2k22/amd64/*.inf",
      "drivers/vioserial/2k22/amd64/*.sys",
      "drivers/viostor/2k22/amd64/*.cat",
      "drivers/viostor/2k22/amd64/*.inf",
      "drivers/viostor/2k22/amd64/*.sys",
      "drivers/virtio-win-guest-tools.exe",
      "provision-autounattend.ps1",
      "provision-guest-tools-qemu-kvm.ps1",
      "provision-openssh.ps1",
      "provision-psremoting.ps1",
      "provision-pwsh.ps1",
      "provision-winrm.ps1",
      "windows-2022/autounattend.xml",
    ]
  }
  os             = "win11"
  ssh_username   = "vagrant"
  ssh_password   = "vagrant"
  ssh_timeout    = "60m"
  http_directory = "."
  boot_wait      = "30s"
}

source "virtualbox-iso" "windows-2022-amd64" {
  cpus      = 2
  memory    = 4096
  disk_size = var.disk_size
  floppy_files = [
    "provision-autounattend.ps1",
    "provision-openssh.ps1",
    "provision-psremoting.ps1",
    "provision-pwsh.ps1",
    "provision-winrm.ps1",
    "windows-2022/autounattend.xml",
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
  communicator             = "ssh"
  ssh_username             = "vagrant"
  ssh_password             = "vagrant"
  ssh_timeout              = "4h"
  ssh_file_transfer_method = "sftp"
}

source "hyperv-iso" "windows-2022-amd64" {
  cpus         = 2
  memory       = 4096
  generation   = 2
  boot_wait    = "1s"
  boot_command = ["<up><wait><up><wait><up><wait><up><wait><up><wait><up><wait><up><wait><up><wait><up><wait><up><wait>"]
  boot_order   = ["SCSI:0:0"]
  cd_files = [
    "provision-autounattend.ps1",
    "provision-openssh.ps1",
    "provision-psremoting.ps1",
    "provision-pwsh.ps1",
    "provision-winrm.ps1",
    "windows-2022-uefi/autounattend.xml",
  ]
  disk_size                = var.disk_size
  first_boot_device        = "DVD"
  headless                 = true
  iso_url                  = var.iso_url
  iso_checksum             = var.iso_checksum
  switch_name              = var.hyperv_switch_name
  temp_path                = "tmp"
  vlan_id                  = var.hyperv_vlan_id
  shutdown_command         = "shutdown /s /t 0 /f /d p:4:1 /c \"Packer Shutdown\""
  communicator             = "ssh"
  ssh_username             = "vagrant"
  ssh_password             = "vagrant"
  ssh_timeout              = "4h"
  ssh_file_transfer_method = "sftp"
}

build {
  sources = [
    "source.qemu.windows-2022-amd64",
    "source.proxmox-iso.windows-2022-amd64",
    "source.virtualbox-iso.windows-2022-amd64",
    "source.hyperv-iso.windows-2022-amd64",
  ]

  provisioner "powershell" {
    use_pwsh = true
    script   = "disable-windows-updates.ps1"
  }

  provisioner "powershell" {
    use_pwsh = true
    script   = "disable-windows-defender.ps1"
  }

  provisioner "powershell" {
    use_pwsh = true
    only     = ["virtualbox-iso.windows-2022-amd64"]
    script   = "virtualbox-prevent-vboxsrv-resolution-delay.ps1"
  }

  provisioner "powershell" {
    use_pwsh = true
    only     = ["qemu.windows-2022-amd64"]
    script   = "provision-guest-tools-qemu-kvm.ps1"
  }

  provisioner "windows-restart" {
  }

  provisioner "powershell" {
    use_pwsh = true
    script   = "provision.ps1"
  }

  provisioner "windows-update" {
  }

  provisioner "powershell" {
    use_pwsh = true
    script   = "enable-remote-desktop.ps1"
  }

  provisioner "powershell" {
    use_pwsh = true
    script   = "provision-cloudbase-init.ps1"
  }

  provisioner "powershell" {
    use_pwsh = true
    script   = "eject-media.ps1"
  }

  provisioner "powershell" {
    use_pwsh = true
    script   = "optimize.ps1"
  }

  post-processor "vagrant" {
    except               = ["proxmox-iso.windows-2022-amd64"]
    output               = var.vagrant_box
    vagrantfile_template = "Vagrantfile.template"
  }
}
