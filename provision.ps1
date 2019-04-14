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

Add-Type -A System.IO.Compression.FileSystem

# install Guest Additions.
$systemVendor = (Get-WmiObject Win32_ComputerSystemProduct Vendor).Vendor
if ($systemVendor -eq 'QEMU') {
    # install drivers.
    if (Test-Path 'C:\Windows\Temp\virtio\virtio.zip') {
        function Install-Driver($path) {
            # trust the driver certificate.
            $catPath = $path.Replace('.inf', '.cat')
            $cerPath = $path.Replace('.inf', '.cer')
            $certificate = (Get-AuthenticodeSignature $catPath).SignerCertificate
            [System.IO.File]::WriteAllBytes($cerPath, $certificate.Export('Cert'))
            Import-Certificate -CertStoreLocation Cert:\LocalMachine\TrustedPublisher $cerPath | Out-Null

            # install the driver.
            pnputil -i -a $path
            if ($LASTEXITCODE) {
                throw "Failed with exit code $LASTEXITCODE"
            }
        }

        [IO.Compression.ZipFile]::ExtractToDirectory('C:\Windows\Temp\virtio\virtio.zip', 'C:\Windows\Temp\virtio')
        $virtioDestinationDirectory = "$env:ProgramFiles\virtio"
        Get-ChildItem -Recurse -File C:\Windows\Temp\virtio\drivers.tmp | ForEach-Object {
            $driverName = $_.Directory.Parent.Parent.Name
            $driverSourceDirectory = $_.Directory
            $driverDestinationDirectory = "$virtioDestinationDirectory\$driverName"
            if (Test-Path $driverDestinationDirectory) {
                return
            }
            Write-Host "Installing the $driverName driver..."
            mkdir -Force $driverDestinationDirectory | Out-Null
            Copy-Item "$driverSourceDirectory\*" $driverDestinationDirectory
            Install-Driver (Resolve-Path "$driverDestinationDirectory\*.inf").Path
        }

        Write-Host 'Installing the Balloon service...'
        &"$virtioDestinationDirectory\Balloon\blnsvr.exe" -i
    }

    # install qemu-ga.
    $qemuAgentSetupUrl = "http://$env:PACKER_HTTP_ADDR/drivers/guest-agent/qemu-ga-x86_64.msi"
    $qemuAgentSetup = "$env:TEMP\qemu-ga-x86_64.msi"
    Write-Host "Downloading the qemu-kvm Guest Agent from $qemuAgentSetupUrl..."
    Invoke-WebRequest $qemuAgentSetupUrl -OutFile $qemuAgentSetup
    Write-Host 'Installing the qemu-kvm Guest Agent...'
    msiexec.exe /i $qemuAgentSetup /qn | Out-String -Stream

    # install spice-vdagent.
    $spiceAgentZipUrl = 'https://www.spice-space.org/download/windows/vdagent/vdagent-win-0.9.0/vdagent-win-0.9.0-x64.zip'
    $spiceAgentZip = "$env:TEMP\vdagent-win-0.9.0-x64.zip"
    $spiceAgentDestination = "C:\Program Files\spice-vdagent"
    Write-Host "Downloading the spice-vdagent from $spiceAgentZipUrl..."
    Invoke-WebRequest $spiceAgentZipUrl -OutFile $spiceAgentZip
    Write-Host 'Installing the spice-vdagent...'
    [IO.Compression.ZipFile]::ExtractToDirectory($spiceAgentZip, $spiceAgentDestination)
    Move-Item "$spiceAgentDestination\vdagent-win-*\*" $spiceAgentDestination
    Get-ChildItem "$spiceAgentDestination\vdagent-win-*" -Recurse | Remove-Item -Force -Recurse
    Remove-Item -Force "$spiceAgentDestination\vdagent-win-*"
    &"$spiceAgentDestination\vdservice.exe" install | Out-String -Stream # NB the logs are inside C:\Windows\Temp
    Start-Service vdservice
} elseif ($systemVendor -eq 'innotek GmbH') {
    Write-Host 'Importing the Oracle (for VirtualBox) certificate as a Trusted Publisher...'
    E:\cert\VBoxCertUtil.exe add-trusted-publisher E:\cert\vbox-sha1.cer
    if ($LASTEXITCODE) {
        throw "failed to import certificate with exit code $LASTEXITCODE"
    }

    Write-Host 'Installing the VirtualBox Guest Additions...'
    E:\VBoxWindowsAdditions-amd64.exe /S | Out-String -Stream
    if ($LASTEXITCODE) {
        throw "failed to install with exit code $LASTEXITCODE. Check the logs at C:\Program Files\Oracle\VirtualBox Guest Additions\install.log."
    }
} elseif ($systemVendor -eq 'VMware, Inc.') {
    # do nothing. VMware Tools were already installed by vmtools.ps1 (executed from autounattend.xml).
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
$autoLogonKeyPath = 'HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty -Path $autoLogonKeyPath -Name AutoAdminLogon -Value 0
@('DefaultDomainName', 'DefaultUserName', 'DefaultPassword') | ForEach-Object {
    Remove-ItemProperty -Path $autoLogonKeyPath -Name $_ -ErrorAction SilentlyContinue
}

Write-Host 'Disabling Automatic Private IP Addressing (APIPA)...'
Set-ItemProperty `
    -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' `
    -Name IPAutoconfigurationEnabled `
    -Value 0

Write-Host 'Disabling IPv6...'
Set-ItemProperty `
    -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' `
    -Name DisabledComponents `
    -Value 0xff

Write-Host 'Disabling hibernation...'
powercfg /hibernate off

Write-Host 'Setting the power plan to high performance...'
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c

Write-Host 'Disabling the Windows Boot Manager menu...'
# NB to have the menu show with a lower timeout, run this instead: bcdedit /timeout 2
#    NB with a timeout of 2 you can still press F8 to show the boot manager menu.
bcdedit /set '{bootmgr}' displaybootmenu no

# remove temporary files.
'C:\tmp','C:\Windows\Temp',$env:TEMP | ForEach-Object {
    Get-ChildItem $_ -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
}
