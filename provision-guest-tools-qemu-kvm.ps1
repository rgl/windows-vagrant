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

# trust the qemu driver publisher certificate.
# NB this is needed for the qemu-gt silent installation to succeed.
# NB qemu-gt is bundled in virtio-win-guest-tools.exe.
$catPath = 'A:\netkvm.cat'
$cerPath = "$env:TEMP\$(Split-Path -Leaf $catPath)" -replace '\.cat$','.cer'
Write-Host "Getting the qemu driver publisher certificate from $catPath..."
$certificate = (Get-AuthenticodeSignature $catPath).SignerCertificate
Write-Host "Trusting the qemu $($certificate.Subject) driver publisher certificate..."
[System.IO.File]::WriteAllBytes($cerPath, $certificate.Export('Cert'))
Import-Certificate -CertStoreLocation Cert:\LocalMachine\TrustedPublisher $cerPath | Out-Null

$guestToolsUrl = "http://$env:PACKER_HTTP_ADDR/drivers/virtio-win-guest-tools.exe"
$guestTools = "$env:TEMP\$(Split-Path -Leaf $guestToolsUrl)"
$guestToolsLog = "$guestTools.log"
Write-Host "Downloading the guest tools from $guestToolsUrl..."
Invoke-WebRequest $guestToolsUrl -OutFile $guestTools
Write-Host 'Installing the guest tools...'
&$guestTools /install /norestart /quiet /log $guestToolsLog | Out-String -Stream
if ($LASTEXITCODE) {
    throw "failed to install guest tools with exit code $LASTEXITCODE"
}
Write-Host "Done installing the guest tools."
