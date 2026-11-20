# Windows 11/2022/2025 Assessment and Deployment Kit (ADK) 10.1.26100.9457 (September 2026).
# see https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install
$artifactUrl = 'https://download.microsoft.com/download/8e0c0f5a-abb5-4358-a51b-168eb40b1590/adk/adksetup.exe'
$artifactPath = "$env:TEMP\$(Split-Path -Leaf $artifactUrl)"

Write-Host 'Downloading the Windows Assessment and Deployment Kit (ADK) setup...'
(New-Object System.Net.WebClient).DownloadFile($artifactUrl, $artifactPath)

Write-Host 'Installing the ADK Deployment Tools...'
&$artifactPath /quiet /features OptionId.DeploymentTools | Out-String -Stream

Write-Host 'Creating the Windows System Image Manager shortcut in the Desktop...'
Import-Module C:\ProgramData\chocolatey\helpers\chocolateyInstaller.psm1
Install-ChocolateyShortcut `
    -ShortcutFilePath "$env:USERPROFILE\Desktop\Windows System Image Manager.lnk" `
    -TargetPath 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\WSIM\amd64\imgmgr.exe'
