# Compatibility entry point for the original launcher.
param([ValidateSet('Preview','Capture')][string]$Action = 'Preview')
& (Join-Path $PSScriptRoot 'viewer.ps1') -Action $Action