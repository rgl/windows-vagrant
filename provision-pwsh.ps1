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

# enable TLS 1.2.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol `
    -bor [Net.SecurityProtocolType]::Tls12

# disable update notifications.
# see https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_update_notifications?view=powershell-7.4
$env:POWERSHELL_UPDATECHECK = 'Off'
[Environment]::SetEnvironmentVariable(
    'POWERSHELL_UPDATECHECK',
    $env:POWERSHELL_UPDATECHECK,
    'Machine')

# install powershell lts.
# see https://github.com/PowerShell/PowerShell/releases
# renovate: datasource=github-releases depName=PowerShell/PowerShell extractVersion=^v(?<version>7\.4\..+)
$archiveVersion = '7.4.13'
$archiveUrl = "https://github.com/PowerShell/PowerShell/releases/download/v$archiveVersion/PowerShell-$archiveVersion-win-x64.msi"
$archiveHash = 'b5c32ec7902748648624f97c70a6d5637d93e9db4f21f9713868d7933e419efb'
$archiveName = Split-Path -Leaf $archiveUrl
$archivePath = "$env:TEMP\$archiveName"

Write-Host "Downloading $archiveUrl..."
(New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
$archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
if ($archiveHash -ne $archiveActualHash) {
    throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash which does not match the expected $archiveHash"
}

Write-Host "Installing $archiveName..."
# see https://learn.microsoft.com/en-us/powershell/scripting/install/microsoft-update-faq?view=powershell-7.4#can-i-enable-these-update-options-from-the-command-line-or-in-a-script
msiexec /i $archivePath `
    /qn `
    /L*v "$archivePath.log" `
    USE_MU=0 `
    ENABLE_MU=0 `
    | Out-String -Stream
if ($LASTEXITCODE) {
    throw "$archiveName installation failed with exit code $LASTEXITCODE. See $archivePath.log."
}
Remove-Item $archivePath
