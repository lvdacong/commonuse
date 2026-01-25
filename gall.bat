@echo off
setlocal enabledelayedexpansion

echo ============================================
echo Updating all git repositories in C:\data
echo ============================================
echo.

set "count=0"
set "success=0"
set "failed=0"

for /d %%D in (C:\data\*) do (
    if exist "%%D\.git" (
        set /a count+=1
        echo [!count!] Processing: %%~nxD
        echo --------------------------------------------
        pushd "%%D"

        git add .
        git commit -m "1"
        git push

        if !errorlevel! equ 0 (
            set /a success+=1
            echo [OK] %%~nxD updated successfully
        ) else (
            set /a failed+=1
            echo [WARN] %%~nxD may have issues
        )

        popd
        echo.
    )
)

echo ============================================
echo Summary: !count! repositories processed
echo ============================================
echo Done!!!!!!!!!!!!!!

endlocal
