@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_phone.ps1" %*
