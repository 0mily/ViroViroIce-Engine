package substates;

import backend.Highscore;
import backend.Song;
import backend.CameraResizeFix;

import flixel.util.FlxStringUtil;
import flash.media.Sound;

import states.StoryMenuState;
import states.FreeplayState;
import options.OptionsState;

private class PauseMenuOption
{
	public var tag:String;
	public var name:String;
	public var order:Int;

	public function new(tag:String, name:String, order:Int)
	{
		this.tag = tag;
		this.name = name;
		this.order = order;
	}
}

class PauseMenuItem extends Alphabet
{
	public var tag:String;
	public var optionName:String;
	public var order:Int;

	public function new(x:Float, y:Float, tag:String, optionName:String, order:Int)
	{
		super(x, y, Language.getPhrase('pause_$optionName', optionName), true);
		this.tag = tag;
		this.optionName = optionName;
		this.order = order;
	}
}

class PauseSubState extends ScriptedSubState
{
	public static var instance:PauseSubState;
	public static var pauseMusicName:String = null;
	public static var pauseTrackName:String = 'music';
	public static var musicCharacterName:String = 'default';

	public var defaultMenuEnabled(default, null):Bool = true;
	public var currentCategory(default, null):String = 'default';
	public var pauseMusicSound:FlxSound;
	public var pauseItems(get, never):Array<PauseMenuItem>;
	public var optionsCentered(default, null):Bool = false;

	var grpMenuShit:FlxTypedGroup<PauseMenuItem>;
	var options:Map<String, PauseMenuOption> = [];
	var categories:Map<String, Array<String>> = [];
	var menuItems:Array<PauseMenuOption> = [];
	var curSelected:Int = 0;
	var switchingCategory:Bool = false;

	var practiceText:FlxText;
	var skipTimeText:FlxText;
	var skipTimeTracker:Alphabet;
	var curTime:Float = Math.max(0, Conductor.songPosition);
	var holdTime:Float = 0;
	var optionRepeatTime:Float = 0;
	var cantUnpause:Float = 0.1;

	var missingTextBG:FlxSprite;
	var missingText:FlxText;
	var pauseContextPrepared:Bool = false;
	var pauseScriptsPrepared:Bool = false;
	var pauseOpenFinished:Bool = false;
	var scriptObjectTags:Array<String> = [];

	function get_pauseItems():Array<PauseMenuItem>
		return grpMenuShit != null ? grpMenuShit.members : [];

	public static function resetVariables():Void
	{
		pauseMusicName = null;
		pauseTrackName = 'music';
		musicCharacterName = 'default';
	}

	public static function changePauseMusic(?folder:String, ?track:String = 'music'):String
	{
		if(folder != null)
		{
			var value:String = folder.trim();
			pauseMusicName = value.length > 0 && Paths.formatToSongPath(value) != 'none' ? value : null;
		}
		pauseTrackName = track != null && track.trim().length > 0 ? track.trim() : 'music';
		if(instance?.pauseMusicSound != null)
			instance.reloadPauseMusic();
		instance?.refreshPauseScriptVars();
		return pauseMusicName;
	}

	public static function requestOpen(game:PlayState):Bool
	{
		if(game == null || instance != null)
			return false;

		var pause:PauseSubState = new PauseSubState();
		pause.preparePauseContext();
		pause.loadPauseScriptsOnce();
		pause.refreshPauseScriptVars();
		if(!pause.callWasStopped('onLoadPre'))
			pause.finishPauseOpen();
		return true;
	}

	public function finishPauseOpen():Bool
	{
		if(pauseOpenFinished || PlayState.instance == null)
			return false;
		if(!PlayState.instance.finishPauseOpen(this))
			return false;
		pauseOpenFinished = true;
		return true;
	}

	function preparePauseContext():Void
	{
		if(pauseContextPrepared)
			return;

		instance = this;
		if(pauseMusicName == null)
			pauseMusicName = getDefaultPauseSong();
		musicCharacterName = (PlayState.instance?.boyfriend?.curCharacter != null
			&& PlayState.instance.boyfriend.curCharacter.trim().length > 0)
			? PlayState.instance.boyfriend.curCharacter
			: 'default';
		buildDefaultOptions();
		pauseContextPrepared = true;
	}

	override function getScriptFolders():Array<String>
		return [];

	override function create():Void
	{
		preparePauseContext();
		preCreate();
		loadPauseScriptsOnce();
		refreshPauseScriptVars();
		var loadStopped:Bool = callWasStopped('onLoad');
		var createStopped:Bool = callWasStopped('onCreate');
		defaultMenuEnabled = !loadStopped && !createStopped;

		if(defaultMenuEnabled)
		{
			setupPauseMusic();
			createDefaultMenu();
			switchCategory(currentCategory);
		}

		refreshPauseScriptVars();
		super.create();
	}

	function getDefaultPauseSong():String
	{
		if(backend.WeekData.getWeekFileName() == 'week6')
			return 'breakfast';

		var formattedPauseMusic:String = Paths.formatToSongPath(ClientPrefs.data.pauseMusic);
		return formattedPauseMusic == 'none' ? null : formattedPauseMusic;
	}

	function setupPauseMusic():Void
	{
		pauseMusicSound = new FlxSound();
		reloadPauseMusic(false);
		if(pauseMusicSound != null)
			FlxG.sound.list.add(pauseMusicSound);
	}

	function reloadPauseMusic(addToList:Bool = true):Void
	{
		if(instance == null || !defaultMenuEnabled)
			return;

		if(pauseMusicSound == null)
		{
			pauseMusicSound = new FlxSound();
			if(addToList)
				FlxG.sound.list.add(pauseMusicSound);
		}
		else
		{
			pauseMusicSound.stop();
		}

		if(pauseMusicName == null)
			return;

		try
		{
			var sound:Sound = Paths.pauseMusic(pauseMusicName, musicCharacterName, PlayState.stageUI, pauseTrackName);
			if(sound == null)
				return;
			pauseMusicSound.loadEmbedded(sound, true, true);
			pauseMusicSound.volume = 0;
			var startTime:Int = pauseMusicSound.length > 0 ? FlxG.random.int(0, Std.int(pauseMusicSound.length / 2)) : 0;
			pauseMusicSound.play(false, startTime);
		}
		catch(e:Dynamic)
		{
			trace('Could not load pause music "$pauseMusicName/$pauseTrackName": $e');
		}
	}

	function createDefaultMenu():Void
	{
		CameraResizeFix.aplyAll();
		var pauseCamera:FlxCamera = FlxG.cameras.list[FlxG.cameras.list.length - 1];
		var fullScreenX:Float = CameraResizeFix.pegarFSX(pauseCamera);
		var fullScreenY:Float = CameraResizeFix.pegarFSY(pauseCamera);
		var fullScreenWidth:Float = CameraResizeFix.pegarFSL(pauseCamera);
		var fullScreenHeight:Float = CameraResizeFix.pegarFSA(pauseCamera);

		var bg:FlxSprite = new FlxSprite(fullScreenX, fullScreenY).makeGraphic(1, 1, FlxColor.BLACK);
		bg.scale.set(fullScreenWidth, fullScreenHeight);
		bg.updateHitbox();
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		var levelInfo:FlxText = new FlxText(20, 15, 0, PlayState.SONG.song, 32);
		levelInfo.scrollFactor.set();
		levelInfo.setFormat(Paths.font('vcr.ttf'), 32);
		levelInfo.updateHitbox();
		add(levelInfo);

		var levelDifficulty:FlxText = new FlxText(20, 47, 0, Difficulty.getString().toUpperCase(), 32);
		levelDifficulty.scrollFactor.set();
		levelDifficulty.setFormat(Paths.font('vcr.ttf'), 32);
		levelDifficulty.updateHitbox();
		add(levelDifficulty);

		var blueballedTxt:FlxText = new FlxText(
			20,
			79,
			0,
			Language.getPhrase('blueballed', 'Blueballed: {1}', [Std.string(PlayState.deathCounter)]),
			32
		);
		blueballedTxt.scrollFactor.set();
		blueballedTxt.setFormat(Paths.font('vcr.ttf'), 32);
		blueballedTxt.updateHitbox();
		add(blueballedTxt);

		practiceText = new FlxText(20, 116, 0, Language.getPhrase('Practice Mode').toUpperCase(), 32);
		practiceText.scrollFactor.set();
		practiceText.setFormat(Paths.font('vcr.ttf'), 32);
		practiceText.x = FlxG.width - practiceText.width - 20;
		practiceText.updateHitbox();
		practiceText.visible = PlayState.instance.practiceMode;
		add(practiceText);

		var chartingText:FlxText = new FlxText(20, 116, 0, Language.getPhrase('Charting Mode').toUpperCase(), 32);
		chartingText.scrollFactor.set();
		chartingText.setFormat(Paths.font('vcr.ttf'), 32);
		chartingText.x = FlxG.width - chartingText.width - 20;
		chartingText.y = FlxG.height - chartingText.height - 20;
		chartingText.updateHitbox();
		chartingText.visible = PlayState.chartingMode;
		add(chartingText);

		blueballedTxt.alpha = 0;
		levelDifficulty.alpha = 0;
		levelInfo.alpha = 0;
		levelInfo.x = FlxG.width - levelInfo.width - 20;
		levelDifficulty.x = FlxG.width - levelDifficulty.width - 20;
		blueballedTxt.x = FlxG.width - blueballedTxt.width - 20;

		FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});
		FlxTween.tween(levelInfo, {alpha: 1, y: 20}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3});
		FlxTween.tween(levelDifficulty, {alpha: 1, y: levelDifficulty.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.5});
		FlxTween.tween(blueballedTxt, {alpha: 1, y: blueballedTxt.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.7});

		grpMenuShit = new FlxTypedGroup<PauseMenuItem>();
		add(grpMenuShit);

		missingTextBG = new FlxSprite(fullScreenX, fullScreenY).makeGraphic(1, 1, FlxColor.BLACK);
		missingTextBG.scale.set(fullScreenWidth, fullScreenHeight);
		missingTextBG.updateHitbox();
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);

		missingText = new FlxText(fullScreenX + 50, 0, fullScreenWidth - 100, '', 24);
		missingText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		cameras = [pauseCamera];
	}

	function buildDefaultOptions():Void // it's better like this tbh
	{
		categories.set('default', []);
		addBuiltInOption('resume', 'Resume', 0);
		addBuiltInOption('restart', 'Restart Song', 10);

		if(PlayState.chartingMode)
		{
			addBuiltInOption('leave_chart', 'Leave Charting Mode', 20);
			if(!PlayState.instance.startingSong)
				addBuiltInOption('skip_chart', 'Skip Time', 30);
			addBuiltInOption('end_chart', 'End Song', 40);
			addBuiltInOption('practice_chart', 'Toggle Practice Mode', 50);
			addBuiltInOption('botplay_chart', 'Toggle Botplay', 60);
		}
		else if(PlayState.instance.practiceMode && !PlayState.instance.startingSong)
		{
			addBuiltInOption('skip_chart', 'Skip Time', 20);
		}

		if(Difficulty.list.length > 1)
			addBuiltInOption('diff', 'Change Difficulty', 70);
		addBuiltInOption('options', 'Options', 80);
		addBuiltInOption('exit', 'Exit to menu', 90);
		rebuildMenuItems();
	}

	function addBuiltInOption(tag:String, name:String, order:Int):Void
	{
		var option:PauseMenuOption = new PauseMenuOption(tag, name, order);
		options.set(tag, option);
		categories.get('default').push(tag);
	}

	public function makeOption(tag:String, name:String, order:Int = 0):Bool
	{
		tag = normalizeTag(tag);
		if(tag.length < 1 || name == null || name.trim().length < 1)
			return false;

		if(options.exists(tag))
		{
			var existing:PauseMenuOption = options.get(tag);
			existing.name = name;
			existing.order = order;
		}
		else
		{
			options.set(tag, new PauseMenuOption(tag, name, order));
		}
		rebuildMenuItems();
		if(!switchingCategory && grpMenuShit != null)
			regenMenu();
		refreshPauseScriptVars();
		return true;
	}

	public function setOptionName(tag:String, name:String):Bool
	{
		tag = resolveOptionTag(tag);
		if(tag == null || name == null || name.trim().length < 1)
			return false;

		var option:PauseMenuOption = options.get(tag);
		if(option == null)
			return false;
		option.name = name;

		if(grpMenuShit != null)
		{
			for(index => visibleOption in menuItems)
				if(visibleOption.tag == tag && index < grpMenuShit.members.length)
				{
					var item:PauseMenuItem = grpMenuShit.members[index];
					if(item != null)
					{
						item.text = Language.getPhrase('pause_${option.name}', option.name);
						item.optionName = option.name;
					}
					break;
				}
		}
		refreshPauseScriptVars();
		return true;
	}

	public function addOption(tag:String):Bool
	{
		tag = resolveOptionTag(tag);
		if(tag == null || !options.exists(tag))
			return false;

		if(!categories.exists(currentCategory))
			categories.set(currentCategory, []);
		var list:Array<String> = categories.get(currentCategory);
		if(!list.contains(tag))
			list.push(tag);

		if(!switchingCategory)
		{
			rebuildMenuItems();
			if(grpMenuShit != null)
				regenMenu();
		}
		return true;
	}

	public function removeOption(optionOrTag:String):Bool
	{
		var tag:String = resolveOptionTag(optionOrTag);
		if(tag == null)
			return false;

		for(category in categories)
			category.remove(tag);
		options.remove(tag);
		if(!switchingCategory)
		{
			rebuildMenuItems();
			if(grpMenuShit != null)
				regenMenu();
		}
		refreshPauseScriptVars();
		return true;
	}

	public function switchCategory(name:String):Bool
	{
		name = normalizeTag(name);
		if(name.length < 1)
			return false;
		if(name == 'difficulty')
			buildDifficultyCategory();
		if(!categories.exists(name))
			categories.set(name, []);

		currentCategory = name;
		switchingCategory = true;
		callEveryScript('onCategory', [name]);
		switchingCategory = false;
		rebuildMenuItems();
		if(grpMenuShit != null)
			regenMenu();
		refreshPauseScriptVars();
		callEveryScript('onCategoryPost', [name]);
		return true;
	}

	public function switchDefault():Bool
		return switchCategory('default');

	function buildDifficultyCategory():Void
	{
		var tags:Array<String> = [];
		for(i in 0...Difficulty.list.length)
		{
			var tag:String = 'difficulty_$i';
			options.set(tag, new PauseMenuOption(tag, Difficulty.getString(i), i * 10));
			tags.push(tag);
		}
		options.set('back', new PauseMenuOption('back', 'BACK', 10000));
		tags.push('back');
		categories.set('difficulty', tags);
	}

	function rebuildMenuItems():Void
	{
		menuItems = [];
		var tags:Array<String> = categories.get(currentCategory);
		if(tags != null)
			for(tag in tags)
			{
				var option:PauseMenuOption = options.get(tag);
				if(option != null)
					menuItems.push(option);
			}
		menuItems.sort(function(a:PauseMenuOption, b:PauseMenuOption)
		{
			var order:Int = a.order - b.order;
			return order != 0 ? order : Reflect.compare(a.tag, b.tag);
		});
		if(menuItems.length > 0)
			curSelected = FlxMath.wrap(curSelected, 0, menuItems.length - 1);
		else
			curSelected = 0;
	}

	function resolveOptionTag(value:String):String
	{
		var normalized:String = normalizeTag(value);
		if(options.exists(normalized))
			return normalized;
		if(value != null)
			for(tag => option in options)
				if(option.name.toLowerCase().trim() == value.toLowerCase().trim())
					return tag;
		return null;
	}

	static function normalizeTag(value:String):String
	{
		if(value == null)
			return '';
		return value.toLowerCase().trim().replace(' ', '_').replace('-', '_');
	}

	function loadPauseScriptsOnce():Void
	{
		if(pauseScriptsPrepared)
			return;
		pauseScriptsPrepared = true;
		if(pauseMusicName == null)
			loadScriptFolderLayers(['music/game/pause/scripts'], false);
		else
			loadScriptFolderLayers(Paths.pauseScriptFolders(pauseMusicName, musicCharacterName, PlayState.stageUI), false);
	}

	function refreshPauseScriptVars():Void
	{
		var visibleOptions:Array<String> = [for(option in menuItems) option.tag];
		setOnScripts('pauseSubstate', this);
		setOnScripts('pauseMusicSound', pauseMusicSound);
		setOnScripts('pauseMusic', pauseMusicName);
		setOnScripts('pauseMusicName', pauseMusicName);
		setOnScripts('pauseMusicTrack', pauseTrackName);
		setOnScripts('pauseMusicCharacter', musicCharacterName);
		setOnScripts('pauseStageUI', PlayState.stageUI);
		setOnScripts('pauseCategory', currentCategory);
		setOnScripts('pauseOptions', visibleOptions);
		setOnScripts('pauseOptionTags', visibleOptions);
		setOnScripts('pauseItems', pauseItems);
		setOnScripts('pauseSelectedOption', menuItems.length > 0 ? menuItems[curSelected].tag : null);
		setOnScripts('pauseNotesPressed', PlayState.instance?.songHits ?? 0);
		setOnScripts('pauseNotesMissed', PlayState.instance?.songMisses ?? 0);
		setOnScripts('pauseOptionsCentered', optionsCentered);
	}

	function callEveryScript(func:String, ?args:Array<Dynamic>):Void
	{
		callOnLuas(func, args, true);
		callOnHScript(func, args, true);
	}

	function callWasStopped(func:String, ?args:Array<Dynamic>):Bool
	{
		var luaResult:Dynamic = callOnLuas(func, args, true);
		var hscriptResult:Dynamic = callOnHScript(func, args, true);
		return isStopValue(luaResult) || isStopValue(hscriptResult);
	}

	static function isStopValue(value:Dynamic):Bool
	{
		return value == psychlua.LuaUtils.Function_Stop
			|| value == psychlua.LuaUtils.Function_StopLua
			|| value == psychlua.LuaUtils.Function_StopHScript
			|| value == psychlua.LuaUtils.Function_StopAll;
	}

	override function update(elapsed:Float):Void
	{
		var runDefaultUpdate:Bool = preUpdate(elapsed);
		cantUnpause -= elapsed;
		if(pauseMusicSound != null && pauseMusicSound.volume < 0.5)
			pauseMusicSound.volume += 0.01 * elapsed;

		super.update(elapsed);
		if(runDefaultUpdate && defaultMenuEnabled)
			updateDefaultMenu(elapsed);
		postUpdate(elapsed);
	}

	function updateDefaultMenu(elapsed:Float):Void
	{
		if(controls.BACK)
		{
			if(currentCategory == 'default')
				resumeGame();
			else
				switchDefault();
			return;
		}

		updateSkipTextStuff();
		if(controls.UI_UP_P)
			changeSelection(-1);
		if(controls.UI_DOWN_P)
			changeSelection(1);
		if(menuItems.length < 1)
			return;

		var selected:PauseMenuOption = menuItems[curSelected];
		if(selected.tag == 'skip_chart')
			updateSkipTimeInput(elapsed);
		else
			updateOptionChangeInput(selected, elapsed);

		if(controls.ACCEPT && (cantUnpause <= 0 || !controls.controllerMode))
		{
			if(!callWasStopped('onSelected', [selected.tag]))
				runDefaultOption(selected);
		}
	}

	function updateOptionChangeInput(option:PauseMenuOption, elapsed:Float):Void
	{
		var direction:Int = 0;
		if(controls.UI_LEFT_P)
			direction = -1;
		else if(controls.UI_RIGHT_P)
			direction = 1;

		if(direction != 0)
		{
			holdTime = 0;
			optionRepeatTime = 0;
			dispatchOptionChange(option.tag, direction);
		}
		else if(controls.UI_LEFT || controls.UI_RIGHT)
		{
			holdTime += elapsed;
			if(holdTime > 0.5)
			{
				optionRepeatTime -= elapsed;
				if(optionRepeatTime <= 0)
				{
					dispatchOptionChange(option.tag, controls.UI_LEFT ? -1 : 1);
					optionRepeatTime = 0.075;
				}
			}
		}
		else
		{
			holdTime = 0;
			optionRepeatTime = 0;
		}
	}

	function dispatchOptionChange(tag:String, direction:Int):Void
	{
		callEveryScript('onOptionChanged', [tag, direction]);
	}

	function updateSkipTimeInput(elapsed:Float):Void
	{
		if(controls.UI_LEFT_P)
		{
			FlxG.sound.play(Paths.uiSound('scrollMenu'), 0.4);
			curTime -= 1000;
			holdTime = 0;
		}
		if(controls.UI_RIGHT_P)
		{
			FlxG.sound.play(Paths.uiSound('scrollMenu'), 0.4);
			curTime += 1000;
			holdTime = 0;
		}

		if(controls.UI_LEFT || controls.UI_RIGHT)
		{
			holdTime += elapsed;
			if(holdTime > 0.5)
				curTime += 45000 * elapsed * (controls.UI_LEFT ? -1 : 1);

			if(FlxG.sound.music != null)
			{
				if(curTime >= FlxG.sound.music.length) curTime -= FlxG.sound.music.length;
				else if(curTime < 0) curTime += FlxG.sound.music.length;
			}
			updateSkipTimeText();
		}
	}

	function runDefaultOption(option:PauseMenuOption):Void
	{
		switch(option.tag)
		{
			case 'resume':
				resumeGame();
			case 'restart':
				restartGame();
			case 'diff':
				switchCategory('difficulty');
			case 'back':
				switchDefault();
			case 'leave_chart':
				PlayState.chartingMode = false;
				PlayState.restartSong();
			case 'skip_chart':
				curTime = Math.max(curTime, 1);
				if(curTime < Conductor.songPosition)
				{
					PlayState.startOnTime = curTime;
					PlayState.restartSong(true);
				}
				else // mt mais clean, shadow mario perdão ai
				{
					if(curTime != Conductor.songPosition)
					{
						PlayState.instance.clearNotesBefore(curTime);
						PlayState.instance.setSongTime(curTime);
					}
					close();
				}
			case 'end_chart':
				close();
				PlayState.instance.notes.clear();
				PlayState.instance.unspawnNotes = [];
				PlayState.instance.finishSong(true);
			case 'practice_chart':
				PlayState.instance.practiceMode = !PlayState.instance.practiceMode;
				PlayState.changedDifficulty = true;
				if(practiceText != null)
					practiceText.visible = PlayState.instance.practiceMode;
			case 'botplay_chart':
				PlayState.instance.cpuControlled = !PlayState.instance.cpuControlled;
				PlayState.changedDifficulty = true;
				PlayState.instance.botplayTxt.visible = PlayState.instance.cpuControlled;
				PlayState.instance.botplayTxt.alpha = 1;
				PlayState.instance.botplaySine = 0;
			case 'options':
				openOptionsMenu();
			case 'exit':
				exitGame();
			default:
				if(option.tag.startsWith('difficulty_'))
					selectDifficulty(Std.parseInt(option.tag.substr('difficulty_'.length)));
		}
	}

	function selectDifficulty(index:Int):Void
	{
		if(index < 0 || index >= Difficulty.list.length)
			return;

		var songLowercase:String = Paths.formatToSongPath(Song.loadedSongName != null ? Song.loadedSongName : PlayState.SONG.song);
		var chartName:String = Highscore.formatSong(songLowercase, index);
		try
		{
			Song.loadFromJson(chartName, songLowercase);
			PlayState.storyDifficulty = index;
			FlxG.sound.music.volume = 0;
			PlayState.changedDifficulty = true;
			PlayState.chartingMode = false;
			MusicBeatState.resetState();
		}
		catch(e:haxe.Exception)
		{
			var errorStr:String = e.message;
			if(errorStr.startsWith('[lime.utils.Assets] ERROR:'))
				errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length - 1);
			else
				errorStr += '\n\n' + e.stack;

			missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
			missingText.screenCenter(Y);
			missingText.visible = true;
			missingTextBG.visible = true;
			FlxG.sound.play(Paths.uiSound('cancelMenu'));
		}
	}

	public function resumeGame():Bool
	{
		if(PlayState.instance == null)
			return false;
		if(callWasStopped('onResumeRequested'))
			return true;
		return resumeNow();
	}

	public function resumeNow():Bool
	{
		if(PlayState.instance == null)
			return false;
		close();
		return true;
	}

	public function setOptionsCentered(value:Bool):Bool
	{
		optionsCentered = value;
		applyOptionsLayout();
		refreshPauseScriptVars();
		return value;
	}

	function applyOptionsLayout():Void
	{
		if(grpMenuShit == null)
			return;
		for(item in grpMenuShit.members)
			if(item != null)
			{
				item.changeX = false;
				if(optionsCentered)
					item.screenCenter(X);
				else
					item.x = 90;
			}
	}

	public function addPauseObject(object:Dynamic):Bool
	{
		var tag:String = Std.isOfType(object, String) ? cast object : null;
		if(tag != null)
			object = psychlua.LuaUtils.getObjectDirectly(tag);
		if(!Std.isOfType(object, FlxBasic))
			return false;

		var basic:FlxBasic = cast object;
		if(cameras != null && cameras.length > 0)
			basic.cameras = cameras;
		add(basic);
		if(tag != null && !scriptObjectTags.contains(tag))
			scriptObjectTags.push(tag);
		return true;
	}

	public function restartGame():Bool
	{
		if(PlayState.instance == null)
			return false;
		PlayState.restartSong();
		return true;
	}

	public function openOptionsMenu():Bool
	{
		if(PlayState.instance == null)
			return false;
		PlayState.instance.paused = true;
		PlayState.instance.vocals.volume = 0;
		PlayState.instance.canResync = false;
		OptionsState.rememberPlayStateContext();
		MusicBeatState.switchState(new OptionsState());
		if(pauseMusicName != null && pauseMusicSound != null)
		{
			FlxG.sound.playMusic(
				Paths.pauseMusic(pauseMusicName, musicCharacterName, PlayState.stageUI, pauseTrackName),
				pauseMusicSound.volume
			);
			FlxTween.tween(FlxG.sound.music, {volume: 1}, 0.8);
			FlxG.sound.music.time = pauseMusicSound.time;
		}
		return true;
	}

	public function exitGame():Bool
	{
		if(PlayState.instance == null)
			return false;
		#if DISCORD_ALLOWED
		DiscordClient.resetClientID();
		#end
		PlayState.deathCounter = 0;
		PlayState.seenCutscene = false;
		PlayState.instance.canResync = false;

		if(PlayState.isStoryMode)
		{
			PlayState.storyPlaylist = [];
			if(Mods.modUsesStickerTrans())
				openSubState(new StickerSubState(null, (sticker) -> new StoryMenuState(sticker)));
			else
			{
				MusicBeatState.switchState(new StoryMenuState());
				FlxG.sound.playMusic(Paths.menuMusic('mainMenu'));
			}
		}
		else
		{
			if(Mods.modUsesStickerTrans())
				openSubState(new StickerSubState(null, (sticker) -> new FreeplayState(sticker)));
			else
			{
				MusicBeatState.switchState(new FreeplayState());
				FlxG.sound.playMusic(Paths.menuMusic('mainMenu'));
			}
		}
		PlayState.changedDifficulty = false;
		PlayState.chartingMode = false;
		FlxG.camera.followLerp = 0;
		return true;
	}

	function changeSelection(change:Int = 0, forced:Bool = false):Void
	{
		if(menuItems.length < 1 || grpMenuShit == null)
			return;
		var next:Int = FlxMath.wrap(curSelected + change, 0, menuItems.length - 1);
		var stopped:Bool = callWasStopped('onHighlighted', [menuItems[next].tag]);
		if(stopped && !forced)
			return;

		curSelected = next;
		for(num => item in grpMenuShit.members)
		{
			item.targetY = num - curSelected;
			item.alpha = 0.6;
			if(item.targetY == 0)
			{
				item.alpha = 1;
				if(item == skipTimeTracker)
				{
					curTime = Math.max(0, Conductor.songPosition);
					updateSkipTimeText();
				}
			}
		}

		missingText.visible = false;
		missingTextBG.visible = false;
		if(change != 0)
			FlxG.sound.play(Paths.uiSound('scrollMenu'), 0.4);
		refreshPauseScriptVars();
	}

	function regenMenu():Void
	{
		deleteSkipTimeText();
		while(grpMenuShit.members.length > 0)
		{
			var object:PauseMenuItem = grpMenuShit.members[0];
			object.kill();
			grpMenuShit.remove(object, true);
			object.destroy();
		}

		for(index => option in menuItems)
		{
			var item:PauseMenuItem = new PauseMenuItem(90, 320, option.tag, option.name, option.order);
			item.isMenuItem = true;
			// X is script-controlled. `pauseItems[index].screenCenter(X)` now
			// remains centered instead of being overwritten on the next frame.
			item.changeX = false;
			item.targetY = index;
			grpMenuShit.add(item);

			if(option.tag == 'skip_chart')
			{
				skipTimeText = new FlxText(0, 0, 0, '', 64);
				skipTimeText.setFormat(Paths.font('vcr.ttf'), 64, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				skipTimeText.scrollFactor.set();
				skipTimeText.borderSize = 2;
				skipTimeTracker = item;
				add(skipTimeText);
				updateSkipTextStuff();
				updateSkipTimeText();
			}
		}

		curSelected = 0;
		changeSelection(0, true);
		applyOptionsLayout();
	}

	function deleteSkipTimeText():Void
	{
		if(skipTimeText != null)
		{
			skipTimeText.kill();
			remove(skipTimeText);
			skipTimeText.destroy();
		}
		skipTimeText = null;
		skipTimeTracker = null;
	}

	function updateSkipTextStuff():Void
	{
		if(skipTimeText == null || skipTimeTracker == null)
			return;
		skipTimeText.x = skipTimeTracker.x + skipTimeTracker.width + 60;
		skipTimeText.y = skipTimeTracker.y;
		skipTimeText.visible = skipTimeTracker.alpha >= 1;
	}

	function updateSkipTimeText():Void
	{
		if(skipTimeText == null)
			return;
		var length:Float = FlxG.sound.music != null ? FlxG.sound.music.length : 0;
		skipTimeText.text = FlxStringUtil.formatTime(Math.max(0, Math.floor(curTime / 1000)), false)
			+ ' / '
			+ FlxStringUtil.formatTime(Math.max(0, Math.floor(length / 1000)), false);
	}

	public override function reset():Void
	{
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		PlayState.nextReloadAll = true;
		MusicBeatState.resetState();
	}

	public static function restartSong(skipTransition:Bool = false):Void
		PlayState.restartSong(skipTransition);

	#if LUA_ALLOWED
	public override function implementLua(lua:psychlua.FunkinLua):Void
	{
		super.implementLua(lua);

		lua.set('pauseSubstate', this);
		lua.set('pauseMusicSound', pauseMusicSound);
		lua.set('pauseMusic', pauseMusicName);
		lua.set('pauseMusicName', pauseMusicName);
		lua.set('pauseMusicTrack', pauseTrackName);
		lua.set('pauseMusicCharacter', musicCharacterName);
		lua.set('pauseStageUI', PlayState.stageUI);
		lua.set('pauseCategory', currentCategory);
		lua.set('pauseItems', pauseItems);
		lua.set('pauseOptions', [for(option in menuItems) option.tag]);
		lua.set('pauseOptionTags', [for(option in menuItems) option.tag]);
		lua.set('pauseNotesPressed', PlayState.instance?.songHits ?? 0);
		lua.set('pauseNotesMissed', PlayState.instance?.songMisses ?? 0);
		lua.set('pauseOptionsCentered', optionsCentered);
		lua.addLocalCallback('changePauseMusic', changePauseMusic);
		lua.addLocalCallback('makeOption', makeOption);
		lua.addLocalCallback('setOptionName', setOptionName);
		lua.addLocalCallback('addOption', addOption);
		lua.addLocalCallback('removeOption', removeOption);
		lua.addLocalCallback('switchCategory', switchCategory);
		lua.addLocalCallback('switchDefault', switchDefault);
		lua.addLocalCallback('openPause', finishPauseOpen);
		lua.addLocalCallback('resume', resumeGame);
		lua.addLocalCallback('resumeNow', resumeNow);
		lua.addLocalCallback('restart', restartGame);
		lua.addLocalCallback('exit', exitGame);
		lua.addLocalCallback('options', openOptionsMenu);
		lua.addLocalCallback('setPauseOptionsCentered', setOptionsCentered);
		lua.addLocalCallback('addPauseObject', addPauseObject);
	}
	#end

	override function destroy():Void
	{
		if(instance == this)
			instance = null;
		for(tag in scriptObjectTags)
			MusicBeatState.getVariables().remove(tag);
		scriptObjectTags = [];
		pauseMusicSound?.destroy();
		super.destroy();
	}
}
