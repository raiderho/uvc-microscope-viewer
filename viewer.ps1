param([ValidateSet('Menu','Preview','Capture','Photos','Settings','Stop','ListDevices','ListFormats','Check')][string]$Action = 'Menu')
$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $PSScriptRoot 'viewer-core.ps1')
    Initialize-Viewer $PSScriptRoot
    if ($Action -in @('Menu','Settings')) {
        Write-Output 'Loading the Windows control panel...'
        . (Join-Path $PSScriptRoot 'viewer-ui.ps1')
        Write-Output 'Opening the control panel...'
        if ($Action -eq 'Menu') { Show-ViewerMenu } else { Show-ViewerSettings }
    } else { Invoke-ViewerAction $Action }
} catch { Write-Error $_ -ErrorAction Continue; exit 1 }
