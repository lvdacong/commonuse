@echo off
chcp 65001 >nul 2>&1
echo 正在删除当前目录下的 nul 文件...

:: 方法1: 使用 Git Bash 的 rm 命令（如果安装了 Git）
where git >nul 2>&1
if %errorlevel%==0 (
    git bash -c "rm -f '%cd%/nul'" 2>nul
    if not exist "%cd%\nul" (
        echo 删除成功！（通过 Git Bash）
        pause
        exit /b 0
    )
)

:: 方法2: 使用 \\?\ 前缀
del "\\?\%cd%\nul" 2>nul
if not exist "\\?\%cd%\nul" (
    echo 删除成功！
    pause
    exit /b 0
)

:: 方法3: 使用 fsutil
fsutil file setZeroData offset=0 length=0 "\\?\%cd%\nul" >nul 2>&1
del "\\?\%cd%\nul" 2>nul

echo 如果仍未删除，请在 Git Bash 中运行: rm nul
pause
