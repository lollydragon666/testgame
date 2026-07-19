@echo off
title Dread Blocks LAN Server
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1" -Port 4173
pause
