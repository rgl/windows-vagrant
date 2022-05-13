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

$oneDriveSetup = 'C:\Windows\SysWOW64\OneDriveSetup.exe'

# bail when OneDrive is not installed.
if (!(Test-Path $oneDriveSetup)) {
    Exit 0
}

# disable OneDrive.
New-Item `
    -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows' `
    -Name OneDrive `
    -Force `
    | Out-Null
New-ItemProperty `
    -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' `
    -Name DisableFileSyncNGSC `
    -Value 1 `
    -Force `
    | Out-Null

# uninstall OneDrive.
# NB one drive setup will still be WinSxS and it does not seem possible to
#    remove with Remove-WindowsPackage.
Get-Process OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force
&$oneDriveSetup /uninstall | Out-String -Stream

# ignore uninstall error.
# NB because it fails in windows 20H2, and not having OneDrive is just a
#    nice to have.
if ($LASTEXITCODE) {
    Write-Output "WARN Failed to uninstall OneDrive with exit code $LASTEXITCODE."
    Exit 0
}
