# ResQMove - One-Click Release APK Builder
# Run from project root: .\build_apk.ps1

param(
    [string]$HotlineNumber = "+63322661355",
    [string]$HotlineDisplay = "(032) 266-1355"
)

$ErrorActionPreference = "Stop"

Write-Host "ResQMove APK Builder" -ForegroundColor Cyan
Write-Host "-------------------------------------" -ForegroundColor Cyan

# Step 1: Keystore
$keystorePath = "android\app\resqmove-release.jks"
$keystorePassword = "resqmove2024"
$keyAlias = "resqmove"
$keyPassword = "resqmove2024"

if (-not (Test-Path $keystorePath)) {
    Write-Host "[1/4] Generating release keystore..." -ForegroundColor Yellow
    & keytool -genkey -v `
        -keystore $keystorePath `
        -keyAlg RSA -keysize 2048 -validity 10000 `
        -alias $keyAlias `
        -storepass $keystorePassword `
        -keypass $keyPassword `
        -dname "CN=ResQMove, OU=App, O=ResQMove, L=Cebu, ST=Cebu, C=PH"
    Write-Host "Keystore created at $keystorePath" -ForegroundColor Green
    Write-Host ""
    Write-Host "WARNING - BACK UP YOUR KEYSTORE NOW" -ForegroundColor Red
    Write-Host "If you lose this file you cannot publish updates to the same app." -ForegroundColor Yellow
    Write-Host "  File:     $(Resolve-Path $keystorePath)" -ForegroundColor White
    Write-Host "  Password: $keystorePassword" -ForegroundColor White
    Write-Host "  Alias:    $keyAlias" -ForegroundColor White
    Write-Host ""
    Read-Host "Press Enter once you have backed it up to continue"
} else {
    Write-Host "[1/4] Keystore already exists - skipping." -ForegroundColor Green
}

# Step 2: Set keystore env vars
$env:KEYSTORE_PATH     = "resqmove-release.jks"
$env:KEYSTORE_PASSWORD = $keystorePassword
$env:KEY_ALIAS         = $keyAlias
$env:KEY_PASSWORD      = $keyPassword
Write-Host "[2/4] Keystore env vars set." -ForegroundColor Green

# Step 3: Find local IP and confirm
Write-Host "[3/4] Detecting local IP address..." -ForegroundColor Yellow
$ip = (Get-NetIPAddress -AddressFamily IPv4 |
       Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.*" } |
       Select-Object -First 1).IPAddress

if (-not $ip) {
    Write-Host "Could not auto-detect IP. Using 10.0.2.2 (emulator only)." -ForegroundColor Red
    $ip = "10.0.2.2"
} else {
    Write-Host "Detected IP: $ip" -ForegroundColor Green
}

$apiUrl = "http://${ip}:8000/api/v1"
Write-Host ""
Write-Host "The APK will be built pointing to:" -ForegroundColor Yellow
Write-Host "  $apiUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "Make sure your phone and PC are on the same Wi-Fi network." -ForegroundColor Yellow
Write-Host "If this IP looks wrong, press Ctrl+C and rebuild with:" -ForegroundColor Yellow
Write-Host "  flutter build apk --release --dart-define=API_BASE_URL=http://YOUR_IP:8000/api/v1" -ForegroundColor White
Write-Host ""
$confirm = Read-Host "Continue with this IP? (Y/n)"
if ($confirm -eq "n" -or $confirm -eq "N") {
    Write-Host "Cancelled. Re-run and use the correct IP." -ForegroundColor Red
    exit 0
}

# Step 4: Build APK
Write-Host "[4/4] Building release APK (this takes 2-5 minutes)..." -ForegroundColor Yellow

flutter build apk --release `
    "--dart-define=API_BASE_URL=$apiUrl" `
    "--dart-define=HOTLINE_NUMBER=$HotlineNumber" `
    "--dart-define=HOTLINE_DISPLAY=$HotlineDisplay"

# Done
$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apkPath) {
    $size = [math]::Round((Get-Item $apkPath).Length / 1MB, 1)
    Write-Host ""
    Write-Host "BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "APK: $apkPath ($size MB)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Before installing on phone:" -ForegroundColor Yellow
    Write-Host "  1. Make sure phone and PC are on the same Wi-Fi network"
    Write-Host "  2. Start the backend:  .\start_backend.ps1"
    Write-Host "  3. Enable Install unknown apps on your Android phone"
    Write-Host "  4. Transfer and install: $apkPath"
    Write-Host ""
} else {
    Write-Host "Build may have failed. Check the output above." -ForegroundColor Red
}
