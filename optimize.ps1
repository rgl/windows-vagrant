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
# run automatic maintenance.

Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class Windows
{
    [DllImport("kernel32", SetLastError=true)]
    public static extern UInt64 GetTickCount64();

    public static TimeSpan GetUptime()
    {
        return TimeSpan.FromMilliseconds(GetTickCount64());
    }
}
'@

function Wait-Condition {
    param(
      [scriptblock]$Condition,
      [int]$DebounceSeconds=15
    )
    process {
        $begin = [Windows]::GetUptime()
        do {
            Start-Sleep -Seconds 3
            try {
              $result = &$Condition
            } catch {
              $result = $false
            }
            if (-not $result) {
                $begin = [Windows]::GetUptime()
                continue
            }
        } while ((([Windows]::GetUptime()) - $begin).TotalSeconds -lt $DebounceSeconds)
    }
}

function Get-ScheduledTasks() {
    $s = New-Object -ComObject 'Schedule.Service'
    try {
        $s.Connect()
        Get-ScheduledTasksInternal $s.GetFolder('\')
    } finally {
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($s) | Out-Null
    }
}

function Get-ScheduledTasksInternal($Folder) {
    $Folder.GetTasks(0)
    $Folder.GetFolders(0) | ForEach-Object {
        Get-ScheduledTasksInternal $_
    }
}

function Test-IsMaintenanceTask([xml]$definition) {
    # see MaintenanceSettings (maintenanceSettingsType) Element at https://msdn.microsoft.com/en-us/library/windows/desktop/hh832151(v=vs.85).aspx
    $ns = New-Object System.Xml.XmlNamespaceManager($definition.NameTable)
    $ns.AddNamespace('t', $definition.DocumentElement.NamespaceURI)
    $definition.SelectSingleNode("/t:Task/t:Settings/t:MaintenanceSettings", $ns) -ne $null
}

Write-Host 'Running Automatic Maintenance...'
MSchedExe.exe Start
Wait-Condition {@(Get-ScheduledTasks | Where-Object {($_.State -ge 4) -and (Test-IsMaintenanceTask $_.XML)}).Count -eq 0} -DebounceSeconds 60


#
# reclaim the free disk space.

Write-Host 'Reclaiming the free disk space...'
$results = defrag.exe C: /H /L
if ($results -eq 'The operation completed successfully.') {
    $results
} else {
    Write-Host 'Zero filling the free disk space...'
    (New-Object System.Net.WebClient).DownloadFile('https://download.sysinternals.com/files/SDelete.zip', "$env:TEMP\SDelete.zip")
    Expand-Archive "$env:TEMP\SDelete.zip" $env:TEMP
    Remove-Item "$env:TEMP\SDelete.zip"
    &"$env:TEMP\sdelete64.exe" -accepteula -z C:
}
