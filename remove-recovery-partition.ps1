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

Write-Host 'Disabling the Windows Recovery Environment...'
$output = reagentc /disable 2>&1
# NB exit codes:
#       0: successfully disabled.
#       2: already disabled.
if (@(0, 2) -notcontains $LASTEXITCODE) {
    throw "Failed with exit code $LASTEXITCODE and output $output"
}

# see https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/configure-uefigpt-based-hard-drive-partitions?view=windows-11
Get-Partition | Where-Object { $_.Type -eq 'Recovery' } | ForEach-Object {
    Write-Host "Removing the Windows Recovery partition..."
    $_ | Remove-Partition -Confirm:$false
}

# expand the C drive when there is disk available.
$partition = Get-Partition -DriveLetter C
$partitionSupportedSize = Get-PartitionSupportedSize -DriveLetter C
# calculate the maximum size (1MB aligned).
# NB when running in the hyperv hypervisor, the size must be must multiple of
#    1MB, otherwise, it fails with:
#       The size of the extent is less than the minimum of 1MB.
$sizeMax = $partitionSupportedSize.SizeMax - ($partitionSupportedSize.SizeMax % (1*1024*1024))
if ($partition.Size -lt $sizeMax) {
    Write-Host "Expanding the C: partition from $($partition.Size) to $sizeMax bytes..."
    Resize-Partition -DriveLetter C -Size $sizeMax
}
