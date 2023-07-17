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

# try to find it in a drive.
$guestToolsFilename = 'virtio-win-guest-tools.exe'
$guestTools = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $p = Join-Path $_.Root $guestToolsFilename
    if (Test-Path $p) {
        $p
    }
} | Select-Object -First 1

# otherwise, download it from the packer http server.
if (!$guestTools) {
    $guestToolsUrl = "http://$env:PACKER_HTTP_ADDR/drivers/$guestToolsFilename"
    $guestTools = "$env:TEMP\$guestToolsFilename"
    Write-Host "Downloading the guest tools from $guestToolsUrl..."
    Invoke-WebRequest $guestToolsUrl -OutFile $guestTools
}

Write-Host 'Installing the guest tools...'
$guestToolsLog = "$env:TEMP\$guestToolsFilename.log"
&$guestTools /install /norestart /quiet /log $guestToolsLog | Out-String -Stream
if ($LASTEXITCODE) {
    throw "failed to install guest tools with exit code $LASTEXITCODE"
}
Write-Host "Done installing the guest tools."
