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
# download PowerShell / Windows Management Framework 5.1.

$artifactUrl = 'https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win8.1AndW2K12R2-KB3191564-x64.msu'
$artifactChecksum = 'a8d788fa31b02a999cc676fb546fc782e86c2a0acd837976122a1891ceee42c0'
$artifactPath = "$env:TEMP\$(Split-Path -Leaf $artifactUrl)"
(New-Object System.Net.WebClient).DownloadFile($artifactUrl, $artifactPath)
$actualChecksum = (Get-FileHash $artifactPath -Algorithm SHA256).Hash
if ($actualChecksum -ne $artifactChecksum) {
    throw "$(Split-Path -Leaf $artifactUrl) downloaded from $artifactUrl to $artifactPath has $actualChecksum checksum that does not match the expected $artifactChecksum"
}


#
# install PowerShell.
# NB we must extract the package and manually install it because wusa.exe
#    returns 5 (access denied) when its run from WinRM.
#    see https://support.microsoft.com/en-us/kb/2773898

wusa.exe $artifactPath "/extract:$artifactPath-tmp" | Out-String -Stream
dism.exe /Online /Quiet /NoRestart /Add-Package "/PackagePath:$(Resolve-Path "$artifactPath-tmp\*KB*.cab")"
if ($LASTEXITCODE -ne 3010) {
    throw "Failed to install PowerShell with Exit Code $LASTEXITCODE"
}
cmd.exe /c 'exit 0' # indirectly set $LASTEXITCODE 0 to prevent packer from aborting with $LASTEXITCODE 3010.
Remove-Item -Recurse -Force @($artifactPath, "$artifactPath-tmp")
