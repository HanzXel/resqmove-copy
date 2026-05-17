# ResQMove - Backend Starter
# Run from project root: .\start_backend.ps1

$ErrorActionPreference = "Stop"

$backendDir = Join-Path $PSScriptRoot "backend"

if (-not (Test-Path $backendDir)) {
    Write-Host "ERROR: backend folder not found at $backendDir" -ForegroundColor Red
    exit 1
}

Write-Host "ResQMove Backend" -ForegroundColor Cyan
Write-Host "-------------------------------------" -ForegroundColor Cyan

Set-Location $backendDir
Write-Host "Working directory: $backendDir" -ForegroundColor DarkGray

if (-not (Test-Path "node_modules")) {
    Write-Host "[1/3] Installing dependencies..." -ForegroundColor Yellow
    npm install
    Write-Host "Done." -ForegroundColor Green
} else {
    Write-Host "[1/3] Dependencies already installed." -ForegroundColor Green
}

Write-Host "[2/3] Seeding demo accounts..." -ForegroundColor Yellow
node seed.js
Write-Host "Done." -ForegroundColor Green

$ip = (Get-NetIPAddress -AddressFamily IPv4 |
       Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.*" } |
       Select-Object -First 1).IPAddress

if (-not $ip) { $ip = "localhost" }

Write-Host "[3/3] Starting server..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Your PC IP:  $ip" -ForegroundColor Cyan
Write-Host "Backend URL: http://${ip}:8000/api/v1" -ForegroundColor Cyan
Write-Host "Health URL:  http://${ip}:8000/health" -ForegroundColor Cyan
Write-Host ""
Write-Host "Demo accounts:" -ForegroundColor Yellow
Write-Host "  Driver 1 - ID: DRV-001  Password: resq123"
Write-Host "  Driver 2 - ID: DRV-002  Password: resq123"
Write-Host "  Patient  - Enter any phone number in the app"
Write-Host ""
Write-Host "Press Ctrl+C to stop the server." -ForegroundColor DarkGray
Write-Host ""

node server.js
