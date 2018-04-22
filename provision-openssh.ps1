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
# install OpenSSH (for rsync vagrant shared folders from a linux host and for general use on clients of this base box).
# see https://github.com/PowerShell/Win32-OpenSSH/wiki/Install-Win32-OpenSSH
# NB Binaries are in $openSshHome (C:\Program Files\OpenSSH).
# NB Configuration, keys, and logs are in $openSshConfigHome (C:\ProgramData\ssh).

Write-Host 'Installing the PowerShell/Win32-OpenSSH service...'
$openSshHome = 'C:\Program Files\OpenSSH'
$openSshConfigHome = 'C:\ProgramData\ssh'

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Install-ZippedApplication($destinationPath, $name, $url, $expectedHash, $expectedHashAlgorithm='SHA256') {
    $localZipPath = "$env:TEMP\$name.zip"
    Invoke-WebRequest $url -OutFile $localZipPath
    $actualHash = (Get-FileHash $localZipPath -Algorithm $expectedHashAlgorithm).Hash
    if ($actualHash -ne $expectedHash) {
        throw "$name downloaded from $url to $localZipPath has $actualHash hash that does not match the expected $expectedHash"
    }
    [IO.Compression.ZipFile]::ExtractToDirectory($localZipPath, $destinationPath)
    Remove-Item $localZipPath
}
function Install-OpenSshBinaries {
    Install-ZippedApplication `
        $openSshHome `
        OpenSSH `
        https://github.com/PowerShell/Win32-OpenSSH/releases/download/v7.6.1.0p1-Beta/OpenSSH-Win64.zip `
        a8bf470dd399b0a513268d1a8e33a444cefb1a1de539cab42a952d2eda7b17d6
    Push-Location $openSshHome
    Move-Item OpenSSH-Win64\* .
    Remove-Item OpenSSH-Win64
    .\ssh.exe -V
    Pop-Location
}
Install-OpenSshBinaries
mkdir -Force $openSshConfigHome | Out-Null
Copy-Item "$openSshHome\sshd_config_default" "$openSshConfigHome\sshd_config"
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

Write-Host 'Configuring sshd and ssh-agent services to start automatically...' 
'sshd','ssh-agent' | ForEach-Object {
    Set-Service $_ -StartupType Automatic
    sc.exe failure $_ reset= 0 actions= restart/1000
}
sc.exe config sshd depend= ssh-agent

New-NetFirewallRule -Protocol TCP -LocalPort 22 -Direction Inbound -Action Allow -DisplayName SSH | Out-Null

Write-Host 'Installing the default vagrant insecure public key...'
$authorizedKeysPath = "$env:USERPROFILE\.ssh\authorized_keys"
mkdir -Force "$env:USERPROFILE\.ssh" | Out-Null
Invoke-WebRequest `
    'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub' `
    -OutFile $authorizedKeysPath
