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
if ($LASTEXITCODE) {
    throw "failed to install guest tools with exit code $LASTEXITCODE"
}
Write-Host "Asserting that the QEMU-GA (QEMU Guest Agent) service exists"
Get-Service QEMU-GA
Write-Host "Done installing the guest tools."

# install the spice guest tools.
Write-Host "Trusting the spice guest tools code sign certificate..."
$spiceGuestToolsCodeSignPath = "$env:TEMP\spice-guest-tools-redhat-code-sign.cer"
Set-Content -Encoding ascii -Path $spiceGuestToolsCodeSignPath -Value @'
-----BEGIN CERTIFICATE-----
MIIFBjCCA+6gAwIBAgIQVsbSZ63gf3LutGA7v4TOpTANBgkqhkiG9w0BAQUFADCB
tDELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQL
ExZWZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTswOQYDVQQLEzJUZXJtcyBvZiB1c2Ug
YXQgaHR0cHM6Ly93d3cudmVyaXNpZ24uY29tL3JwYSAoYykxMDEuMCwGA1UEAxMl
VmVyaVNpZ24gQ2xhc3MgMyBDb2RlIFNpZ25pbmcgMjAxMCBDQTAeFw0xNjAzMTgw
MDAwMDBaFw0xODEyMjkyMzU5NTlaMGgxCzAJBgNVBAYTAlVTMRcwFQYDVQQIEw5O
b3J0aCBDYXJvbGluYTEQMA4GA1UEBxMHUmFsZWlnaDEWMBQGA1UEChQNUmVkIEhh
dCwgSW5jLjEWMBQGA1UEAxQNUmVkIEhhdCwgSW5jLjCCASIwDQYJKoZIhvcNAQEB
BQADggEPADCCAQoCggEBAMA3SYpIcNIEzqqy1PNimjt3bVY1KuIuvDABkx8hKUG6
rl9WDZ7ibcW6f3cKgr1bKOAeOsMSDu6i/FzB7Csd9u/a/YkASAIIw48q9iD4K6lb
Kvd+26eJCUVyLHcWlzVkqIEFcvCrvaqaU/YlX/antLWyHGbtOtSdN3FfY5pvvTbW
xf8PJBWGO3nV9CVL1DMK3wSn3bRNbkTLttdIUYdgiX+q8QjbM/VyGz7nA9UvGO0n
FWTZRdoiKWI7HA0Wm7TjW3GSxwDgoFb2BZYDDNSlfzQpZmvnKth/fQzNDwumhDw7
tVicu/Y8E7BLhGwxFEaP0xZtENTpn+1f0TxPxpzL2zMCAwEAAaOCAV0wggFZMAkG
A1UdEwQCMAAwDgYDVR0PAQH/BAQDAgeAMCsGA1UdHwQkMCIwIKAeoByGGmh0dHA6
Ly9zZi5zeW1jYi5jb20vc2YuY3JsMGEGA1UdIARaMFgwVgYGZ4EMAQQBMEwwIwYI
KwYBBQUHAgEWF2h0dHBzOi8vZC5zeW1jYi5jb20vY3BzMCUGCCsGAQUFBwICMBkM
F2h0dHBzOi8vZC5zeW1jYi5jb20vcnBhMBMGA1UdJQQMMAoGCCsGAQUFBwMDMFcG
CCsGAQUFBwEBBEswSTAfBggrBgEFBQcwAYYTaHR0cDovL3NmLnN5bWNkLmNvbTAm
BggrBgEFBQcwAoYaaHR0cDovL3NmLnN5bWNiLmNvbS9zZi5jcnQwHwYDVR0jBBgw
FoAUz5mp6nsm9EvJjo/X8AUm7+PSp50wHQYDVR0OBBYEFL/39F5yNDVDib3B3Uk3
I8XJSrxaMA0GCSqGSIb3DQEBBQUAA4IBAQDWtaW0Dar82t1AdSalPEXshygnvh87
Rce6PnM2/6j/ijo2DqwdlJBNjIOU4kxTFp8jEq8oM5Td48p03eCNsE23xrZl5qim
xguIfHqeiBaLeQmxZavTHPNM667lQWPAfTGXHJb3RTT4siowcmGhxwJ3NGP0gNKC
PHW09x3CdMNCIBfYw07cc6h9+Vm2Ysm9MhqnVhvROj+AahuhvfT9K0MJd3IcEpjX
Z7aMX78Vt9/vrAIUR8EJ54YGgQsF/G9Adzs6fsfEw5Nrk8R0pueRMHRTMSroTe0V
Ae2nvuUU6rVI30q8+UjQCxu/ji1/JnitNkUyOPyC46zL+kfHYSnld8U1
-----END CERTIFICATE-----
'@
# NB we cannot use the following Import-Certificate in windows 11, as,
#    sometimes, it fails with an access denied error. instead, directly
#    call into the certificate store.
#       Import-Certificate `
#           -FilePath $spiceGuestToolsCodeSignPath `
#           -CertStoreLocation Cert:\LocalMachine\TrustedPublisher `
#           | Out-Null
$certificateStore = Get-Item Cert:\LocalMachine\TrustedPublisher
$certificateStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]"ReadWrite")
$certificateStore.Add($spiceGuestToolsCodeSignPath)
$certificateStore.Close()
$spiceGuestTools = Get-GuestTool spice-guest-tools.exe
Write-Host 'Installing the spice guest tools...'
&$spiceGuestTools /S | Out-String -Stream
if ($LASTEXITCODE) {
    throw "failed to install spice guest tools with exit code $LASTEXITCODE"
}
Write-Host "Asserting that the vdservice (SPICE Agent) service exists"
Get-Service vdservice
Write-Host "Done installing the spice guest tools."
