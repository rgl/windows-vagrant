param(
    [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
    [string[]]$serviceNames
)

$serviceNames | ForEach-Object {
    $serviceName = $_
    # ensure the service is configured as automatic start delayed.
    # e.g. START_TYPE         : 2   AUTO_START  (DELAYED)
    $result = sc.exe qc $serviceName | Out-String
    if ($result -match '\s+START_TYPE\s+:\s+(?<startTypeId>\d+)\s+(?<startType>\w+)(\s+\((?<startDelayed>\w+)\))?\s+') {
        $startType = $Matches['startType']
        $startIsDelayed = $Matches['startDelayed'] -eq 'DELAYED'
        if ($startType -ne 'AUTO_START' -or -not $startIsDelayed) {
            throw "$serviceName start type is not set to automatic start delayed"
        }
    } else {
        throw "failed to parse the sc.exe qc $serviceName output"
    }
}
