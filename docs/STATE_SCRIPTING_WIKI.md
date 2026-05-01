# State Scripting Wiki

Guia completo para editar states existentes e criar states novos via `.lua` ou `.hx`.

> Nota: a referencia mais nova e focada em Custom States esta em
> [`CUSTOM_STATES_WIKI.md`](CUSTOM_STATES_WIKI.md). Ela documenta o fluxo atual
> de `pack.json -> states`, `forkState`/`baseState`, `CustomState` e
> `CustomSubstate` diretamente pelo codigo.

Este documento cobre:

- como a engine procura scripts de state
- como sobrescrever states existentes com `pack.json`
- como criar um state novo do zero
- callbacks genéricos
- callbacks e APIs extras dos menus
- formato do `titleState.xml`
- dicas de performance e troubleshooting

---

## 1. Visão geral

Agora a engine tem **dois jeitos diferentes** de trabalhar com states scriptados:

### A. Editar um state compilado já existente

Exemplo:

- `MainMenuState`
- `TitleState`
- `StoryMenuState`
- `FreeplayState`
- `CreditsState`
- `OptionsState`
- `AchievementsMenuState`

Nesse modo, o state Haxe continua existindo normalmente, criando sprites, grupos, câmera, lógica-base e layout-base.

O seu script roda **por cima** dele, podendo:

- interceptar input
- mudar seleção
- reposicionar itens
- trocar textos
- trocar sprites
- bloquear comportamentos padrão com `Function_Stop`

Esse é o melhor jeito para menus.

### B. Criar um custom state do zero

Exemplo:

- `switchState('MyCustomState')`
- `openCustomState('MyCustomState')`

Se não existir uma classe Haxe chamada `states.MyCustomState`, a engine abre um `CustomState`.

Nesse caso, o state é praticamente vazio.

Você precisa criar tudo por script:

- sprites
- textos
- input
- câmera
- troca de state

Esse modo é ótimo para:

- telas extras
- menus especiais
- galerias
- ferramentas
- testes

Mas não é o ideal para “substituir” o menu principal visualmente se você ainda quer aproveitar a estrutura dele.

---

## 2. Onde colocar scripts

### Caminhos novos

A engine agora procura scripts em:

- `data/states`
- `data/substates`

Exemplos:

- `mods/MyMod/data/states/MainMenuState.lua`
- `mods/MyMod/data/states/tgtState.lua`
- `mods/MyMod/data/substates/PauseSubState.lua`

### Compatibilidade com caminho antigo

Também continua aceitando:

- `data/scripts/states`
- `data/scripts/substates`

Então mods antigos não quebram.

---

## 3. Como a engine decide qual script carregar

Para states compilados que herdam de `ScriptedState`, a engine pega:

1. o nome da classe do state
2. verifica se existe um alias em `pack.json`
3. se existir alias, abre um `CustomState` com o nome do alias
4. se esse script declarar `forkState`/`baseState`, carrega o state compilado e usa o alias como script dele

Exemplo:

Se o state atual é `MainMenuState`, normalmente ela procuraria:

- `data/states/MainMenuState.lua`
- `data/states/MainMenuState.hx`

Mas se o `pack.json` tiver:

```json
{
    "states": {
        "MainMenuState": "tgtState"
    }
}
```

ela abre `CustomState('tgtState')`. Esse CustomState vai procurar:

- `data/states/tgtState.lua`
- `data/states/tgtState.hx`

Importante:

- sem `forkState`/`baseState`, isso **vira um CustomState vazio/scriptado**
- com `forkState = 'MainMenuState'`, o script roda por cima do `MainMenuState` compilado

Esse é o comportamento certo para menus.

---

## 4. `pack.json` e alias de state

Exemplo:

```json
{
    "states": {
        "TitleState": "myTitle",
        "MainMenuState": "tgtState",
        "StoryMenuState": "myStory",
        "FreeplayState": "myFreeplay",
        "CreditsState": "myCredits",
        "OptionsState": "myOptions"
    }
}
```

### O que isso faz

- quando a engine abrir `TitleState`, ela abre `CustomState('myTitle')`
- quando abrir `MainMenuState`, ela abre `CustomState('tgtState')`
- e assim por diante
- para manter o state compilado, o script alias deve declarar `forkState`/`baseState`

### O que isso não faz

- não muda o nome da classe Haxe
- não remove automaticamente a lógica-base do state quando voce usa `forkState`
- sem `forkState`, o alias nao usa a lógica-base do state compilado

---

## 5. Como criar um state novo do zero

Se você quiser um state 100% novo, sem classe Haxe própria:

### Arquivo

`mods/MyMod/data/states/MyGallery.lua`

### Abrir por Lua

```lua
switchState('MyGallery')
```

ou

```lua
openCustomState('MyGallery')
```

### O que acontece

A engine não encontra uma classe `states.MyGallery`, então ela abre um `CustomState`.

Esse `CustomState` vai procurar:

- `data/states/MyGallery.lua`
- `data/states/MyGallery.hx`

### Quando usar

Use isso quando você quer:

- uma tela totalmente nova
- uma ferramenta
- uma galeria
- um menu especial

Evite isso para menus vanilla se o objetivo for só trocar layout, porque editar o state compilado costuma ser mais estável e mais fácil.

---

## 6. Funções de troca de state

### `switchState(name, args)`

Troca de state com transição.

Exemplos:

```lua
switchState('FreeplayState')
switchState('states.FreeplayState')
switchState('MyGallery')
```

### `loadState(name, args)`

Troca de state sem a transição normal.

Exemplos:

```lua
loadState('TitleState')
loadState('MyGallery')
```

### `reloadState(name, args)`

Recarrega um state.

Exemplos:

```lua
reloadState()
reloadState('MainMenuState')
reloadState('MyGallery')
```

### Regra importante

Se o nome passado:

- for uma classe Haxe válida, a engine usa a classe
- senão, ela tenta abrir um `CustomState` com esse nome

---

## 7. Callbacks genéricos

Todos os states/substates scriptados podem usar os callbacks abaixo.

### Criação

```lua
function onCreate()
end

function onCreatePost()
end
```

### Update

```lua
function onUpdate(elapsed)
end

function onUpdatePost(elapsed)
end
```

Se `onUpdate` retornar `Function_Stop`, o `update` padrão do state é interrompido naquele frame.

### Draw

```lua
function onDraw()
end

function onDrawPost()
end
```

Se `onDraw` retornar `Function_Stop`, o `draw` padrão é bloqueado.

### Música/Conductor

```lua
function onStepHit(step)
end

function onBeatHit(beat)
end

function onSectionHit(section)
end
```

### Fechamento

```lua
function onClose()
end

function onDestroy()
end
```

---

## 8. Variáveis genéricas úteis

Boa parte dessas já existe nos scripts de Psych/engine:

- `curStep`
- `curBeat`
- `curSection`
- `curDecStep`
- `curDecBeat`
- `curDecSection`
- `screenWidth`
- `screenHeight`
- `version`
- `modVersion`
- `scriptName`
- `modFolder`

Também continuam disponíveis utilitários como:

- `getProperty`
- `setProperty`
- `getPropertyFromGroup`
- `setPropertyFromGroup`
- `runHaxeCode`
- `keyboardJustPressed`
- `keyboardPressed`
- `keyboardReleased`
- `keyJustPressed`
- `keyPressed`
- `keyReleased`
- `mouseClicked`
- `mousePressed`
- `mouseReleased`
- `getMouseX`
- `getMouseY`

---

## 9. Inputs e `Function_Stop`

O jeito mais seguro de sobrescrever um menu é usar:

```lua
function onInputUpdate(elapsed)
    if keyboardJustPressed('LEFT') then
        -- sua lógica
        return Function_Stop
    end

    return Function_Continue
end
```

### O que isso faz

- você trata seu input primeiro
- se retornar `Function_Stop`, a lógica padrão do menu não roda naquele frame

### Dica prática

Use `onInputUpdate` para:

- trocar navegação
- trocar binds
- bloquear mouse
- criar layout próprio

Use `onHighlightedPost` para:

- atualizar posição
- mover câmera
- aplicar tweens visuais

Use `onSelected` para:

- zoom de confirmação
- som extra
- pré-animação antes da troca de state

---

## 10. Editando o `MainMenuState`

O `MainMenuState` foi preparado para script por cima da lógica-base.

### Callbacks úteis

```lua
function onInputUpdate(elapsed)
end

function onBack()
end

function onHighlighted(itemName, index, column)
end

function onHighlightedPost(itemName, index, column)
end

function onSelected(itemName, index, column)
end

function onAccept(index)
end

function onSelectItem(index)
end

function onSelectItemPost(index)
end
```

### Colunas

`column` pode ser:

- `'left'`
- `'center'`
- `'right'`

### Variáveis extras expostas

- `curSelected`
- `curColumn`
- `selectedItemName`
- `menuItemNames`
- `menuItemsGroup`
- `bg`
- `magenta`
- `camFollow`
- `EngineVerTxt`
- `FNFVerTxt`
- `storymode`
- `freeplay`
- `mods`
- `options`
- `credits`
- `awards`

### Funções extras

#### `addItemMenu(item, imagePath, fps, column, insertAt)`

Adiciona item ao menu.

Exemplo:

```lua
addItemMenu('gallery', 'mainmenu/menu_gallery', 24, 'center')
```

`column` pode ser:

- `'center'`
- `'left'`
- `'right'`

#### `removeItemMenu(item)`

Exemplo:

```lua
removeItemMenu('mods')
```

#### `setItemOrder(orderArray)`

Exemplo:

```lua
setItemOrder({
    'story_mode',
    'freeplay',
    'credits'
})
```

#### `hasBeatenSong(songName)`

Exemplo:

```lua
if hasBeatenSong('bopeebo') then
    debugPrint('ja passou')
end
```

#### `hasBeatenWeek(weekName)`

Exemplo:

```lua
if hasBeatenWeek('week1') then
    debugPrint('week1 completa')
end
```

#### `changeMainMenuSelection(change, column)`

Exemplo:

```lua
changeMainMenuSelection(1, 'center')
changeMainMenuSelection(0, 'left')
```

#### `acceptMainMenuSelection()`

Confirma o item atual.

---

## 11. Editando o `StoryMenuState`

### Callbacks úteis

- `onInputUpdate(elapsed)`
- `onBack()`
- `onHighlighted(weekName, index)`
- `onHighlightedPost(weekName, index)`
- `onSelected(weekName, index)`
- `onAccept(weekData, index)`
- `onSelectItem(weekData, index)`
- `onSelectItemPost(weekName, index)`
- `onChangeDifficulty(diffName, diffIndex)`
- `onChangeDifficultyPost(diffName, diffIndex)`

### Variáveis extras

- `curWeek`
- `curDifficulty`
- `selectedWeek`
- `loadedWeeks`
- `weekTextGroup`
- `weekCharactersGroup`
- `bgYellow`
- `bgSprite`

### Funções extras

- `changeStoryWeek(change)`
- `changeStoryDifficulty(change)`
- `acceptStoryWeek()`
- `isStoryWeekLocked(name)`
- `hasBeatenWeek(name)`

---

## 12. Editando o `FreeplayState`

### Callbacks úteis

- `onInputUpdate(elapsed)`
- `onBack()`
- `onHighlighted(songName, index)`
- `onHighlightedPost(songName, index)`
- `onSelected(songName, index)`
- `onAccept(index)`
- `onSelectItem(songData, index)`
- `onSelectItemPost(index)` / `onSelectItemPost(songData, index)` no HScript
- `onChangeDifficulty(diffName, diffIndex)`
- `onChangeDifficultyPost(diffName, diffIndex)`
- `onMusicPlayer(isPlayAction, index)`
- `onMusicPlayerPost(isPlayAction, index)`

### Variáveis extras

- `curSelected`
- `curDifficulty`
- `selectedSong`
- `songsList`
- `scoreText`
- `diffText`
- `bg`
- `bottomText`

### Funções extras

- `changeFreeplaySelection(change, playSound)`
- `changeFreeplayDifficulty(change)`
- `setFreeplayBottomText(text)`

---

## 13. Editando o `OptionsState`

### Callbacks úteis

- `onInputUpdate(elapsed)`
- `onBack()`
- `onHighlighted(optionName, index)`
- `onHighlightedPost(optionName, index)`
- `onSelected(optionName, index)`
- `onAccept(optionName, index)`
- `onSelectItem(optionName, index)`

### Variáveis extras

- `curSelected`
- `selectedOption`
- `optionsList`
- `optionsGroup`
- `bg`

### Funções extras

- `addOptionMenu(label, stateName, insertAt)`
- `removeOptionMenu(label)`
- `setOptionOrder(orderArray)`
- `changeOptionsSelection(change)`
- `acceptOptionsSelection()`

---

## 14. Editando o `CreditsState`

### Callbacks úteis

- `onInputUpdate(elapsed)`
- `onBack()`
- `onHighlighted(name, index)`
- `onHighlightedPost(name, index)`
- `onSelected(name, index)`
- `onAccept(creditData, index)`

### Variáveis extras

- `curSelected`
- `selectedCredit`
- `creditsList`
- `bg`
- `descText`

### Funções extras

- `changeCreditsSelection(change)`
- `setCreditDescription(text)`

---

## 15. Editando o `AchievementsMenuState`

### Callbacks úteis

- `onInputUpdate(elapsed)`
- `onBack()`
- `onHighlighted(achievementName, index)`
- `onHighlightedPost(achievementName, index)`

### Variáveis extras

- `curSelected`
- `selectedAchievement`
- `achievementsList`
- `bg`
- `progressText`

### Funções extras

- `changeAchievementSelection(change)`

Observação:

Esse menu usa grid, não lista simples.

---

## 16. Editando o `TitleState`

### Callbacks úteis

- `onInputUpdate(elapsed)`
- `onAccept()`
- `onIntroBeat(beat)`

### Variáveis extras

- `logoBl`
- `gfDance`
- `titleText`
- `ngSpr`
- `credGroup`
- `textGroup`
- `introActions`

### Funções extras

- `skipTitleIntro()`
- `setTitleIntroActions(actions)`

### XML do Title

O `TitleState` agora aceita:

- `data/titleState.xml`

Se o XML não existir, ele volta para:

- `images/gfDanceTitle.json`

---

## 17. Formato do `titleState.xml`

Exemplo:

```xml
<?xml version="1.0" encoding="utf-8"?>
<titleState>
    <layout
        titlex="-150"
        titley="-100"
        startx="100"
        starty="576"
        gfx="512"
        gfy="40"
        bpm="102"
        image="gfDanceTitle"
        animation="gfDance"
        idle="false"
        backgroundSprite="menuDesat">

        <dance
            left="15,16,17,18,19,20,21,22,23,24,25,26,27,28,29"
            right="30,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14" />

        <background sprite="menuBG" />
    </layout>

    <intro>
        <beat index="0">
            <music song="freakyMenu" />
        </beat>

        <beat index="1">
            <create lines="ViroViroIce by" offset="40" />
        </beat>

        <beat index="3">
            <add text="mily_0" offset="40" />
            <add text="Shiho" offset="40" />
        </beat>

        <beat index="4">
            <clear />
        </beat>

        <beat index="7">
            <add text="newgrounds" offset="-40" />
            <newgrounds visible="true" />
        </beat>

        <beat index="8">
            <clear />
            <newgrounds visible="false" />
        </beat>

        <beat index="16">
            <skipIntro />
        </beat>
    </intro>
</titleState>
```

### `layout`

Aceita:

- `titlex`
- `titley`
- `startx`
- `starty`
- `gfx`
- `gfy`
- `bpm`
- `image`
- `animation`
- `idle`
- `backgroundSprite`

### `<dance />`

Aceita:

- `left`
- `right`

São listas separadas por vírgula.

### `<background />`

Aceita:

- `sprite`

### `intro`

Cada `<beat index="N">` roda ações naquele beat.

### Ações do intro

- `<music song="freakyMenu" />`
- `<create lines="linha1|linha2" offset="40" />`
- `<add text="texto" offset="40" />`
- `<clear />`
- `<newgrounds visible="true" />`
- `<skipIntro />`

### Observação sobre `lines`

Use `|` para quebrar em várias linhas:

```xml
<create lines="Linha 1|Linha 2|Linha 3" />
```

---

## 18. Exemplo de override do `MainMenuState`

### `pack.json`

```json
{
    "states": {
        "MainMenuState": "tgtState"
    }
}
```

### Arquivo

`mods/MyMod/data/states/tgtState.lua`

No topo do arquivo:

```lua
forkState = 'MainMenuState'
```

### O que isso significa

- o alias abre `CustomState('tgtState')`
- `forkState` manda esse CustomState carregar o `MainMenuState` compilado
- o script `tgtState.lua` vira o script do `MainMenuState`
- então o script ainda tem acesso a:
  - `menuItems`
  - `leftItem`
  - `rightItem`
  - `camFollow`
  - `bg`
  - callbacks do menu

Isso é o jeito recomendado para carrossel, menu 3D e layouts alternativos do menu principal.
Sem `forkState`, `tgtState` vira um CustomState puro.

---

## 19. Exemplo de custom state totalmente novo

### Arquivo

`mods/MyMod/data/states/GalleryState.lua`

### Abrir

```lua
switchState('GalleryState')
```

### Exemplo mínimo

```lua
function onCreate()
    makeLuaSprite('bg', 'menuDesat', 0, 0)
    addLuaSprite('bg')
end

function onUpdate(elapsed)
    if keyboardJustPressed('ESCAPE') then
        switchState('MainMenuState')
    end
end
```

Esse modo é “state vazio”.

Se você precisar de itens de menu vanilla, use alias por `pack.json` + `forkState` em vez de custom state puro.

---

## 20. HScript funciona igual?

Sim.

A lógica de pasta, alias e carregamento serve tanto para:

- `.lua`
- `.hx`

Exemplos:

- `data/states/MainMenuState.lua`
- `data/states/MainMenuState.hx`
- `data/states/tgtState.lua`
- `data/states/tgtState.hx`

Se ambos existirem, os dois podem rodar, dependendo do fluxo do state.

---

## 21. Performance: como não travar menu

Se um menu ficar travado ou pesado, normalmente é por um destes motivos:

### 1. `runHaxeCode` todo frame para muita coisa

Evite fazer dezenas de blocos Haxe por frame se der para usar:

- `setProperty`
- `setPropertyFromGroup`
- callbacks só quando seleção muda

### 2. Tween cancelado e recriado o tempo todo

Se você tweena todos os itens em `onUpdate`, o menu pode ficar pesado.

Prefira:

- `onHighlightedPost`
- `onSelected`
- `onCreatePost`

### 3. Input duplicado

Se você cria sua própria navegação e não retorna `Function_Stop`, o input padrão e o seu rodam juntos.

Resultado:

- pulo de seleção
- movimento estranho
- sensação de travado

### 4. Atualizar layout inteiro sem necessidade

Exemplo ruim:

```lua
function onUpdate(elapsed)
    -- recalcula tudo sempre
end
```

Exemplo melhor:

```lua
function onHighlightedPost(item, index, column)
    -- recalcula só quando a seleção muda
end
```

---

## 22. Troubleshooting

### Tela preta ao sobrescrever menu

Causa comum:

- tratar `MainMenuState -> tgtState` como se fosse custom state vazio

Jeito certo:

- usar `pack.json` com `states`
- colocar `tgtState.lua` em `data/states`
- colocar `forkState = 'MainMenuState'` no topo do script
- deixar o script rodar sobre o state compilado depois do fork

### Script não carrega

Cheque:

- nome do arquivo
- maiúsculas/minúsculas
- pasta correta
- se o alias no `pack.json` bate com o nome do script

### `switchState('MeuScript')` abre uma tela vazia

Isso é normal se `MeuScript` não for um state compilado.

Você abriu um `CustomState`.

Se você queria editar um menu vanilla, use:

- `pack.json`
- `forkState` apontando para o menu vanilla

Se você queria um state novo do zero, então crie tudo no script.

### Input fica bugado

Cheque:

- se `onInputUpdate` retorna `Function_Stop`
- se você não está misturando input custom com input padrão
- se não está chamando mudança de seleção em mais de um callback

### Menu fica travado

Cheque:

- `runHaxeCode` excessivo
- loops/tweens em `onUpdate`
- reordenação de itens todo frame

---

## 23. Recomendação prática

### Quer só editar layout e comportamento de um menu vanilla?

Use:

- `pack.json` + alias de state
- script em `data/states`
- `forkState`/`baseState` apontando para o menu vanilla

### Quer uma tela totalmente nova?

Use:

- `switchState('MeuStateNovo')`
- script em `data/states/MeuStateNovo.lua`

### Quer compatibilidade máxima

Prefira:

- callbacks do state
- `Function_Stop`
- `setProperty`
- APIs extras do menu

Evite depender demais de `runHaxeCode` por frame.

---

## 24. Checklist rápido

### Override de menu existente

1. criar alias em `pack.json`
2. criar script em `data/states`
3. declarar `forkState`/`baseState`
4. usar `onInputUpdate`
5. usar `onHighlightedPost` para layout
6. usar `onSelected` para zoom/confirm

### State novo

1. criar script em `data/states`
2. abrir com `switchState('Nome')`
3. criar sprites e input manualmente
4. usar `switchState('MainMenuState')` para sair

---

## 25. Resumo final

- `pack.json -> states` abre um `CustomState` com o nome do alias
- `forkState`/`baseState` faz esse alias rodar por cima de um state compilado
- `switchState('NomeSemClasse')` abre um **CustomState** vazio
- menus devem ser sobrescritos via alias + fork, não via custom state puro
- `data/states` e `data/substates` são os caminhos principais
- `titleState.xml` permite layout e intro do title por XML

Se você esquecer de tudo, lembra desta regra:

**menu vanilla modificado = alias + forkState**

**state novo do zero = custom state**
