# see How to configure automatic updates by using Group Policy or registry settings
#     at https://support.microsoft.com/en-us/help/328010
New-ItemProperty `
    -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU `
    -Name NoAutoUpdate `
    -Value 1 `
    -PropertyType DWORD `
    | Out-Null
