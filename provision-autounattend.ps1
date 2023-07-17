# NB this file executed by powershell.
# NB the remaining steps are executed by pwsh.

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

# disable autologon.
Write-Host 'Disabling auto logon...'
$autoLogonKeyPath = 'HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
Set-ItemProperty -Path $autoLogonKeyPath -Name AutoAdminLogon -Value 0
@('DefaultDomainName', 'DefaultUserName', 'DefaultPassword') | ForEach-Object {
    Remove-ItemProperty -Path $autoLogonKeyPath -Name $_ -ErrorAction SilentlyContinue
}

# install pwsh.
$p = Join-Path $PSScriptRoot provision-pwsh.ps1
Write-Host "Executing $p..."
&"$p"
$env:PATH += ";$(Split-Path -Parent (Resolve-Path 'C:\Program Files\PowerShell\*\pwsh.exe'))"

# install the remaining steps using pwsh.
$systemVendor = (Get-CimInstance -ClassName Win32_ComputerSystemProduct -Property Vendor).Vendor
@(
    if ($systemVendor -eq 'QEMU') { 'provision-guest-tools-qemu-kvm' }
    if ($systemVendor -eq 'VMware, Inc.') { 'provision-vmtools' }
    'provision-winrm'
    'provision-psremoting'
    'provision-openssh'
) | ForEach-Object {
    Join-Path $PSScriptRoot "$_.ps1"
} | Where-Object {
    Test-Path $_
} | ForEach-Object {
    Write-Host "Executing $_..."
    # NB for some unknown reason, when the host hypervisor is hyper-v, we cannot
    #    run scripts from the E: drive due to the default RemoteSigned policy.
    #    so, we have to explicitly bypass the execution policy.
    pwsh -ExecutionPolicy Bypass -File $_
    if ($LASTEXITCODE) {
        throw "$_ failed with exit code $LASTEXITCODE"
    }
}

# logoff from the current autologon session.
logoff
