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
    $env:FFREPORT = $null
}

function Resolve-PhotoDirectory([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -match '[\x00-\x1f<>"|?*]') { throw 'Choose a valid local photo folder.' }
    if ($Value -match '^[a-zA-Z]:[\\/]') { return [IO.Path]::GetFullPath($Value) }
    if ([IO.Path]::IsPathRooted($Value) -or $Value.Contains(':')) { throw 'Use a local drive path or relative folder, not a network path or URL.' }
    $resolved = [IO.Path]::GetFullPath((Join-Path $script:ViewerRoot $Value))
    if (-not $resolved.StartsWith($script:ViewerRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Relative photo folders must stay inside the portable folder.' }
    $first = $resolved.Substring($script:ViewerRoot.Length + 1).Split('\')[0]
    if ($first -in @('.git','tools','runtime','tests')) { throw 'This folder is reserved for application files.' }
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

function Resolve-ViewerTool([ValidateSet('ffmpeg','ffplay')][string]$Name) {
    $tool = Join-Path $script:ViewerRoot ('tools\' + $Name + '.exe')
    $manifest = Get-Content -LiteralPath (Join-Path $script:ViewerRoot 'tools\checksums.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $property = $manifest.PSObject.Properties[$Name]
    if ($null -eq $property -or $property.Value -notmatch '^[0-9a-fA-F]{64}$') { throw "Missing or invalid trusted SHA-256 for $Name." }
    if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) { throw "Missing $tool. Read tools/README.md. Nothing was downloaded or executed." }
    if ((Get-FileHash -LiteralPath $tool -Algorithm SHA256).Hash -ne $property.Value) { throw "SHA-256 mismatch for $Name. Review the source and checksum; do not bypass this check." }
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
        $expected = Join-Path $script:ViewerRoot 'tools\ffplay.exe'
        if ($process.Path -eq $expected -and $process.StartTime.ToUniversalTime().Ticks.ToString() -eq $state.startTicks) { return $process }
    } catch { }
    return $null
}

function Stop-ViewerPreview {
    $process = Get-OwnedPreview
    if ($process) {
        $process.Kill()
        if (-not $process.WaitForExit(5000)) { throw 'The preview did not release the camera.' }
    }
}

function Get-VideoArguments($Settings) {
    $arguments = @('-f','dshow','-video_device_number',"$($Settings.deviceNumber)",'-video_size',$Settings.resolution,'-framerate',"$($Settings.fps)")
    if ($Settings.inputFormat -eq 'mjpeg') { $arguments += @('-vcodec','mjpeg') }
    else { $arguments += @('-pixel_format','yuyv422') }
    return $arguments + @('-i',('video=' + $Settings.deviceName))
}

function Start-ViewerPreview {
    if (Get-OwnedPreview) { return 'Preview is already open.' }
    $settings = Get-ViewerSettings
    $tool = Resolve-ViewerTool 'ffplay'
    $arguments = @('-hide_banner','-loglevel','warning','-an','-sn') + (Get-VideoArguments $settings) +
        @('-x','960','-y','540','-window_title',($settings.deviceName + ' - UVC Viewer'))
    $process = Start-ViewerProcess $tool $arguments 'preview' -Visible
    $start = $process.StartTime.ToUniversalTime().Ticks.ToString()
    if ($process.WaitForExit(1500)) { throw 'Preview failed. See runtime/logs/preview.stderr.txt.' }
    [ordered]@{pid=$process.Id;startTicks=$start;device=$settings.deviceName} | ConvertTo-Json | Set-Content -LiteralPath $script:StateFile -Encoding UTF8
    return 'Preview opened. Close its window or press Q to stop.'
}

function Save-ViewerPhoto {
    $settings = Get-ViewerSettings
    $tool = Resolve-ViewerTool 'ffmpeg'
    $restore = $null -ne (Get-OwnedPreview)
    $folder = Resolve-PhotoDirectory $settings.photoDirectory
    $null = New-Item -ItemType Directory -Path $folder -Force
    $name = 'photo-' + (Get-Date).ToString('yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N').Substring(0,6) + '.png'
    $path = Join-Path $folder $name
    if ($restore) { Stop-ViewerPreview }
    try {
        $arguments = @('-hide_banner','-nostdin','-n') + (Get-VideoArguments $settings) +
            @('-map','0:v:0','-an','-vf',("select=gte(n\,$($settings.fps))"),'-frames:v','1','-threads','1',
              '-c:v','png','-compression_level','3','-update','1',$path)
        $process = Start-ViewerProcess $tool $arguments $name
        if (-not $process.WaitForExit(20000)) {
            $process.Kill(); $null = $process.WaitForExit(5000)
            throw 'No photo within 20 seconds. Check connection, format and whether another app is using the camera.'
        }
        if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $path) -or (Get-Item -LiteralPath $path).Length -eq 0) { throw "Capture failed. See runtime/logs/$name.stderr.txt." }
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
    $tool = Resolve-ViewerTool 'ffmpeg'
    $name = 'devices'
    $arguments = @('-hide_banner','-nostdin','-list_devices','true','-f','dshow','-i','dummy')
    if ($Formats) {
        $settings = Get-ViewerSettings
        $name = 'formats'
        $arguments = @('-hide_banner','-nostdin','-list_options','true','-f','dshow','-video_device_number',"$($settings.deviceNumber)",'-i',('video=' + $settings.deviceName))
    }
    $process = Start-ViewerProcess $tool $arguments $name
    if (-not $process.WaitForExit(15000)) { $process.Kill(); $null = $process.WaitForExit(5000); throw 'Device enumeration timed out.' }
    # FFmpeg normally exits nonzero after listing; inspect its log.
    return Get-Content -LiteralPath (Join-Path $script:Runtime ("logs\$name.stderr.txt")) -Raw -Encoding UTF8
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
                    ffmpeg=(Resolve-ViewerTool 'ffmpeg');ffplay=(Resolve-ViewerTool 'ffplay')} | ConvertTo-Json -Depth 4
            }
            default { throw "Unsupported action: $Action" }
        }
    } catch [IO.IOException] { throw ('Another action may be running, or a file/folder is unavailable: ' + $_.Exception.Message) }
    finally { if ($lock) { $lock.Dispose() } }
}
