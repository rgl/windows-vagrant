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
} else {
    throw "Cannot install Guest Additions: Unsupported system ($systemVendor)."
}

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
