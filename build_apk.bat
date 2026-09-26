@echo off
rem Сборка APK «Литр До Дома» (обёртка над build_apk.ps1).
rem Запуск: build_apk.bat                 - обычная release-сборка
rem         build_apk.bat -Icons -Sounds  - иконка и звуки
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_apk.ps1" %*
set RESULT=%ERRORLEVEL%
endlocal & exit /b %RESULT%
