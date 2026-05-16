# ─────────────────────────────────────────────────────────────────────────────
#  ResQMove — Backend Starter
#  start_backend.ps1
#
#  Run this from the project root:
#    .\start_backend.ps1
#
#  What it does:
#    1. Installs npm dependencies if needed
#    2. Seeds the database with demo accounts (if empty)
#    3. Shows your PC's IP address (for the Flutter app)
#    4. Starts the backend server on port 8000
# ─────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"

Write-Host "`n ResQMove Backend" -ForegroundColor Cyan
Write-Host " ─────────────────────────────────────" -ForegroundColor Cyan

Set-Location "$PSScriptRoot\backend"

# ── npm install if node_modules is missing ──────────────────────────────────
if (-not (Test-Path "node_modules")) {
    Write-Host "`n[1/3] Installing dependencies..." -ForegroundColor Yellow
    npm install
} else {
    Write-Host "`n[1/3] Dependencies already installed." -ForegroundColor Green
}

# ── Seed database ───────────────────────────────────────────────────────────
Write-Host "`n[2/3] Seeding demo accounts..." -ForegroundColor Yellow
node seed.js

# ── Show IP ─────────────────────────────────────────────────────────────────
$ip = (Get-NetIPAddress -AddressFamily IPv4 |
       Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.*" } |
       Select-Object -First 1).IPAddress

Write-Host "`n[3/3] Starting server..." -ForegroundColor Yellow
Write-Host "`n Your PC IP:  $ip" -ForegroundColor Cyan
Write-Host " Backend URL: http://${ip}:8000/api/v1" -ForegroundColor Cyan
Write-Host " Health URL:  http://${ip}:8000/health`n" -ForegroundColor Cyan
Write-Host " Demo accounts:" -ForegroundColor Yellow
Write-Host "   Driver 1:  DRV-001 / resq123"
Write-Host "   Driver 2:  DRV-002 / resq123"
Write-Host "   Patient:   Enter any phone number in the app`n"
Write-Host " Press Ctrl+C to stop the server.`n" -ForegroundColor DarkGray

node server.js
