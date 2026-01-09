@echo off
REM =============================
REM Rye Hunter Love2D Launcher
REM =============================

REM Path to local Love2D executable
set "LOVE_PATH=%~dp0love2d\love.exe"

REM Change directory to the project root
cd /d "%~dp0"

REM Launch Love2D with current folder as game
"%LOVE_PATH%" .

pause
