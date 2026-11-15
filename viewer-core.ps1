# Windows PowerShell 5.1 compatible; no code runs when dot-sourced.
Set-StrictMode -Version Latest

function Initialize-Viewer([string]$Root) {
    $script:ViewerRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    $script:Runtime = Join-Path $script:ViewerRoot 'runtime'
    $script:SettingsFile = Join-Path $script:ViewerRoot 'settings.json'
    $script:StateFile = Join-Path $script:Runtime 'preview.json'
    foreach ($relative in @('runtime','runtime\logs','runtime\temp')) {
        $null = New-Item -ItemType Directory -Path (Join-Path $script:ViewerRoot $relative) -Force
    }
    $env:TEMP = Join-Path $script:Runtime 'temp'
    $env:TMP = $env:TEMP
}

function Resolve-PhotoDirectory([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -match '[\x00-\x1f<>"|?*]') { throw 'Choose a valid local photo folder.' }
    if ($Value -match '^[a-zA-Z]:[\\/]') { return [IO.Path]::GetFullPath($Value) }
    if ([IO.Path]::IsPathRooted($Value) -or $Value.Contains(':')) { throw 'Use a local drive path or relative folder, not a network path or URL.' }
    $resolved = [IO.Path]::GetFullPath((Join-Path $script:ViewerRoot $Value))
    if (-not $resolved.StartsWith($script:ViewerRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Relative photo folders must stay inside the portable folder.' }
    $first = $resolved.Substring($script:ViewerRoot.Length + 1).Split('\')[0]
    if ($first -in @('.git','tools','bin','src','runtime','tests','docs')) { throw 'This folder is reserved for application files.' }
    return $resolved
}

function Assert-Settings($Settings) {
    foreach ($key in @('schemaVersion','deviceName','deviceNumber','resolution','fps','inputFormat','photoDirectory')) {
        if ($Settings.PSObject.Properties.Name -notcontains $key) { throw "Missing setting: $key" }
    }
    if ($Settings.schemaVersion -ne 1) { throw 'Unsupported settings schema version.' }
    if ([string]::IsNullOrWhiteSpace($Settings.deviceName) -or $Settings.deviceName -match '[\x00-\x1f":]') { throw 'Use the exact video device name, without quotes, colons or control characters.' }
    if ("$($Settings.deviceNumber)" -notmatch '^\d+$' -or $Settings.deviceNumber -gt 99) { throw 'deviceNumber must be 0..99.' }
    if ($Settings.resolution -notmatch '^([1-9]\d{0,3})x([1-9]\d{0,3})$') { throw 'Resolution must look like 1920x1080.' }
    if ("$($Settings.fps)" -notmatch '^\d+$' -or $Settings.fps -lt 1 -or $Settings.fps -gt 120) { throw 'FPS must be 1..120.' }
    if ($Settings.inputFormat -notin @('mjpeg','yuyv422')) { throw 'inputFormat must be mjpeg or yuyv422.' }
    $null = Resolve-PhotoDirectory $Settings.photoDirectory
}

function Get-ViewerSettings {
    $path = $script:SettingsFile
    if (-not (Test-Path -LiteralPath $path)) { $path = Join-Path $script:ViewerRoot 'settings.example.json' }
    $settings = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Settings $settings
    return $settings
}

function Save-ViewerSettings($Settings) {
    Assert-Settings $Settings
    $Settings | ConvertTo-Json | Set-Content -LiteralPath $script:SettingsFile -Encoding UTF8
}

function Resolve-ViewerBackend {
    . (Join-Path $script:ViewerRoot 'build.ps1') -FunctionsOnly
    $tool = Join-Path $script:ViewerRoot 'bin\UvcCapture.exe'
    $manifestPath = Join-Path $script:ViewerRoot 'bin\build.json'
    $manifest = $null
    if (Test-Path -LiteralPath $manifestPath) { $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json }
    $sourceHash = Get-ViewerSourceHash $script:ViewerRoot
    if (-not (Test-Path -LiteralPath $tool) -or $null -eq $manifest -or $manifest.sourceSha256 -ne $sourceHash) {
        if (Get-OwnedPreview) { throw 'Close the preview before rebuilding the updated viewer.' }
        $null = Build-ViewerBackend $script:ViewerRoot
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    if ($manifest.binarySha256 -notmatch '^[0-9a-fA-F]{64}$' -or (Get-FileHash -LiteralPath $tool -Algorithm SHA256).Hash -ne $manifest.binarySha256) {
        throw 'Built viewer has changed. Review the local source and run build.ps1 to rebuild it.'
    }
    return $tool
}

function ConvertTo-NativeArgument([AllowEmptyString()][string]$Value) {
    # Windows argv quoting, including embedded quotes and trailing backslashes.
    $builder = New-Object Text.StringBuilder
    $null = $builder.Append('"')
    $slashes = 0
    foreach ($char in $Value.ToCharArray()) {
        if ($char -eq '\') { $slashes++; continue }
        if ($char -eq '"') { $null = $builder.Append(('\' * (2 * $slashes + 1))) }
        else { $null = $builder.Append(('\' * $slashes)) }
        $null = $builder.Append($char)
        $slashes = 0
    }
    $null = $builder.Append(('\' * (2 * $slashes)))
    $null = $builder.Append('"')
    return $builder.ToString()
}

function Start-ViewerProcess([string]$Tool, [string[]]$Arguments, [string]$LogName, [switch]$Visible) {
    $commandLine = ($Arguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '
    $style = 'Hidden'
    if ($Visible) { $style = 'Normal' }
    $process = Start-Process -FilePath $Tool -ArgumentList $commandLine -WorkingDirectory $script:ViewerRoot -WindowStyle $style `
        -RedirectStandardOutput (Join-Path $script:Runtime ("logs\$LogName.stdout.txt")) `
        -RedirectStandardError (Join-Path $script:Runtime ("logs\$LogName.stderr.txt")) -PassThru
    $null = $process.Handle # Retain the exit code on Windows PowerShell.
    return $process
}

function Get-OwnedPreview {
    if (-not (Test-Path -LiteralPath $script:StateFile)) { return $null }
    try {
        $state = Get-Content -LiteralPath $script:StateFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $process = Get-Process -Id ([int]$state.pid) -ErrorAction Stop
        $expected = Join-Path $script:ViewerRoot 'bin\UvcCapture.exe'
        if ($process.Path -eq $expected -and $process.StartTime.ToUniversalTime().Ticks.ToString() -eq $state.startTicks) { return $process }
    } catch { }
    return $null
}

function Stop-ViewerPreview {
    $process = Get-OwnedPreview
    if ($process) {
        $null = $process.CloseMainWindow()
        if (-not $process.WaitForExit(5000)) {
            $process.Kill()
            if (-not $process.WaitForExit(5000)) { throw 'The preview did not release the camera.' }
        }
    }
    if (Test-Path -LiteralPath $script:StateFile) { Remove-Item -LiteralPath $script:StateFile }
}

function Get-VideoArguments($Settings) {
    return @('--device',$Settings.deviceName,'--number',"$($Settings.deviceNumber)",'--size',$Settings.resolution,
        '--fps',"$($Settings.fps)",'--format',$Settings.inputFormat)
}

function Start-ViewerPreview {
    if (Get-OwnedPreview) { return 'Preview is already open.' }
    $settings = Get-ViewerSettings
    $tool = Resolve-ViewerBackend
    $ready = Join-Path $script:Runtime ('ready-' + [guid]::NewGuid().ToString('N') + '.txt')
    $arguments = @('--mode','preview') + (Get-VideoArguments $settings) +
        @('--photos',(Resolve-PhotoDirectory $settings.photoDirectory),'--ready',$ready)
    $process = Start-ViewerProcess $tool $arguments 'preview' -Visible
    try {
        $start = $process.StartTime.ToUniversalTime().Ticks.ToString()
        $timer = [Diagnostics.Stopwatch]::StartNew()
        while (-not (Test-Path -LiteralPath $ready)) {
            if ($process.WaitForExit(100)) { throw 'Preview failed. See runtime/logs/preview.stderr.txt.' }
            if ($timer.ElapsedMilliseconds -gt 20000) { throw 'No preview frame within 20 seconds. Check connection and camera permissions.' }
        }
        if ($process.HasExited) { throw 'Preview closed before initialization completed.' }
        [ordered]@{pid=$process.Id;startTicks=$start;device=$settings.deviceName;backend='MediaFoundation'} |
            ConvertTo-Json | Set-Content -LiteralPath $script:StateFile -Encoding UTF8
        return 'Preview opened. Use its photo button or Space to save PNG; Q closes it.'
    } catch {
        if (-not $process.HasExited) { $process.Kill(); $null = $process.WaitForExit(5000) }
        throw
    } finally {
        foreach ($temporary in @($ready,($ready + '.tmp'))) {
            if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
        }
    }
}

function Save-ViewerPhoto {
    $settings = Get-ViewerSettings
    $tool = Resolve-ViewerBackend
    $restore = $null -ne (Get-OwnedPreview)
    $folder = Resolve-PhotoDirectory $settings.photoDirectory
    $null = New-Item -ItemType Directory -Path $folder -Force
    $name = 'photo-' + (Get-Date).ToString('yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N').Substring(0,6) + '.png'
    $path = Join-Path $folder $name
    if ($restore) { Stop-ViewerPreview }
    try {
        $arguments = @('--mode','capture') + (Get-VideoArguments $settings) + @('--output',$path)
        $process = Start-ViewerProcess $tool $arguments 'capture'
        if (-not $process.WaitForExit(25000)) {
            $process.Kill(); $null = $process.WaitForExit(5000)
            throw 'No photo within 25 seconds. Check connection, format and whether another app is using the camera.'
        }
        if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).Length -eq 0) { throw 'Capture failed. See runtime/logs/capture.stderr.txt.' }
        return $path
    } finally { if ($restore) { $null = Start-ViewerPreview } }
}

function Show-ViewerPhotos {
    $settings = Get-ViewerSettings
    $folder = Resolve-PhotoDirectory $settings.photoDirectory
    $null = New-Item -ItemType Directory -Path $folder -Force
    Start-Process -FilePath (Join-Path $env:WINDIR 'explorer.exe') -ArgumentList (ConvertTo-NativeArgument $folder)
    return $folder
}

function Get-ViewerDeviceInfo([switch]$Formats) {
    $tool = Resolve-ViewerBackend
    $name = 'devices'
    $arguments = @('--mode','devices')
    if ($Formats) {
        $settings = Get-ViewerSettings
        $name = 'formats'
        $arguments = @('--mode','formats','--device',$settings.deviceName,'--number',"$($settings.deviceNumber)")
    }
    $process = Start-ViewerProcess $tool $arguments $name
    if (-not $process.WaitForExit(25000)) { $process.Kill(); $null = $process.WaitForExit(5000); throw 'Device enumeration timed out.' }
    if ($process.ExitCode -ne 0) { throw "Enumeration failed. See runtime/logs/$name.stderr.txt." }
    return Get-Content -LiteralPath (Join-Path $script:Runtime ("logs\$name.stdout.txt")) -Raw -Encoding UTF8
}

function Invoke-ViewerAction([string]$Action) {
    $lock = $null
    try {
        $lock = [IO.File]::Open((Join-Path $script:Runtime 'action.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        switch ($Action) {
            'Preview' { Start-ViewerPreview }
            'Capture' { Save-ViewerPhoto }
            'Photos' { Show-ViewerPhotos }
            'Stop' { Stop-ViewerPreview; 'Preview stopped.' }
            'ListDevices' { Get-ViewerDeviceInfo }
            'ListFormats' { Get-ViewerDeviceInfo -Formats }
            'Check' {
                $settings = Get-ViewerSettings
                [pscustomobject]@{root=$script:ViewerRoot;settings=$settings;photoDirectory=(Resolve-PhotoDirectory $settings.photoDirectory);
                    backend='Windows Media Foundation';executable=(Resolve-ViewerBackend)} | ConvertTo-Json -Depth 4
            }
            default { throw "Unsupported action: $Action" }
        }
    } catch [IO.IOException] { throw ('Another action may be running, or a file/folder is unavailable: ' + $_.Exception.Message) }
    finally { if ($lock) { $lock.Dispose() } }
}
