Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
trap {
    Write-Host
    Write-Host "ERROR: $_"
    ($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1' | Write-Host
    ($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1' | Write-Host
    Write-Host
    Write-Host 'Sleeping for 60m to give you time to look around the virtual machine before self-destruction...'
    Start-Sleep -Seconds (60*60)
    Exit 1
}


#
# enable TLS 1.2.

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol `
    -bor [Net.SecurityProtocolType]::Tls12

#
# install rsync (for rsync vagrant shared folders from a linux host and for general use on clients of this base box) and OpenSSH.
# see https://github.com/PowerShell/Win32-OpenSSH/wiki/Install-Win32-OpenSSH
# NB Binaries are in $openSshHome (C:\Program Files\OpenSSH).
# NB Configuration, keys, and logs are in $openSshConfigHome (C:\ProgramData\ssh).

$rsyncHome = 'C:\Program Files\rsync'
$openSshHome = 'C:\Program Files\OpenSSH'
$openSshConfigHome = 'C:\ProgramData\ssh'

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Install-ZippedApplication($destinationPath, $name, $url, $expectedHash, $expectedHashAlgorithm='SHA256') {
    $localZipPath = "$env:TEMP\$name.zip"
    (New-Object System.Net.WebClient).DownloadFile($url, $localZipPath)
    $actualHash = (Get-FileHash $localZipPath -Algorithm $expectedHashAlgorithm).Hash
    if ($actualHash -ne $expectedHash) {
        throw "$name downloaded from $url to $localZipPath has $actualHash hash that does not match the expected $expectedHash"
    }
    [IO.Compression.ZipFile]::ExtractToDirectory($localZipPath, $destinationPath)
    Remove-Item $localZipPath
}
function Install-Rsync {
    Install-ZippedApplication `
        $rsyncHome `
        rsync `
        https://github.com/rgl/rsync-vagrant/releases/download/v3.2.7-20230305/rsync-vagrant-3.2.7-20230305.zip `
        c0e5a5e48c0cc32c137b1dca8845cc780b570fdeca1e266cf79d1a7f4a0cf793
    [Environment]::SetEnvironmentVariable(
        'PATH',
        "$([Environment]::GetEnvironmentVariable('PATH', 'Machine'));$rsyncHome",
        'Machine')
    &"$rsyncHome\rsync.exe" --version
}
function Install-OpenSshBinaries {
    Install-ZippedApplication `
        $openSshHome `
        OpenSSH `
        https://github.com/PowerShell/Win32-OpenSSH/releases/download/v9.4.0.0p1-Beta/OpenSSH-Win64.zip `
        580231dc77c96acdbc84f3c99e5c780cd0d8a06a6edfe6fecfe3d07664159a78
    Push-Location $openSshHome
    Move-Item OpenSSH-Win64\* .
    Remove-Item OpenSSH-Win64
    .\ssh.exe -V
    Pop-Location
}
Write-Host 'Installing rsync...'
Install-Rsync
# uninstall the Windows provided OpenSSH binaries.
$windowsOpenSshCapabilities = Get-WindowsCapability -Online -Name 'OpenSSH.*' | Where-Object {$_.State -ne 'NotPresent'}
if ($windowsOpenSshCapabilities) {
    Write-Host 'Uninstalling the Windows OpenSSH Capabilities...'
    $windowsOpenSshCapabilities | Remove-WindowsCapability -Online | Out-Null
}
Write-Host 'Installing the PowerShell/Win32-OpenSSH service...'
Install-OpenSshBinaries
# add the OpenSSH binaries to the system PATH.
[Environment]::SetEnvironmentVariable(
    'PATH',
    "$([Environment]::GetEnvironmentVariable('PATH', 'Machine'));$openSshHome",
    'Machine')
# remove any existing configuration.
if (Test-Path $openSshConfigHome) {
    Remove-Item -Recurse -Force $openSshConfigHome
}
# install the service.
&"$openSshHome\install-sshd.ps1" -Confirm:$false
# start the service (it will create the default configuration and host keys).
Start-Service sshd
Stop-Service sshd
# modify the configuration.
$sshdConfig = Get-Content -Raw "$openSshHome\sshd_config_default"
# Configure the Administrators group to also use the ~/.ssh/authorized_keys file.
# see https://github.com/PowerShell/Win32-OpenSSH/issues/1324
$sshdConfig = $sshdConfig `
    -replace '(?m)^(Match Group administrators.*)','#$1' `
    -replace '(?m)^(\s*AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys.*)','#$1'
# Disable UseDNS.
$sshdConfig = $sshdConfig `
    -replace '(?m)^#?\s*UseDNS .+','UseDNS no'
# Configure the powershell ssh subsystem (for powershell remoting over ssh).
# see https://docs.microsoft.com/en-us/powershell/scripting/learn/remoting/ssh-remoting-in-powershell-core?view=powershell-7.2
$sshdConfig = $sshdConfig `
    -replace '(?m)^(Subsystem\s+sftp\s+.+)',"`$1`nSubsystem`tpowershell`tC:/Progra~1/PowerShell/7/pwsh.exe -nol -sshs"
Set-Content -Encoding ascii "$openSshConfigHome\sshd_config" $sshdConfig

Write-Host 'Setting the host file permissions...'
&"$openSshHome\FixHostFilePermissions.ps1" -Confirm:$false

Write-Host 'Configuring sshd and ssh-agent services...'
# make sure the service startup type is delayed-auto.
# WARN do not be tempted to change the service startup type from
#      delayed-auto to auto, as the later proved to be unreliable.
$result = sc.exe config sshd start= delayed-auto
if ($result -ne '[SC] ChangeServiceConfig SUCCESS') {
    throw "sc.exe config sshd failed with $result"
}
$result = sc.exe failure sshd reset= 0 actions= restart/60000
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe failure sshd failed with $result"
}
$result = sc.exe failure ssh-agent reset= 0 actions= restart/60000
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe failure ssh-agent failed with $result"
}

Write-Host 'Installing the default vagrant insecure public key...'
$authorizedKeysPath = "$env:USERPROFILE\.ssh\authorized_keys"
mkdir -Force "$env:USERPROFILE\.ssh" | Out-Null
(New-Object System.Net.WebClient).DownloadFile(
    'https://raw.github.com/hashicorp/vagrant/master/keys/vagrant.pub',
    $authorizedKeysPath)

Write-Host 'Starting the sshd service...'
Start-Service sshd

Write-Host 'Allow firewall access to the sshd service port...'
New-NetFirewallRule -Protocol TCP -LocalPort 22 -Direction Inbound -Action Allow -DisplayName SSH | Out-Null
