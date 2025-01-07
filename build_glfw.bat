@echo off

if not exist "build\windows" mkdir "build\windows"

call odin.exe build src -target:windows_amd64 -out:build/windows/wgpu_debug.exe -subsystem:windows -debug
