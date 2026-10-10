@echo off
title AppGrowth Studio - ViMax AI Video Backend
echo ===================================================
echo Starting AppGrowth Studio + ViMax Backend Service
echo Local API: http://127.0.0.1:8765
echo ===================================================
cd /d "%~dp0.."
py backend/app.py
pause
