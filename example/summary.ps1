$FormatEnumerationLimit = -1

function Write-Title($title) {
    Write-Output "`n#`n# $title`n#"
}

function Get-DotNetVersion {
    # see https://docs.microsoft.com/en-us/dotnet/framework/migration-guide/how-to-determine-which-versions-are-installed#net_d
    $release = [int](Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release).Release
    if ($release -ge 461808) {
        return '4.7.2 or later'
    }
    if ($release -ge 461308) {
        return '4.7.1'
    }
    if ($release -ge 460798) {
        return '4.7'
    }
    if ($release -ge 394802) {
        return '4.6.2'
    }
    if ($release -ge 394254) {
        return '4.6.1'
    }
    if ($release -ge 393295) {
        return '4.6'
    }
    if ($release -ge 379893) {
        return '4.5.2'
    }
    if ($release -ge 378675) {
        return '4.5.1'
    }
    if ($release -ge 378389) {
        return '4.5'
    }
    return 'No 4.5 or later version detected'
}

Write-title 'Firmware'
Get-ComputerInfo `
    -Property `
        BiosFirmwareType,
        BiosManufacturer,
        BiosVersion `
    | Format-List

Write-Title 'Operating System version (from Get-ComputerInfo)'
Get-ComputerInfo `
    -Property `
        WindowsProductName,
        WindowsInstallationType,
        OsVersion,
        BuildVersion,
        WindowsBuildLabEx `
    | Format-List

Write-Title 'Operating System version (from registry)'
$currentVersionKey = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
Write-Output "$($currentVersionKey.CurrentMajorVersionNumber).$($currentVersionKey.CurrentMinorVersionNumber).$($currentVersionKey.CurrentBuildNumber).$($currentVersionKey.UBR)"

Write-Title '.NET Framework version'
Get-DotNetVersion

Write-Title 'PowerShell version'
$PSVersionTable.GetEnumerator() `
    | Sort-Object Name `
    | Format-Table -AutoSize `
    | Out-String -Stream -Width ([int]::MaxValue) `
    | ForEach-Object {$_.TrimEnd()}

Write-Title 'Network Interfaces'
Get-NetAdapter `
    | ForEach-Object {
        New-Object PSObject -Property @{
            Name = $_.Name
            Description = $_.InterfaceDescription
            MacAddress = $_.MacAddress
            IpAddress = ($_ | Get-NetIPConfiguration | ForEach-Object { $_.IPv4Address.IPAddress })
        }
    } `
    | Sort-Object -Property Name `
    | Format-Table Name,Description,MacAddress,IpAddress `
    | Out-String -Stream -Width ([int]::MaxValue) `
    | ForEach-Object {$_.TrimEnd()}

Write-Title 'Environment Variables'
dir env: `
    | Sort-Object -Property Name `
    | Format-Table -AutoSize `
    | Out-String -Stream -Width ([int]::MaxValue) `
    | ForEach-Object {$_.TrimEnd()}

Write-Title 'Installed Windows Features'
if (Get-Command -ErrorAction SilentlyContinue Get-WindowsFeature) {
    # for Windows Server.
    Get-WindowsFeature `
        | Where Installed `
        | Format-Table -AutoSize `
        | Out-String -Stream -Width ([int]::MaxValue) `
        | ForEach-Object {$_.TrimEnd()}
} else {
    # for Windows Client.
    Get-WindowsOptionalFeature -Online `
        | Where-Object {$_.State -eq 'Enabled'} `
        | Sort-Object -Property FeatureName `
        | Format-Table -AutoSize `
        | Out-String -Stream -Width ([int]::MaxValue) `
        | ForEach-Object {$_.TrimEnd()}
}

# see https://gist.github.com/IISResetMe/36ef331484a770e23a81
function Get-MachineSID {
    param(
        [switch]$DomainSID
    )

    # Retrieve the Win32_ComputerSystem class and determine if machine is a Domain Controller
    $WmiComputerSystem = Get-WmiObject -Class Win32_ComputerSystem
    $IsDomainController = $WmiComputerSystem.DomainRole -ge 4

    if ($IsDomainController -or $DomainSID) {
        # We grab the Domain SID from the DomainDNS object (root object in the default NC)
        $Domain    = $WmiComputerSystem.Domain
        $SIDBytes = ([ADSI]"LDAP://$Domain").objectSid | %{$_}
        New-Object System.Security.Principal.SecurityIdentifier -ArgumentList ([Byte[]]$SIDBytes),0
    } else {
        # Going for the local SID by finding a local account and removing its Relative ID (RID)
        $LocalAccountSID = Get-WmiObject -Query "SELECT SID FROM Win32_UserAccount WHERE LocalAccount = 'True'" | Select-Object -First 1 -ExpandProperty SID
        $MachineSID      = ($p = $LocalAccountSID -split "-")[0..($p.Length-2)]-join"-"
        New-Object System.Security.Principal.SecurityIdentifier -ArgumentList $MachineSID
    }
}
Write-Title 'Windows SID'
Write-Output "$(Get-MachineSID)"

Write-Title 'Partitions'
Get-Partition `
    | Format-Table -AutoSize `
    | Out-String -Stream -Width ([int]::MaxValue) `
    | ForEach-Object {$_.TrimEnd()}

Write-Title 'Volumes'
Get-Volume `
    | Format-Table -AutoSize `
    | Out-String -Stream -Width ([int]::MaxValue) `
    | ForEach-Object {$_.TrimEnd()}
