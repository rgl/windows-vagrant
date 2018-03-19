Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
trap {
    #Write-Host
    #Write-Host 'whoami from autounattend:'
    #Get-Content C:\whoami-autounattend.txt | ForEach-Object { Write-Host "whoami from autounattend: $_" }
    #Write-Host 'whoami from current WinRM session:'
    #whoami /all >C:\whoami-winrm.txt
    #Get-Content C:\whoami-winrm.txt | ForEach-Object { Write-Host "whoami from winrm: $_" }
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

if (![Environment]::Is64BitProcess) {
    throw 'this must run in a 64-bit PowerShell session'
}

if (!(New-Object System.Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'this must run with Administrator privileges (e.g. in a elevated shell session)'
}

# install Guest Additions.
$systemVendor = (Get-WmiObject Win32_ComputerSystemProduct Vendor).Vendor
if ($systemVendor -eq 'QEMU') {
    # install qemu-qa.
    $qemuAgentSetupUrl = "http://$env:PACKER_HTTP_ADDR/drivers/guest-agent/qemu-ga-x64.msi"
    $qemuAgentSetup = "$env:TEMP\qemu-ga-x64.msi"
    Write-Host "Downloading the qemu-kvm Guest Agent from $qemuAgentSetupUrl..."
    Invoke-WebRequest $qemuAgentSetupUrl -OutFile $qemuAgentSetup
    Write-Host 'Installing the qemu-kvm Guest Agent...'
    Start-Process $qemuAgentSetup /qn -Wait

    # install spice-vdagent.
    $spiceAgentZipUrl = 'https://www.spice-space.org/download/windows/vdagent/vdagent-win-0.9.0/vdagent-win-0.9.0-x64.zip'
    $spiceAgentZip = "$env:TEMP\vdagent-win-0.9.0-x64.zip"
    $spiceAgentDestination = "C:\Program Files\spice-vdagent"
    Write-Host "Downloading the spice-vdagent from $spiceAgentZipUrl..."
    Invoke-WebRequest $spiceAgentZipUrl -OutFile $spiceAgentZip
    Write-Host 'Installing the spice-vdagent...'
    Add-Type -A System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($spiceAgentZip, $spiceAgentDestination)
    Move-Item "$spiceAgentDestination\vdagent-win-*\*" $spiceAgentDestination
    Get-ChildItem "$spiceAgentDestination\vdagent-win-*" -Recurse | Remove-Item -Force -Recurse
    Remove-Item -Force "$spiceAgentDestination\vdagent-win-*"
    Start-Process "$spiceAgentDestination\vdservice.exe" install -Wait # NB the logs are inside C:\Windows\Temp
    Start-Service vdservice
} elseif ($systemVendor -eq 'innotek GmbH') {
    Write-Host 'Importing the Oracle (for VirtualBox) certificate as a Trusted Publisher...'
    E:\cert\VBoxCertUtil.exe add-trusted-publisher E:\cert\vbox-sha1.cer
    if ($LASTEXITCODE) {
        throw "failed to import certificate with exit code $LASTEXITCODE"
    }
    #Get-ChildItem Cert:\LocalMachine\TrustedPublisher

    Write-Host 'Installing the VirtualBox Guest Additions...'
    $p = Start-Process -Wait -NoNewWindow -PassThru -FilePath E:\VBoxWindowsAdditions-amd64.exe -ArgumentList '/S'
    $p.WaitForExit()
    if ($p.ExitCode) {
        throw "failed to install with exit code $($p.ExitCode). Check the logs at C:\Program Files\Oracle\VirtualBox Guest Additions\install.log."
    }

    Write-Host 'Ejecting the VirtualBox Guest Additions media...'
    $ejectVolumeMediaExeUrl = 'https://github.com/rgl/EjectVolumeMedia/releases/download/v1.0.0/EjectVolumeMedia.exe'
    $ejectVolumeMediaExeHash = 'f7863394085e1b3c5aa999808b012fba577b4a027804ea292abf7962e5467ba0'
    $ejectVolumeMediaExe = "$env:TEMP\EjectVolumeMedia.exe"
    Invoke-WebRequest $ejectVolumeMediaExeUrl -OutFile $ejectVolumeMediaExe
    $ejectVolumeMediaExeActualHash = (Get-FileHash $ejectVolumeMediaExe -Algorithm SHA256).Hash
    if ($ejectVolumeMediaExeActualHash -ne $ejectVolumeMediaExeHash) {
        throw "the $ejectVolumeMediaExeUrl file hash $ejectVolumeMediaExeActualHash does not match the expected $ejectVolumeMediaExeHash"
    }
    &$ejectVolumeMediaExe E
} else {
    throw "Cannot install Guest Additions: Unsupported system ($systemVendor)."
}

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
        https://github.com/PowerShell/Win32-OpenSSH/releases/download/v7.6.0.0p1-Beta/OpenSSH-Win64.zip `
        585d28ce1aa2935c8cd5570413b9214e6c80c41bda6ba6b1b206dbe63d7d2e76
    Push-Location $openSshHome
    Move-Item OpenSSH-Win64\* .
    Remove-Item OpenSSH-Win64
    Pop-Location
}
Install-OpenSshBinaries
&"$openSshHome\install-sshd.ps1"
&"$openSshHome\ssh-keygen.exe" -A
if ($LASTEXITCODE) {
    throw "Failed to run ssh-keygen with exit code $LASTEXITCODE"
}
Set-Content `
    -Encoding Ascii `
    "$openSshConfigHome\sshd_config" `
    ( `
        (Get-Content "$openSshConfigHome\sshd_config") `
            -replace '#?\s*UseDNS .+','UseDNS no' `
    )
&"$openSshHome\FixHostFilePermissions.ps1" -Confirm:$false
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

Write-Host 'Setting the vagrant account properties...'
# see the ADS_USER_FLAG_ENUM enumeration at https://msdn.microsoft.com/en-us/library/aa772300(v=vs.85).aspx
$AdsScript              = 0x00001
$AdsAccountDisable      = 0x00002
$AdsNormalAccount       = 0x00200
$AdsDontExpirePassword  = 0x10000
$account = [ADSI]'WinNT://./vagrant'
$account.Userflags = $AdsNormalAccount -bor $AdsDontExpirePassword
$account.SetInfo()

Write-Host 'Setting the Administrator account properties...'
$account = [ADSI]'WinNT://./Administrator'
$account.Userflags = $AdsNormalAccount -bor $AdsDontExpirePassword -bor $AdsAccountDisable
$account.SetInfo()

Write-Host 'Disabling auto logon...'
Set-ItemProperty -Path 'HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name AutoAdminLogon -Value 0

Write-Host 'Disabling hibernation...'
powercfg /hibernate off

Write-Host 'Setting the power plan to high performance...'
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

# remove temporary files.
'C:\tmp','C:\Windows\Temp',$env:TEMP | ForEach-Object {
    Get-ChildItem $_ -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
}
