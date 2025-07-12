$windowsBuild = [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber

# remove appx packages that prevent sysprep from working.
# NB without this, sysprep will fail with:
#       2024-12-14 14:08:40, Error                 SYSPRP Package Microsoft.MicrosoftEdge.Stable_131.0.2903.99_neutral__8wekyb3d8bbwe was installed for a user, but not provisioned for all users. This package will not function properly in the sysprep image.
# NB you can list all the appx and which users have installed them:
#       Get-AppxPackage -AllUsers | Format-List PackageFullName,PackageUserInformation
# NB this only seems to be required in Windows 11/2025+ (aka 24H2 aka build 26100).
#    NB on earlier versions pwsh fails to load the Appx module as:
#           Operation is not supported on this platform. (0x80131539)
# see https://learn.microsoft.com/en-us/troubleshoot/windows-client/setup-upgrade-and-drivers/sysprep-fails-remove-or-update-store-apps#cause
if ($windowsBuild -ge 26100) {
    Write-Host "Removing appx packages that prevent sysprep from working..."
    Get-AppxPackage -AllUsers `
        | Where-Object { $_.PackageUserInformation } `
        | Where-Object { $_.PackageUserInformation.InstallState -eq 'Installed' } `
        | Where-Object {
            $_.PackageFullName -like 'Microsoft.MicrosoftEdge.*' -or `
            $_.PackageFullName -like 'Microsoft.Edge.*' -or `
            $_.PackageFullName -like 'NotepadPlusPlus*'
        } `
        | ForEach-Object {
            Write-Host "Removing the $($_.PackageFullName) appx package..."
            Remove-AppxPackage -AllUsers -Package $_.PackageFullName
        }
}
