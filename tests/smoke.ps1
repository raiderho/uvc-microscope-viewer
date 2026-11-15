# Offline regression tests. Never opens a camera or executes vendor code.
$ErrorActionPreference = 'Stop'
$app = Split-Path $PSScriptRoot -Parent
. (Join-Path $app 'viewer-core.ps1')
$fixture = Join-Path $app ('runtime\tests-' + [guid]::NewGuid().ToString('N'))
Initialize-Viewer $fixture
Copy-Item -LiteralPath (Join-Path $app 'settings.example.json') -Destination $fixture
$null = New-Item -ItemType Directory -Path (Join-Path $fixture 'src') -Force
Copy-Item -LiteralPath (Join-Path $app 'build.ps1') -Destination $fixture
Get-ChildItem -LiteralPath (Join-Path $app 'src') -Filter '*.cs' -File | Copy-Item -Destination (Join-Path $fixture 'src')
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
try {
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
$backend=Resolve-ViewerBackend
Assert-True ((Get-Item -LiteralPath $backend).Length -lt 1MB) 'Clean local build needs no downloaded tools and is below 1 MiB'
$process=Start-ViewerProcess $backend @('--mode','selftest') 'selftest'
Assert-True ($process.WaitForExit(15000)) 'Pixel and PNG tests complete'
Assert-True ($process.ExitCode -eq 0) 'Pixel orientation, padding, PNG and malformed buffer tests pass'
$nativeManifest=Get-Content -LiteralPath (Join-Path $fixture 'bin\build.json') -Raw | ConvertFrom-Json
Assert-True ((Get-FileHash -LiteralPath $backend).Hash -eq $nativeManifest.binarySha256) 'Built binary matches manifest'
[IO.File]::WriteAllText($backend,'not an executable')
Assert-Throws { Resolve-ViewerBackend } 'Changed binary rejected without running it'
$current=Get-Process -Id $PID
[ordered]@{pid=$PID;startTicks=$current.StartTime.ToUniversalTime().Ticks.ToString()} | ConvertTo-Json | Set-Content -LiteralPath $script:StateFile -Encoding UTF8
Assert-True ($null -eq (Get-OwnedPreview)) 'Unrelated process is not owned'
Write-Output ("PASS: $script:passed offline checks. Temporary fixtures removed.")
} finally {
    $expectedRoot = [IO.Path]::GetFullPath((Join-Path $app 'runtime')).TrimEnd('\') + '\'
    $resolved = (Resolve-Path -LiteralPath $fixture).Path
    if (-not $resolved.StartsWith($expectedRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected test cleanup path.' }
    if ((Get-Item -LiteralPath $resolved -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Test folder is a reparse point.' }
    if (@(Get-ChildItem -LiteralPath $resolved -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) { throw 'Test folder contains a reparse point.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
