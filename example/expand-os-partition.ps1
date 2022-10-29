# expand the C drive when there is disk available.
$partition = Get-Partition -DriveLetter C
$partitionSupportedSize = Get-PartitionSupportedSize -DriveLetter C
if ($partition.Size -ne $partitionSupportedSize.SizeMax) {
    Write-Host "Expanding the C: partition from $($partition.Size) to $($partitionSupportedSize.SizeMax) bytes..."
    Resize-Partition -DriveLetter C -Size $partitionSupportedSize.SizeMax
}
