# AppGrowth Studio - ViMax AI Video Backend Launcher
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "Starting AppGrowth Studio + ViMax Backend Service" -ForegroundColor Green
Write-Host "Local API: http://127.0.0.1:8765" -ForegroundColor Yellow
Write-Host "===================================================" -ForegroundColor Cyan

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $scriptDir "..")

py backend/app.py
