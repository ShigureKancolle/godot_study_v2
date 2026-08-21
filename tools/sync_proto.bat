@echo off
setlocal

rem Optional: set GODOT_BIN before running this file when Godot is not on PATH.
if not defined GODOT_BIN if exist "C:\work\godot\Godot_v4.6.3-stable_win64.exe" set "GODOT_BIN=C:\work\godot\Godot_v4.6.3-stable_win64.exe"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync_proto.ps1" -GodotExecutable "%GODOT_BIN%"
set "SYNC_EXIT_CODE=%ERRORLEVEL%"

if not "%SYNC_EXIT_CODE%"=="0" (
    echo.
    echo Proto sync failed with exit code %SYNC_EXIT_CODE%.
) else (
    echo.
    echo Proto sync completed successfully.
)

pause
exit /b %SYNC_EXIT_CODE%
