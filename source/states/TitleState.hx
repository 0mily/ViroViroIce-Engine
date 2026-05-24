package states;

import backend.WeekData;

import flixel.input.keyboard.FlxKey;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import haxe.Json;

import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.BitmapData;

import shaders.ColorSwap;

import states.StoryMenuState;
import states.MainMenuState;

typedef TitleData =
{
	var titlex:Float;
	var titley:Float;
	var startx:Float;
	var starty:Float;
	var gfx:Float;
	var gfy:Float;
	var backgroundSprite:String;
	var bpm:Float;
	
	@:optional var animation:String;
	@:optional var dance_left:Array<Int>;
	@:optional var dance_right:Array<Int>;
	@:optional var idle:Bool;
}

typedef TitleIntroAction =
{
	var action:String;
	@:optional var text:String;
	@:optional var lines:Array<String>;
	@:optional var offset:Float;
	@:optional var visible:Bool;
	@:optional var value:String;
}

class TitleState extends ScriptedState
{
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

	public static var initialized:Bool = false;

	var credGroup:FlxGroup = new FlxGroup();
	var textGroup:FlxGroup = new FlxGroup();
	var blackScreen:FlxSprite;
	var credTextShit:Alphabet;
	var ngSpr:FlxSprite;
	
	var titleTextColors:Array<FlxColor> = [0xFF33FFFF, 0xFF3333CC];
	var titleTextAlphas:Array<Float> = [1, .64];

	var curWacky:Array<String> = [];
	var titleTextPools:Map<String, Array<String>> = [];
	var introActions:Map<Int, Array<TitleIntroAction>> = [];
	var eCustomLegal:Bool = false;

	var wackyImage:FlxSprite;

	#if TITLE_SCREEN_EASTER_EGG
	final easterEggKeys:Array<String> = [
		'SHADOW', 'RIVEREN', 'BBPANZU', 'PESSY'
	];
	final allowedKeys:String = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
	var easterEggKeysBuffer:String = '';
	#end

	override public function create():Void {
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		
		rpcDetails = 'Title Screen';

		loadTitleTextPools();

		if(!initialized) {
			if(FlxG.save.data != null && FlxG.save.data.fullscreen)
			{
				FlxG.fullscreen = FlxG.save.data.fullscreen;
				//trace('LOADED FULLSCREEN SETTING!!');
			}
			persistentUpdate = true;
			persistentDraw = true;
		}

		FlxG.mouse.visible = false;
		
		preCreate();
		
		#if FREEPLAY
		MusicBeatState.switchState(new FreeplayState());
		#elseif CHARTING
		MusicBeatState.switchState(new ChartingState());
		#else
		if (FlxG.save.data.flashing == null && !FlashingState.leftState) {
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new FlashingState());
		}
		else {
			startIntro();
		}
		#end
		
		super.create();
	}

	var logoBl:FlxSprite;
	var gfDance:FlxSprite;
	var danceLeft:Bool = false;
	var titleText:FlxSprite;
	var swagShader:ColorSwap = null;

	function startIntro()
	{
		persistentUpdate = true;
		if (!initialized || FlxG.sound.music == null || !FlxG.sound.music.playing)
		{
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
			Conductor.songPosition = 0;
		}

		loadJsonData();
		#if TITLE_SCREEN_EASTER_EGG easterEggData(); #end
		Conductor.bpm = musicBPM;

		logoBl = new FlxSprite(logoPosition.x, logoPosition.y);
		logoBl.frames = Paths.getSparrowAtlas('logoBumpin');
		logoBl.antialiasing = ClientPrefs.data.antialiasing;

		logoBl.animation.addByPrefix('bump', 'logo bumpin', 24, false);
		logoBl.animation.play('bump');
		logoBl.updateHitbox();

		gfDance = new FlxSprite(gfPosition.x, gfPosition.y);
		gfDance.antialiasing = ClientPrefs.data.antialiasing;
		
		if(ClientPrefs.data.shaders)
		{
			swagShader = new ColorSwap();
			gfDance.shader = swagShader.shader;
			logoBl.shader = swagShader.shader;
		}
		
		gfDance.frames = Paths.getSparrowAtlas(characterImage);
		if(!useIdle)
		{
			gfDance.animation.addByIndices('danceLeft', animationName, danceLeftFrames, "", 24, false);
			gfDance.animation.addByIndices('danceRight', animationName, danceRightFrames, "", 24, false);
			gfDance.animation.play('danceRight');
		}
		else
		{
			gfDance.animation.addByPrefix('idle', animationName, 24, false);
			gfDance.animation.play('idle');
		}


		var animFrames:Array<FlxFrame> = [];
		titleText = new FlxSprite(enterPosition.x, enterPosition.y);
		titleText.frames = Paths.getSparrowAtlas('titleEnter');
		@:privateAccess
		{
			titleText.animation.findByPrefix(animFrames, "ENTER IDLE");
			titleText.animation.findByPrefix(animFrames, "ENTER FREEZE");
		}
		
		if (newTitle = animFrames.length > 0)
		{
			titleText.animation.addByPrefix('idle', "ENTER IDLE", 24);
			titleText.animation.addByPrefix('press', ClientPrefs.data.flashing ? "ENTER PRESSED" : "ENTER FREEZE", 24);
		}
		else
		{
			titleText.animation.addByPrefix('idle', "Press Enter to Begin", 24);
			titleText.animation.addByPrefix('press', "ENTER PRESSED", 24);
		}
		titleText.animation.play('idle');
		titleText.updateHitbox();

		blackScreen = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		blackScreen.scale.set(FlxG.width, FlxG.height);
		blackScreen.updateHitbox();
		credGroup.add(blackScreen);

		credTextShit = new Alphabet(0, 0, "", true);
		credTextShit.screenCenter();
		credTextShit.visible = false;

		ngSpr = new FlxSprite(0, FlxG.height * 0.52).loadGraphic(Paths.image('newgrounds_logo'));
		ngSpr.visible = false;
		ngSpr.setGraphicSize(Std.int(ngSpr.width * 0.8));
		ngSpr.updateHitbox();
		ngSpr.screenCenter(X);
		ngSpr.antialiasing = ClientPrefs.data.antialiasing;

		add(gfDance);
		add(logoBl); //FNF Logo
		add(titleText); //"Press Enter to Begin" text
		add(credGroup);
		add(ngSpr);
		refreshShitScript();

		if (initialized)
			skipIntro();
		else
			initialized = true;

		// credGroup.add(credTextShit);
	}

	// JSON data
	var characterImage:String = 'gfDanceTitle';
	var animationName:String = 'gfDance';

	var gfPosition:FlxPoint = FlxPoint.get(512, 40);
	var logoPosition:FlxPoint = FlxPoint.get(-150, -100);
	var enterPosition:FlxPoint = FlxPoint.get(100, 576);
	
	var useIdle:Bool = false;
	var musicBPM:Float = 102;
	var danceLeftFrames:Array<Int> = [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29];
	var danceRightFrames:Array<Int> = [30, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];

	function refreshShitScript():Void
	{
		setOnScripts('logoBl', 'logoBl');
		setOnScripts('gfDance', 'gfDance');
		setOnScripts('titleText', 'titleText');
		setOnScripts('ngSpr', 'ngSpr');
		setOnScripts('credGroup', 'credGroup');
		setOnScripts('textGroup', 'textGroup');
		setOnScripts('curWacky', curWacky);
		setOnScripts('titleTextPools', titleTextPools);
		setOnScripts('introActions', introActions);
	}

	inline function parseTitleFloat(value:String, fallback:Float):Float
	{
		var parsed = Std.parseFloat(value);
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	function parseTitleBool(value:String, fallback:Bool):Bool
	{
		if (value == null) return fallback;
		switch (value.trim().toLowerCase()) {
			case 'true', '1', 'yes', 'y', 'on': return true;
			case 'false', '0', 'no', 'n', 'off': return false;
		}
		return fallback;
	}

	function parseTitleIntList(value:String, fallback:Array<Int>):Array<Int>
	{
		if (value == null || value.trim().length < 1)
			return fallback;

		var result:Array<Int> = [];
		for (part in value.split(',')) {
			var parsed:Null<Int> = Std.parseInt(part.trim());
			if (parsed != null)
				result.push(parsed);
		}
		return result.length > 0 ? result : fallback;
	}

	function parseTitleLines(value:String):Array<String>
	{
		if (value == null || value.trim().length < 1)
			return [];
		return [for (line in value.split('|')) if (line.trim().length > 0) line.trim()];
	}

	function resolveTitleText(value:String):String
	{
		if (value == null)
			return '';

		var trimmed:String = value.trim();
		if (!trimmed.startsWith('[') || !trimmed.endsWith(']'))
			return value;

		var inside:String = trimmed.substr(1, trimmed.length - 2);
		var parts:Array<String> = inside.split(',');
		var poolName:String = parts[0].trim();
		if (poolName.length < 1 || !titleTextPools.exists(poolName))
			return value;

		var pool:Array<String> = titleTextPools.get(poolName);
		if (parts.length < 2)
			return pool.join('\n');

		var index:Null<Int> = Std.parseInt(parts[1].trim());
		if (index == null || index < 0 || index >= pool.length)
			return '';

		return pool[index];
	}

	function resolveTitleLines(lines:Array<String>):Array<String>
	{
		if (lines == null)
			return [];

		return [for (line in lines) resolveTitleText(line)];
	}

	function getNodeText(node:Xml):String // KKKKKKKKKKKKKKK BUCETA DE DIFICIL mas é mais facil de mexer
	{
		var text = '';
		for (child in node)
			if (child.nodeType == Xml.PCData || child.nodeType == Xml.CData)
				text += child.nodeValue;
		return text.trim();
	}

	function registerIntroAction(beat:Int, action:TitleIntroAction):Void
	{
		if (!introActions.exists(beat))
			introActions.set(beat, []);
		introActions.get(beat).push(action);
	}

	function loadXmlData():Bool
	{
		if (!Paths.fileExists('data/titleState.xml', TEXT))
			return false;

		var titleRaw:String = Paths.getTextFromFile('data/titleState.xml');
		if (titleRaw == null || titleRaw.trim().length < 1)
			return false;

		try
		{
			var gostosas:Xml = Xml.parse(titleRaw).firstElement(); // ME DÁ UM DESCONTO, eu tive q olhar sources e forums pra saber como funciona XML, nem eu sei
			if (gostosas == null)
				return false;

			for (node in gostosas.elements())
			{
				switch (node.nodeName)
				{
					case 'layout':
						if (node.exists('titlex')) logoPosition.x = parseTitleFloat(node.get('titlex'), logoPosition.x);
						if (node.exists('titley')) logoPosition.y = parseTitleFloat(node.get('titley'), logoPosition.y);
						if (node.exists('startx')) enterPosition.x = parseTitleFloat(node.get('startx'), enterPosition.x);
						if (node.exists('starty')) enterPosition.y = parseTitleFloat(node.get('starty'), enterPosition.y);
						if (node.exists('gfx')) gfPosition.x = parseTitleFloat(node.get('gfx'), gfPosition.x);
						if (node.exists('gfy')) gfPosition.y = parseTitleFloat(node.get('gfy'), gfPosition.y);
						if (node.exists('bpm')) musicBPM = parseTitleFloat(node.get('bpm'), musicBPM);
						if (node.exists('animation')) animationName = node.get('animation');
						if (node.exists('image')) characterImage = node.get('image');
						if (node.exists('idle')) useIdle = parseTitleBool(node.get('idle'), useIdle);

						if (node.exists('backgroundSprite'))
						{
							var bgName:String = node.get('backgroundSprite');
							if (bgName != null && bgName.trim().length > 0)
							{
								var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image(bgName));
								bg.antialiasing = ClientPrefs.data.antialiasing;
								add(bg);
							}
						}

						for (child in node.elements())
						{
							switch (child.nodeName)
							{
								case 'dance':
									if (child.exists('left')) danceLeftFrames = parseTitleIntList(child.get('left'), danceLeftFrames);
									if (child.exists('right')) danceRightFrames = parseTitleIntList(child.get('right'), danceRightFrames);

								case 'background':
									var bgName:String = child.get('sprite');
									if (bgName != null && bgName.trim().length > 0)
									{
										var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image(bgName));
										bg.antialiasing = ClientPrefs.data.antialiasing;
										add(bg);
									}

								default:
							}
						}

					case 'intro':
						eCustomLegal = true;
						for (beatNode in node.elementsNamed('beat'))
						{
							var beat:Null<Int> = Std.parseInt(beatNode.get('index'));
							if (beat == null)
								continue;
							for (actionNode in beatNode.elements())
							{
								var rawText:String = actionNode.exists('text') ? actionNode.get('text') : getNodeText(actionNode);
								var lines:Array<String> = parseTitleLines(actionNode.exists('lines') ? actionNode.get('lines') : rawText);
								var offset:Float = actionNode.exists('offset') ? parseTitleFloat(actionNode.get('offset'), 0) : 0;

								switch (actionNode.nodeName.toLowerCase())
								{
									case 'create':
										registerIntroAction(beat, {action: 'create', lines: lines, offset: offset});
									case 'add':
										registerIntroAction(beat, {action: 'add', text: rawText, offset: offset});
									case 'clear':
										registerIntroAction(beat, {action: 'clear'});
									case 'newgrounds':
										registerIntroAction(beat, {action: 'newgrounds', visible: parseTitleBool(actionNode.get('visible'), true)});
									case 'music':
										registerIntroAction(beat, {action: 'music', value: actionNode.exists('song') ? actionNode.get('song') : 'freakyMenu'});
									case 'skipintro':
										registerIntroAction(beat, {action: 'skipIntro'});
									default:
								}
							}
						}

					default:
				}
			}

			return true;
		}
		catch(e:haxe.Exception)
		{
			trace('[WARN] Title XML might broken, ignoring issue...\n${e.details()}');
		}

		return false;
	}

	function runIntroAction(action:TitleIntroAction):Void
	{
		switch (action.action)
		{
			case 'music':
				FlxG.sound.playMusic(Paths.music(action.value ?? 'freakyMenu'), 0);
				FlxG.sound.music.fadeIn(4, 0, 0.7);

			case 'create':
				createCoolText(resolveTitleLines(action.lines ?? []), action.offset ?? 0);

			case 'add':
				addMoreText(resolveTitleText(action.text ?? ''), action.offset ?? 0);

			case 'clear':
				deleteCoolText();

			case 'newgrounds':
				ngSpr.visible = (action.visible == true);

			case 'skipIntro':
				skipIntro();

			default:
		}
	}

	function loadJsonData()
	{
		if (loadXmlData())
			return;

		if(Paths.fileExists('images/gfDanceTitle.json', TEXT))
		{
			var titleRaw:String = Paths.getTextFromFile('images/gfDanceTitle.json');
			if(titleRaw != null && titleRaw.length > 0)
			{
				try
				{
					var titleJSON:TitleData = tjson.TJSON.parse(titleRaw);
					gfPosition.set(titleJSON.gfx, titleJSON.gfy);
					logoPosition.set(titleJSON.titlex, titleJSON.titley);
					enterPosition.set(titleJSON.startx, titleJSON.starty);
					musicBPM = titleJSON.bpm;
					
					if(titleJSON.animation != null && titleJSON.animation.length > 0) animationName = titleJSON.animation;
					if(titleJSON.dance_left != null && titleJSON.dance_left.length > 0) danceLeftFrames = titleJSON.dance_left;
					if(titleJSON.dance_right != null && titleJSON.dance_right.length > 0) danceRightFrames = titleJSON.dance_right;
					useIdle = (titleJSON.idle == true);
	
					if (titleJSON.backgroundSprite != null && titleJSON.backgroundSprite.trim().length > 0)
					{
						var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image(titleJSON.backgroundSprite));
						bg.antialiasing = ClientPrefs.data.antialiasing;
						add(bg);
					}
				}
				catch(e:haxe.Exception)
				{
					trace('[WARN] Title JSON might broken, ignoring issue...\n${e.details()}');
				}
			}
			else trace('[WARN] No Title JSON detected, using default values.');
		}
		//else trace('[WARN] No Title JSON detected, using default values.');
	}

	function easterEggData()
	{
		if (FlxG.save.data.psychDevsEasterEgg == null) FlxG.save.data.psychDevsEasterEgg = ''; //Crash prevention
		var easterEgg:String = FlxG.save.data.psychDevsEasterEgg;
		switch(easterEgg.toUpperCase())
		{
			case 'SHADOW':
				characterImage = 'ShadowBump';
				animationName = 'Shadow Title Bump';
				gfPosition.x += 210;
				gfPosition.y += 40;
				useIdle = true;
			case 'RIVEREN':
				characterImage = 'ZRiverBump';
				animationName = 'River Title Bump';
				gfPosition.x += 180;
				gfPosition.y += 40;
				useIdle = true;
			case 'BBPANZU':
				characterImage = 'BBBump';
				animationName = 'BB Title Bump';
				danceLeftFrames = [14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27];
				danceRightFrames = [27, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13];
				gfPosition.x += 45;
				gfPosition.y += 100;
			case 'PESSY':
				characterImage = 'PessyBump';
				animationName = 'Pessy Title Bump';
				gfPosition.x += 165;
				gfPosition.y += 60;
				danceLeftFrames = [29, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];
				danceRightFrames = [15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28];
		}
	}

	function loadTitleTextPools():Void
	{
		titleTextPools = [];
		setTitleTextPool('curWacky', getRandomTitleTextLines('introText', '--'));
		loadTitleTextPoolConfigs();

		curWacky = getTitleTextPool('curWacky');
		while (curWacky.length < 2)
			curWacky.push('');
	}

	function setTitleTextPool(name:String, lines:Array<String>):Void
	{
		if (name == null || name.trim().length < 1)
			return;

		titleTextPools.set(name.trim(), lines != null ? lines : []);
	}

	function getTitleTextPool(name:String):Array<String>
	{
		if (name != null && titleTextPools.exists(name))
			return titleTextPools.get(name);
		return [];
	}

	function normalizeTitleTextFileName(fileName:String):String
	{
		if (fileName == null)
			return '';

		fileName = fileName.trim().replace('\\', '/');
		if (fileName.startsWith('data/'))
			fileName = fileName.substr(5);
		if (fileName.endsWith('.txt'))
			fileName = fileName.substr(0, fileName.length - 4);
		return fileName;
	}

	function getRandomTitleTextLines(fileName:String, lineBreak:String):Array<String>
	{
		fileName = normalizeTitleTextFileName(fileName);
		if (fileName.length < 1)
			return [];

		if (lineBreak == null || lineBreak.length < 1)
			lineBreak = '--';

		var firstArray:Array<String> = getTitleTextFileLines(fileName);
		var swagGoodArray:Array<Array<String>> = [];

		for (i in firstArray)
		{
			var split:Array<String> = i.split(lineBreak);
			for (partIndex in 0...split.length)
				split[partIndex] = split[partIndex].trim();
			swagGoodArray.push(split);
		}

		var picked:Array<String> = FlxG.random.getObject(swagGoodArray);
		return picked != null ? picked : [];
	}

	function getTitleTextFileLines(fileName:String):Array<String>
	{
		#if MODS_ALLOWED
		return Mods.mergeAllTextsNamed('data/$fileName.txt');
		#else
		var fullText:String = Assets.getText(Paths.txt(fileName));
		return fullText.split('\n');
		#end
	}

	function loadTitleTextPoolConfigs():Void
	{
		#if sys
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'data/'))
		{
			if (folder == null || !FileSystem.exists(folder) || !FileSystem.isDirectory(folder))
				continue;

			var dataFolder:String = folder.replace('\\', '/');
			if (!dataFolder.endsWith('/'))
				dataFolder += '/';

			for (file in FileSystem.readDirectory(dataFolder))
			{
				var lowerFile:String = file.toLowerCase();
				if (!lowerFile.endsWith('.json') && !lowerFile.endsWith('.xml'))
					continue;

				var baseName:String = file.substr(0, file.length - (lowerFile.endsWith('.json') ? 5 : 4));
				if (!FileSystem.exists(dataFolder + baseName + '.txt'))
					continue;

				loadTitleTextPoolConfig(dataFolder + file, baseName);
			}
		}
		#end
	}

	function loadTitleTextPoolConfig(path:String, fileName:String):Void
	{
		#if sys
		try
		{
			var raw:String = File.getContent(path);
			if (raw == null || raw.trim().length < 1)
				return;

			var poolName:String = fileName;
			var lineBreak:String = '--';
			var sourceFile:String = fileName;

			if (path.toLowerCase().endsWith('.json'))
			{
				var data:Dynamic = Json.parse(raw);
				if (Reflect.hasField(data, 'name')) poolName = Std.string(Reflect.field(data, 'name'));
				if (Reflect.hasField(data, 'lineBreak')) lineBreak = Std.string(Reflect.field(data, 'lineBreak'));
				if (Reflect.hasField(data, 'linebreak')) lineBreak = Std.string(Reflect.field(data, 'linebreak'));
				if (Reflect.hasField(data, 'separator')) lineBreak = Std.string(Reflect.field(data, 'separator'));
				if (Reflect.hasField(data, 'file')) sourceFile = Std.string(Reflect.field(data, 'file'));
			}
			else
			{
				var xml:Xml = Xml.parse(raw).firstElement();
				if (xml != null)
				{
					if (xml.exists('name')) poolName = xml.get('name');
					if (xml.exists('lineBreak')) lineBreak = xml.get('lineBreak');
					if (xml.exists('linebreak')) lineBreak = xml.get('linebreak');
					if (xml.exists('separator')) lineBreak = xml.get('separator');
					if (xml.exists('file')) sourceFile = xml.get('file');
				}
			}

			setTitleTextPool(poolName, getRandomTitleTextLines(sourceFile, lineBreak));
		}
		catch(e:haxe.Exception)
		{
			trace('[WARN] Title text pool config "$path" might be broken, ignoring issue...\n${e.details()}');
		}
		#end
	}

	function getIntroTextShit():Array<Array<String>>
	{
		#if MODS_ALLOWED
		var firstArray:Array<String> = Mods.mergeAllTextsNamed('data/introText.txt');
		#else
		var fullText:String = Assets.getText(Paths.txt('introText'));
		var firstArray:Array<String> = fullText.split('\n');
		#end
		var swagGoodArray:Array<Array<String>> = [];

		for (i in firstArray)
		{
			swagGoodArray.push(i.split('--'));
		}

		return swagGoodArray;
	}

	var transitioning:Bool = false;
	private static var playJingle:Bool = false;
	
	var newTitle:Bool = false;
	var titleTimer:Float = 0;

	override function update(elapsed:Float)
	{
		preUpdate(elapsed);
		
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;
		// FlxG.watch.addQuick('amp', FlxG.sound.music.amplitude);

		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || controls.ACCEPT;

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				pressedEnter = true;
			}
		}
		#end

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;
		var blockedFNFInput:Bool = (callOnScripts('onInputUpdate', [elapsed], true) == psychlua.LuaUtils.Function_Stop);

		if (gamepad != null)
		{
			if (gamepad.justPressed.START)
				pressedEnter = true;

			#if switch
			if (gamepad.justPressed.B)
				pressedEnter = true;
			#end
		}
		
		if (newTitle) {
			titleTimer += FlxMath.bound(elapsed, 0, 1);
			if (titleTimer > 2) titleTimer -= 2;
		}

		// EASTER EGG

		if (initialized && !transitioning && skippedIntro && !blockedFNFInput)
		{
			if (newTitle && !pressedEnter)
			{
				var timer:Float = titleTimer;
				if (timer >= 1)
					timer = (-timer) + 2;
				
				timer = FlxEase.quadInOut(timer);
				
				titleText.color = FlxColor.interpolate(titleTextColors[0], titleTextColors[1], timer);
				titleText.alpha = FlxMath.lerp(titleTextAlphas[0], titleTextAlphas[1], timer);
			}
			
			if(pressedEnter)
			{
				titleText.color = FlxColor.WHITE;
				titleText.alpha = 1;
				
				if (titleText != null) titleText.animation.play('press');

				FlxG.camera.flash(ClientPrefs.data.flashing ? FlxColor.WHITE : 0x4CFFFFFF, 1);
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

				transitioning = true;
				// FlxG.sound.music.stop();

				new FlxTimer().start(1, (_) -> {
					MusicBeatState.switchState(new MainMenuState());
					closedState = true;
				});
				
				callOnScripts('onAccept');
			}
			#if TITLE_SCREEN_EASTER_EGG
			else if (FlxG.keys.firstJustPressed() != FlxKey.NONE)
			{
				var keyPressed:FlxKey = FlxG.keys.firstJustPressed();
				var keyName:String = Std.string(keyPressed);
				if(allowedKeys.contains(keyName)) {
					easterEggKeysBuffer += keyName;
					if(easterEggKeysBuffer.length >= 32) easterEggKeysBuffer = easterEggKeysBuffer.substring(1);
					//trace('Test! Allowed Key pressed!!! Buffer: ' + easterEggKeysBuffer);

					for (wordRaw in easterEggKeys)
					{
						var word:String = wordRaw.toUpperCase(); //just for being sure you're doing it right
						if (easterEggKeysBuffer.contains(word))
						{
							//trace('YOOO! ' + word);
							if (FlxG.save.data.psychDevsEasterEgg == word)
								FlxG.save.data.psychDevsEasterEgg = '';
							else
								FlxG.save.data.psychDevsEasterEgg = word;
							FlxG.save.flush();

							FlxG.sound.play(Paths.sound('secret'));

							var black:FlxSprite = new FlxSprite(0, 0).makeGraphic(1, 1, FlxColor.BLACK);
							black.scale.set(FlxG.width, FlxG.height);
							black.updateHitbox();
							black.alpha = 0;
							add(black);

							FlxTween.tween(black, {alpha: 1}, 1, {onComplete:
								function(twn:FlxTween) {
									FlxTransitionableState.skipNextTransIn = true;
									FlxTransitionableState.skipNextTransOut = true;
									MusicBeatState.switchState(new TitleState());
								}
							});
							FlxG.sound.music.fadeOut();
							if(FreeplayState.vocals != null)
							{
								FreeplayState.vocals.fadeOut();
							}
							closedState = true;
							transitioning = true;
							playJingle = true;
							easterEggKeysBuffer = '';
							break;
						}
					}
				}
			}
			#end
		}

		if (initialized && pressedEnter && !skippedIntro && !blockedFNFInput)
		{
			skipIntro();
		}

		if(swagShader != null)
		{
			if(controls.UI_LEFT) swagShader.hue -= elapsed * 0.1;
			if(controls.UI_RIGHT) swagShader.hue += elapsed * 0.1;
		}

		super.update(elapsed);
		
		postUpdate(elapsed);
	}

	function createCoolText(textArray:Array<String>, ?offset:Float = 0)
	{
		for (i in 0...textArray.length)
		{
			var money:Alphabet = new Alphabet(0, 0, textArray[i], true);
			money.screenCenter(X);
			money.y += (i * 60) + 200 + offset;
			if(credGroup != null && textGroup != null)
			{
				credGroup.add(money);
				textGroup.add(money);
			}
		}
	}

	function addMoreText(text:String, ?offset:Float = 0)
	{
		if(textGroup != null && credGroup != null) {
			var coolText:Alphabet = new Alphabet(0, 0, text, true);
			coolText.screenCenter(X);
			coolText.y += (textGroup.length * 60) + 200 + offset;
			credGroup.add(coolText);
			textGroup.add(coolText);
		}
	}

	function deleteCoolText()
	{
		while (textGroup.members.length > 0)
		{
			credGroup.remove(textGroup.members[0], true);
			textGroup.remove(textGroup.members[0], true);
		}
	}

	private var sickBeats:Int = 0; //Basically curBeat but won't be skipped if you hold the tab or resize the screen
	public static var closedState:Bool = false;
	override function beatHit(beat:Int):Void {
		if (logoBl != null)
			logoBl.animation.play('bump', true);

		if (gfDance != null) {
			danceLeft = !danceLeft;
			if (!useIdle) {
				if (danceLeft) {
					gfDance.animation.play('danceRight');
				} else {
					gfDance.animation.play('danceLeft');
				}
			}
			else if(curBeat % 2 == 0) {
				gfDance.animation.play('idle', true);
			}
		}

		if (!closedState && sickBeats <= beat) {
			for (b in sickBeats ... beat + 1) {
				callOnScripts('onIntroBeat', [b]);
				if (eCustomLegal) {
					if (introActions.exists(b))
						for (action in introActions.get(b))
							runIntroAction(action);
				} else {
					switch (b) {
						case 0:
							FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
							FlxG.sound.music.fadeIn(4, 0, 0.7);
						case 1:
							createCoolText(['ViroViroIce by'], 40);
						case 3:
							addMoreText('mily_0', 40);
							addMoreText('Shiho', 40);
						case 4:
							deleteCoolText();
						case 5:
							createCoolText(['Not associated', 'with'], -40);
						case 7:
							addMoreText('newgrounds', -40);
							ngSpr.visible = true;
						case 8:
							deleteCoolText();
							ngSpr.visible = false;
						case 9:
							createCoolText([curWacky[0]]);
						case 11:
							addMoreText(curWacky[1]);
						case 12:
							deleteCoolText();
						case 13:
							addMoreText('Friday');
						case 14:
							addMoreText('Night');
						case 15:
							addMoreText('Funkin');

						case 16:
							skipIntro();
					}
				}
			}
			
			sickBeats = beat + 1;
		}
		
		super.beatHit(beat);
	}
	
	override function stepHit(step:Int):Void {
		var syncTime:Float = FlxG.sound.music.time + Conductor.offset;
		if (Math.abs(Conductor.songPosition - syncTime) > 10)
			Conductor.songPosition = syncTime;
		
		super.stepHit(step);
	}

	var skippedIntro:Bool = false;
	var increaseVolume:Bool = false;
	function skipIntro():Void
	{
		if (!skippedIntro)
		{
			#if TITLE_SCREEN_EASTER_EGG
			if (playJingle) //Ignore deez
			{
				playJingle = false;
				var easteregg:String = FlxG.save.data.psychDevsEasterEgg;
				if (easteregg == null) easteregg = '';
				easteregg = easteregg.toUpperCase();

				var sound:FlxSound = null;
				switch(easteregg)
				{
					case 'RIVEREN':
						sound = FlxG.sound.play(Paths.sound('JingleRiver'));
					case 'SHADOW':
						FlxG.sound.play(Paths.sound('JingleShadow'));
					case 'BBPANZU':
						sound = FlxG.sound.play(Paths.sound('JingleBB'));
					case 'PESSY':
						sound = FlxG.sound.play(Paths.sound('JinglePessy'));

					default: //Go back to normal ugly ass boring GF
						remove(ngSpr);
						remove(credGroup);
						FlxG.camera.flash(FlxColor.WHITE, 2);
						skippedIntro = true;

						FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
						FlxG.sound.music.fadeIn(4, 0, 0.7);
						return;
				}

				transitioning = true;
				if(easteregg == 'SHADOW')
				{
					new FlxTimer().start(3.2, function(tmr:FlxTimer)
					{
						remove(ngSpr);
						remove(credGroup);
						FlxG.camera.flash(FlxColor.WHITE, 0.6);
						transitioning = false;
					});
				}
				else
				{
					remove(ngSpr);
					remove(credGroup);
					FlxG.camera.flash(FlxColor.WHITE, 3);
					sound.onComplete = function() {
						FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
						FlxG.sound.music.fadeIn(4, 0, 0.7);
						transitioning = false;
						#if ACHIEVEMENTS_ALLOWED
						if(easteregg == 'PESSY') Achievements.unlock('pessy_easter_egg');
						#end
					};
				}
			}
			else #end //Default! Edit this one!!
			{
				remove(ngSpr);
				remove(credGroup);
				FlxG.camera.flash(FlxColor.WHITE, 4);

				var easteregg:String = FlxG.save.data.psychDevsEasterEgg;
				if (easteregg == null) easteregg = '';
				easteregg = easteregg.toUpperCase();
				#if TITLE_SCREEN_EASTER_EGG
				if(easteregg == 'SHADOW')
				{
					FlxG.sound.music.fadeOut();
					if(FreeplayState.vocals != null)
					{
						FreeplayState.vocals.fadeOut();
					}
				}
				#end
			}
			skippedIntro = true;
			refreshShitScript();
		}
	}

	#if LUA_ALLOWED
	public override function implementLua(lua:psychlua.FunkinLua):Void {
		super.implementLua(lua);

		lua.addLocalCallback('skipTitleIntro', function() {
			skipIntro();
			return skippedIntro;
		});
		lua.addLocalCallback('setTitleIntroActions', function(actions:Dynamic) {
			introActions = cast actions;
			eCustomLegal = true;
			refreshShitScript();
			return true;
		});
	}
	#end
}
