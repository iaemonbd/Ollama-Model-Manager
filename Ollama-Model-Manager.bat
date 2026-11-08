@echo off
title Ollama Model Manager
color 0B
setlocal enabledelayedexpansion

set "BASE_DIR=D:\AI MODEL"
if not exist "%BASE_DIR%" mkdir "%BASE_DIR%" >nul 2>nul
cd /d "%BASE_DIR%"

where ollama >nul 2>nul
if errorlevel 1 (
    color 0C
    echo.
    echo  ERROR: "ollama" was not found on your PATH.
    echo  Install it from https://ollama.com and re-run this script.
    color 0B
    pause
    exit /b
)

:MENU
cls
echo ===================================================
echo               OLLAMA MODEL MANAGER
echo ===================================================
echo  Models folder: %BASE_DIR%
echo ===================================================
echo.
echo  [1] Install a model from a local GGUF file
echo  [2] Download a model from Hugging Face
echo  [3] Edit system prompt / settings of an existing model
echo  [4] Uninstall a model
echo  [5] List installed models
echo  [6] Run a model
echo  [7] Exit
echo.
set /p CHOICE="Select option (1-7): "

if "%CHOICE%"=="1" goto INSTALL_LOCAL
if "%CHOICE%"=="2" goto INSTALL_HF
if "%CHOICE%"=="3" goto EDIT_MODEL
if "%CHOICE%"=="4" goto UNINSTALL
if "%CHOICE%"=="5" goto LIST
if "%CHOICE%"=="6" goto RUN
if "%CHOICE%"=="7" exit
goto MENU

:: ============================================================
:: 1) INSTALL FROM LOCAL GGUF
:: ============================================================
:INSTALL_LOCAL
cls
echo ===================================================
echo        INSTALL FROM A LOCAL GGUF FILE
echo ===================================================
echo.
echo Available .gguf files in %BASE_DIR%:
echo ---------------------------------------------------
dir /b "%BASE_DIR%\*.gguf" 2>nul || echo  (No .gguf files found here)
echo ---------------------------------------------------
echo.
set /p GGUF_FILE="Enter GGUF filename (with .gguf): "
set /p MODEL_NAME="Enter a name for this model in Ollama: "

if not exist "%BASE_DIR%\%GGUF_FILE%" (
    color 0C
    echo ERROR: File "%GGUF_FILE%" not found in %BASE_DIR%
    pause & color 0B & goto MENU
)

cls
echo ===================================================
echo         CONTEXT WINDOW SIZE
echo ===================================================
echo  Larger contexts use more RAM.
echo.
echo  [1] 4K Context  (Recommended for 8GB RAM - Stable)
echo  [2] 8K Context  (Balanced - may use disk swap)
echo  [3] 16K+ Context (Heavy - may lag / run out of memory)
echo.
set /p CTX_CHOICE="Select Context Window Size (1-3): "

set CTX_SIZE=4096
if "%CTX_CHOICE%"=="2" set CTX_SIZE=8192
if "%CTX_CHOICE%"=="3" set CTX_SIZE=16384

set "HAS_PROMPT=0"
set /p WANT_PROMPT="Set a custom system prompt for this model? (y/n): "
if /i "%WANT_PROMPT%"=="y" call :GET_SYSTEM_PROMPT & set "HAS_PROMPT=1"

cls
echo Writing Modelfile...
echo Context: %CTX_SIZE% tokens ^| Threads: 6

(
echo FROM "./%GGUF_FILE%"
echo PARAMETER num_ctx %CTX_SIZE%
echo PARAMETER num_thread 6
if "%HAS_PROMPT%"=="1" (
    echo SYSTEM """
    type "%PROMPT_CLEAN%"
    echo """
)
) > Modelfile

echo.
echo Building model in Ollama...
echo.
ollama create "%MODEL_NAME%" -f Modelfile

if %ERRORLEVEL%==0 (
    color 0A
    echo.
    echo ===================================================
    echo  SUCCESS: "%MODEL_NAME%" is ready.
    echo ===================================================
    color 0B
) else (
    color 0C
    echo ERROR: Model build failed. Modelfile contents:
    echo.
    type Modelfile
    color 0B
)

if defined PROMPT_FILE del "%PROMPT_FILE%" 2>nul
if defined PROMPT_CLEAN del "%PROMPT_CLEAN%" 2>nul
set "PROMPT_FILE="
set "PROMPT_CLEAN="
del Modelfile 2>nul
pause
goto MENU

:: ============================================================
:: 2) DOWNLOAD FROM HUGGING FACE
:: ============================================================
:INSTALL_HF
cls
echo ===================================================
echo       DOWNLOAD A MODEL FROM HUGGING FACE
echo ===================================================
echo.
echo  Enter a Hugging Face GGUF repo, e.g.:
echo    bartowski/Llama-3.2-3B-Instruct-GGUF
echo    bartowski/Llama-3.2-3B-Instruct-GGUF:Q4_K_M   (specific quant)
echo.
echo  Browse quantizations at https://huggingface.co/models?library=gguf
echo.
set /p HF_REPO="Hugging Face repo (user/repo[:quant]): "
if "%HF_REPO%"=="" goto MENU

echo.
echo Pulling hf.co/%HF_REPO% ...
echo (Ollama downloads the GGUF and registers it automatically)
echo.
ollama pull hf.co/%HF_REPO%

if %ERRORLEVEL%==0 (
    color 0A
    echo.
    echo SUCCESS: hf.co/%HF_REPO% is ready.
    echo Run it anytime with: ollama run hf.co/%HF_REPO%
    echo Want a custom system prompt on it? Use option [3] and enter
    echo the same name: hf.co/%HF_REPO%
    color 0B
) else (
    color 0C
    echo ERROR: Download failed. Check the repo name, quant tag, and
    echo your internet connection.
    color 0B
)
pause
goto MENU

:: ============================================================
:: 3) EDIT SYSTEM PROMPT / SETTINGS OF AN EXISTING MODEL
:: ============================================================
:EDIT_MODEL
cls
echo ===================================================
echo   EDIT AN EXISTING MODEL'S SYSTEM PROMPT / SETTINGS
echo ===================================================
echo.
ollama list
echo.
set /p EDIT_NAME="Enter the exact model name to edit: "
if "%EDIT_NAME%"=="" goto MENU

set "MF_FILE=%TEMP%\ollama_modelfile_%RANDOM%.txt"
ollama show "%EDIT_NAME%" --modelfile > "%MF_FILE%" 2>nul

if not exist "%MF_FILE%" (
    color 0C
    echo ERROR: Could not find model "%EDIT_NAME%".
    color 0B
    pause
    goto MENU
)

echo.
echo Notepad will open with this model's current Modelfile.
echo Edit the SYSTEM """ ... """ block (or any PARAMETER line),
echo then save and close Notepad to continue.
pause
notepad "%MF_FILE%"

echo.
echo Rebuilding "%EDIT_NAME%" with your changes...
ollama create "%EDIT_NAME%" -f "%MF_FILE%"

if %ERRORLEVEL%==0 (
    color 0A
    echo.
    echo SUCCESS: "%EDIT_NAME%" updated.
    color 0B
) else (
    color 0C
    echo ERROR: Update failed - check the Modelfile syntax.
    color 0B
)
del "%MF_FILE%" 2>nul
pause
goto MENU

:: ============================================================
:: 4) UNINSTALL
:: ============================================================
:UNINSTALL
cls
echo ===================================================
echo              UNINSTALL A MODEL
echo ===================================================
echo.
ollama list
echo.
set /p DEL_NAME="Enter model name to remove: "
if "%DEL_NAME%"=="" goto MENU

set /p CONFIRM="Delete '%DEL_NAME%' permanently? (y/n): "
if /i "%CONFIRM%"=="y" (
    ollama rm "%DEL_NAME%"
    if %ERRORLEVEL%==0 (
        color 0A
        echo SUCCESS: "%DEL_NAME%" removed.
        color 0B
    ) else (
        color 0C
        echo ERROR: Model not found.
        color 0B
    )
) else (
    echo Cancelled.
)
pause
goto MENU

:: ============================================================
:: 5) LIST
:: ============================================================
:LIST
cls
echo ===================================================
echo              INSTALLED MODELS
echo ===================================================
echo.
ollama list
echo.
pause
goto MENU

:: ============================================================
:: 6) RUN
:: ============================================================
:RUN
cls
echo ===================================================
echo                  RUN A MODEL
echo ===================================================
echo.
ollama list
echo.
set /p RUN_NAME="Enter model name to run: "
if "%RUN_NAME%"=="" goto MENU
cls
echo Starting %RUN_NAME% ... (type /bye to exit the chat)
echo.
ollama run "%RUN_NAME%"
echo.
echo Session ended.
pause
goto MENU

:: ============================================================
:: Subroutine: open Notepad for a multi-line system prompt,
:: strip lines starting with # (instructions), leave result
:: in PROMPT_CLEAN
:: ============================================================
:GET_SYSTEM_PROMPT
set "PROMPT_FILE=%TEMP%\ollama_sysprompt_%RANDOM%.txt"
set "PROMPT_CLEAN=%PROMPT_FILE%.clean"
(
echo # Write the system prompt for this model below.
echo # Lines starting with # are instructions and are removed automatically.
echo # Save and close Notepad when you're done.
echo.
) > "%PROMPT_FILE%"
notepad "%PROMPT_FILE%"
findstr /v /b "#" "%PROMPT_FILE%" > "%PROMPT_CLEAN%" 2>nul
exit /b
