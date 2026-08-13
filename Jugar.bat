@echo off
rem Arranca Writer Fighter sin abrir el editor de Godot.
rem Doble clic y a jugar. Si Godot cambia de sitio, ajustar la ruta.
start "" "%LOCALAPPDATA%\Microsoft\WinGet\Links\godot.exe" --path "%~dp0."
