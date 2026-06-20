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

$guestServicesServiceName = 'eryph-guest-services'
$guestServicesHome = 'C:\Program Files\eryph\guest-services'

# see https://github.com/eryph-org/guest-services/releases
# renovate: datasource=github-releases depName=eryph-org/guest-services
$guestServicesVersion = '0.5.0'

$artifactUrl = "https://releases.dbosoft.eu/eryph/guest-services/$guestServicesVersion/egs_${guestServicesVersion}_windows_amd64.zip"
$artifactPath = "$env:TEMP\$(Split-Path -Leaf $artifactUrl)"

$systemVendor = (Get-CimInstance -ClassName Win32_ComputerSystemProduct -Property Vendor).Vendor
if ($systemVendor -ne 'Microsoft Corporation') {
    Write-Host "WARNING: $guestServicesServiceName is not supported on your system vendor $systemVendor"
    Exit 0
}

# NB we might have to retry the download due to errors:
#       The underlying connection was closed: Could not establish trust relationship for the SSL/TLS secure channel
while ($true) {
    try {
        Write-Host "Downloading the $guestServicesServiceName setup..."
        (New-Object System.Net.WebClient).DownloadFile($artifactUrl, $artifactPath)
        break
    } catch {
        Write-Host "Failed to download the $guestServicesServiceName setup. Trying in a bit due to error $_"
        Start-Sleep -Seconds 5
    }
}

Write-Host "Installing the $guestServicesServiceName binaries..."
Expand-Archive -Path $artifactPath -DestinationPath $guestServicesHome

Write-Host "Installing the $guestServicesServiceName service..."
New-Service `
    -Name $guestServicesServiceName `
    -BinaryPathName "$guestServicesHome\bin\egs-service.exe" `
    -StartupType Automatic `
    | Out-Null
$result = sc.exe failure $guestServicesServiceName reset= 60 actions= restart/10000
if ($result -ne '[SC] ChangeServiceConfig2 SUCCESS') {
    throw "sc.exe failure sshd failed with $result"
}
Start-Service $guestServicesServiceName
