# Offline regression tests. Never opens a camera or executes vendor code.
$ErrorActionPreference = 'Stop'
$app = Split-Path $PSScriptRoot -Parent
. (Join-Path $app 'viewer-core.ps1')
$fixture = Join-Path $app ('runtime\tests-' + [guid]::NewGuid().ToString('N'))
Initialize-Viewer $fixture
Copy-Item -LiteralPath (Join-Path $app 'settings.example.json') -Destination $fixture
$script:passed = 0
function Assert-True([bool]$Condition,[string]$Name) {
    if (-not $Condition) { throw "FAILED: $Name" }
    $script:passed++
}
function Assert-Throws([scriptblock]$Code,[string]$Name) {
    $threw = $false
    try { $null = & $Code } catch { $threw = $true }
    Assert-True $threw $Name
}
foreach ($file in Get-ChildItem -LiteralPath $app -Filter '*.ps1' -File) {
    $tokens=$null; $errors=$null
    $null=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    Assert-True ($errors.Count -eq 0) ('Syntax: ' + $file.Name)
}
$cfg=Get-ViewerSettings
Assert-True ($cfg.deviceName -eq 'TN2.0M-D') 'Known device is the default profile'
Assert-True ((Resolve-PhotoDirectory $cfg.photoDirectory) -eq (Join-Path $fixture 'photos')) 'Relative default follows portable root'
$cfg.deviceName='USB Camera Example'
$cfg.photoDirectory='custom photos'
Save-ViewerSettings $cfg
Assert-True ((Get-ViewerSettings).deviceName -eq 'USB Camera Example') 'Generic camera profile persists'
Assert-True ((Resolve-PhotoDirectory $cfg.photoDirectory) -eq (Join-Path $fixture 'custom photos')) 'Folder with spaces'
Assert-True ((Resolve-PhotoDirectory (Join-Path $fixture 'absolute photos')) -eq (Join-Path $fixture 'absolute photos')) 'Explicit local path'
Assert-Throws { Resolve-PhotoDirectory '..\outside' } 'Relative traversal rejected'
Assert-Throws { Resolve-PhotoDirectory '\\server\share' } 'Network folder rejected'
Assert-Throws { Resolve-PhotoDirectory 'https://example.com/photos' } 'URL rejected'
Assert-Throws { Resolve-PhotoDirectory 'tools' } 'Reserved folder rejected'
$cfg.deviceName='camera:audio=Microphone'
Assert-Throws { Assert-Settings $cfg } 'Device separator cannot inject audio input'
$cfg.deviceName='USB Camera Example'; $cfg.inputFormat='h264'
Assert-Throws { Assert-Settings $cfg } 'Unimplemented format rejected'
$cfg.inputFormat='mjpeg'; $cfg.fps=0
Assert-Throws { Assert-Settings $cfg } 'Invalid frame rate rejected'
$cfg.fps=30
Save-ViewerSettings $cfg
Assert-True ((ConvertTo-NativeArgument 'a b') -eq '"a b"') 'Spaces quoted'
Assert-True ((ConvertTo-NativeArgument 'a"b') -eq '"a\"b"') 'Quotes escaped'
Assert-True ((ConvertTo-NativeArgument 'C:\folder\') -eq '"C:\folder\\"') 'Trailing slash escaped'
$lock=[IO.File]::Open((Join-Path $script:Runtime 'action.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try { Assert-Throws { Invoke-ViewerAction 'Check' } 'Concurrent action rejected' } finally { $lock.Dispose() }
$null=New-Item -ItemType Directory -Path (Join-Path $fixture 'tools') -Force
Copy-Item -LiteralPath (Join-Path $app 'tools\checksums.json') -Destination (Join-Path $fixture 'tools')
Assert-Throws { Resolve-ViewerTool 'ffmpeg' } 'Missing executable rejected'
[IO.File]::WriteAllText((Join-Path $fixture 'tools\ffmpeg.exe'),'not an executable')
Assert-Throws { Resolve-ViewerTool 'ffmpeg' } 'Changed executable rejected without running it'
$current=Get-Process -Id $PID
[ordered]@{pid=$PID;startTicks=$current.StartTime.ToUniversalTime().Ticks.ToString()} | ConvertTo-Json | Set-Content -LiteralPath $script:StateFile -Encoding UTF8
Assert-True ($null -eq (Get-OwnedPreview)) 'Unrelated process is not owned'
Write-Output ("PASS: $script:passed offline checks. Fixtures: $fixture")
