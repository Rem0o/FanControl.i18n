@echo off
rem -----------------------------------------------------------------------------
rem Script to compare JSON keys and check for additions/removals.
rem 
rem Created by: ChatGPT (OpenAI) <https://chatgpt.com/>
rem Input provided by: Caio Oliveira (Caio99BR@GitHub)
rem License: MIT License
rem -----------------------------------------------------------------------------

rem Initialize variables
set "__NAME=FanControl Json LangControl i18n"
set "__VERSION=1.1"
set "suffix=pt-BR"
set "override=0"

rem Handle command-line arguments
:parse
if "%~1"=="" goto :validate
if /i "%~1"=="-h" goto :usage
if /i "%~1"=="--help" goto :usage
if /i "%~1"=="-v" call :version & exit /b
if /i "%~1"=="--version" call :version full & exit /b

if /i "%~1"=="--override" (
    set "override=1"
    shift
    goto :parse
)

rem Set suffix if provided
if not "%~1"=="" (
    set "suffix=%~1"
)

shift
goto :parse

:validate
goto :main

:usage
    echo USAGE:
    echo   %__NAME% [suffix] [--override]
    echo.
    echo   -h, --help       shows this help
    echo   -v, --version    shows the version
    exit /b

:version
    echo %__NAME% v%__VERSION%
    exit /b

:main
echo Using suffix: %suffix%
echo Override mode: %override%
echo.

rem Check if jq or jq-windows-amd64.exe is installed
set "jq_executable="
where jq >nul 2>&1 || if exist "jq-windows-amd64.exe" set "jq_executable=jq-windows-amd64.exe"
if not defined jq_executable (
    echo.
    echo Neither jq nor jq-windows-amd64.exe was found. Please install jq before running this script.
    echo Available at: https://jqlang.github.io/jq/download/
    echo.
    pause
    exit /b 1
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

                    rem Compare with translated file keys
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

                    rem Display unexpected keys if found
                    if defined unexpected_keys (
                        echo - ERROR: UNEXPECTED KEYS ON "!translated_file!":
                        echo !unexpected_keys!
                        echo.
                    )

                    rem Display new keys if found
                    if defined new_keys (
                        echo + NEW: KEYS TO TRANSLATE ON "!base_file!":
                        echo !new_keys!
                        echo.
                    )

                    rem If --override is set, add new keys to the translated file
                    if "!override!"=="1" (
                        for %%K in (!new_keys!) do (
                            set "new_value="
                            for /f "delims=" %%V in ('%jq_executable% -r ".%%K" "!base_file!"') do set "new_value=%%V"
                            if defined new_value (
                                echo Adding key: %%K
                                %jq_executable% --arg key "%%K" --arg value "!new_value!" ". + {($key): $value}" "!translated_file!" > "!translated_file!.tmp"
                                move /y "!translated_file!.tmp" "!translated_file!" >nul
                            )
                        )
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
