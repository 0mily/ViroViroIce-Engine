@echo off
setlocal enabledelayedexpansion

REM ==========================================================
REM  AUTO SETUP + CONVERSOR RECURSIVO PARA .ASTC
REM  Coloque este .bat na pasta raiz das imagens.
REM  Ele baixa o ASTC Encoder se nao encontrar.
REM ==========================================================

set "BASE_DIR=%~dp0"
set "TOOLS_DIR=%BASE_DIR%_astc_tools"
set "ENCODER=%TOOLS_DIR%\astcenc.exe"

REM Versao do ASTC Encoder
set "ASTC_VERSION=5.3.0"
set "ASTC_ZIP=astcenc-%ASTC_VERSION%-windows-x64.zip"
set "ASTC_URL=https://github.com/ARM-software/astc-encoder/releases/download/%ASTC_VERSION%/%ASTC_ZIP%"
set "ASTC_ZIP_PATH=%TOOLS_DIR%\%ASTC_ZIP%"

REM Configuracoes da conversao
set "BLOCK_SIZE=6x6"
set "QUALITY=-medium"
set "MODE=-cs"

echo ==========================================
echo   Conversor automatico para ASTC
echo ==========================================
echo.

if not exist "%TOOLS_DIR%" (
    mkdir "%TOOLS_DIR%"
)

if not exist "%ENCODER%" (
    echo ASTC Encoder nao encontrado.
    echo Baixando automaticamente...
    echo.

    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "try { Invoke-WebRequest -Uri '%ASTC_URL%' -OutFile '%ASTC_ZIP_PATH%' -UseBasicParsing } catch { exit 1 }"

    if errorlevel 1 (
        echo.
        echo ERRO: Nao consegui baixar o ASTC Encoder.
        echo Verifique sua internet ou baixe manualmente:
        echo %ASTC_URL%
        echo.
        pause
        exit /b 1
    )

    echo Download concluido.
    echo Extraindo...
    echo.

    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "try { Expand-Archive -Path '%ASTC_ZIP_PATH%' -DestinationPath '%TOOLS_DIR%' -Force } catch { exit 1 }"

    if errorlevel 1 (
        echo.
        echo ERRO: Nao consegui extrair o arquivo ZIP.
        pause
        exit /b 1
    )

    REM Procura o executavel mais compativel/rapido disponivel
    if exist "%TOOLS_DIR%\bin\astcenc-avx2.exe" (
        copy /Y "%TOOLS_DIR%\bin\astcenc-avx2.exe" "%ENCODER%" >nul
    ) else if exist "%TOOLS_DIR%\bin\astcenc-sse4.1.exe" (
        copy /Y "%TOOLS_DIR%\bin\astcenc-sse4.1.exe" "%ENCODER%" >nul
    ) else if exist "%TOOLS_DIR%\bin\astcenc-sse2.exe" (
        copy /Y "%TOOLS_DIR%\bin\astcenc-sse2.exe" "%ENCODER%" >nul
    ) else (
        for /r "%TOOLS_DIR%" %%E in (astcenc*.exe) do (
            copy /Y "%%E" "%ENCODER%" >nul
            goto encoder_found
        )

        echo.
        echo ERRO: Nao achei nenhum astcenc.exe depois de extrair.
        pause
        exit /b 1
    )

    :encoder_found
    echo ASTC Encoder instalado em:
    echo "%ENCODER%"
    echo.
)

if not exist "%ENCODER%" (
    echo ERRO: astcenc.exe ainda nao foi encontrado.
    pause
    exit /b 1
)

echo Iniciando conversao...
echo Pasta base:
echo "%BASE_DIR%"
echo.
echo Configuracao:
echo   Modo: %MODE%
echo   Bloco: %BLOCK_SIZE%
echo   Qualidade: %QUALITY%
echo.

set /a COUNT=0
set /a FAILS=0

for /r "%BASE_DIR%" %%F in (*.png *.jpg *.jpeg *.bmp *.tga) do (
    echo "%%F" | find /I "\_astc_tools\" >nul
    if errorlevel 1 (
        set "INPUT=%%F"
        set "OUTPUT=%%~dpnF.astc"

        echo Convertendo:
        echo   "%%F"

        "%ENCODER%" %MODE% "%%F" "!OUTPUT!" %BLOCK_SIZE% %QUALITY%

        if errorlevel 1 (
            echo   ERRO!
            set /a FAILS+=1
        ) else (
            echo   OK: "!OUTPUT!"
            set /a COUNT+=1

            REM Apaga apenas arquivos .png apos conversao bem-sucedida
            if /I "%%~xF"==".png" (
                del "%%F"
                echo   PNG original apagado.
            )
        )

        echo.
    )
)

echo ==========================================
echo Conversao finalizada!
echo Convertidas: %COUNT%
echo Erros: %FAILS%
echo ==========================================
pause