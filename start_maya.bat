@echo off
title MAYA Cinema - Personal Streaming Server
color 0B

echo ===================================================================
echo                     MAYA CINEMA PRO SERVER
echo ===================================================================
echo [1/2] Starting Unified Backend ^& Web Application on port 8000...

cd /d "%~dp0backend"
start /B venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000

timeout /t 2 /nobreak >nul

echo [2/2] Launching Free Cloudflare HTTPS Global Tunnel...
cd /d "%~dp0"
if exist tools\cloudflared.exe (
    start tools\cloudflared.exe tunnel --url http://localhost:8000
) else (
    echo Cloudflared binary not found in tools folder.
)

echo.
echo ===================================================================
echo   MAYA CINEMA IS NOW RUNNING!
echo.
echo   Local Web Access:       http://localhost:8000
echo   Local Network / Wi-Fi:  http://10.77.125.112:8000
echo   Android APK Download:   http://10.77.125.112:8000/apk
echo   Interactive API Docs:   http://localhost:8000/docs
echo ===================================================================
echo Keep this window open while streaming.
pause
