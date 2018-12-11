param(
    [switch]$RunningAsScheduledTask = $false
)

# this is a fix for https://bugzilla.redhat.com/show_bug.cgi?id=1377155#c12

Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
trap {
    Write-Host
    Write-Host "ERROR: $_"
    Write-Host (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Host (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Exit 1
}

# NB this fix only applies to qemu.
if ('SeaBIOS' -ne (Get-WmiObject WIN32_BIOS -Property Manufacturer).Manufacturer) {
    Exit 0
}


#
# enable TLS 1.1 and 1.2.

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol `
    -bor [Net.SecurityProtocolType]::Tls11 `
    -bor [Net.SecurityProtocolType]::Tls12

$taskName = 'libvirt-fix-cpu-driver'
$transcriptPath = "C:\tmp\$taskName.log"
$devConPath = 'C:\tmp\devcon.exe'

function Get-Devices($filter='*') {
    # example devcon output:
    #
    #   SWD\PRINTENUM\{385C45DF-7B30-4EB4-886E-7EFDD3817A40}
    #       Name: Microsoft Print to PDF
    #       Driver is running.
    #   {6FDE7547-1B65-48AE-B628-80BE62016026}\VIOSERIALPORT\4&176259CF&0&01
    #       Name: vport0p1
    #       Driver is running.
    #   55 matching device(s) found.
    $devices = @()
    &$devConPath status $filter | ForEach-Object {$device=$null} {
        # detect the start of a new device block.
        if ($_ -match '^[^\d][^\\]+\\.+') {
            $device = New-Object PSObject -Property @{
                Id = $_
                Name = ''
                State = ''
            }
            $devices += $device
            return
        }
        # detect the driver name field.
        if ($_ -match '^\s+Name: (.+)') {
            $device.Name = $matches[1].Trim()
            return
        }
        # detect the driver state field.
        if ($_ -match '^\s+.+') {
            $device.State = $_.Trim()
            return
        }
    }
    return $devices
}

function Get-HidButtonDevice {
    Get-Devices 'ACPI\ACPI0010*' | Where-Object {$_.Name -eq 'HID Button over Interrupt Driver'}
}

if ($RunningAsScheduledTask) {
    Start-Transcript $transcriptPath
    $device = Get-HidButtonDevice
    if ($device) {
        Write-Output "Removing the $($device.Name) ($($device.Id)) device..."
        &$devConPath remove "@$($device.Id)"
        # NB touching these registry keys requires us to be running as SYSTEM.
        Remove-Item (Resolve-Path HKLM:\SYSTEM\DriverDataBase\DriverPackages\hidinterrupt.inf_amd64_*\Descriptors\ACPI\ACPI0010)
        Remove-ItemProperty -Path HKLM:\SYSTEM\DriverDatabase\DeviceIds\ACPI\ACPI0010 -Name hidinterrupt.inf
        Write-Output 'Rescanning the devices...'
        &$devConPath rescan
    }
} else {
    if (!(Test-Path $devConPath)) {
        $archiveUrl = 'https://github.com/rgl/devcon/releases/download/20181014/devcon.zip'
        $archiveHash = '64b3380743722c7e72efbd63d35dd5fe4427ee852462299aa334437f244d7ea3'
        $archiveName = Split-Path -Leaf $archiveUrl
        $archivePath = "$env:TEMP\$archiveName"
        Write-Host "Downloading $archiveName..."
        (New-Object Net.WebClient).DownloadFile($archiveUrl, $archivePath)
        $archiveActualHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash
        if ($archiveHash -ne $archiveActualHash) {
            throw "$archiveName downloaded from $archiveUrl to $archivePath has $archiveActualHash hash witch does not match the expected $archiveHash"
        }
        Write-Host "Extracting $archiveName..."
        Expand-Archive $archivePath (Split-Path -Parent $devConPath)
    }

    if (Get-HidButtonDevice) {
        Write-Output 'Registering Scheduled Task...'
        $action = New-ScheduledTaskAction `
            -Execute 'PowerShell.exe' `
            -Argument "-NoProfile -ExecutionPolicy Bypass $PSCommandPath -RunningAsScheduledTask"
        Register-ScheduledTask `
            -TaskName $taskName `
            -Action $action `
            -User 'SYSTEM' `
            | Out-Null
        Start-ScheduledTask `
            -TaskName $taskName

        Write-Output 'Waiting for the Scheduled Task to complete...'
        while ((Get-ScheduledTask -TaskName $taskName).State -ne 'Ready') {
            Start-Sleep -Seconds 1
        }
        $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
        $taskResult = $taskInfo.LastTaskResult

        Write-Output 'Unregistering Scheduled Task...'
        Unregister-ScheduledTask `
            -TaskName $taskName `
            -Confirm:$false

        Write-Output 'Scheduled Task output:'
        Get-Content -ErrorAction SilentlyContinue $transcriptPath
        Write-Output "Scheduled Task result: $taskResult"
        Remove-Item $transcriptPath
    }

    Remove-Item $devConPath
}
