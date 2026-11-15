# Optional hardware check. Uses the configured UVC device, never the first available webcam.
param([switch]$IncludePreview, [switch]$TestYuy2)
$ErrorActionPreference = 'Stop'
$app = Split-Path $PSScriptRoot -Parent
. (Join-Path $app 'viewer-core.ps1')
Initialize-Viewer $app
if (Get-OwnedPreview) { throw 'Close the preview before this hardware check.' }
$cfg = Get-ViewerSettings
$fixture = Join-Path $script:Runtime ('camera-test-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixture
$script:SettingsFile = Join-Path $fixture 'settings.json'
$cfg.photoDirectory = Join-Path $fixture 'photos with spaces'
Save-ViewerSettings $cfg
Add-Type -AssemblyName System.Drawing
function Assert-Photo([string]$Path, [int]$Width, [int]$Height) {
    $image = [Drawing.Image]::FromFile($Path)
    try {
        if ($image.Width -ne $Width -or $image.Height -ne $Height -or $image.RawFormat.Guid -ne [Drawing.Imaging.ImageFormat]::Png.Guid) { throw 'PNG dimensions or format mismatch.' }
    } finally { $image.Dispose() }
}
try {
    $null = Resolve-ViewerBackend
    $devices = Invoke-ViewerAction 'ListDevices'
    if (-not $devices.Contains($cfg.deviceName)) { throw 'Configured camera was not listed.' }
    $null = Invoke-ViewerAction 'ListFormats'
    if ($IncludePreview) { $null = Invoke-ViewerAction 'Preview'; $before = (Get-OwnedPreview).StartTime.ToUniversalTime().Ticks }
    $photo = Invoke-ViewerAction 'Capture'
    $size = $cfg.resolution.Split('x')
    Assert-Photo $photo ([int]$size[0]) ([int]$size[1])
    if ($IncludePreview) {
        $restored = Get-OwnedPreview
        if ($null -eq $restored -or $restored.StartTime.ToUniversalTime().Ticks -eq $before) { throw 'Preview did not restart after command-line capture.' }
    }
    $null = Invoke-ViewerAction 'Stop'
    if ($TestYuy2) {
        $cfg.inputFormat='yuyv422'; $cfg.resolution='640x480'; $cfg.fps=30
        Save-ViewerSettings $cfg
        Assert-Photo (Invoke-ViewerAction 'Capture') 640 480
    }
    Write-Output "PASS: $($cfg.deviceName), device/mode listing, PNG capture, folder with spaces; preview=$IncludePreview; YUY2=$TestYuy2. Personal settings unchanged."
} finally {
    Stop-ViewerPreview
    $runtimeRoot = [IO.Path]::GetFullPath((Join-Path $app 'runtime')).TrimEnd('\') + '\'
    $resolved = (Resolve-Path -LiteralPath $fixture).Path
    if (-not $resolved.StartsWith($runtimeRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected camera test cleanup path.' }
    if ((Get-Item -LiteralPath $resolved -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Test folder is a reparse point.' }
    if (@(Get-ChildItem -LiteralPath $resolved -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) { throw 'Test folder contains a reparse point.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
