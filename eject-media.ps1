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
# eject removable volume media.

Write-Host 'Downloaing EjectVolumeMedia...'
$ejectVolumeMediaExeUrl = 'https://github.com/rgl/EjectVolumeMedia/releases/download/v1.0.0/EjectVolumeMedia.exe'
$ejectVolumeMediaExeHash = 'f7863394085e1b3c5aa999808b012fba577b4a027804ea292abf7962e5467ba0'
$ejectVolumeMediaExe = "$env:TEMP\EjectVolumeMedia.exe"
Invoke-WebRequest $ejectVolumeMediaExeUrl -OutFile $ejectVolumeMediaExe
$ejectVolumeMediaExeActualHash = (Get-FileHash $ejectVolumeMediaExe -Algorithm SHA256).Hash
if ($ejectVolumeMediaExeActualHash -ne $ejectVolumeMediaExeHash) {
    throw "the $ejectVolumeMediaExeUrl file hash $ejectVolumeMediaExeActualHash does not match the expected $ejectVolumeMediaExeHash"
}

Get-Volume | Where-Object {$_.DriveType -ne 'Fixed' -and $_.DriveLetter} | ForEach-Object {
    &$ejectVolumeMediaExe $_.DriveLetter
}
