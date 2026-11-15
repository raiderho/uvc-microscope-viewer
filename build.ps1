# Build only our readable source with the compiler already provided by Windows.
param([switch]$FunctionsOnly)
$ErrorActionPreference = 'Stop'

function Get-ViewerSourceHash([string]$Root) {
    $files = @((Join-Path $Root 'build.ps1')) + @(Get-ChildItem -LiteralPath (Join-Path $Root 'src') -Filter '*.cs' -File | Sort-Object Name | ForEach-Object FullName)
    $hashes = ($files | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash }) -join ':'
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($hashes)))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Build-ViewerBackend([string]$Root) {
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    if (-not (Test-Path -LiteralPath $compiler)) { throw 'Windows x64 .NET Framework 4.x compiler is missing. Nothing was downloaded.' }
    $null = New-Item -ItemType Directory -Path (Join-Path $Root 'bin') -Force
    $output = Join-Path $Root 'bin\UvcCapture.exe'
    $sources = @(Get-ChildItem -LiteralPath (Join-Path $Root 'src') -Filter '*.cs' -File | Sort-Object Name | ForEach-Object FullName)
    $tempFolder = Join-Path $Root 'runtime\temp'
    $null = New-Item -ItemType Directory -Path $tempFolder -Force
    $previousTemp = $env:TEMP; $previousTmp = $env:TMP
    try {
        $env:TEMP = $tempFolder; $env:TMP = $tempFolder
        & $compiler /nologo /target:winexe /platform:x64 /optimize+ /checked+ /codepage:65001 /utf8output "/out:$output" /reference:System.Drawing.dll /reference:System.Windows.Forms.dll $sources
        if ($LASTEXITCODE -ne 0) { throw 'Native viewer compilation failed.' }
    } finally { $env:TEMP = $previousTemp; $env:TMP = $previousTmp }
    [ordered]@{sourceSha256=(Get-ViewerSourceHash $Root);binarySha256=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Root 'bin\build.json') -Encoding UTF8
    Write-Output $output
}

if (-not $FunctionsOnly) { Build-ViewerBackend $PSScriptRoot }
