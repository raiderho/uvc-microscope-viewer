@echo off
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -File "%~dp0viewer.ps1" -Action Stop
if errorlevel 1 pause
