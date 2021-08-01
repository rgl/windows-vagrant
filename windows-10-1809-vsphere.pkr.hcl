packer {
  required_plugins {
    windows-update = {
      version = "0.14.0"
      source = "github.com/rgl/windows-update"
    }
  }
}

variable "vsphere_disk_size" {
  type    = string
  default = "61440"
}

variable "vsphere_host" {
  type    = string
  default = env("GOVC_HOST")
}

variable "vsphere_username" {
  type    = string
  default = env("GOVC_USERNAME")
}

variable "vsphere_password" {
  type      = string
  default   = env("GOVC_PASSWORD")
  sensitive = true
}

variable "vsphere_esxi_host" {
  type    = string
  default = env("VSPHERE_ESXI_HOST")
}

variable "vsphere_datacenter" {
  type    = string
  default = env("GOVC_DATACENTER")
}

variable "vsphere_cluster" {
  type    = string
  default = env("GOVC_CLUSTER")
}

variable "vsphere_datastore" {
  type    = string
  default = env("GOVC_DATASTORE")
}

variable "vsphere_folder" {
  type    = string
  default = env("VSPHERE_TEMPLATE_FOLDER")
}

variable "vsphere_network" {
  type    = string
  default = env("VSPHERE_VLAN")
}

source "vsphere-iso" "windows-10-1809-amd64" {
  CPUs          = 4
  RAM           = 4096
  guest_os_type = "windows9_64Guest"
  floppy_files = [
    "tmp/windows-10-1809-vsphere/autounattend.xml",
    "vmtools.ps1",
    "winrm.ps1",
    "provision-openssh.ps1",
  ]
  iso_paths = [
    "[${var.vsphere_datastore}] iso/windows-10-1809-17763.107.101029-1455.rs5_release_svc_refresh_CLIENT_LTSC_EVAL_x64FRE_en-us.iso",
    "[${var.vsphere_datastore}] iso/VMware-tools-windows-11.3.0-18090558.iso",
  ]
  network_adapters {
    network      = var.vsphere_network
    network_card = "vmxnet3"
  }
  disk_controller_type = ["pvscsi"]
  storage {
    disk_size             = var.vsphere_disk_size
    disk_thin_provisioned = true
  }
  convert_to_template = false
  insecure_connection = true
  vcenter_server      = var.vsphere_host
  username            = var.vsphere_username
  password            = var.vsphere_password
  host                = var.vsphere_esxi_host
  datacenter          = var.vsphere_datacenter
  cluster             = var.vsphere_cluster
  datastore           = var.vsphere_datastore
  folder              = var.vsphere_folder
  vm_name             = "windows-10-1809-amd64-vsphere"
  shutdown_command    = "shutdown /s /t 0 /f /d p:4:1 /c \"Packer Shutdown\""
  communicator        = "ssh"
  ssh_password        = "vagrant"
  ssh_username        = "vagrant"
  ssh_timeout         = "4h"
}

build {
  sources = ["source.vsphere-iso.windows-10-1809-amd64"]

  provisioner "powershell" {
    script = "disable-windows-updates.ps1"
  }

  provisioner "powershell" {
    inline = ["<# disable Windows Defender #> Set-MpPreference -DisableRealtimeMonitoring $true; Set-ItemProperty -Path 'HKLM:/SOFTWARE/Policies/Microsoft/Windows Defender' -Name DisableAntiSpyware -Value 1"]
  }

  provisioner "powershell" {
    script = "remove-one-drive.ps1"
  }

  provisioner "windows-restart" {
  }

  provisioner "powershell" {
    script = "provision.ps1"
  }

  provisioner "windows-update" {
    filters = [
      "exclude:$_.Title -like '*VMware*'",
      "include:$true"
    ]
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
}
