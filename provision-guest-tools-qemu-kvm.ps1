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

function Get-GuestTool($filename) {
    # try to find it in a drive.
    $path = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
        $p = Join-Path $_.Root $filename
        if (Test-Path $p) {
            $p
        }
    } | Select-Object -First 1
    # otherwise, download it from the packer http server.
    if (!$path) {
        $url = "http://$env:PACKER_HTTP_ADDR/drivers/$filename"
        $path = "$env:TEMP\$filename"
        Write-Host "Downloading $url..."
        Invoke-WebRequest $url -OutFile $path
    }
    return $path
}

# install the guest tools.
$guestTools = Get-GuestTool virtio-win-guest-tools.exe
Write-Host 'Installing the guest tools...'
$guestToolsLog = "$env:TEMP\$(Split-Path -Leaf $guestTools).log"
&$guestTools /install /norestart /quiet /log $guestToolsLog | Out-String -Stream
# NB 3010 exit code means the computer needs to be restarted.
if ($LASTEXITCODE -and $LASTEXITCODE -ne 3010) {
    throw "failed to install guest tools with exit code $LASTEXITCODE"
}
Write-Host "Asserting that the QEMU-GA (QEMU Guest Agent) service exists"
Get-Service QEMU-GA
Write-Host "Done installing the guest tools."

# assert that the spice agent exists.
Write-Host "Asserting that the spice-agent service exists"
Get-Service spice-agent
