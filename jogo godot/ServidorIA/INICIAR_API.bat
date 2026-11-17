@echo off
cd /d "%~dp0"
if not exist .venv\Scripts\python.exe (
echo Execute PREPARAR_API.bat primeiro.
pause
exit /b 1
)
.venv\Scripts\python.exe -m uvicorn api.servidor:app --host 127.0.0.1 --port 8000
pause
