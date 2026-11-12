param(
    # Phone-test builds start from a clean save by default. Use -KeepSave only
    # when deliberately testing save/load behavior.
    [switch]$KeepSave
)

$ErrorActionPreference = "Stop"

# This script can be launched from any directory.
$projectPath = Split-Path -Parent $PSScriptRoot
Set-Location $projectPath

$godotPath = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Directory -Filter "GodotEngine*" |
    ForEach-Object {
        Get-ChildItem $_.FullName -Filter "Godot*_console.exe" -File -Recurse
    } |
    Select-Object -First 1 -ExpandProperty FullName

if (-not $godotPath) {
    throw "Godot was not found through WinGet. Open Godot once or install Godot 4.x first."
}

$adbPath = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path -LiteralPath $adbPath)) {
    throw "ADB was not found at $adbPath. Check the Android SDK installation."
}

$apkPath = Join-Path $projectPath "build\android\AFC-Chicken-Shop.apk"
$apkFolder = Split-Path -Parent $apkPath
New-Item -ItemType Directory -Force -Path $apkFolder | Out-Null

Write-Host "Checking Godot project..." -ForegroundColor Cyan
& $godotPath --headless --path $projectPath --editor --quit
if ($LASTEXITCODE -ne 0) {
    throw "Godot reported a project/script error. Fix the error shown above."
}

Write-Host "Exporting Android APK..." -ForegroundColor Cyan
& $godotPath --headless --path $projectPath --export-debug "Android APK (Phone Test)" $apkPath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $apkPath)) {
    throw "Android export failed. Confirm the export preset is named 'Android APK (Phone Test)'."
}

Write-Host "Checking Android device..." -ForegroundColor Cyan
& $adbPath start-server | Out-Null
$connectedDevices = @(& $adbPath devices | Select-String "\sdevice$")
if ($connectedDevices.Count -eq 0) {
    throw "No Android device detected. Unlock the POCO and enable USB debugging, then run this command again."
}

if (-not $KeepSave) {
    Write-Host "Clearing AFC saved data..." -ForegroundColor Yellow
    & $adbPath shell pm clear com.alwin.afcchickenshop | Out-Host
}

Write-Host "Installing APK on POCO..." -ForegroundColor Cyan
& $adbPath install -r $apkPath | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "APK installation failed. Check the phone's USB-install permission."
}

Write-Host "Launching AFC Chicken Shop..." -ForegroundColor Green
& $adbPath shell monkey -p com.alwin.afcchickenshop -c android.intent.category.LAUNCHER 1 | Out-Host

Write-Host "Done. The game is running on the connected phone." -ForegroundColor Green
