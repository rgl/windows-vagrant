# Windows 11/2022/2025 Assessment and Deployment Kit (ADK) 10.1.26100.2454 (December 2024).
# see https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install
$artifactUrl = 'https://download.microsoft.com/download/2/d/9/2d9c8902-3fcd-48a6-a22a-432b08bed61e/ADK/adksetup.exe'
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
