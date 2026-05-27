# Run MotoRemap Pro on Windows desktop (UI preview mode)
# Uses stub packages for usb_serial and flutter_bluetooth_serial.
# No real ECU connection — all hardware calls return empty/null.

$ErrorActionPreference = 'Stop'
$AppDir = $PSScriptRoot

# Backup original pubspec
Copy-Item "$AppDir\pubspec.yaml" "$AppDir\pubspec.yaml.bak" -Force

try {
    # Swap in Windows config
    Copy-Item "$AppDir\pubspec_windows.yaml" "$AppDir\pubspec.yaml" -Force
    Write-Host "[MotoRemap] Using Windows pubspec (Android stubs active)" -ForegroundColor Cyan

    Set-Location $AppDir
    flutter pub get
    Write-Host "[MotoRemap] Launching on Windows..." -ForegroundColor Green
    flutter run -d windows
} finally {
    # Always restore original pubspec
    Copy-Item "$AppDir\pubspec.yaml.bak" "$AppDir\pubspec.yaml" -Force
    flutter pub get | Out-Null
    Write-Host "[MotoRemap] Restored original pubspec." -ForegroundColor Yellow
}
