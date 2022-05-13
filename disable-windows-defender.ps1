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

if (Get-Command -ErrorAction SilentlyContinue Uninstall-WindowsFeature) {
    # for Windows Server.
    Get-WindowsFeature 'Windows-Defender*' | Uninstall-WindowsFeature
} else {
    # for Windows Client.
    Set-MpPreference `
        -DisableRealtimeMonitoring $true `
        -ExclusionPath @('C:\', 'D:\')
    Set-ItemProperty `
        -Path 'HKLM:/SOFTWARE/Policies/Microsoft/Windows Defender' `
        -Name DisableAntiSpyware `
        -Value 1
}
