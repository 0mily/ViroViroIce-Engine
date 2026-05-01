
<p align="center"><img width="1002" height="557" alt="mily mc itm v3-3" src="https://github.com/user-attachments/assets/230d5d74-51dc-4878-8a37-0f78e7318e96" />

<p align="center"><b> Uma ferramenta de modcharting 100% em Lua, desenvolvida especialmente para esta engine. Um sistema livre, poderoso e de código aberto, criado para facilitar o modcharting em músicas de <a href="https://ninja-muffin24.itch.io/funkin">Friday Night Funkin'</a>. </b></p>


***

## O que é Mily MC ITM?

* [**Mily MC ITM**](https://github.com/xdshiho/ViroViroIce/wiki/Modcharts/) _(abreviação de Mily Modcharting: Into the Music)_ é um sistema de modcharting para Friday Night Funkin', desenvolvido utilizando a [API de Lua da Psych Engine](https://gamebanana.com/mods/309789) e projetado especificamente para a engine [ViroViroIce](https://github.com/xdshiho/ViroViroIce).

> * Facilidade e agilidade
> * API própria
> * Lésbica
> * Inúmeras animações matemáticas iradas
> * Customização praticamente infinita
> * Suporte a modifiers customizados<sup>[[1]](https://github.com/xdshiho/ViroViroIce/wiki/Modcharts#kick-shots-)</sup>




# Variáveis <img width="23" height="29" alt="Icon-newtenma" src="https://github.com/user-attachments/assets/eaa98734-ffe7-4794-8746-1b38d0f5bc76" />

* **`BF_Strum`** = Strum de notas do Player
* **`DAD_Strum`** = Strum de notas do Opponent
* **`Strum_Gen`** = Strum das notas

***


# Callbacks <img width="23" height="29" alt="Icon-newtenma" src="https://github.com/user-attachments/assets/eaa98734-ffe7-4794-8746-1b38d0f5bc76" />

Os callbacks agora tem nomes diferentes. Unicamente para os modcharts. Portanto, aqui estão as suas funções e etc:

| Original | Agora se torna | Modchart |
|------------------|----------------|-------------|
| `function onCreate()` | → | `function modChartCreate()` |
| `function onCreatePost()` | → | `function modChartCreatePost()` |
| `function onUpdate()` | → | `function modChartUpdate()` |
| `function onUpdatePost()` | → | `function modChartUpdatePost()` |
| `function onBeatHit()` | → | `function modChartBeatHit()` |
| `function onStepHit()` | → | `function modChartStepHit()` |
| `function onSectionHit()` | → | `function modChartSectionHit()` |
| `function onMoveCamera(focus)` | → | `function modChartFocus(focus)` |
| `function goodNoteHit(id, nd, nt, sus)` | → | `function modChartBFNote(id, nd, nt, sus)` |
| `function opponentNoteHit(id, nd, nt, sus)` | → | `function modChartDADNote(id, nd, nt, sus)` |
| `function goodNoteHitPre(id, nd, nt, sus)` | → | `function modChartBFNotePre(id, nd, nt, sus)` |
| `function opponentNoteHitPre(id, nd, nt, sus)` | → | `function modChartDADNotePre(id, nd, nt, sus)` |
| `function noteMiss(id, nd, nt, sus)` | → | `function modChartMiss(id, nd, nt, sus)` |
| `function noteMissPress(id, nd, nt, sus)` | → | `function modChartMissPress(id, nd, nt, sus)` |
| `function onSongStart()` | → | `function modChartSongStart()` |
> provavelmente esqueci algum btw

***

# Funções <img width="23" height="29" alt="Icon-newtenma" src="https://github.com/user-attachments/assets/eaa98734-ffe7-4794-8746-1b38d0f5bc76" />

### addModchart(modchart:String):Void
Adiciona os modcharts que pretende usar nas músicas. Elas não são ativas desde o começo, sendo apenas colocadas.

exemplos: `drunk`, `invert`, `beat`, `flip`, `zigzag`, etc. Saiba mais [aqui!](https://github.com/xdshiho/ViroViroIce/wiki/Modcharts#Modifiers)!

por padrão, uma mensagem de debug irá aparecer no canto da tela afirmando todos os modcharts que foram ativados com sucesso.

<img width="327" height="33" alt="image" src="https://github.com/user-attachments/assets/0ecc0696-9b27-441c-8b69-7aa4bd598e3c" />

> Pode ser desativado nas configurations do `backendMily.lua`.

* Lua Script
```lua

function modChartCreatePost()
     addModchart('drunk');
     addModchart('beat');
     addModchart('zigzag');
end
```
* Hscript
```haxe

function modChartCreatePost():Void {
    game.addModchart('drunk');
    game.addModchart('beat');
    game.addModchart('zigzag');
}
```

***

### easeModchart(modchart:String, intensity:Dynamic, duration:Float, ?ease:String = 'linear'):String
Faz um tween de um modchart na música.

* Lua Script
```lua
function modChartStepHit()
     if curStep == 128 then
          easeModchart('drunk', 1.5, 4, 'linear');
     end
end
```
* Hscript
```haxe
function modChartStepHit():Void {
    if (curStep == 128) {
        game.easeModchart('drunk', 1.5, 4, 'linear');
    }
}
```

***

### setModchart(modchart:String, value:Dynamic):Void
Seta o valor de um modchart.

* Lua Script
```lua
function modChartStepHit()
     if curStep == 64 then
          setModchart('drunk', 1.5, 4);
     end
end
```
* Hscript
```haxe
function modChartStepHit():Void {
    if (curStep == 64) {
        game.setModchart('drunk', 1.5, 4);
    }
}
```

***

### clearModchart(modchart:String):Void

Remove um modchart.

* Lua Script
```lua
local ron = true
function modChartCreatePost(elapsed)
     if ron then
          clearModchart('zigzag');
     else
     end
end
```

* Hscript
```haxe
var ron:Bool = true;

function modChartCreatePost() {
    if (ron) {
        game.clearModchart("zigzag");
    } else {
          //eu vou parar de oclocar hx por agora, nem sei se funciona e nn quero passar info desinformação oof
    }
}
```

***

# Modifiers <img width="23" height="29" alt="Icon-newtenma" src="https://github.com/user-attachments/assets/eaa98734-ffe7-4794-8746-1b38d0f5bc76" />

* `Drunk`
> Faz as notas ficar balançandinho. Melhor qualidade: (https://imgur.com/a/D4H2IG1)

<img width="479" height="270" alt="2026-04-1600-58-27online-video-cutter com-ezgif com-video-to-gif-converter (2) (2)" src="https://github.com/user-attachments/assets/9b031342-953f-4703-9bca-2283d20a6602" />

* `Float`
> Faz as notas ficarem com um efeito flutuante (Strum apenas). Melhor qualidade: (https://imgur.com/a/D4H2IG1)

<img width="479" height="270" alt="2026-04-1600-58-27online-video-cutter com-ezgif com-video-to-gif-converter (2) (2)" src="https://github.com/user-attachments/assets/9b031342-953f-4703-9bca-2283d20a6602" />

* `Zigzag`
> Faz as notas que sobem fazerem um zigzag dependendo da intensidade (Notes apenas). Melhor qualidade: (https://imgur.com/a/D4H2IG1)

<img width="479" height="270" alt="2026-04-1600-58-27online-video-cutter com-ezgif com-video-to-gif-converter (2) (2)" src="https://github.com/user-attachments/assets/9b031342-953f-4703-9bca-2283d20a6602" />

* `Invert`
> Inverte a ordem das notas, fazendo com que fiquem espelhadas. Normalmente combinada com um tween. Melhor qualidade: (https://imgur.com/a/D4H2IG1)

<img width="479" height="270" alt="2026-04-1600-58-27online-video-cutter com-ezgif com-video-to-gif-converter (2) (2)" src="https://github.com/user-attachments/assets/9b031342-953f-4703-9bca-2283d20a6602" />

* `Dash`
> Faz as notas subirem numa velocidade, e na metade do caminho, avançam no Strum, ainda estando no rítmo. Melhor qualidade: (https://imgur.com/a/D4H2IG1)

<img width="479" height="270" alt="2026-04-1600-58-27online-video-cutter com-ezgif com-video-to-gif-converter (2) (2)" src="https://github.com/user-attachments/assets/9b031342-953f-4703-9bca-2283d20a6602" />

***

# Kick Shots <img width="23" height="29" alt="Icon-newtenma" src="https://github.com/user-attachments/assets/eaa98734-ffe7-4794-8746-1b38d0f5bc76" />

* `Spin`
> Faz o strum girar. Melhor qualidade: (https://imgur.com/a/D4H2IG1)

<img width="479" height="270" alt="2026-04-1600-58-27online-video-cutter com-ezgif com-video-to-gif-converter (2) (2)" src="https://github.com/user-attachments/assets/9b031342-953f-4703-9bca-2283d20a6602" />

* `SpinZ`
> Faz o strum girar no eixo Z. Melhor qualidade: (https://imgur.com/a/D4H2IG1)

<img width="479" height="270" alt="2026-04-1600-58-27online-video-cutter com-ezgif com-video-to-gif-converter (2) (2)" src="https://github.com/user-attachments/assets/9b031342-953f-4703-9bca-2283d20a6602" />

* `Beat`
> Faz o strum dar um pulso aleatoriamente no kick. Melhor qualidade: (https://imgur.com/a/D4H2IG1)

<img width="479" height="270" alt="2026-04-1600-58-27online-video-cutter com-ezgif com-video-to-gif-converter (2) (2)" src="https://github.com/user-attachments/assets/9b031342-953f-4703-9bca-2283d20a6602" />

* `earthquake`
> Faz o strum tremer. Melhor qualidade: (https://imgur.com/a/D4H2IG1)

<img width="479" height="270" alt="2026-04-1600-58-27online-video-cutter com-ezgif com-video-to-gif-converter (2) (2)" src="https://github.com/user-attachments/assets/9b031342-953f-4703-9bca-2283d20a6602" />
