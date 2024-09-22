@echo off
rem -----------------------------------------------------------------------------
rem Script to compare JSON keys and check for additions/removals.
rem 
rem Created by: ChatGPT (OpenAI) <https://chatgpt.com/>
rem Input provided/Modified by: Caio Oliveira (Caio99BR@GitHub)
rem License: MIT License
rem -----------------------------------------------------------------------------

rem Initialize variables
set "__NAME=FanControl Json LangControl i18n"
set "__VERSION=1.2"
set "update=0"
set "cleanup=0"
set "prettify=0"
set "all=0"

rem Handle command-line arguments
:parse
if "%~1"=="" goto :validate
if /i "%~1"=="-h" goto :usage
if /i "%~1"=="--help" goto :usage
if /i "%~1"=="-v" call :version & exit /b
if /i "%~1"=="--version" call :version full & exit /b
if /i "%~1"=="--update" (set "update=1" & shift)
if /i "%~1"=="--cleanup" (set "cleanup=1" & shift)
if /i "%~1"=="--prettify" (set "prettify=1" & shift)
if /i "%~1"=="--all" (set "all=1" & shift)

goto :validate

:validate
goto :main

:usage
    echo USAGE:
    echo   %__NAME% [OPTIONS]
    echo.
    echo   OPTIONS:
    echo     -h, --help       Show this help message.
    echo     -v, --version    Show the version of the script.
    echo     --update         Add new keys from the base file to translated files.
    echo     --cleanup        Remove old/unexpected keys from translated files.
    echo     --prettify       Format JSON files with pretty printing.
    echo     --all            Include base translation when processing.
    echo.
    exit /b

:version
    echo %__NAME% v%__VERSION%
    exit /b

:main
echo.

rem Check if jq or jq-windows-amd64.exe is installed
set "jq_executable="
where jq >nul 2>&1 || if exist "jq-windows-amd64.exe" set "jq_executable=jq-windows-amd64.exe"
if not defined jq_executable (
    echo.
    echo ERROR: Neither jq nor jq-windows-amd64.exe was found. Please install jq before running this script.
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

    rem Include base translation file if --all is set
    if "!all!"=="1" call :process_files "!base_file!" "!base_file!"

    for %%S in (!current_folder!\*.json) do (
        if /i not "%%~nS"=="%%~nD" (
            call :process_files "!base_file!" "%%S"
        )
    )
)

echo Done.
pause
exit /b

:process_files
set "base_file=%~1"
set "translated_file=%~2"

rem Check if the files exist and validate JSON
if not exist "%base_file%" (
    echo ERROR: Base file not found: %base_file%
    exit /b
)
if not exist "%translated_file%" (
    echo ERROR: Translated file not found: %translated_file%
    exit /b
)

rem Validate JSON files
for %%F in ("%base_file%" "%translated_file%") do (
    %jq_executable% empty "%%F" >nul 2>&1 || (
        echo ERROR: Invalid JSON in file: %%F
        exit /b
    )
)

set "unexpected_keys="
set "new_keys="

rem Store base keys in an array
for /f "delims=" %%K in ('%jq_executable% -r "keys[]" "%base_file%"') do set "key_%%K=1"

rem Compare with translated file keys
for /f "delims=" %%L in ('%jq_executable% -r "keys[]" "%translated_file%"') do (
    if defined key_%%L (
        set "key_%%L="
    ) else (
        set "unexpected_keys=!unexpected_keys!%%L "
    )
)

rem Check for new keys in base file
for /f "delims=" %%K in ('%jq_executable% -r "keys[]" "%base_file%"') do (
    if defined key_%%K (
        set "new_keys=!new_keys!%%K "
    )
)

rem Display unexpected keys if found
if defined unexpected_keys (
    echo - ERROR: UNEXPECTED KEYS ON "%translated_file%":
    for %%K in (!unexpected_keys!) do echo %%K
    echo.
)

rem Display new keys if found
if defined new_keys (
    echo + NEW KEYS TO TRANSLATE ON "%base_file%":
    for %%K in (!new_keys!) do echo %%K
    echo.
)

rem If --update is set, add new keys to the translated file
if "!update!"=="1" (
    for %%K in (!new_keys!) do (
        set "new_value="
        for /f "delims=" %%V in ('%jq_executable% -r ".%%K" "%base_file%"') do set "new_value=%%V"
        if defined new_value (
            echo Adding key: %%K
            %jq_executable% --join-output --binary --sort-keys --arg key "%%K" --arg value "!new_value!" ". + {($key): $value}" "%translated_file%" > "%translated_file%.tmp"
            move /y "%translated_file%.tmp" "%translated_file%" >nul
        )
    )
)

rem If --cleanup is set, remove unexpected keys
if "!cleanup!"=="1" (
    for %%K in (!unexpected_keys!) do (
        echo Removing unexpected key: %%K
        %jq_executable% --join-output --binary --sort-keys "del(.%%K)" "%translated_file%" > "%translated_file%.tmp"
        move /y "%translated_file%.tmp" "%translated_file%" >nul
    )
)

rem If --prettify is set, format the JSON files with prettify options
if "!prettify!"=="1" (
    %jq_executable% --sort-keys "." "%translated_file%" > "%translated_file%.tmp"
    fc /b "%translated_file%" "%translated_file%.tmp" >nul
    if errorlevel 1 (
        move /y "%translated_file%.tmp" "%translated_file%" >nul
        echo Prettified %translated_file%.
    ) else (
        del "%translated_file%.tmp"
    )
)
goto :eof
