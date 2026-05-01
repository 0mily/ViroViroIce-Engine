<# :
@echo off
echo Iniciando limpeza de mp3, atualizacao de stages e renomeacao dos charts...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Command -ScriptBlock ([Scriptblock]::Create((Get-Content -LiteralPath '%~f0' -Raw)))"
echo.
echo Processo concluido com sucesso!
pause
exit /b
#>

# 1. Remove todos os arquivos .mp3 recursivamente
Write-Host "Procurando e removendo arquivos .mp3..." -ForegroundColor Cyan
Get-ChildItem -Path . -Filter *.mp3 -Recurse | Remove-Item -Force

# Dicionário de conversão de stages
$stageMap = @{
    'stage' = 'mainStage'
    'spooky' = 'spookyMansion'
    'philly' = 'phillyTrain'
    'limo' = 'limoRide'
    'mall' = 'mallXmas'
    'mallEvil' = 'mallXmasEvil'
    'school' = 'schoolPixel'
    'schoolEvil' = 'schoolPixelEvil'
    'tank' = 'tankmanBattlefield'
    'phillyStreetsErect' = 'phillyStreetErect'
}

Write-Host "Processando arquivos .json (Charts)..." -ForegroundColor Cyan
$jsonFiles = Get-ChildItem -Path . -Filter *.json -Recurse

foreach ($file in $jsonFiles) {
    # Ignora arquivos de metadata/events caso estejam misturados na pasta
    if ($file.BaseName -match '^(events|meta|metadata|inst|voices)$' -and $file.Directory.Name -notmatch 'chart') {
        continue
    }

    $content = Get-Content -Raw -Path $file.FullName

    # 2. Atualizar os stages dentro do JSON via Regex
    foreach ($key in $stageMap.Keys) {
        $val = $stageMap[$key]
        # Procura por "stage": "nome_antigo" considerando possíveis espaços
        $pattern = '"stage"\s*:\s*"' + [regex]::Escape($key) + '"'
        $replacement = '"stage": "' + $val + '"'
        $content = $content -replace $pattern, $replacement
    }
    
    # Salva o arquivo com os stages corrigidos
    Set-Content -Path $file.FullName -Value $content -NoNewline

    # 3. Renomear o arquivo para a dificuldade
    $baseName = $file.BaseName
    $newName = ""
    
    # Se tiver um hífen (ex: bopeebo-hard), pega o que vem depois
    if ($baseName -match '-(.*)$') {
        $newName = "$($matches[1]).json"
    } else {
        # Se não tiver hífen (ex: bopeebo), assume que é o normal
        $newName = "normal.json"
    }

    $newPath = Join-Path -Path $file.DirectoryName -ChildPath $newName
    
    # Só renomeia se o nome for diferente e o arquivo destino ainda não existir
    if ($file.FullName -ne $newPath) {
        if (-not (Test-Path $newPath)) {
            Rename-Item -Path $file.FullName -NewName $newName -Force
            Write-Host "Chart renomeada: $($file.Name) -> $newName" -ForegroundColor Green
        } else {
            Write-Host "O arquivo $newName ja existe, pulando renomeacao de $($file.Name)." -ForegroundColor Yellow
        }
    }
}