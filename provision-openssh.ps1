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


#
# enable TLS 1.1 and 1.2.

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol `
    -bor [Net.SecurityProtocolType]::Tls11 `
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
        https://github.com/rgl/rsync-vagrant/releases/download/v3.1.3/rsync-vagrant-3.1.3.zip `
        aa03c06ac12cbb4c2c5667d735cbf9a672f2f732f4f750c97164751d72448de2
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
        https://github.com/PowerShell/Win32-OpenSSH/releases/download/v8.1.0.0p1-Beta/OpenSSH-Win64.zip `
        c99240af89452610f66b7ce54c4fa3180b66aae2bc326afc2aac8fc1dd48f488
    Push-Location $openSshHome
    Move-Item OpenSSH-Win64\* .
    Remove-Item OpenSSH-Win64
    .\ssh.exe -V
    Pop-Location
}
Write-Host 'Installing rsync...'
Install-Rsync
Write-Host 'Installing the PowerShell/Win32-OpenSSH service...'
Install-OpenSshBinaries
mkdir -Force $openSshConfigHome | Out-Null
$originalSshdConfig = Get-Content -Raw "$openSshHome\sshd_config_default"
# Configure the Administrators group to also use the ~/.ssh/authorized_keys file.
# see https://github.com/PowerShell/Win32-OpenSSH/issues/1324
$sshdConfig = $originalSshdConfig `
    -replace '(?m)^(Match Group administrators.*)','#$1' `
    -replace '(?m)^(\s*AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys.*)','#$1'
Set-Content -Encoding ascii "$openSshConfigHome\sshd_config" $sshdConfig
&"$openSshHome\install-sshd.ps1"

Write-Host 'Generating the host SSH keys...' 
&"$openSshHome\ssh-keygen.exe" -A
if ($LASTEXITCODE) {
    throw "Failed to run ssh-keygen with exit code $LASTEXITCODE"
}

Write-Host 'Configuring sshd...' 
Set-Content `
    -Encoding Ascii `
    "$openSshConfigHome\sshd_config" `
    ( `
        (Get-Content "$openSshConfigHome\sshd_config") `
            -replace '#?\s*UseDNS .+','UseDNS no' `
    )

Write-Host 'Setting the host file permissions...' 
&"$openSshHome\FixHostFilePermissions.ps1" -Confirm:$false

Write-Host 'Configuring sshd and ssh-agent services...' 
Set-Service 'sshd' -StartupType Automatic
sc.exe failure 'sshd' reset= 0 actions= restart/1000
sc.exe failure 'ssh-agent' reset= 0 actions= restart/1000

New-NetFirewallRule -Protocol TCP -LocalPort 22 -Direction Inbound -Action Allow -DisplayName SSH | Out-Null

Write-Host 'Installing the default vagrant insecure public key...'
$authorizedKeysPath = "$env:USERPROFILE\.ssh\authorized_keys"
mkdir -Force "$env:USERPROFILE\.ssh" | Out-Null
(New-Object System.Net.WebClient).DownloadFile(
    'https://raw.github.com/hashicorp/vagrant/master/keys/vagrant.pub',
    $authorizedKeysPath)
