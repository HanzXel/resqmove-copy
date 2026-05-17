# ResQMove - One-Click Release APK Builder
# Run from project root: .\build_apk.ps1
# For production: .\build_apk.ps1 -ApiUrl "https://resqmove-backend.onrender.com/api/v1"

param(
    [string]$ApiUrl = "",
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

# Step 3: Determine API URL
Write-Host "[3/4] Setting API URL..." -ForegroundColor Yellow

if ($ApiUrl -ne "") {
    Write-Host "Using provided URL: $ApiUrl" -ForegroundColor Green
} else {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 |
           Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.*" } |
           Select-Object -First 1).IPAddress
    if (-not $ip) { $ip = "10.0.2.2" }
    $ApiUrl = "http://${ip}:8000/api/v1"
    Write-Host "Using local IP: $ApiUrl" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Tip: For a production build use:" -ForegroundColor DarkGray
    Write-Host "  .\build_apk.ps1 -ApiUrl https://resqmove-backend.onrender.com/api/v1" -ForegroundColor DarkGray
    Write-Host ""
    $confirm = Read-Host "Continue with local IP? (Y/n)"
    if ($confirm -eq "n" -or $confirm -eq "N") {
        Write-Host "Cancelled." -ForegroundColor Red
        exit 0
    }
}

# Step 4: Build APK
Write-Host "[4/4] Building release APK (this takes 2-5 minutes)..." -ForegroundColor Yellow

flutter build apk --release `
    "--dart-define=API_BASE_URL=$ApiUrl" `
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
    Write-Host "Transfer to phone via Telegram, Google Drive, or USB." -ForegroundColor Yellow
} else {
    Write-Host "Build may have failed. Check the output above." -ForegroundColor Red
}
