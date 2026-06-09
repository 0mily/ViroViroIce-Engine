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

REM Pastas globais antigas para o novo formato dentro de data\
call :MoveFolderContents "%ROOT%custom_events" "%ROOT%data\events"
call :MoveFolderContents "%ROOT%custom_notetypes" "%ROOT%data\notetypes"
call :MoveFolderContents "%ROOT%scripts" "%ROOT%data\scripts"
call :MoveFolderContents "%ROOT%characters" "%ROOT%data\chrs"
call :MoveFolderContents "%ROOT%stages" "%ROOT%data\stages"
call :MoveFolderContents "%ROOT%weeks" "%ROOT%data\levels"

REM Converte data\<musica>\ para songs\<musica>\
if exist "%ROOT%data" (
    for /d %%D in ("%ROOT%data\*") do (
        set "NAME=%%~nxD"

        REM Estas pastas ja sao globais de data\, nao sao musicas.
        if /I not "!NAME!"=="events" if /I not "!NAME!"=="notetypes" if /I not "!NAME!"=="scripts" if /I not "!NAME!"=="chrs" if /I not "!NAME!"=="stages" if /I not "!NAME!"=="levels" (
            if not exist "%ROOT%songs\!NAME!" md "%ROOT%songs\!NAME!" >nul 2>nul
            if not exist "%ROOT%songs\!NAME!\events" md "%ROOT%songs\!NAME!\events" >nul 2>nul
            if not exist "%ROOT%songs\!NAME!\chart" md "%ROOT%songs\!NAME!\chart" >nul 2>nul

            REM Move .lua e .hx para songs\<musica>\
            for %%F in ("%%~fD\*.lua" "%%~fD\*.hx") do (
                if exist "%%~fF" move /y "%%~fF" "%ROOT%songs\!NAME!\" >nul
            )

            REM Move events.json para songs\<musica>\events\
            if exist "%%~fD\events.json" (
                move /y "%%~fD\events.json" "%ROOT%songs\!NAME!\events\" >nul
            )

            REM Move os charts para songs\<musica>\chart\ e renomeia:
            REM <musica>.json vira normal.json
            REM <musica>-hard.json vira hard.json
            REM <musica>-easy.json vira easy.json
            REM <musica>-custom.json vira custom.json
            for %%F in ("%%~fD\*.*") do (
                set "FILE=%%~nxF"
                set "EXT=%%~xF"

                if /I not "!FILE!"=="events.json" (
                    if /I not "!EXT!"==".lua" (
                        if /I not "!EXT!"==".hx" (
                            if exist "%%~fF" call :MoveAsChart "%%~fF" "!NAME!" "%ROOT%songs\!NAME!\chart"
                        )
                    )
                )
            )

            rd "%%~fD" 2>nul
        )
    )
)

REM Ajusta arquivos que ja estavam em songs\<musica>\
if exist "%ROOT%songs" (
    for /d %%S in ("%ROOT%songs\*") do (
        set "SONG=%%~nxS"
        if not exist "%%~fS\song" md "%%~fS\song" >nul 2>nul
        if not exist "%%~fS\chart" md "%%~fS\chart" >nul 2>nul

        REM Audios ficam em songs\<musica>\song\
        for %%F in ("%%~fS\*.ogg") do (
            if exist "%%~fF" move /y "%%~fF" "%%~fS\song\" >nul
        )

        REM Charts soltos na pasta da musica vao para chart\ com o novo nome.
        for %%F in ("%%~fS\*.json") do (
            if exist "%%~fF" call :MoveAsChart "%%~fF" "!SONG!" "%%~fS\chart"
        )

        REM Charts que ja estavam em chart\ tambem sao normalizados.
        for %%F in ("%%~fS\chart\*.json") do (
            if exist "%%~fF" call :MoveAsChart "%%~fF" "!SONG!" "%%~fS\chart"
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

    REM Move arquivos e subpastas sem achatar estrutura interna.
    for /f "delims=" %%F in ('dir /b "%~1" 2^>nul') do (
        move /y "%~1\%%F" "%~2\" >nul
    )

    REM remove a pasta de origem se ficou vazia
    rd "%~1" 2>nul
)
exit /b

:MoveAsChart
REM %1 = arquivo origem
REM %2 = nome da musica/pasta
REM %3 = pasta chart destino
set "SRC=%~1"
set "SONGNAME=%~2"
set "DEST=%~3"
set "BASE=%~n1"
set "EXT=%~x1"
set "OUT=%~nx1"

if not exist "%DEST%" md "%DEST%" >nul 2>nul

if /I "%EXT%"==".json" (
    if /I "%BASE%"=="%SONGNAME%" (
        set "OUT=normal.json"
    ) else (
        set "PREFIX=%SONGNAME%-"
        call :StrLen "!PREFIX!" PREFIXLEN
        call set "HEAD=%%BASE:~0,!PREFIXLEN!%%"
        call set "REST=%%BASE:~!PREFIXLEN!%%"

        REM Se o arquivo comeca com o nome da musica + "-", tudo depois disso e a dificuldade.
        REM Ex.: dad-battle-hard.json -> hard.json; dad-battle.json -> normal.json
        if /I "!HEAD!"=="!PREFIX!" if not "!REST!"=="" set "OUT=!REST!.json"
    )
)

if /I "%SRC%"=="%DEST%\!OUT!" (
    exit /b
)

move /y "%SRC%" "%DEST%\!OUT!" >nul
exit /b

:StrLen
REM %1 = string
REM %2 = variavel de saida
setlocal EnableDelayedExpansion
set "STR=%~1"
set /a LEN=0
:StrLenLoop
if defined STR (
    set "STR=!STR:~1!"
    set /a LEN+=1
    goto StrLenLoop
)
endlocal & set "%~2=%LEN%"
exit /b
