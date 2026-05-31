# RoadSOS Dependency Installer
# Run this script to instantly set up all dependencies for the Backend, Citizen App, Police App, and Admin Dashboard.

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "🤖 Starting RoadSOS Dependency Installation..." -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

$root = Get-Location

# 1. Python Backend
Write-Host "`n1. Setting up Python Backend..." -ForegroundColor Green
cd "$root\backend"
if (-not (Test-Path "venv")) {
    Write-Host "Creating Python virtual environment (venv)..." -ForegroundColor Gray
    python -m venv venv
}
Write-Host "Installing Python requirements..." -ForegroundColor Gray
# Use the virtual environment's pip directly to avoid needing to activate/deactivate
& .\venv\Scripts\pip install -r requirements.txt

# 2. Citizen App
Write-Host "`n2. Installing Citizen App (flutter_app_v2) packages..." -ForegroundColor Green
cd "$root\flutter_app_v2"
flutter pub get

# 3. Police App
Write-Host "`n3. Installing Police App (officer_mobile_app) packages..." -ForegroundColor Green
cd "$root\officer_mobile_app"
flutter pub get

# 4. Admin Dashboard
Write-Host "`n4. Installing Admin Dashboard npm packages..." -ForegroundColor Green
cd "$root\admin_dashboard"
if (Get-Command npm -ErrorAction SilentlyContinue) {
    npm install
} else {
    Write-Warning "npm not found. Please install Node.js to set up the admin dashboard."
}

cd $root
Write-Host "`n==============================================" -ForegroundColor Cyan
Write-Host "✅ Installation completed successfully!" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
