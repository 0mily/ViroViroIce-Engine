package states.editors;

import backend.WeekData;

import objects.Character;

import states.MainMenuState;
import states.FreeplayState;
import psychlua.CustomState;

class MasterEditorMenu extends ScriptedSubState
{
	var options:Array<String> = [
		'Chart Editor',
		'Character Editor',
		'Blank UI Editor',
		'Stage Editor',
		'Dropshadow Editor',
		'Level Editor',
		'Menu Character Editor',
		'Dialogue Editor',
		'Dialogue Portrait Editor',
		'Note Splash Editor',
		'Test Stickers'
	];
	var optionFunctions:Map<String, Void -> Void> = [];
	private var grpTexts:FlxTypedGroup<Alphabet>;
	private var directories:Array<String> = [null];

	public static var curSelected = 0;
	private var directoryTxt:FlxText;
	private var curDirectory = 0;
	private var fadeIn:Bool;
	
	var textBG:FlxSprite;
	var bg:FlxSprite;
	var shutdim:FlxSprite;
	var shutvig:FlxSprite;
	var shuttext:FlxText;
	var shutTreme:Float = 0;
	var shuttxtY:Float = 0;
	final msgs:Array<String> = [
		"NÃO",
		"Tá ruim",
		"Incompleto",
		"*Tosse*",
		"*fart*",
		"Pó parando",
		"Eu em",
		"Shiho, para.", // :( -Shiho
		"Agora não",
		"dps termino",
		"ativem vocês mesmos, eu em",
		"Bleh",
		"oxi cara?",
		"nem dá",
		"tô não",
		"later",
		"soon",
		"not now",
		"vai embora",
		"pq nn tenta outra opção em?"
	];
	
	public function new(fadeIn:Bool = false) {
		super();
		this.fadeIn = fadeIn;
	}
	
	override function create() {
		preCreate();
		
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Editors Main Menu", null);
		#end

		bg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.scale.set(FlxG.width, FlxG.height);
		bg.scrollFactor.set();
		bg.updateHitbox();
		bg.alpha = 0;
		add(bg);

		grpTexts = new FlxTypedGroup<Alphabet>();
		add(grpTexts);

		for (i in 0...options.length) {
			var leText:Alphabet = new Alphabet(90, 320, options[i], true);
			leText.scrollFactor.set();
			leText.isMenuItem = true;
			leText.targetY = i - curSelected;
			leText.snapToPosition();
			grpTexts.add(leText);
		}
		
		optionFunctions['Chart Editor'] = () -> openSubState(new states.editors.content.CoolNewSongSubState());
		optionFunctions['Character Editor'] = () -> LoadingState.loadAndSwitchState(new CharacterEditorState(Character.DEFAULT_CHARACTER, false));
		// optionFunctions['Blank UI Editor'] = () -> MusicBeatState.switchState(new BlankUIEditorState()); believe me. Is just as buggy as it looks.
		optionFunctions['Blank UI Editor'] = blockshut;
		optionFunctions['Stage Editor'] = () -> LoadingState.loadAndSwitchState(new StageEditorState());
		optionFunctions['Dropshadow Editor'] = () -> LoadingState.loadAndSwitchState(new DropShadowEditor(), false);
		optionFunctions['Level Editor'] = () -> MusicBeatState.switchState(new LevelEditorState());
		optionFunctions['Menu Character Editor'] = () -> MusicBeatState.switchState(new MenuCharacterEditorState());
		optionFunctions['Dialogue Editor'] = () -> LoadingState.loadAndSwitchState(new DialogueEditorState(), false);
		optionFunctions['Dialogue Portrait Editor'] = () -> LoadingState.loadAndSwitchState(new DialogueCharacterEditorState(), false);
		optionFunctions['Note Splash Editor'] =  () -> MusicBeatState.switchState(new NoteSplashEditorState());
		optionFunctions['Test Stickers'] =  () -> MusicBeatState.switchState(new StickerTest());
		
		#if ADDONS_ALLOWED
		textBG = new FlxSprite(0, FlxG.height - 42).makeGraphic(FlxG.width, 42, 0xFF000000);
		textBG.scrollFactor.set();
		textBG.alpha = 0.6;
		add(textBG);

		directoryTxt = new FlxText(textBG.x, textBG.y + 4, FlxG.width, '', 32);
		directoryTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		directoryTxt.scrollFactor.set();
		add(directoryTxt);
		
		for (folder in Mods.getEditorModDirectories()) {
			directories.push(folder);
		}

		var found:Int = directories.indexOf(Mods.currentModDirectory);
		if(found > -1) curDirectory = found;
		changeDirectory();
		#end
		changeSelection(true);
		
		if (fadeIn) {
			bg.alpha = .6;
			
			openSubState(new CustomFadeTransition(.5, true));
		} else {
			FlxTween.tween(bg, {alpha: .6}, .4, {ease: FlxEase.quartInOut});
		}
		
		persistentUpdate = persistentDraw = true;
		FlxG.mouse.visible = false;
		super.create();
	}

	override function update(elapsed:Float)
	{
		preUpdate(elapsed);
		
		if (controls.BACK)
		{
			close();
			return;
		}
		
		if (controls.UI_UP_P)
		{
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
		}
		#if ADDONS_ALLOWED
		if(controls.UI_LEFT_P)
		{
			changeDirectory(-1);
		}
		if(controls.UI_RIGHT_P)
		{
			changeDirectory(1);
		}
		#end

		if (controls.ACCEPT)
		{
			var option:String = options[curSelected];
			var optionFunc:Void -> Void = optionFunctions[option];
			
			if (callOnScripts('onAccept', [option], true) != psychlua.LuaUtils.Function_Stop) {
				if (optionFunc != null) {
					optionFunc();
					if(FlxG.sound.music != null)
						FlxG.sound.music.volume = 0;
					FreeplayState.destroyFreeplayVocals();
				} else {
					trace('Option "$option" doesn\'t do anything');
				}
			}
		}
		
		for (num => item in grpTexts.members) {
			item.targetY = num - curSelected;
			item.alpha = 0.6;
			if (item.targetY == 0)
				item.alpha = 1;
		}

		if (shutTreme > 0 && shuttext != null)
		{
			shutTreme -= elapsed;
			shuttext.x = 40 + FlxG.random.float(-10, 10);
			shuttext.y = shuttxtY + FlxG.random.float(-8, 8);
		}
		else if (shuttext != null)
		{
			shuttext.x = 40;
			shuttext.y = shuttxtY;
		}
		super.update(elapsed);
		
		postUpdate(elapsed);
	}

	function blockshut():Void
	{
		FlxG.sound.play(Paths.missnoteRandom(), FlxG.random.float(0.1, 0.2));
		FlxG.camera.shake(0.006, 0.15);

		if (FlxG.sound.music != null)
		{
			var musicVolume:Float = FlxG.sound.music.volume;
			FlxTween.cancelTweensOf(FlxG.sound.music, ['volume']);
			FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume, 0.25);
			new FlxTimer().start(0.01, (_) -> {
				if (FlxG.sound.music != null)
					FlxTween.tween(FlxG.sound.music, {volume: musicVolume}, 1.4, {ease: FlxEase.quadOut});
			});
		}

		if (shutdim == null)
		{
			shutdim = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
			shutdim.scale.set(FlxG.width, FlxG.height);
			shutdim.scrollFactor.set();
			shutdim.updateHitbox();
			shutdim.alpha = 0;
			add(shutdim);

			shutvig = new FlxSprite();
			shutvig.loadGraphic(backend.VignetteUtil.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK, 1, 0.35, 0.5));
			shutvig.scrollFactor.set();
			shutvig.alpha = 0;
			add(shutvig);
		}

		if (shuttext == null)
		{
			shuttext = new FlxText(40, 0, FlxG.width - 80, '', 72);
			shuttext.setFormat(Paths.font("vcr.ttf"), 72, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			shuttext.borderSize = 3;
			shuttext.scrollFactor.set();
			add(shuttext);
		}

		FlxTween.cancelTweensOf(shutdim);
		FlxTween.cancelTweensOf(shutvig);
		FlxTween.cancelTweensOf(shuttext);
		FlxTween.cancelTweensOf(shuttext.scale);

		shutdim.alpha = 0;
		shutvig.alpha = 0;
		FlxTween.tween(shutdim, {alpha: 0.55}, 0.12, {ease: FlxEase.quadOut});
		FlxTween.tween(shutvig, {alpha: 0.95}, 0.12, {ease: FlxEase.quadOut});
		FlxTween.tween(shutdim, {alpha: 0}, 0.65, {ease: FlxEase.quadIn, startDelay: 0.6});
		FlxTween.tween(shutvig, {alpha: 0}, 0.65, {ease: FlxEase.quadIn, startDelay: 0.6});

		var message:String = FlxG.random.getObject(msgs);
		if (message == '*fart*')
			FlxG.sound.play(Paths.sound('general/fart'), 0.7);

		shuttext.text = message;
		shuttext.alpha = 1;
		shuttext.angle = FlxG.random.float(-6, 6);
		shuttext.scale.set(1.2, 1.2);
		shuttext.screenCenter(Y);
		shuttxtY = shuttext.y;
		shutTreme = 0.45;

		FlxTween.tween(shuttext, {alpha: 0, angle: FlxG.random.float(-12, 12)}, 0.75, {ease: FlxEase.quadIn, startDelay: 0.35});
		FlxTween.tween(shuttext.scale, {x: 1, y: 1}, 0.2, {ease: FlxEase.backOut});
	}

	function changeSelection(change:Int = 0, forced:Bool = false) {
		var next:Int = FlxMath.wrap(curSelected + change, 0, options.length - 1);
		
		if (callOnScripts('onSelectItem', [options[next], next], true) != psychlua.LuaUtils.Function_Stop) {
			if (change != 0 && ClientPrefs.data.editorSFX)
				FlxG.sound.play(Paths.uiSound('scrollMenu'), .4);
			curSelected = next;
		}
	}

	#if ADDONS_ALLOWED
	function changeDirectory(change:Int = 0) {
		var next:Int = FlxMath.wrap(curDirectory + change, 0, directories.length - 1);
		curDirectory = next;
		
		if(ClientPrefs.data.editorSFX)
			FlxG.sound.play(Paths.uiSound('scrollMenu'), .4);
		
		WeekData.setDirectoryFromWeek();
		if (directories[curDirectory] == null || directories[curDirectory].length < 1) {
			Mods.currentModDirectory = '';
			Mods.pushGlobalMods();
			directoryTxt.text = '< No Mod Directory Loaded >';
		} else {
			Mods.currentModDirectory = directories[curDirectory];
			Mods.pushGlobalMods();
			directoryTxt.text = '< Loaded Mod Directory: ' + Mods.currentModDirectory + ' >';
		}
		directoryTxt.text = directoryTxt.text.toUpperCase();
		
		callOnScripts('onSelectDirectory', [directories[curDirectory], next]);
	}
	#end
}
