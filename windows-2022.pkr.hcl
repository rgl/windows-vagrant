packer {
  required_plugins {
    # see https://github.com/hashicorp/packer-plugin-qemu
    qemu = {
      version = "1.1.4"
      source  = "github.com/hashicorp/qemu"
    }
    # see https://github.com/hashicorp/packer-plugin-proxmox
    proxmox = {
      version = "1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
    # see https://github.com/hashicorp/packer-plugin-vagrant
    vagrant = {
      version = "1.1.6"
      source  = "github.com/hashicorp/vagrant"
    }
    # see https://github.com/hashicorp/packer-plugin-hyperv
    hyperv = {
      version = "1.1.5"
      source  = "github.com/hashicorp/hyperv"
    }
    # see https://github.com/rgl/packer-plugin-windows-update
    windows-update = {
      version = "0.17.1"
      source  = "github.com/rgl/windows-update"
    }
  }
}

variable "http_bind_address" {
  type    = string
  default = env("PACKER_HTTP_BIND_ADDRESS")
}

variable "disk_size" {
  type    = string
  default = "61440"
}

variable "iso_url" {
  type    = string
  default = env("WINDOWS_2022_ISO_URL")
}

variable "iso_checksum" {
  type    = string
  default = env("WINDOWS_2022_ISO_CHECKSUM")
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
  cd_label       = "PROVISION"
  cd_files = [
    "drivers/NetKVM/2k22/amd64/*.cat",
    "drivers/NetKVM/2k22/amd64/*.inf",
    "drivers/NetKVM/2k22/amd64/*.sys",
    "drivers/NetKVM/2k22/amd64/*.exe",
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
    "tmp/windows-2022/autounattend.xml",
  ]
  format                   = "qcow2"
  headless                 = true
  net_device               = "virtio-net"
  http_bind_address        = var.http_bind_address
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
  template_description     = <<-EOS
                              See https://github.com/rgl/windows-vagrant

                              ```
                              Build At: ${timestamp()}
                              ```
                              EOS
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
    format       = "raw"
  }
  boot_iso {
    type             = "ide"
    iso_storage_pool = "local"
    iso_url          = var.iso_url
    iso_checksum     = var.iso_checksum
    iso_download_pve = true
    unmount          = true
  }
  additional_iso_files {
    type             = "ide"
    unmount          = true
    iso_storage_pool = "local"
    cd_label         = "PROVISION"
    cd_files = [
      "drivers/NetKVM/2k22/amd64/*.cat",
      "drivers/NetKVM/2k22/amd64/*.inf",
      "drivers/NetKVM/2k22/amd64/*.sys",
      "drivers/NetKVM/2k22/amd64/*.exe",
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
      "tmp/windows-2022/autounattend.xml",
    ]
  }
  os                = "win11"
  ssh_username      = "vagrant"
  ssh_password      = "vagrant"
  ssh_timeout       = "60m"
  http_bind_address = var.http_bind_address
  http_directory    = "."
  boot_wait         = "30s"
}

source "hyperv-iso" "windows-2022-amd64" {
  cpus         = 2
  memory       = 4096
  generation   = 2
  boot_wait    = "1s"
  boot_command = ["<up><wait><up><wait><up><wait><up><wait><up><wait><up><wait><up><wait><up><wait><up><wait><up><wait>"]
  boot_order   = ["SCSI:0:0"]
  cd_label     = "PROVISION"
  cd_files = [
    "provision-autounattend.ps1",
    "provision-openssh.ps1",
    "provision-psremoting.ps1",
    "provision-pwsh.ps1",
    "provision-winrm.ps1",
    "tmp/windows-2022-uefi/autounattend.xml",
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
    script   = "optimize-cleanup-image.ps1"
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
    script   = "provision-lock-screen-background.ps1"
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
