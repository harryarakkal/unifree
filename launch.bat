::
:: launch.bat
::

@echo off
setlocal enabledelayedexpansion

set "PROJECT_NAME=unifree"
:: Assuming the script's location is the current directory
set "SRC_DIR=%~dp0"

:: #######################################################
:: Override variables as needed                          #
:: This is the only section that should be modified      #
:: #######################################################

set "INSTALL_DIR=%SRC_DIR%"
set "CLONE_DIR=%INSTALL_DIR%\%PROJECT_NAME%"
set "VENV_DIR=%CLONE_DIR%\venv"
set "USE_VENV=true"
set "PROJECT_GIT_URL=https://github.com/ProjectUnifree/unifree.git"
set "PROJECT_GIT_BRANCH=main"
set "PYTHON_CMD=python.exe"

:: #######################################################
:: End of variables to override                          #
:: Do not modify anything below this line                #
:: #######################################################

goto Start

:: Helper Functions

:Usage
    echo "Usage: launch.bat <openai_api_key> <config_name> <source_directory> <destination_directory>"
    echo "  config_name can be one of: 'godot' 'unreal'."
    goto:eof

:Check_Empty
    if "%~1"=="" (
        echo "%~2 cannot be empty."
        call :Usage
        exit /b 1
    )
    goto:eof

:Try_Install_Dependencies
    :: Check for git installation
    where git >nul 2>&1
    if !errorlevel! neq 0 (
        echo "Git is not found."

        where winget >nul 2>&1
        if !errorlevel! neq 0 (
            echo "Please install Git and try again."
            exit /b 1
        ) else (
            echo "Installing Git..."
            winget install Git.Git
        )
    )

    :: Check for C++ build tools. 'cl' is the C++ compiler.
    where cl >nul 2>&1
    if !errorlevel! neq 0 (
        echo "Microsoft C++ build tools not found."

        where winget >nul 2>&1
        if !errorlevel! neq 0 (
            echo "Please install Microsoft C++ Build Tools and try again."
        ) else (
            echo "Installing Microsoft C++ Build Tools..."
            winget install Microsoft.VisualStudio.2022.BuildTools --override "--wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
        )

        echo "Once installed, please run this script from the 'Developer Command Prompt for Visual Studio'."
        echo "That command prompt has the needed environment variables for compiling C++ code."

        exit /b 1
    )

    :: Check for python installation
    where "%PYTHON_CMD%" >nul 2>&1
    if !errorlevel! neq 0 (
        echo "Python is not found."

        where winget >nul 2>&1
        if !errorlevel! neq 0 (
            echo "Please install Python and try again."
            exit /b 1
        ) else (
            echo "Installing Python..."
            winget install Python.Python.3.11
        )
    )

    :: Check that pip is installed
    "%PYTHON_CMD%" -m ensurepip
    if !errorlevel! neq 0 (
        echo "Installing pip..."
        "%PYTHON_CMD%" -m ensurepip --upgrade
    )

    goto:eof

:Activate_Venv
    if "%USE_VENV%"=="true" (
        echo "Creating and activating venv..."
        "%PYTHON_CMD%" -m venv "%VENV_DIR%"
        call "%VENV_DIR%\Scripts\activate.bat"
    )

    goto:eof

:Install_And_Activate_Venv_If_Needed
    if exist "%CLONE_DIR%\.installed" (
        echo "Project is already installed."

        cd "%CLONE_DIR%"
        call :Activate_Venv

        goto:eof
    )

    call :Try_Install_Dependencies || exit /b !errorlevel!

    :: Clone repo if not exists
    if exist "%CLONE_DIR%\unifree\free.py" (
        echo "Directory %CLONE_DIR% already exists."
    ) else (
        echo "Cloning git repo %PROJECT_GIT_URL% to %CLONE_DIR%..."
        git clone -b %PROJECT_GIT_BRANCH% %PROJECT_GIT_URL% "%CLONE_DIR%"
    )

    cd "%CLONE_DIR%"

    call :Activate_Venv

    pip.exe install -r requirements.txt

    if exist "%CLONE_DIR%\vendor\tree-sitter-c-sharp" (
        echo "Directory %CLONE_DIR%\vendor\tree-sitter-c-sharp already exists. Skipping cloning..."
    ) else (
        echo "Cloning git repo tree-sitter-c-sharp..."
        mkdir "%CLONE_DIR%\vendor\tree-sitter-c-sharp"
        git clone https://github.com/tree-sitter/tree-sitter-c-sharp.git "%CLONE_DIR%\vendor\tree-sitter-c-sharp"
    )

    :: touch .installed file
    echo "%date% %time%" > .installed
    echo "Installation done."

    goto:eof

:Start

echo "------------------------------------------------------------"

set "OPENAI_API_KEY=%1"
set "CONFIG_NAME=%2"
set "ORIGIN_DIR=%3"
set "DEST_DIR=%4"

if exist "%SRC_DIR%\.git" (
    echo "The current directory is a git repo, assuming it is the %PROJECT_NAME% repo."
    set "CLONE_DIR=%SRC_DIR%"
    set "VENV_DIR=!CLONE_DIR!\venv"
)

call :Install_And_Activate_Venv_If_Needed || exit /b !errorlevel!

echo "------------------------------------------------------------"

:: Exit if no arguments are defined.
if "%OPENAI_API_KEY%"=="" (
    echo "Installing only, run with launch.bat <openai_api_key> <config_name> <source_directory> <destination_directory>."
    exit /b 0
)

call :Check_Empty "%OPENAI_API_KEY%" "Argument - Open AI Api Key" || exit /b !errorlevel!
call :Check_Empty "%CONFIG_NAME%" "Argument - Config Name" || exit /b !errorlevel!
call :Check_Empty "%ORIGIN_DIR%" "Argument - Source Directory" || exit /b !errorlevel!
call :Check_Empty "%DEST_DIR%" "Argument - Destination Directory" || exit /b !errorlevel!

:run_main

set "PYTHONPATH=%PYTHONPATH%;!CLONE_DIR!"

@echo on
"%PYTHON_CMD%" "%CLONE_DIR%\unifree\free.py" -c "%CONFIG_NAME%" -k "%OPENAI_API_KEY%" -s "%ORIGIN_DIR%" -d "%DEST_DIR%"

exit /b
