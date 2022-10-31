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
