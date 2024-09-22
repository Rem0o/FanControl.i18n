@echo off
rem -----------------------------------------------------------------------------
rem Script to compare JSON keys and check for additions/removals.
rem 
rem Created by: ChatGPT (OpenAI) <https://chatgpt.com/>
rem Input provided by: Caio Oliveira (Caio99BR@GitHub)
rem License: MIT License
rem -----------------------------------------------------------------------------

rem Check if a suffix was passed as an argument, otherwise use "pt-BR"
set "suffix=%~1"
if "%suffix%"=="" set "suffix=pt-BR"

echo Using suffix: %suffix%
echo.

rem Check if jq or jq-windows-amd64.exe is installed
set "jq_executable="
where jq >nul 2>&1
if %errorlevel% neq 0 (
    if exist "jq-windows-amd64.exe" set "jq_executable=jq-windows-amd64.exe"
    if not defined jq_executable (
        echo.
        echo Neither jq nor jq-windows-amd64.exe was found. Please install jq before running this script.
        echo Available at: https://jqlang.github.io/jq/download/
        echo.
        pause
        exit /b 1
    )
) else (
    set "jq_executable=jq"
)

setlocal enabledelayedexpansion

rem Define the base directory as the location of the script
set "base_dir=%~dp0"

rem Loop through all folders in the base directory
for /d %%D in ("%base_dir%*") do (
    set "current_folder=%%D"
    set "base_file=!current_folder!\%%~nxD.json"
    set "translated_file=!current_folder!\%%~nxD.%suffix%.json"

    rem Check if the files exist
    if exist "!base_file!" (
        if exist "!translated_file!" (
            rem Validate JSON
            %jq_executable% empty "!base_file!" >nul 2>&1
            if errorlevel 1 (
                echo Invalid JSON in file "!base_file!": 
                %jq_executable% empty "!base_file!"
                echo.
            ) else (
                %jq_executable% empty "!translated_file!" >nul 2>&1
                if errorlevel 1 (
                    echo Invalid JSON in file "!translated_file!": 
                    %jq_executable% empty "!translated_file!"
                    echo.
                ) else (
                    set "unexpected_keys="
                    set "new_keys="

                    rem Store base keys in an array
                    for /f "delims=" %%K in ('%jq_executable% -r "keys[]" "!base_file!"') do (
                        set "key_%%K=1"
                    )

                    rem Check for keys in translated file
                    for /f "delims=" %%L in ('%jq_executable% -r "keys[]" "!translated_file!"') do (
                        if defined key_%%L (
                            set "key_%%L="
                        ) else (
                            set "unexpected_keys=!unexpected_keys!%%L "
                        )
                    )

                    rem Check for new keys in base file
                    for /f "delims=" %%K in ('%jq_executable% -r "keys[]" "!base_file!"') do (
                        if defined key_%%K (
                            set "new_keys=!new_keys!%%K "
                        )
                    )

                    rem Display results
                    if defined unexpected_keys (
                        echo - ERROR: UNEXPECTED KEYS ON "!translated_file!":
                        echo !unexpected_keys!
                        echo.
                    )

                    if defined new_keys (
                        echo + NEW: KEYS TO TRANSLATE ON "!base_file!":
                        echo !new_keys!
                        echo.
                    )
                )
            )
        ) else (
            echo Translated file not found: "!translated_file!"
        )
    ) else (
        echo Base file not found: "!base_file!"
    )
)

echo Done.
pause
