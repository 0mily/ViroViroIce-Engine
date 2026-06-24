package substates;

import backend.WeekData;

import objects.Character;
import flixel.FlxObject;
import flixel.FlxSubState;
import flixel.math.FlxPoint;
import flash.media.Sound;

import states.StoryMenuState;
import states.FreeplayState;

class GameOverSubstate extends ScriptedSubState
{
	public var boyfriend:Character;
	var camFollow:FlxObject;

	var stagePostfix:String = '';

	public static var characterName:String = 'bf-dead';
	public static var musicCharacterName:String = 'bf';
	public static var deathSoundName:String = 'fnf_loss_sfx';
	public static var loopSoundName:String = 'music';
	public static var endSoundName:String = 'music-end';
	public static var deathDelay:Float = 0;

	public static var instance:GameOverSubstate;
	public static function setGameOverMusic(kind:String = 'loop', songfile:String = 'music'):Void
	{
		var musicKind:String = kind == null ? 'loop' : kind.toLowerCase().trim();
		var musicTrack:String = songfile == null || songfile.trim().length < 1 ? 'music' : songfile;
		switch(musicKind)
		{
			case 'end' | 'retry' | 'confirm':
				endSoundName = musicTrack;
			default:
				loopSoundName = musicTrack;
		}
	}

	public function new(?playStateBoyfriend:Character = null)
	{
		if(playStateBoyfriend != null && playStateBoyfriend.curCharacter != null && playStateBoyfriend.curCharacter.trim().length > 0)
			musicCharacterName = playStateBoyfriend.curCharacter;

		if(playStateBoyfriend != null && playStateBoyfriend.curCharacter == characterName) //Avoids spawning a second boyfriend cuz animate atlas is laggy
		{
			this.boyfriend = playStateBoyfriend;
		}
		super();
	}

	public static function resetVariables() {
		characterName = 'bf-dead';
		musicCharacterName = (PlayState.SONG != null && PlayState.SONG.player1 != null && PlayState.SONG.player1.trim().length > 0) ? PlayState.SONG.player1 : 'bf';
		deathSoundName = 'fnf_loss_sfx';
		loopSoundName = 'music';
		endSoundName = 'music-end';
		deathDelay = 0;

		var _song = PlayState.SONG;
		if(_song != null)
		{
			if(_song.gameOverChar != null && _song.gameOverChar.trim().length > 0) characterName = _song.gameOverChar;
			if(_song.gameOverSound != null && _song.gameOverSound.trim().length > 0) deathSoundName = _song.gameOverSound;
		}
	}

	var charX:Float = 0;
	var charY:Float = 0;

	var overlay:FlxSprite;
	var overlayConfirmOffsets:FlxPoint = FlxPoint.get();
	override function create()
	{
		preCreate();
		
		instance = this;

		Conductor.songPosition = 0;

		if (boyfriend == null) {
			boyfriend = new Character(PlayState.instance.boyfriend.getScreenPosition().x, PlayState.instance.boyfriend.getScreenPosition().y, characterName, true);
			boyfriend.x += boyfriend.positionArray[0] - PlayState.instance.boyfriend.positionArray[0];
			boyfriend.y += boyfriend.positionArray[1] - PlayState.instance.boyfriend.positionArray[1];
		}
		boyfriend.skipDance = true;
		add(boyfriend);

		FlxG.camera.scroll.set();
		FlxG.camera.target = null;
		camFollow = new FlxObject(0, 0, 1, 1);
		camFollow.setPosition(boyfriend.getGraphicMidpoint().x + boyfriend.cameraPosition[0], boyfriend.getGraphicMidpoint().y + boyfriend.cameraPosition[1]);
		backend.CameraResizeFix.focarEm(FlxG.camera, new FlxPoint(backend.CameraResizeFix.desgracaX(FlxG.camera), backend.CameraResizeFix.desgracaY(FlxG.camera)));
		FlxG.camera.follow(camFollow, LOCKON, 0.01);
		add(camFollow);

		loadGameOverScripts();
		callOnScripts('onDie');

		playGameOverDeathSound();

		boyfriend.playAnim('firstDeath');
		
		PlayState.instance?.stagesFunc((stage:BaseStage) -> stage.onGameOverStart());
		
		PlayState.instance?.setOnScripts('inGameOver', true);
		PlayState.instance?.callOnScripts('onGameOverStart', []);
		loadGameOverLoopMusic();
		
		if (characterName == 'pico-dead') {
			overlay = new FlxSprite(boyfriend.x + 205, boyfriend.y - 80);
			overlay.frames = Paths.getSparrowAtlas('Pico_Death_Retry');
			overlay.animation.addByPrefix('deathLoop', 'Retry Text Loop', 24, true);
			overlay.animation.addByPrefix('deathConfirm', 'Retry Text Confirm', 24, false);
			overlay.antialiasing = ClientPrefs.data.antialiasing;
			overlayConfirmOffsets.set(250, 200);
			overlay.visible = false;
			add(overlay);

			boyfriend.animation.onFrameChange.add(function(name:String, frameNumber:Int, frameIndex:Int) {
				switch (name) {
					case 'firstDeath':
						if (frameNumber >= 36 - 1) {
							overlay.visible = true;
							overlay.animation.play('deathLoop');
							boyfriend.animation.onFrameChange.removeAll();
						}
					default:
						boyfriend.animation.onFrameChange.removeAll();
				}
			});

			if (PlayState.instance.gf != null && PlayState.instance.gf.curCharacter == 'nene') {
				var neneKnife:FlxSprite = new FlxSprite(boyfriend.x - 450, boyfriend.y - 250);
				neneKnife.frames = Paths.getSparrowAtlas('NeneKnifeToss');
				neneKnife.animation.addByPrefix('anim', 'knife toss', 24, false);
				neneKnife.antialiasing = ClientPrefs.data.antialiasing;
				neneKnife.animation.onFinish.addOnce(function(_) {
					remove(neneKnife, true);
					neneKnife.kill();
				});
				insert(0, neneKnife);
				neneKnife.animation.play('anim', true);
			}
		}

		super.create();
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
		var sound:Sound = null;
		for(character in [musicCharacterName, 'default'])
		{
			if(character == null || character.trim().length < 1)
				continue;

			sound = Paths.gameOverMusic(character, PlayState.stageUI, track, true, false);
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

		if(FlxG.sound.music != null)
			FlxG.sound.music.stop();
		FlxG.sound.playMusic(sound, 0, true);
		if(FlxG.sound.music != null)
			FlxG.sound.music.pause();
	}

	function loadGameOverScripts():Void
	{
		#if sys
		var folder:String = resolveGameOverScriptFolder();
		if(folder == null)
			return;

		var files:Array<String> = FileSystem.readDirectory(folder);
		files.sort(function(a:String, b:String) return Reflect.compare(a.toLowerCase(), b.toLowerCase()));

		for(file in files)
		{
			var path:String = '$folder/$file';
			if(FileSystem.isDirectory(path))
				continue;

			#if LUA_ALLOWED
			if(file.toLowerCase().endsWith('.lua'))
				initLuaScript(path);
			#end

			#if HSCRIPT_ALLOWED
			if(psychlua.HScript.hasScriptExtension(file))
				initHScript(path);
			#end
		}

		setOnScripts('gameOver', this);
		setOnScripts('gameOverSubstate', this);
		setOnScripts('boyfriend', boyfriend);
		setOnScripts('camFollow', camFollow);
		setOnScripts('gameOverCharacter', characterName);
		setOnScripts('gameOverMusicCharacter', musicCharacterName);
		setOnScripts('gameOverStageUI', PlayState.stageUI);
		#if LUA_ALLOWED
		callOnLuas('onLoad');
		#end
		#end
	}

	#if sys
	function resolveGameOverScriptFolder():String
	{
		for(folder in Paths.gameOverScriptFolders(musicCharacterName, PlayState.stageUI))
		{
			#if ADDONS_ALLOWED
			var modFolder:String = Paths.modFolders(folder);
			if(FileSystem.exists(modFolder) && FileSystem.isDirectory(modFolder))
				return modFolder;
			#end

			var sharedFolder:String = Paths.getSharedPath(folder);
			if(FileSystem.exists(sharedFolder) && FileSystem.isDirectory(sharedFolder))
				return sharedFolder;
		}
		return null;
	}
	#end

	override function update(elapsed:Float)
	{
		preUpdate(elapsed);
		
		super.update(elapsed);
		
		PlayState.instance?.callOnScripts('onUpdate', [elapsed]);

		var justPlayedLoop:Bool = false;
		if (!boyfriend.isAnimationNull() && boyfriend.getAnimationName() == 'firstDeath' && boyfriend.isAnimationFinished()) {
			boyfriend.playAnim('deathLoop');
			if(overlay != null && overlay.animation.exists('deathLoop')) {
				overlay.visible = true;
				overlay.animation.play('deathLoop');
			}
			justPlayedLoop = true;
		}

		if(!isEnding)
		{
			if (controls.ACCEPT)
			{
				endBullshit();
			}
			else if (controls.BACK && PlayState.instance?.callOnScripts('onGameOverConfirmPre', [false], true) != psychlua.LuaUtils.Function_Stop)
			{
				#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
				FlxG.camera.visible = false;
				if(FlxG.sound.music != null)
					FlxG.sound.music.stop();
				PlayState.deathCounter = 0;
				PlayState.seenCutscene = false;
				PlayState.chartingMode = false;
				
				PlayState.instance?.stagesFunc((stage:BaseStage) -> stage.onGameOverConfirm(false));
				
				var stopped:Bool = (callOnScripts('onGameOverConfirm', [false], true) == psychlua.LuaUtils.Function_Stop);
				stopped = (stopped || (PlayState.instance != null && PlayState.instance.callOnScripts('onGameOverConfirm', [false], true) == psychlua.LuaUtils.Function_Stop));
				
				if (!stopped) {
					Mods.loadTopMod();
					
					if (PlayState.isStoryMode) {
						if (Mods.modUsesStickerTrans()) {
							openSubState(new StickerSubState(null, (sticker) -> new StoryMenuState(sticker)));
						} else {
							MusicBeatState.switchState(new StoryMenuState());
							FlxG.sound.playMusic(Paths.menuMusic('mainMenu'));
						}
					} else {
						if (Mods.modUsesStickerTrans()) {
							openSubState(new StickerSubState(null, (sticker) -> new FreeplayState(sticker)));
						} else {
							MusicBeatState.switchState(new FreeplayState());
							FlxG.sound.playMusic(Paths.menuMusic('mainMenu'));
						}
					}
				}
			} else if (justPlayedLoop) {
				coolStartDeath();
			}
			
			if (FlxG.sound.music != null && FlxG.sound.music.playing)
				Conductor.songPosition = FlxG.sound.music.time;
		}
		
		PlayState.instance?.callOnScripts('onUpdatePost', [elapsed]);
		
		postUpdate(elapsed);
	}

	public var isEnding:Bool = false;
	function coolStartDeath(?volume:Float = 1):Void
	{
		if(FlxG.sound.music == null)
			loadGameOverLoopMusic();
		if(FlxG.sound.music == null)
			return;

		FlxG.sound.music.play(true);
		FlxG.sound.music.volume = volume;
		
		PlayState.instance?.stagesFunc((stage:BaseStage) -> stage.onGameOverLoop());
		PlayState.instance?.callOnScripts('onGameOverLoop', []);
	}

	function endBullshit():Void
	{
		if (!isEnding && PlayState.instance?.callOnScripts('onGameOverConfirmPre', [true], true) != psychlua.LuaUtils.Function_Stop)
		{
			isEnding = true;
			if (boyfriend.hasAnimation('deathConfirm')) {
				boyfriend.playAnim('deathConfirm', true);
			} else if (boyfriend.hasAnimation('deathLoop')) {
				boyfriend.playAnim('deathLoop', true);
			}

			if(overlay != null && overlay.animation.exists('deathConfirm')) {
				overlay.visible = true;
				overlay.animation.play('deathConfirm');
				overlay.offset.set(overlayConfirmOffsets.x, overlayConfirmOffsets.y);
			}
			if(FlxG.sound.music != null)
				FlxG.sound.music.stop();
			callOnScripts('onRetry');
			var endSound:Sound = resolveGameOverMusic(endSoundName, true);
			if(endSound != null)
				FlxG.sound.play(endSound);
			
			new FlxTimer().start(.7, (_) -> {
				FlxG.camera.fade(FlxColor.BLACK, 2, false, () -> MusicBeatState.resetState());
			});
			
			PlayState.instance?.stagesFunc((stage:BaseStage) -> stage.onGameOverConfirm(true));
			
			callOnScripts('onGameOverConfirm', [true]);
			PlayState.instance?.callOnScripts('onGameOverConfirm', [true]);
		}
	}

	#if LUA_ALLOWED
	public override function implementLua(lua:psychlua.FunkinLua):Void
	{
		super.implementLua(lua);

		lua.set('gameOverCharacter', characterName);
		lua.set('gameOverMusicCharacter', musicCharacterName);
		lua.set('gameOverStageUI', PlayState.stageUI);
		lua.addLocalCallback('gameOverMusic', function(kind:String = 'loop', songfile:String = 'music') {
			setGameOverMusic(kind, songfile);
		});
	}
	#end

	override function destroy()
	{
		instance = null;
		super.destroy();
	}
}
