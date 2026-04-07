@echo off
REM Transparent wrapper for claude.exe that auto-configures HTTP proxy.
REM Detects Windows system proxy state from registry:
REM   - System proxy ON  -> set HTTP_PROXY/HTTPS_PROXY (Node.js does not read Windows system proxy)
REM   - System proxy OFF -> assume TUN mode or direct connection, no env vars
REM
REM This file MUST be earlier in PATH than the real claude.exe at:
REM   C:\Users\ASUS\.local\bin\claude.exe

set "ProxyEnable="
for /f "tokens=3" %%a in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyEnable 2^>nul') do set "ProxyEnable=%%a"

if /i not "%ProxyEnable%"=="0x1" goto :launch

set "ProxyServer=127.0.0.1:7890"
for /f "tokens=2*" %%a in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v ProxyServer 2^>nul') do set "ProxyServer=%%b"
set "HTTP_PROXY=http://%ProxyServer%"
set "HTTPS_PROXY=http://%ProxyServer%"

:launch
"C:\Users\ASUS\.local\bin\claude.exe" %*
