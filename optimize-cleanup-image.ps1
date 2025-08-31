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

#
# cleanup the WinSxS folder.

# NB even thou the automatic maintenance includes a component cleanup task,
#    it will not clean everything, as such, dism will clean the rest.
# NB to analyze the used space use: dism.exe /Online /Cleanup-Image /AnalyzeComponentStore
# see https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/clean-up-the-winsxs-folder
Write-Host 'Cleaning up the WinSxS folder...'
dism.exe /Online /Quiet /Cleanup-Image /StartComponentCleanup /ResetBase
if ($LASTEXITCODE) {
    throw "Failed with Exit Code $LASTEXITCODE"
}

# NB even after cleaning up the WinSxS folder the "Backups and Disabled Features"
#    field of the analysis report will display a non-zero number because the
#    disabled features packages are still on disk. you can remove them with:
#       Get-WindowsOptionalFeature -Online `
#           | Where-Object {$_.State -eq 'Disabled'} `
#           | ForEach-Object {
#               Write-Host "Removing feature $($_.FeatureName)..."
#               dism.exe /Online /Quiet /Disable-Feature "/FeatureName:$($_.FeatureName)" /Remove
#           }
#    NB a removed feature can still be installed from other sources (e.g. windows update).
Write-Host 'Analyzing the WinSxS folder...'
dism.exe /Online /Cleanup-Image /AnalyzeComponentStore
