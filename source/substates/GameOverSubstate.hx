package substates;

import backend.StageDataController;
import backend.WeekData;

import objects.Character;
import flixel.FlxObject;
import flixel.math.FlxPoint;
import flash.media.Sound;

import states.StoryMenuState;
import states.FreeplayState;

class GameOverSubstate extends ScriptedSubState
{
	public static var instance:GameOverSubstate;

	public static var characterName:String = 'bf-dead';
	public static var musicCharacterName:String = 'bf';
	public static var deathSoundName:String = 'fnf_loss_sfx';
	public static var loopSoundName:String = 'music';
	public static var endSoundName:String = 'music-end';
	public static var deathDelay:Float = 0;
	static var customMusicCharacter:Bool = false;

	public var boyfriend:Character;
	public var camFollow:FlxObject;
	public var stageData:StageDataController;
	public var defaultGameOverEnabled(default, null):Bool = true;
	public var isEnding:Bool = false;
	public var gameOverClockStarted(default, null):Bool = false;

	var sourceBoyfriend:Character;
	var overlay:FlxSprite;
	var overlayConfirmOffsets:FlxPoint = FlxPoint.get();
	var lastLoopMusicTime:Float = -1;
	var lastGameOverStep:Int = -1;
	var retryCallbackRunning:Bool = false;
	var customDeathSequenceActive:Bool = false;

	public function new(?playStateBoyfriend:Character = null)
	{
		sourceBoyfriend = playStateBoyfriend;
		boyfriend = playStateBoyfriend;
		if(!customMusicCharacter && playStateBoyfriend != null && playStateBoyfriend.curCharacter != null
			&& playStateBoyfriend.curCharacter.trim().length > 0)
			musicCharacterName = playStateBoyfriend.curCharacter;

		super();
		instance = this;
		stageData = PlayState.instance?.stageData;
		if(stageData == null)
			stageData = new StageDataController(PlayState.instance);
	}

	override function getScriptFolders():Array<String>
		return [];

	public static function resetVariables():Void
	{
		characterName = 'bf-dead';
		musicCharacterName = (PlayState.SONG != null && PlayState.SONG.player1 != null && PlayState.SONG.player1.trim().length > 0)
			? PlayState.SONG.player1
			: 'bf';
		deathSoundName = 'fnf_loss_sfx';
		loopSoundName = 'music';
		endSoundName = 'music-end';
		deathDelay = 0;
		customMusicCharacter = false;
	}

	public static function changeGameOver(name:String, ?musicFolder:String):String
	{
		if(name != null && name.trim().length > 0)
			characterName = name.trim();
		if(musicFolder != null && musicFolder.trim().length > 0)
		{
			musicCharacterName = musicFolder.trim();
			customMusicCharacter = true;
		}

		if(instance != null)
		{
			if(instance.defaultGameOverEnabled && instance.camFollow != null)
				instance.replaceBoyfriend(characterName);
			else if(!instance.defaultGameOverEnabled)
				instance.createCustomGameOverCharacter(characterName);
		}
		instance?.refreshGameOverScriptVars();
		return characterName;
	}

	public static function setGameOverMusic(kind:String = 'loop', songfile:String = 'music'):Void
	{
		var musicKind:String = kind == null ? 'loop' : kind.toLowerCase().trim();
		var musicTrack:String = songfile == null || songfile.trim().length < 1 ? 'music' : songfile.trim();
		switch(musicKind)
		{
			case 'end' | 'retry' | 'confirm':
				endSoundName = musicTrack;
			case 'death' | 'sfx' | 'sound':
				deathSoundName = musicTrack;
			default:
				loopSoundName = musicTrack;
		}
		instance?.refreshGameOverScriptVars();
	}

	public static function startGameOver(?newBpm:Float = 100):Bool
		return instance != null && instance.beginGameOverClock(newBpm);

	public static function retrySong():Bool
		return instance != null && instance.performRetry();

	override function create():Void
	{
		instance = this;
		preCreate();

		loadGameOverScripts();
		refreshGameOverScriptVars();
		callEveryScript('onLoad');

		defaultGameOverEnabled = !callWasStopped('onCreate');
		if(defaultGameOverEnabled)
		{
			stageData.hide();
			createDefaultGameOver();
		}
		else
		{
			if(!stageData.visibilityWasSet)
				stageData.show();
		}

		refreshGameOverScriptVars();
		super.create();
	}

	function createDefaultGameOver():Void
	{
		Conductor.songPosition = 0;

		if(sourceBoyfriend == null || sourceBoyfriend.curCharacter != characterName)
		{
			var playStateBoyfriend:Character = PlayState.instance?.boyfriend;
			var baseX:Float = playStateBoyfriend != null ? playStateBoyfriend.getScreenPosition().x : 0;
			var baseY:Float = playStateBoyfriend != null ? playStateBoyfriend.getScreenPosition().y : 0;
			boyfriend = new Character(baseX, baseY, characterName, true);
			if(playStateBoyfriend != null)
			{
				boyfriend.x += boyfriend.positionArray[0] - playStateBoyfriend.positionArray[0];
				boyfriend.y += boyfriend.positionArray[1] - playStateBoyfriend.positionArray[1];
			}
		}
		else
		{
			boyfriend = sourceBoyfriend;
		}

		boyfriend.skipDance = true;
		add(boyfriend);

		FlxG.camera.scroll.set();
		FlxG.camera.target = null;
		camFollow = new FlxObject(0, 0, 1, 1);
		camFollow.setPosition(
			boyfriend.getGraphicMidpoint().x + boyfriend.cameraPosition[0],
			boyfriend.getGraphicMidpoint().y + boyfriend.cameraPosition[1]
		);
		backend.CameraResizeFix.focarEm(
			FlxG.camera,
			new FlxPoint(
				backend.CameraResizeFix.desgracaX(FlxG.camera),
				backend.CameraResizeFix.desgracaY(FlxG.camera)
			)
		);
		FlxG.camera.follow(camFollow, LOCKON, 0.01);
		add(camFollow);

		playGameOverDeathSound();
		boyfriend.playAnim('firstDeath');
		loadGameOverLoopMusic();
		createPicoRetryOverlay();
	}

	function createPicoRetryOverlay():Void
	{
		if(characterName != 'pico-dead' || boyfriend == null)
			return;

		overlay = new FlxSprite(boyfriend.x + 205, boyfriend.y - 80);
		overlay.frames = Paths.getSparrowAtlas('Pico_Death_Retry');
		overlay.animation.addByPrefix('deathLoop', 'Retry Text Loop', 24, true);
		overlay.animation.addByPrefix('deathConfirm', 'Retry Text Confirm', 24, false);
		overlay.antialiasing = ClientPrefs.data.antialiasing;
		overlayConfirmOffsets.set(250, 200);
		overlay.visible = false;
		add(overlay);

		boyfriend.animation.onFrameChange.add(function(name:String, frameNumber:Int, frameIndex:Int)
		{
			switch(name)
			{
				case 'firstDeath':
					if(frameNumber >= 35)
					{
						overlay.visible = true;
						overlay.animation.play('deathLoop');
						boyfriend.animation.onFrameChange.removeAll();
					}
				default:
					boyfriend.animation.onFrameChange.removeAll();
			}
		});

		if(PlayState.instance?.gf != null && PlayState.instance.gf.curCharacter == 'nene')
		{
			var neneKnife:FlxSprite = new FlxSprite(boyfriend.x - 450, boyfriend.y - 250);
			neneKnife.frames = Paths.getSparrowAtlas('NeneKnifeToss');
			neneKnife.animation.addByPrefix('anim', 'knife toss', 24, false);
			neneKnife.antialiasing = ClientPrefs.data.antialiasing;
			neneKnife.animation.onFinish.addOnce(function(_)
			{
				remove(neneKnife, true);
				neneKnife.destroy();
			});
			insert(0, neneKnife);
			neneKnife.animation.play('anim', true);
		}
	}

	function replaceBoyfriend(name:String):Void
	{
		if(name == null || name.trim().length < 1 || boyfriend == null || boyfriend.curCharacter == name)
			return;

		var old:Character = boyfriend;
		var replacement:Character = new Character(old.x, old.y, name, true);
		replacement.skipDance = true;
		var index:Int = members.indexOf(old);
		if(index < 0)
			index = 0;
		insert(index, replacement);
		if(members.contains(old))
			remove(old, true);
		if(old != sourceBoyfriend)
			old.destroy();
		boyfriend = replacement;
		boyfriend.playAnim('firstDeath');

		if(camFollow != null)
			camFollow.setPosition(
				boyfriend.getGraphicMidpoint().x + boyfriend.cameraPosition[0],
				boyfriend.getGraphicMidpoint().y + boyfriend.cameraPosition[1]
			);
	}

	function createCustomGameOverCharacter(name:String):Character
	{
		var targetName:String = name == null ? characterName : name.trim();
		if(targetName.length < 1)
			targetName = characterName;
		characterName = targetName;

		var old:Character = boyfriend != null ? boyfriend : sourceBoyfriend;
		if(old != null && old != sourceBoyfriend && old.curCharacter == targetName)
			return old;

		var baseX:Float = old != null ? old.x : 0;
		var baseY:Float = old != null ? old.y : 0;
		var replacement:Character = new Character(baseX, baseY, targetName, true);
		replacement.skipDance = true;
		if(old != null)
		{
			replacement.x += replacement.positionArray[0] - old.positionArray[0];
			replacement.y += replacement.positionArray[1] - old.positionArray[1];
		}

		var index:Int = old != null ? members.indexOf(old) : -1;
		if(index >= 0)
			insert(index, replacement);
		else
			add(replacement);

		if(old != null)
		{
			if(members.contains(old))
				remove(old, true);
			else
				old.visible = false;
			if(old != sourceBoyfriend)
				old.destroy();
		}

		boyfriend = replacement;
		customDeathSequenceActive = true;
		playGameOverDeathSound();
		loadGameOverLoopMusic();
		if(boyfriend.hasAnimation('firstDeath'))
			boyfriend.playAnim('firstDeath', true);
		else
		{
			if(boyfriend.hasAnimation('deathLoop'))
				boyfriend.playAnim('deathLoop', true);
			coolStartDeath();
		}
		refreshGameOverScriptVars();
		return boyfriend;
	}

	function playGameOverDeathSound():Void
	{
		var sound:Sound = null;
		for(character in [characterName, musicCharacterName])
		{
			if(character == null || character.trim().length < 1)
				continue;
			sound = Paths.gameOverSound(deathSoundName, character, true, false, false);
			if(sound != null)
				break;
		}

		if(sound == null)
			sound = Paths.gameOverSound(deathSoundName, 'default', true, false);
		if(sound == null)
			sound = Paths.gameOverSound(deathSoundName);
		if(sound != null)
			FlxG.sound.play(sound);
	}

	function resolveGameOverMusic(track:String, beepOnNull:Bool = false):Sound
	{
		for(character in [musicCharacterName, 'default'])
		{
			if(character == null || character.trim().length < 1)
				continue;
			var sound:Sound = Paths.gameOverMusic(character, PlayState.stageUI, track, true, false);
			if(sound != null)
				return sound;
		}
		return Paths.gameOverMusic('default', 'normal', track, true, beepOnNull);
	}

	function loadGameOverLoopMusic():Void
	{
		var sound:Sound = resolveGameOverMusic(loopSoundName, true);
		if(sound == null)
			return;

		FlxG.sound.music?.stop();
		FlxG.sound.playMusic(sound, 0, true);
		FlxG.sound.music?.pause();
		lastLoopMusicTime = -1;
	}

	function loadGameOverScripts():Void
	{
		loadScriptFolderLayers(Paths.gameOverScriptFolders(musicCharacterName, PlayState.stageUI), false);
	}

	function refreshGameOverScriptVars():Void
	{
		setOnScripts('gameOver', this);
		setOnScripts('gameOverSubstate', this);
		setOnScripts('boyfriend', boyfriend);
		setOnScripts('camFollow', camFollow);
		setOnScripts('stageData', stageData);
		setOnScripts('gameOverCharacter', characterName);
		setOnScripts('chrMusic', musicCharacterName);
		setOnScripts('gameOverMusicCharacter', musicCharacterName);
		setOnScripts('gameOverStageUI', PlayState.stageUI);
		setOnScripts('gameOverLoopTrack', loopSoundName);
		setOnScripts('gameOverRetryTrack', endSoundName);
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

	public function beginGameOverClock(?newBpm:Float = 100):Bool
	{
		if(Math.isNaN(newBpm) || newBpm <= 0)
			newBpm = 100;
		setBPM(newBpm, true);
		useStateConductorClock(true, true);
		gameOverClockStarted = true;
		lastGameOverStep = 0;
		lastLoopMusicTime = FlxG.sound.music != null ? FlxG.sound.music.time : -1;
		refreshGameOverScriptVars();
		callEveryScript('onGameOver', [0, 0]);
		return true;
	}

	function restartGameOverClock():Void
	{
		if(!gameOverClockStarted)
		{
			beginGameOverClock(100);
			return;
		}

		resetStateConductor(0);
		lastGameOverStep = 0;
		refreshGameOverScriptVars();
		callEveryScript('onGameOver', [0, 0]);
	}

	override function stepHit(step:Int):Void
	{
		super.stepHit(step);
		if(gameOverClockStarted && step != lastGameOverStep)
		{
			lastGameOverStep = step;
			callEveryScript('onGameOver', [step, curBeat]);
		}
	}

	override function update(elapsed:Float):Void
	{
		var runDefaultUpdate:Bool = preUpdate(elapsed);

		if(gameOverClockStarted && FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			var musicTime:Float = FlxG.sound.music.time;
			if(lastLoopMusicTime >= 0 && musicTime + 5 < lastLoopMusicTime)
				restartGameOverClock();
			else
				stateConductorPosition = Math.max(0, musicTime - elapsed * 1000);
			lastLoopMusicTime = musicTime;
		}

		// The PlayState itself is paused while this substate is open. Keep the
		// original character animating during a fully custom Game Over intro.
		if(!defaultGameOverEnabled && boyfriend == sourceBoyfriend && boyfriend != null && boyfriend.active)
			boyfriend.update(elapsed);

		super.update(elapsed);

		if(runDefaultUpdate)
		{
			if(defaultGameOverEnabled || customDeathSequenceActive)
				updateDefaultGameOver();
			if(!isEnding)
			{
				if(controls.ACCEPT)
					requestRetry();
				else if(controls.BACK)
					requestQuit();
			}
		}

		postUpdate(elapsed);
	}

	function updateDefaultGameOver():Void
	{
		var justPlayedLoop:Bool = false;
		if(boyfriend != null && !boyfriend.isAnimationNull() && boyfriend.getAnimationName() == 'firstDeath' && boyfriend.isAnimationFinished())
		{
			boyfriend.playAnim('deathLoop');
			if(overlay != null && overlay.animation.exists('deathLoop'))
			{
				overlay.visible = true;
				overlay.animation.play('deathLoop');
			}
			justPlayedLoop = true;
		}

		if(!isEnding && justPlayedLoop)
			coolStartDeath();
	}

	function coolStartDeath(?volume:Float = 1):Void
	{
		if(Math.isNaN(volume))
			volume = 1;
		if(FlxG.sound.music == null)
			loadGameOverLoopMusic();
		if(FlxG.sound.music == null)
			return;

		FlxG.sound.music.play(true);
		FlxG.sound.music.volume = FlxMath.bound(volume, 0, 1);
		restartGameOverClock();
	}

	function requestRetry():Void
	{
		if(isEnding || retryCallbackRunning)
			return;

		retryCallbackRunning = true;
		var stopped:Bool = callWasStopped('onRetry');
		retryCallbackRunning = false;
		if(!stopped && !isEnding)
			performRetry();
	}

	public function performRetry():Bool
	{
		if(isEnding)
			return false;
		isEnding = true;

		if(boyfriend != null)
		{
			if(boyfriend.hasAnimation('deathConfirm'))
				boyfriend.playAnim('deathConfirm', true);
			else if(boyfriend.hasAnimation('deathLoop'))
				boyfriend.playAnim('deathLoop', true);
		}

		if(overlay != null && overlay.animation.exists('deathConfirm'))
		{
			overlay.visible = true;
			overlay.animation.play('deathConfirm');
			overlay.offset.set(overlayConfirmOffsets.x, overlayConfirmOffsets.y);
		}

		FlxG.sound.music?.stop();
		var endSound:Sound = resolveGameOverMusic(endSoundName, true);
		if(endSound != null)
			FlxG.sound.play(endSound);

		new FlxTimer().start(0.7, function(_)
		{
			FlxG.camera.fade(FlxColor.BLACK, 2, false, function()
			{
				MusicBeatState.resetState();
			});
		});
		return true;
	}

	function requestQuit():Void
	{
		if(isEnding || callWasStopped('onQuit'))
			return;
		performQuit();
	}

	public function performQuit(?blackDuration:Float = 1.25):Bool
	{
		if(isEnding)
			return false;
		isEnding = true;

		#if DISCORD_ALLOWED
		DiscordClient.resetClientID();
		#end
		FlxG.sound.music?.stop();
		PlayState.deathCounter = 0;
		PlayState.seenCutscene = false;
		PlayState.chartingMode = false;

		if(Math.isNaN(blackDuration) || blackDuration < 0)
			blackDuration = 1.25;
		FlxG.camera.fade(FlxColor.BLACK, blackDuration, false, exitToMenu);
		return true;
	}

	function exitToMenu():Void
	{
		Mods.loadTopMod();
		if(PlayState.isStoryMode)
		{
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
	}

	#if LUA_ALLOWED
	public override function implementLua(lua:psychlua.FunkinLua):Void
	{
		super.implementLua(lua);

		lua.set('gameOver', this);
		lua.set('gameOverSubstate', this);
		lua.set('stageData', stageData);
		lua.set('gameOverCharacter', characterName);
		lua.set('chrMusic', musicCharacterName);
		lua.set('gameOverMusicCharacter', musicCharacterName);
		lua.set('gameOverStageUI', PlayState.stageUI);

		lua.addLocalCallback('changeGameOver', changeGameOver);
		lua.addLocalCallback('changeGameOverMusic', setGameOverMusic);
		lua.addLocalCallback('gameOverMusic', setGameOverMusic);
		lua.addLocalCallback('startGameOver', startGameOver);
		lua.addLocalCallback('retrySong', retrySong);
	}
	#end

	override function destroy():Void
	{
		if(instance == this)
			instance = null;
		overlayConfirmOffsets = FlxDestroyUtil.put(overlayConfirmOffsets);
		super.destroy();
	}
}
