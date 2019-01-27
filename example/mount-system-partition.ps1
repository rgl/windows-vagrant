# mount the System/EFI partition (if it exists) as B:.
$systemPartition = Get-Partition | Where-Object {$_.Type -eq 'System'}
if ($systemPartition) {
    Write-Host 'Mounting the System partition in B:...'
    $systemPartition | Add-PartitionAccessPath -AccessPath B:
    # you can later umount it with:
    #    $systemPartition | Remove-PartitionAccessPath -AccessPath B:
}
