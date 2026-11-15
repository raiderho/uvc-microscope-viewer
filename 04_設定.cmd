@echo off
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -STA -File "%~dp0viewer.ps1" -Action Settings
if errorlevel 1 pause
