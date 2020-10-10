Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
trap {
    Write-Host
    Write-Host "ERROR: $_"
    Write-Host (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Host (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Write-Host
    Write-Host 'Sleeping for 60m to give you time to look around the virtual machine before self-destruction...'
    Start-Sleep -Seconds (60*60)
    Exit 1
}

# enable TLS 1.1 and 1.2.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol `
    -bor [Net.SecurityProtocolType]::Tls11 `
    -bor [Net.SecurityProtocolType]::Tls12

$cloudbaseInitHome = 'C:\Program Files\Cloudbase Solutions\Cloudbase-Init'
$cloudbaseInitConfPath = "$cloudbaseInitHome\conf\cloudbase-init.conf"

$artifactUrl = 'https://github.com/cloudbase/cloudbase-init/releases/download/1.1.2/CloudbaseInitSetup_1_1_2_x64.msi'
$artifactPath = "$env:TEMP\$(Split-Path -Leaf $artifactUrl)"
$artifactLogPath = "$artifactPath.log"

$systemVendor = (Get-WmiObject Win32_ComputerSystemProduct Vendor).Vendor
if ($systemVendor -eq 'QEMU') {
    # qemu-kvm.
    $metadataServices = 'cloudbaseinit.metadata.services.nocloudservice.NoCloudConfigDriveService'
} elseif ($systemVendor -eq 'Microsoft Corporation') {
    # Hyper-V.
    $metadataServices = 'cloudbaseinit.metadata.services.nocloudservice.NoCloudConfigDriveService'
} elseif ($systemVendor -eq 'innotek GmbH') {
    # VirtualBox.
    $metadataServices = 'cloudbaseinit.metadata.services.nocloudservice.NoCloudConfigDriveService'
} elseif ($systemVendor -eq 'VMware, Inc.') {
    # VMware ESXi.
    $metadataServices = 'cloudbaseinit.metadata.services.vmwareguestinfoservice.VMwareGuestInfoService'
} else {
    Write-Host "WARNING: cloudbase-init is not supported on your system vendor $systemVendor"
    Exit 0
}

# NB we might have to retry the download due to errors:
#       The underlying connection was closed: Could not establish trust relationship for the SSL/TLS secure channel
while ($true) {
    try {
        Write-Host 'Downloading the cloudbase-init setup...'
        (New-Object System.Net.WebClient).DownloadFile($artifactUrl, $artifactPath)
        break
    } catch {
        Write-Host "Failed to download the cloudbase-init setup. Trying in a bit due to error $_"
        Start-Sleep -Seconds 5
    }
}

Write-Host 'Installing cloudbase-init...'
# NB this also installs the cloudbase-init service, which will automatically start on the next boot.
# see https://github.com/cloudbase/cloudbase-init-installer
msiexec /i $artifactPath /qn /l*v $artifactLogPath | Out-String -Stream
if ($LASTEXITCODE) {
    throw "Failed with Exit Code $LASTEXITCODE"
}

Write-Host 'Replacing the configuration...'
# The default configuration is:
#   [DEFAULT]
#   username=Admin
#   groups=Administrators
#   inject_user_password=true
#   config_drive_raw_hhd=true
#   config_drive_cdrom=true
#   config_drive_vfat=true
#   bsdtar_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\bsdtar.exe
#   mtools_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\
#   verbose=true
#   debug=true
#   logdir=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\
#   logfile=cloudbase-init.log
#   default_log_levels=comtypes=INFO,suds=INFO,iso8601=WARN,requests=WARN
#   logging_serial_port_settings=
#   mtu_use_dhcp_config=true
#   ntp_use_dhcp_config=true
#   local_scripts_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts\
# see https://cloudbase-init.readthedocs.io/en/latest/tutorial.html#configuration-file
# see https://cloudbase-init.readthedocs.io/en/latest/config.html#config-list
Move-Item $cloudbaseInitConfPath "$cloudbaseInitConfPath.orig"
Set-Content -Encoding ascii $cloudbaseInitConfPath @"
[DEFAULT]
username=Administrator
groups=Administrators
first_logon_behaviour=no
debug=true
log_dir=$cloudbaseInitHome\log
log_file=cloudbase-init.log
bsdtar_path=$cloudbaseInitHome\bin\bsdtar.exe
mtools_path=$cloudbaseInitHome\bin\
metadata_services=$metadataServices

[config_drive]
locations=cdrom
types=iso
"@
