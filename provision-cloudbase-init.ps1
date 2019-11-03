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
$cloudbaseInitPackagePath = "$cloudbaseInitHome\Python\Lib\site-packages\cloudbaseinit"

$artifactUrl = 'https://www.cloudbase.it/downloads/CloudbaseInitSetup_x64.msi'
$artifactPath = "$env:TEMP\$(Split-Path -Leaf $artifactUrl)"
$artifactLogPath = "$artifactPath.log"

$systemVendor = (Get-WmiObject Win32_ComputerSystemProduct Vendor).Vendor
if ($systemVendor -eq 'QEMU') {
    $branch = 'add-no-cloud'
    $metadataServices = 'cloudbaseinit.metadata.services.nocloud.NoCloudConfigDriveService'
} elseif ($systemVendor -eq 'VMware, Inc.') {
    $branch = 'add-vmware-guestinfo-service'
    $metadataServices = 'cloudbaseinit.metadata.services.vmwareguestinfoservice.VMwareGuestInfoService'
} else {
    Write-Host "WARNING: cloudbase-init is not supported on your system vendor $systemVendor"
    Exit 0
}

Write-Host 'Downloading the cloudbase-init setup...'
(New-Object System.Net.WebClient).DownloadFile($artifactUrl, $artifactPath)

Write-Host 'Installing cloudbase-init...'
# NB this also installs the cloudbase-init service, which will automatically start on the next boot.
# see https://github.com/cloudbase/cloudbase-init-installer
msiexec /i $artifactPath /qn /l*v $artifactLogPath | Out-String -Stream
if ($LASTEXITCODE) {
    throw "Failed with Exit Code $LASTEXITCODE"
}

Write-Host "Downloading the rgl/cloudbase-init $branch branch..."
$artifactUrl = "https://github.com/rgl/cloudbase-init/archive/$branch.zip"
$artifactPath = "$env:TEMP\$(Split-Path -Leaf $artifactUrl)"
(New-Object System.Net.WebClient).DownloadFile($artifactUrl, $artifactPath)

Write-Host 'Replacing the cloudbaseinit package with rgl/cloudbase-init...'
Expand-Archive $artifactPath "$artifactPath-extracted"
$cloudbaseInitTmpPackagePath = Resolve-Path "$artifactPath-extracted\*\cloudbaseinit"
Remove-Item -Recurse $cloudbaseInitPackagePath
Copy-Item -Recurse $cloudbaseInitTmpPackagePath $cloudbaseInitPackagePath
Remove-Item -Recurse "$artifactPath-extracted"

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
Set-Content -Encoding ascii $cloudbaseInitConfPath @"
[DEFAULT]
username=vagrant
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
