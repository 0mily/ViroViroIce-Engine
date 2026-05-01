@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Use a pasta passada por argumento ou a pasta atual
set "ROOT=%~1"
if not defined ROOT set "ROOT=%CD%"

for %%I in ("%ROOT%") do set "ROOT=%%~fI"
if not exist "%ROOT%" (
    echo Pasta nao encontrada: "%ROOT%"
    pause
    exit /b 1
)

if not "%ROOT:~-1%"=="\" set "ROOT=%ROOT%\"

echo.
echo Pasta alvo: "%ROOT%"
echo.

call :MoveFolderContents "%ROOT%custom_events" "%ROOT%data\events"
call :MoveFolderContents "%ROOT%custom_notetypes" "%ROOT%data\notetypes"
call :MoveFolderContents "%ROOT%scripts" "%ROOT%data\scripts"

if exist "%ROOT%data" (
    for /d %%D in ("%ROOT%data\*") do (
        set "NAME=%%~nxD"

        if /I not "!NAME!"=="events" if /I not "!NAME!"=="notetypes" if /I not "!NAME!"=="scripts" (
            if not exist "%ROOT%songs\!NAME!" md "%ROOT%songs\!NAME!" >nul 2>nul
            if not exist "%ROOT%songs\!NAME!\events" md "%ROOT%songs\!NAME!\events" >nul 2>nul
            if not exist "%ROOT%songs\!NAME!\chart" md "%ROOT%songs\!NAME!\chart" >nul 2>nul

            REM Move .lua e .hx para songs\<song>\
            for %%F in ("%%~fD\*.lua" "%%~fD\*.hx") do (
                if exist "%%~fF" move /y "%%~fF" "%ROOT%songs\!NAME!\" >nul
            )

            REM Move events.json para songs\<song>\events\
            if exist "%%~fD\events.json" (
                move /y "%%~fD\events.json" "%ROOT%songs\!NAME!\events\" >nul
            )

            REM Move o resto para chart
            for %%F in ("%%~fD\*") do (
                set "FILE=%%~nxF"
                set "EXT=%%~xF"

                if /I not "!FILE!"=="events.json" (
                    if /I not "!EXT!"==".lua" (
                        if /I not "!EXT!"==".hx" (
                            if exist "%%~fF" move /y "%%~fF" "%ROOT%songs\!NAME!\chart\" >nul
                        )
                    )
                )
            )

            rd "%%~fD" 2>nul
        )
    )
)

if exist "%ROOT%songs" (
    for /d %%S in ("%ROOT%songs\*") do (
        if not exist "%%~fS\song" md "%%~fS\song" >nul 2>nul

        for %%F in ("%%~fS\*.ogg") do (
            if exist "%%~fF" move /y "%%~fF" "%%~fS\song\" >nul
        )
    )
)

echo.
echo Mod reorganizado com sucesso!
pause
exit /b 0

:MoveFolderContents
REM %1 = pasta origem
REM %2 = pasta destino
if exist "%~1" (
    if not exist "%~2" md "%~2" >nul 2>nul

    for /f "delims=" %%F in ('dir /b /a-d "%~1" 2^>nul') do (
        move /y "%~1\%%F" "%~2\" >nul
    )

    REM remove a pasta de origem se ficou vazia
    rd "%~1" 2>nul
)
exit /b