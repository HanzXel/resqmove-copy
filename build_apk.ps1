# ─────────────────────────────────────────────────────────────────────────────
#  ResQMove — One-Click Release APK Builder
#  build_apk.ps1
#
#  Run this script from the project root in PowerShell:
#    .\build_apk.ps1
#
#  What it does:
#    1. Generates the release keystore (first run only)
#    2. Finds your PC's local IP address automatically
#    3. Builds the release APK with the correct backend URL
#    4. Prints the APK location
# ─────────────────────────────────────────────────────────────────────────────

param(
    [string]$HotlineNumber = "+63322661355",
    [string]$HotlineDisplay = "(032) 266-1355"
)

$ErrorActionPreference = "Stop"

Write-Host "`n ResQMove APK Builder" -ForegroundColor Cyan
Write-Host " ─────────────────────────────────────" -ForegroundColor Cyan

# ── Step 1: Keystore ────────────────────────────────────────────────────────
$keystorePath = "android\app\resqmove-release.jks"
$keystorePassword = "resqmove2024"
$keyAlias = "resqmove"
$keyPassword = "resqmove2024"

if (-not (Test-Path $keystorePath)) {
    Write-Host "`n[1/4] Generating release keystore..." -ForegroundColor Yellow
    & keytool -genkey -v `
        -keystore $keystorePath `
        -keyAlg RSA -keysize 2048 -validity 10000 `
        -alias $keyAlias `
        -storepass $keystorePassword `
        -keypass $keyPassword `
        -dname "CN=ResQMove, OU=App, O=ResQMove, L=Cebu, ST=Cebu, C=PH"
    Write-Host "   Keystore created at $keystorePath" -ForegroundColor Green
} else {
    Write-Host "`n[1/4] Keystore already exists — skipping." -ForegroundColor Green
}

# ── Step 2: Set keystore env vars ──────────────────────────────────────────
$env:KEYSTORE_PATH     = "resqmove-release.jks"
$env:KEYSTORE_PASSWORD = $keystorePassword
$env:KEY_ALIAS         = $keyAlias
$env:KEY_PASSWORD      = $keyPassword
Write-Host "[2/4] Keystore env vars set." -ForegroundColor Green

# ── Step 3: Find local IP ──────────────────────────────────────────────────
Write-Host "`n[3/4] Detecting local IP address..." -ForegroundColor Yellow
$ip = (Get-NetIPAddress -AddressFamily IPv4 |
       Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.*" } |
       Select-Object -First 1).IPAddress

if (-not $ip) {
    Write-Host "   Could not auto-detect IP. Using 10.0.2.2 (emulator only)." -ForegroundColor Red
    $ip = "10.0.2.2"
} else {
    Write-Host "   Found IP: $ip" -ForegroundColor Green
}

$apiUrl = "http://${ip}:8000/api/v1"
Write-Host "   API URL: $apiUrl" -ForegroundColor Cyan

# ── Step 4: Build APK ──────────────────────────────────────────────────────
Write-Host "`n[4/4] Building release APK (this takes 2-5 minutes)..." -ForegroundColor Yellow
Write-Host "   flutter build apk --release" -ForegroundColor DarkGray

flutter build apk --release `
    "--dart-define=API_BASE_URL=$apiUrl" `
    "--dart-define=HOTLINE_NUMBER=$HotlineNumber" `
    "--dart-define=HOTLINE_DISPLAY=$HotlineDisplay"

# ── Done ────────────────────────────────────────────────────────────────────
$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apkPath) {
    $size = [math]::Round((Get-Item $apkPath).Length / 1MB, 1)
    Write-Host "`n BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host " APK: $apkPath ($size MB)" -ForegroundColor Cyan
    Write-Host "`n Before installing on phone:" -ForegroundColor Yellow
    Write-Host "   1. Make sure phone and PC are on the same Wi-Fi network"
    Write-Host "   2. Start the backend:  cd backend; npm install; node server.js"
    Write-Host "   3. Run the seeder:     cd backend; node seed.js"
    Write-Host "   4. Enable 'Install unknown apps' on Android phone"
    Write-Host "   5. Transfer and install: $apkPath`n"
} else {
    Write-Host "`n Build may have failed. Check the output above." -ForegroundColor Red
}
