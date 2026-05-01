# Custom States Wiki

Guia de referencia para criar, abrir, sobrescrever e dirigir `CustomState` e
`CustomSubstate` por Lua ou HScript na ViroViroIce.

Este documento foi montado a partir do codigo atual. Quando uma coisa depende de
`PlayState` ou de um state compilado especifico, ela fica marcada como tal.

---

## Regra de ouro

Existem dois fluxos diferentes:

- **CustomState puro**: uma tela vazia criada por script. Use para galerias,
  ferramentas, telas extras e menus totalmente proprios.
- **State compilado com script por cima**: um state Haxe existente, como
  `MainMenuState`, continua criando a tela base. O script so muda comportamento,
  layout, input e objetos.

No codigo atual, `pack.json -> states` aponta primeiro para um `CustomState`.
Se a intencao for rodar o script por cima de um state compilado, o script precisa
de `forkState`/`baseState` apontando para esse state.

---

## Onde colocar

Estados:

```text
mods/MeuMod/data/states/NomeDoState.lua
mods/MeuMod/data/states/NomeDoState.hx
```

Substates:

```text
mods/MeuMod/data/substates/NomeDoSubstate.lua
mods/MeuMod/data/substates/NomeDoSubstate.hx
```

Caminhos antigos aceitos:

```text
mods/MeuMod/data/scripts/states/NomeDoState.lua
mods/MeuMod/data/scripts/substates/NomeDoSubstate.lua
```

O `CustomState` usa `states/` como pasta interna. O `CustomSubstate` usa
`substates/`.

---

## Abrindo States

### `openCustomState(name, data)`

Lua:

```lua
openCustomState('GalleryState')
openCustomState('GalleryState', {from = 'main-menu'})
```

Abre sempre um `CustomState` com o nome informado. O segundo argumento vai para
o campo `data` do state.

Dentro do Lua do state, leia com:

```lua
local data = getProperty('data')
```

No HScript do state, `data` tambem e um campo do state:

```haxe
trace(data);
```

### `switchState(name, args)`

Lua:

```lua
switchState('MainMenuState')
switchState('states.MainMenuState')
switchState('options.OptionsState')
switchState('GalleryState')
```

O resolvedor tenta, nesta ordem:

1. classe exatamente com o nome passado;
2. `states.Nome`;
3. `options.Nome`;
4. se nada existir, cria `CustomState`.

`args` e usado como argumentos do construtor quando o alvo e uma classe Haxe.
Para um `CustomState` criado por fallback, `args` nao vira `data`. Se precisar
passar dados para um CustomState, use `openCustomState(name, data)` ou HScript
com `new CustomState(name, data)`.

### `loadState(name, args)`

Parecido com `switchState`, mas usa `MusicBeatState.loadState`, pulando a
transicao normal de entrada/saida.

### `reloadState(name, args)`

Sem nome, recarrega o state atual:

```lua
reloadState()
```

Com nome, resolve e troca para o state informado:

```lua
reloadState('GalleryState')
```

### `resetState()`

Recarrega o state atual pelo fluxo de `MusicBeatState.resetState()`:

```lua
resetState()
```

### HScript

```haxe
MusicBeatState.switchState(new CustomState('GalleryState'));
MusicBeatState.switchState(new CustomState('GalleryState', {from: 'options'}));
MusicBeatState.loadState(new CustomState('GalleryState'));
```

---

## `pack.json` E Aliases

Exemplo:

```json
{
  "states": {
    "MainMenuState": "myMainMenu",
    "TitleState": "myTitle"
  }
}
```

Quando a engine tenta abrir `MainMenuState`, ela ve o alias e cria
`CustomState('myMainMenu')`.

Se `myMainMenu` for um state totalmente novo, nao precisa de mais nada.

Se `myMainMenu` deve rodar por cima do `MainMenuState` compilado, coloque no
topo do script:

```lua
forkState = 'MainMenuState'

function onCreatePost()
    debugPrint('Agora estou rodando por cima do MainMenuState.')
end
```

Ou em HScript:

```haxe
var forkState = 'MainMenuState';

function onCreatePost() {
    debugPrint('Agora estou rodando por cima do MainMenuState.');
}
```

### Como o fork e resolvido

Antes de carregar o state de verdade, `CustomState` faz uma leitura de sondagem
do script para descobrir o alvo base.

Ordem no Lua:

1. variavel `forkState`;
2. variavel `baseState`;
3. funcao `getState()`;
4. funcao `getBaseState()`.

Depois, se nada foi encontrado em Lua, a mesma ordem e tentada em HScript.

O retorno precisa ser uma string nao vazia. Se o nome normalizado for igual ao
nome do proprio CustomState, o fork e ignorado. Se o alvo tambem resolver para
outro `CustomState`, o fork e ignorado.

Durante a sondagem, o topo do arquivo roda. Evite efeitos colaterais no topo do
script; coloque criacao de sprites, sons e input dentro de `onCreate` ou
`onCreatePost`.

---

## Como Scripts Sao Carregados

`CustomState` define `multiScript = false`. Na pratica, ele tenta carregar no
maximo um caminho resolvido por linguagem.

Fluxo de `ScriptedState`:

1. inicia HScript, se existir;
2. registra a API Lua;
3. chama `onRegisterLuaAPI` nos HScript carregados;
4. inicia Lua, se existir.

Isso significa que `.hx` pode registrar callbacks ou funcoes antes do `.lua`
rodar.

Se existirem `Nome.hx` e `Nome.lua` no caminho resolvido, os dois podem rodar:
HScript primeiro, Lua depois.

Se nenhum script carregar, o `CustomState` abre um `ErrorState`. Nesse erro:

- ACCEPT tenta recarregar o CustomState;
- BACK volta para `MainMenuState`.

---

## Ciclo De Vida

Callbacks genericos de states e substates scriptados:

| Callback | Quando roda | Pode parar algo |
| --- | --- | --- |
| `onCreate()` | logo depois do script ser carregado | nao |
| `onCreatePost()` | depois do `create()` do state terminar | nao |
| `onUpdate(elapsed)` | antes do update base | `Function_Stop` pula o update base daquele frame |
| `onUpdatePost(elapsed)` | depois do update base | nao |
| `onDraw()` | antes do draw base | `Function_Stop` pula o draw base e o `onDrawPost` |
| `onDrawPost()` | depois do draw base | nao |
| `onStepHit(step)` | quando muda o step | nao |
| `onBeatHit(beat)` | quando muda o beat | nao |
| `onSectionHit(section)` | quando muda a section | nao |
| `onOpenSubState(subState)` | antes de abrir substate | `Function_Stop` bloqueia |
| `onClose()` | antes de `close()` em um substate/state scriptado | `Function_Stop` bloqueia |
| `onDestroy()` | antes de destruir scripts | nao |
| `onUpdatePresence(rpcDetails, rpcState)` | antes de atualizar Discord RPC | `Function_Stop` bloqueia |

No Lua, `onOpenSubState` recebe o nome do substate. No HScript, recebe o objeto
do substate.

Constantes de retorno:

```lua
Function_Continue
Function_Stop
Function_StopLua
Function_StopHScript
Function_StopAll
```

---

## Variaveis E Valores Padrao

Todo Lua recebe:

| Nome | Valor |
| --- | --- |
| `Function_StopLua`, `Function_StopHScript`, `Function_StopAll`, `Function_Stop`, `Function_Continue` | constantes de controle |
| `luaDebugMode` | `false` por padrao |
| `luaDeprecatedWarnings` | `true` por padrao |
| `version` | versao Psych/Mint exposta pelo menu |
| `modVersion` | versao do fork |
| `screenWidth`, `screenHeight` | tamanho da tela |
| `buildTarget` | alvo da build |
| `modFolder` | pasta do mod do script, quando detectada |
| `scriptName` | caminho/nome do script |
| `currentModDirectory` | mod atual |
| `curStep`, `curBeat`, `curSection` | valores ritmicos inteiros |
| `curDecStep`, `curDecBeat`, `curDecSection` | valores ritmicos decimais |
| `DEF_nome` | defines de compilacao espelhados para Lua |

Todo `ScriptedState` cria cameras padrao:

| Nome | Uso |
| --- | --- |
| `camMain` | camera principal criada por `PsychCamera` |
| `camGame` | alias da camera principal |
| `camOther` | camera transparente extra |
| `camHUD` | em state scriptado, aponta para `camOther` |

Essas cameras ficam no mapa de variaveis do state. Em Lua, use:

```lua
setObjectCamera('sprite', 'hud')
setProperty('camGame.zoom', 1.2)
```

Nomes aceitos por funcoes de camera:

```text
game, camGame, main, camMain, hud, camHUD, other, camOther
```

### Variaveis que sao de PlayState

As variaveis abaixo aparecem em scripts de gameplay porque sao setadas por
`PlayState.implementLua`. Elas nao sao garantidas em um `CustomState` puro:

```text
mechanics, modchart, pixelRender, allowMiku, customScore, extra, stageUI
downscroll, middlescroll, framerate, ghostTapping, hideHud, antialiasing
timeBarType, scoreZoom, cameraZoomOnBeat, flashingLights, noteOffset
healthBarAlpha, noResetButton, lowQuality, shadersEnabled
noteSkin, noteSkinPostfix, splashSkin, splashSkinPostfix, splashAlpha
```

Tambem sao de gameplay: `score`, `misses`, `hits`, `combo`, `health`, nomes de
personagem, strums, musica atual, dificuldade e semana.

---

## Variaveis Do State

Lua:

```lua
setVar('tag', value)
local value = getVar('tag')
```

`setVar` grava no `extraData` do state atual. Objetos criados por Lua tambem sao
guardados ali, entao `getProperty('tag.x')` funciona para tags salvas.

HScript:

```haxe
setVar('tag', value);
var value = getVar('tag');
hasVar('tag');
removeVar('tag');
```

HScript tambem expoe:

```haxe
game          // parentState
global        // mapa extraData do state
globalStatic  // mapa static de HScript
this          // instancia HScript
```

Como a macro de `extraData` existe nos objetos, variaveis criadas com
`obj.setVar('nome', valor)` podem ser lidas como campos no HScript quando o
interpretador resolver aquele objeto.

---

## Funcoes De Script

Disponiveis em Lua dentro de states scriptados:

| Funcao | Uso |
| --- | --- |
| `callScript(luaFile, funcName, args)` | chama funcao de outro Lua rodando |
| `isRunning(scriptFile)` | verifica Lua ou HScript ativo |
| `getRunningScripts()` | lista scripts Lua ativos |
| `addLuaScript(luaFile, ignoreAlreadyRunning)` | inicia outro Lua |
| `addHScript(scriptFile, ignoreAlreadyRunning)` | inicia outro HScript |
| `removeLuaScript(luaFile)` | para um Lua |
| `removeHScript(scriptFile)` | destroi um HScript |
| `setOnScripts(varName, value, ignoreSelf, exclusions)` | seta variavel em Lua e HScript |
| `setOnLuas(varName, value, ignoreSelf, exclusions)` | seta variavel em Lua |
| `setOnHScript(varName, value, ignoreSelf, exclusions)` | seta variavel em HScript |
| `callOnScripts(funcName, args, ignoreStops, ignoreSelf, exclusions, excludeValues)` | chama Lua e HScript |
| `callOnLuas(...)` | chama so Lua |
| `callOnHScript(...)` | chama so HScript |
| `close()` | fecha o script Lua atual |

`luaFile`/`scriptFile` pode vir com ou sem extensao. A busca passa por
`Paths.getPath`, e tambem aceita caminho absoluto/existente.

---

## Reflexao E Instancias

Essas funcoes deixam um CustomState montar telas sem precisar de classe Haxe
propria:

| Funcao | Uso |
| --- | --- |
| `getProperty(path, allowMaps)` | le campo do state/objeto |
| `setProperty(path, value, allowMaps, allowInstances)` | seta campo |
| `getPropertyFromClass(className, path, allowMaps)` | le campo static/classe |
| `setPropertyFromClass(className, path, value, allowMaps, allowInstances)` | seta campo static/classe |
| `getPropertyFromGroup(group, index, path, allowMaps)` | le membro de array/grupo |
| `setPropertyFromGroup(group, index, path, value, allowMaps, allowInstances)` | seta membro |
| `callMethod(path, args)` | chama metodo no state atual |
| `callMethodFromClass(className, method, args)` | chama metodo static/classe |
| `createInstance(tag, className, args)` | cria instancia Haxe e salva em `tag` |
| `instanceArg(tag, className)` | passa uma instancia salva como argumento |
| `addLuaSprite(tag, inFront)` | adiciona objeto salvo ao state |
| `addInstance(tag, inFront)` | alias de `addLuaSprite` |
| `addToGroup(group, tag, index)` | adiciona objeto a grupo/array |
| `removeFromGroup(group, index, tag, destroy)` | remove de grupo/array |
| `openSubstate(className, args)` | abre substate Haxe compilado |

`createInstance` nao aceita tag com ponto ou colchete.

---

## Sprites, Textos E Sons

Funcoes comuns para montar tela:

| Grupo | Funcoes |
| --- | --- |
| sprites | `makeLuaSprite`, `makeAnimatedLuaSprite`, `makeGraphic`, `loadGraphic`, `loadFrames`, `loadMultipleFrames` |
| animacao | `addAnimationByPrefix`, `addAnimation`, `addAnimationByIndices`, `playAnim`, `addOffset`, `characterDance` |
| tamanho/posicao | `screenCenter`, `setScrollFactor`, `setGraphicSize`, `scaleObject`, `updateHitbox` |
| ordem | `getObjectOrder`, `setObjectOrder`, `removeLuaSprite` |
| camera/blend | `setObjectCamera`, `setBlendMode` |
| colisoes/pixel | `objectsOverlap`, `getPixelColor` |
| texto | `makeLuaText`, `addLuaText`, `removeLuaText`, `setTextString`, `setTextSize`, `setTextWidth`, `setTextHeight`, `setTextAutoSize`, `setTextBorder`, `setTextColor`, `setTextFont`, `setTextItalic`, `setTextAlignment`, `getTextString`, `getTextSize`, `getTextFont`, `getTextWidth` |
| som | `playMusic`, `playSound`, `stopSound`, `pauseSound`, `resumeSound`, `soundFadeIn`, `soundFadeOut`, `soundFadeCancel`, `getSoundVolume`, `setSoundVolume`, `getSoundTime`, `setSoundTime`, `getSoundPitch`, `setSoundPitch` |

`makeLuaSprite`, `makeAnimatedLuaSprite`, textos e widgets removem pontos do tag.
Evite tags com `.`.

Em CustomState puro, quando usar `addLuaSprite`/`addInstance`, passar `true` em
`inFront` adiciona direto no topo. O valor `false` tenta inserir antes de grupos
de personagem quando existe `PlayState`.

---

## Tweens, Timers E Cores

| Funcao | Uso |
| --- | --- |
| `startTween(tag, vars, values, duration, options)` | tween generico |
| `doTweenX/Y/Angle/Alpha/Zoom/Color` | tweens antigos por propriedade |
| `cancelTween(tag)` | cancela tween salvo |
| `runTimer(tag, time, loops)` | cria timer |
| `cancelTimer(tag)` | cancela timer |
| `FlxColor(color)` | cor por string |
| `getColorFromName(color)` | alias |
| `getColorFromString(color)` | alias |
| `getColorFromHex(hex)` | hex sem `#` |

Callbacks relacionados:

```lua
function onTweenCompleted(tag, vars) end
function onTimerCompleted(tag, loops, loopsLeft) end
function onSoundFinished(tag) end
```

`startTween` pode receber callbacks por `options.onUpdate`, `options.onStart` e
`options.onComplete`, chamando funcoes Lua globais pelo nome.

---

## Transicoes, Musica E Camera Helpers

| Grupo | Funcoes |
| --- | --- |
| state/musica | `resetState`, `loadSong`, `loadWeek`, `changeTransStickers` |
| precache | `precacheImage`, `precacheSound`, `precacheMusic` |
| tempo | `getSongPosition` |
| camera scroll | `setCameraScroll`, `addCameraScroll`, `getCameraScrollX`, `getCameraScrollY` |
| camera efeitos | `cameraShake`, `cameraFlash`, `cameraFade` |
| posicoes | `getMidpointX`, `getMidpointY`, `getGraphicMidpointX`, `getGraphicMidpointY`, `getScreenPositionX`, `getScreenPositionY` |

Funcoes de gameplay como `addScore`, `setHealth`, `triggerEvent`, `startCountdown`,
`endSong`, `exitSong`, `noteTweenX` e semelhantes sao registradas por
`implementGame`, entao dependem de `PlayState.instance`. Nao trate essas funcoes
como API segura de um CustomState puro.

---

## Input, Mouse E Arquivos

Input:

```text
keyboardJustPressed, keyboardPressed, keyboardReleased
keyJustPressed, keyPressed, keyReleased
mouseClicked, mousePressed, mouseReleased, getMouseX, getMouseY
anyGamepadJustPressed, anyGamepadPressed, anyGamepadReleased
gamepadAnalogX, gamepadAnalogY, gamepadJustPressed, gamepadPressed, gamepadReleased
```

Cursor:

```text
setCustomCursor, reloadCustomCursor, resetCustomCursor
```

Save e arquivos:

```text
initSaveData, flushSaveData, getDataFromSave, setDataFromSave, eraseSaveData
checkFileExists, saveFile, deleteFile, getTextFromFile, directoryFileList, getPath
```

Strings e random:

```text
stringStartsWith, stringEndsWith, stringTrim, stringSplit
getRandomInt, getRandomFloat, getRandomBool
```

---

## Cameras E Backdrops

Funcoes locais de `ScriptedState`:

```lua
addCamera(tag, bgColor, x, y, width, height, zoom, front)
setMainCamera(tag)
removeCamera(tag, destroy)
```

`addCamera` salva a camera em `tag`. `setMainCamera` troca o draw target
principal para uma camera criada. `removeCamera` nao remove a camera que esta
como principal.

Grid/backdrop:

```lua
addGridBackdrop(tag, cellWidth, cellHeight, width, height, velocityX, velocityY, color1, color2, alpha, x, y, repeatAxes)
setBackdropVelocity(tag, velocityX, velocityY)
removeBackdrop(tag, destroy)
```

`repeatAxes` aceita:

```text
xy, x, horizontal, y, vertical, none
```

---

## Runtime Shaders

Disponivel via callbacks locais de Lua quando shaders/runtime shaders existem
na build:

```text
initLuaShader
setSpriteShader, removeSpriteShader
setCameraShader, removeCameraShader
setWindowShader, removeWindowShader
doTweenShader
getShaderBool, getShaderBoolArray
getShaderInt, getShaderIntArray
getShaderFloat, getShaderFloatArray
setShaderBool, setShaderBoolArray
setShaderInt, setShaderIntArray
setShaderFloat, setShaderFloatArray
setShaderSampler2D, setShaderValue
```

As funcoes respeitam `ClientPrefs.data.shaders` e retornam `false` em plataformas
sem suporte.

---

## Outras APIs Globais

Dependendo dos defines da build, mais funcoes podem ser registradas:

| Area | Funcoes |
| --- | --- |
| achievements | `getAchievementScore`, `setAchievementScore`, `addAchievementScore`, `unlockAchievement`, `isAchievementUnlocked`, `achievementExists` |
| Discord | `changeDiscordPresence`, `changeDiscordClientID` |
| traducoes | `getTranslationPhrase`, `getFileTranslation` |
| FlxAnimate | `makeFlxAnimateSprite`, `loadAnimateAtlas`, `addAnimationBySymbol`, `addAnimationBySymbolIndices` |

Aliases antigos ainda existem para compatibilidade:

```text
addAnimationByIndicesLoop, objectPlayAnimation, characterPlayAnim
luaSpriteMakeGraphic, luaSpriteAddAnimationByPrefix, luaSpriteAddAnimationByIndices
luaSpritePlayAnimation, setLuaSpriteCamera, setLuaSpriteScrollFactor
scaleLuaSprite, getPropertyLuaSprite, setPropertyLuaSprite
musicFadeIn, musicFadeOut, updateHitboxFromGroup
```

Eles emitem aviso de deprecacao e devem ser trocados pelas funcoes novas
indicadas no proprio aviso.

---

## UI Widgets Lua

Widgets usam as classes `PsychUI*` e salvam o objeto pelo tag.

### Box

```lua
makeLuaBox(tag, tabs, defSelect, width, height, x, y)
addLuaBox(tag, inFront)
addToBox(tag, box, tab)
```

Exemplo:

```lua
makeLuaBox('box', {'Main', 'Config'}, 'Main', 320, 180, 40, 40)
addLuaSprite('box', true)
```

`addToBox` adiciona qualquer objeto salvo no menu da aba.

### Label

```lua
createLabel(spr, txt, box, tab)
```

Cria um `FlxText` em `spr.x`, `spr.y - 15`, largura `250`, tamanho `9`.
Se `box` e `tab` forem informados, adiciona dentro da aba. Senao, adiciona no
state alvo.

### Button

```lua
makeLuaButton(tag, label, scaleX, scaleY, x, y)
addLuaButton(tag, inFront)
addButtonToBox(tag, box, tab)
```

Callback:

```lua
function onButtonPressed(tag) end
```

### Input Text

```lua
makeLuaInputText(tag, input, size, width, x, y)
addLuaInputText(tag, inFront)
addInputTextToBox(tag, box, tab)
getInputTextString(tag)
isInputTextOnFocus()
```

### Slider

```lua
makeLuaSlider(tag, label, min, max, defValue, width, x, y)
addLuaSlider(tag, inFront)
addSliderToBox(tag, box, tab)
```

Callback:

```lua
function onSliderChanged(tag, value) end
```

### CheckBox

```lua
makeLuaCheckBox(tag, label, checked, hitbox, x, y)
addLuaCheckBox(tag, inFront)
addCheckBoxToBox(tag, box, tab)
```

Callback:

```lua
function onCheckBoxChecked(tag, checked) end
```

### Numeric Stepper

```lua
makeLuaNumericStepper(tag, step, decimals, min, max, defValue, wid, x, y, isPercent)
addLuaNumericStepper(tag, inFront)
addNumericStepperToBox(tag, box, tab)
```

Callback:

```lua
function onNumericStepperChange(tag, value) end
```

---

## Custom Substates

Lua:

```lua
openCustomSubstate(name, pauseGame, data)
closeCustomSubstate()
insertToCustomSubstate(tag, pos)
```

Dentro do script do substate:

```lua
closeSubstate()
```

HScript:

```haxe
CustomSubstate.openCustomSubstate('ConfirmBox', true, {reason: 'quit'});
CustomSubstate.closeCustomSubstate();
```

`pauseGame = true` faz:

- tenta setar `paused = true` no state atual;
- `persistentDraw = true`;
- `persistentUpdate = false`.

O substate usa a ultima camera da lista de cameras.

### Callbacks no parent

Quando um CustomSubstate abre, o state pai recebe:

```lua
function onCustomSubstateCreate(name) end
function onCustomSubstateCreatePost(name) end
function onCustomSubstateUpdate(name, elapsed) end
function onCustomSubstateUpdatePost(name, elapsed) end
function onCustomSubstateDestroy(name) end
```

Tambem sao setados no parent:

```text
customSubstateName
customSubstate    // HScript recebe o objeto; Lua recebe o nome via customSubstateName
```

Se nao existir arquivo de script para o substate, mas o state pai tiver algum
desses callbacks, o substate ainda e considerado valido.

Se nao existir script nem callback pai, o substate imprime aviso em amarelo e
fecha.

---

## HScript Em Custom States

Imports/valores comuns predefinidos:

```text
Type, File, FileSystem, FlxG, FlxMath, FlxSprite, FlxText, FlxCamera
PsychCamera, FlxTimer, FlxTween, FlxEase, FlxColor
PlayState, Paths, Conductor, ClientPrefs, CustomCursor
FunkinLua, Character, Alphabet, Note
CustomState, CustomSubstate, MusicBeatState, MusicBeatSubstate
controls, version, modVersion, modFolder, buildTarget
Function_Stop, Function_Continue, Function_StopLua, Function_StopHScript, Function_StopAll
```

HScript tambem recebe helpers de shader quando suportado:

```text
FlxRuntimeShader, ErrorHandledRuntimeShader, CodenameRuntimeShader, CustomShader
addCameraShader, removeCameraShader, addWindowShader, removeWindowShader, ShaderFilter
```

Funcoes HScript disponiveis:

```haxe
setVar(name, value);
getVar(name);
hasVar(name);
removeVar(name);
debugPrint(text, color);
getModSetting(saveTag, modName);
createGlobalCallback(name, func);
createCallback(name, func, funk);
addHaxeLibrary(libName, libPackage);
```

Lua pode executar HScript inline:

```lua
runHaxeCode([[
    function hello(name:String) {
        trace('hi ' + name);
        return name.length;
    }
]])

local size = runHaxeFunction('hello', {'Mily'})
```

`runHaxeFunction` so funciona depois de `runHaxeCode` inicializar o modulo Haxe
daquele Lua.

---

## States Compilados Com Extras

Se voce usa `forkState` para rodar por cima de um menu/state compilado, entram
as APIs locais daquele state. Essas funcoes nao existem em um CustomState puro.

### MainMenuState

Variaveis:

```text
curSelected, curColumn, selectedItemName, menuItemNames, menuItemsGroup
bg, magenta, camFollow, EngineVerTxt, FNFVerTxt
storymode, freeplay, mods, options, credits, awards
```

Callbacks:

```lua
onInputUpdate(elapsed)
onBack()
onHighlighted(itemName, index, column)
onHighlightedPost(itemName, index, column)
onSelectItem(index)              -- Lua
onSelectItemPost(index)          -- Lua
onSelected(itemName, index, column)
onAccept(index)                  -- Lua
```

No HScript, alguns callbacks recebem o objeto `MenuItem` em vez de so nome/index
quando o codigo usa `callOnScriptsExt`.

Funcoes Lua:

```text
addItemMenu(item, imagePath, fps, column, insertAt)
removeItemMenu(item)
setItemOrder(orderArray)
hasBeatenSong(songName)
hasBeatenWeek(weekName)
changeMainMenuSelection(change, column)
acceptMainMenuSelection()
```

### StoryMenuState

Variaveis:

```text
curWeek, curDifficulty, selectedWeek, loadedWeeks
weekTextGroup, weekCharactersGroup, bgYellow, bgSprite
```

Callbacks:

```text
onInputUpdate, onBack, onSelected, onAccept
onChangeDifficulty, onChangeDifficultyPost
onHighlighted, onHighlightedPost
onSelectItem, onSelectItemPost
```

Funcoes Lua:

```text
changeStoryWeek(change)
changeStoryDifficulty(change)
acceptStoryWeek()
isStoryWeekLocked(name)
hasBeatenWeek(name)
```

### FreeplayState

Variaveis:

```text
curSelected, curDifficulty, selectedSong, songsList
scoreText, diffText, bg, bottomText
```

Callbacks:

```text
onInputUpdate, onBack
onMusicPlayer, onMusicPlayerPost
onSelected, onAccept
onChangeDifficulty, onChangeDifficultyPost
onHighlighted, onHighlightedPost
onSelectItem, onSelectItemPost
```

Funcoes Lua:

```text
changeFreeplaySelection(change, playSound)
changeFreeplayDifficulty(change)
setFreeplayBottomText(text)
```

### OptionsState

Variaveis:

```text
curSelected, selectedOption, optionsList, optionsGroup, bg
```

Callbacks:

```text
onInputUpdate, onBack, onSelected, onAccept
onHighlighted, onHighlightedPost
onSelectItem
```

Funcoes Lua:

```text
addOptionMenu(label, stateName, insertAt)
removeOptionMenu(label)
setOptionOrder(orderArray)
changeOptionsSelection(change)
acceptOptionsSelection()
```

### CreditsState

Variaveis:

```text
curSelected, selectedCredit, creditsList, bg, descText
```

Callbacks:

```text
onInputUpdate, onSelected, onAccept, onBack
onHighlighted, onHighlightedPost
```

Funcoes Lua:

```text
changeCreditsSelection(change)
setCreditDescription(text)
```

### AchievementsMenuState

Variaveis:

```text
curSelected, selectedAchievement, achievementsList, bg, progressText
```

Callbacks:

```text
onInputUpdate, onBack, onHighlighted, onHighlightedPost
```

Funcao Lua:

```text
changeAchievementSelection(change)
```

### TitleState

Variaveis:

```text
logoBl, gfDance, titleText, ngSpr, credGroup, textGroup
curWacky, titleTextPools, introActions
```

Callbacks:

```text
onInputUpdate, onAccept, onIntroBeat(beat)
```

Funcoes Lua:

```text
skipTitleIntro()
setTitleIntroActions(actions)
```

### LoadingState

Funcoes Lua:

```text
getLoaded()
getLoadMax()
addBehindBar(tag)
```

---

## Exemplo: CustomState Puro

Arquivo:

```text
mods/MeuMod/data/states/GalleryState.lua
```

Codigo:

```lua
function onCreate()
    setPropertyFromClass('flixel.FlxG', 'mouse.visible', true)

    makeLuaSprite('bg', 'menuDesat')
    screenCenter('bg')
    addLuaSprite('bg', true)

    makeLuaText('title', 'Gallery', 0, 0, 40)
    screenCenter('title', 'x')
    addLuaText('title')
end

function onUpdate(elapsed)
    if keyboardJustPressed('ESCAPE') then
        switchState('MainMenuState')
    end
end
```

Abrir:

```lua
openCustomState('GalleryState')
```

---

## Exemplo: Alias Que Forka MainMenuState

`pack.json`:

```json
{
  "states": {
    "MainMenuState": "myMainMenu"
  }
}
```

`mods/MeuMod/data/states/myMainMenu.lua`:

```lua
forkState = 'MainMenuState'

function onCreatePost()
    debugPrint('Menu vanilla carregado, script custom por cima.')
end

function onInputUpdate(elapsed)
    if keyboardJustPressed('M') then
        openCustomState('GalleryState')
        return Function_Stop
    end
end
```

Sem `forkState`, esse alias abriria `myMainMenu` como CustomState vazio.

---

## Exemplo: CustomSubstate

Parent:

```lua
function onUpdate(elapsed)
    if keyboardJustPressed('ENTER') then
        openCustomSubstate('ConfirmBox', true, {source = 'gallery'})
    end
end

function onCustomSubstateDestroy(name)
    debugPrint(name .. ' fechou.')
end
```

Substate:

```text
mods/MeuMod/data/substates/ConfirmBox.lua
```

```lua
function onCreate()
    makeLuaSprite('shade')
    makeGraphic('shade', screenWidth, screenHeight, 'AA000000')
    addLuaSprite('shade', true)

    makeLuaText('msg', 'Confirm?', 0, 0, 300)
    screenCenter('msg')
    addLuaText('msg')
end

function onUpdate(elapsed)
    if keyboardJustPressed('ESCAPE') then
        closeSubstate()
    end
end
```

---

## Checklist

Para um state novo:

1. crie `data/states/Nome.lua` ou `.hx`;
2. abra com `openCustomState('Nome')`;
3. crie camera/sprites/textos/input no script;
4. use `switchState('MainMenuState')` ou outro state para sair.

Para sobrescrever menu compilado:

1. crie alias em `pack.json`;
2. crie `data/states/Alias.lua` ou `.hx`;
3. coloque `forkState = 'MainMenuState'` ou o state alvo;
4. use callbacks do state compilado, como `onInputUpdate`, `onHighlightedPost`
   e `onAccept`.

Para substate:

1. crie `data/substates/Nome.lua` ou `.hx`;
2. abra com `openCustomSubstate('Nome', pauseGame, data)`;
3. feche com `closeSubstate()` dentro dele ou `closeCustomSubstate()` fora.

---

## Troubleshooting

### Abriu tela vazia

Voce abriu um `CustomState` puro. Isso e normal quando nao existe classe Haxe
com aquele nome e o script nao criou nada.

### Alias de menu nao manteve o menu vanilla

No codigo atual, alias em `pack.json` vira `CustomState(alias)`. Coloque
`forkState = 'MainMenuState'` no topo do script para rodar sobre o menu
compilado.

### Dados nao chegaram no CustomState

`switchState('MeuState', args)` nao passa `args` como `data` para CustomState.
Use `openCustomState('MeuState', data)`.

### Variavel `stageUI`/`mechanics` nao existe

Essas variaveis sao de `PlayState`. Em CustomState puro, leia direto de
`ClientPrefs` por HScript ou exponha por conta propria.

### Substate fecha sozinho

Nao encontrou script do substate e o parent tambem nao tinha callbacks
`onCustomSubstate...`.

### Input duplica

Quando interceptar comportamento vanilla em menus forkados, retorne
`Function_Stop` em callbacks de input/accept/selection que suportam bloqueio.

---

## Fontes No Codigo

- `source/psychlua/CustomState.hx`
- `source/psychlua/CustomSubstate.hx`
- `source/backend/ScriptedState.hx`
- `source/backend/ScriptedSubState.hx`
- `source/backend/MusicBeatState.hx`
- `source/backend/MusicBeatSubstate.hx`
- `source/backend/Mods.hx`
- `source/psychlua/FunkinLua.hx`
- `source/psychlua/ReflectionFunctions.hx`
- `source/psychlua/ExtraFunctions.hx`
- `source/psychlua/TextFunctions.hx`
- `source/psychlua/ShaderFunctions.hx`
- `source/psychlua/HScript.hx`
- states compilados em `source/states/` e `source/options/`
