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

# get the Windows version information.
$currentVersionKey = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$text = @"
$($currentVersionKey.ProductName) (Build $($currentVersionKey.CurrentBuildNumber))
Installed on $((Get-Date).ToString("yyyy-MM-dd"))
"@

# create the lock screen image.
Add-Type -AssemblyName System.Drawing
$defaultLockScreenImagePath = "$env:WINDIR\Web\Screen\img100.jpg"
$localLockScreenImagePath = "$env:WINDIR\Web\Screen\local-lock-screen.jpg"
$image = [System.Drawing.Image]::FromFile($defaultLockScreenImagePath)
$graphics = [System.Drawing.Graphics]::FromImage($image)
$font = New-Object System.Drawing.Font("Arial", 42, [System.Drawing.FontStyle]::Bold)
$brush = [System.Drawing.Brushes]::White
$outlineBrush = [System.Drawing.Brushes]::Black
$padding = [float]($image.Width * 0.01)
$maxWidth = [float]($image.Width - (2 * $padding))
$maxHeight = [float]($image.Height - (2 * $padding))
$textRect = New-Object System.Drawing.RectangleF($padding, $padding, $maxWidth, $maxHeight)
$format = New-Object System.Drawing.StringFormat
$format.Alignment = [System.Drawing.StringAlignment]::Center
$format.LineAlignment = [System.Drawing.StringAlignment]::Near
$offset = 2
for ($x = -$offset; $x -le $offset; $x++) {
    for ($y = -$offset; $y -le $offset; $y++) {
        if ($x -ne 0 -or $y -ne 0) {
            $shadowRect = New-Object System.Drawing.RectangleF(
                ($textRect.X + $x),
                ($textRect.Y + $y),
                $textRect.Width,
                $textRect.Height
            )
            $graphics.DrawString($text, $font, $outlineBrush, $shadowRect, $format)
        }
    }
}
$graphics.DrawString($text, $font, $brush, $textRect, $format)
$image.Save($localLockScreenImagePath, [System.Drawing.Imaging.ImageFormat]::Jpeg)

# set the new lock screen background image.
# NB the new lock screen background image is only visible after the next logon.
$regKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP"
if (-not (Test-Path $regKeyPath)) {
    New-Item -Path $regKeyPath -Force | Out-Null
}
Set-ItemProperty -Path $regKeyPath -Name LockScreenImageStatus -Value 1
Set-ItemProperty -Path $regKeyPath -Name LockScreenImagePath -Value $localLockScreenImagePath
Set-ItemProperty -Path $regKeyPath -Name LockScreenImageUrl -Value $localLockScreenImagePath
