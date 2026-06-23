package states;

import backend.Highscore;
import backend.StageData;
import backend.WeekData;
import backend.Song;
import backend.Rating;

import flixel.FlxSubState;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
import flixel.animation.FlxAnimationController;
import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import openfl.events.KeyboardEvent;
import haxe.Json;

import cutscenes.DialogueBoxPsych;
import cutscenes.DialoguePlus;
import cutscenes.DialoguePlusRuntime;

import states.StoryMenuState;
import states.FreeplayState;
import states.editors.ChartingState;
import states.editors.CharacterEditorState;

import substates.PauseSubState;
import substates.GameOverSubstate;
import substates.StickerSubState;

#if !flash
import openfl.filters.ShaderFilter;
#end

import objects.VideoSprite;
import objects.Note.EventNote;
import objects.*;
import states.stages.*;
import states.stages.objects.*;

#if LUA_ALLOWED
import psychlua.*;
#else
import psychlua.LuaUtils;
import psychlua.HScript;
#end

import backend.DropShadowData;

typedef StrumRuntimeTarget = {
	var staticIndices:Array<Int>;
	var noteIndices:Array<Int>;
}

/*here's some useful tips if you are making a mod in source:

If you want to add your stage to the game, copy states/stages/Template.hx,
and put your stage code there, then, on PlayState, search for
"switch (curStage)", and add your stage to that list.

If you want to code Events, you can either code it on a Stage file or on PlayState, if you're doing the latter, search for:

"function eventPushed" - Only called *one time* when the game loads, use it for precaching events that use the same assets, no matter the values
"function eventPushedUnique" - Called one time per event, use it for precaching events that uses different assets based on its values
"function eventEarlyTrigger" - Used for making your event start a few MILLISECONDS earlier
"function triggerEvent" - Called when the song hits your event's timestamp, this is probably what you were looking for*/

/**
 * This is the main state of the game, where gameplay happens and is managed.
*/
class PlayState extends ScriptedState
{
	public static var STRUM_X = 42;
	public static var STRUM_X_MIDDLESCROLL = -278;

	/**
	 * Rating names used on the score text.
	*/
	public static var ratingStuff:Array<Dynamic> = [
		['You Suck!', 0.2], //From 0% to 19%
		['Shit', 0.4], //From 20% to 39%
		['Bad', 0.5], //From 40% to 49%
		['Bruh', 0.6], //From 50% to 59%
		['Meh', 0.69], //From 60% to 68%
		['Nice', 0.7], //69%
		['Good', 0.8], //From 70% to 79%
		['Great', 0.9], //From 80% to 89%
		['Sick!', 1], //From 90% to 99%
		['Perfect!!', 1] //The value on this one isn't used actually, since Perfect is always "1"
	];

	//event variables
	/**
	 * If set to true, the camera focus position won't change every measure.
	*/
	private var isCameraOnForcedPos:Bool = false;

	/**
	 * Map containing all precached characters the player character will change to (with the Change Character event).
	*/
	public var boyfriendMap:Map<String, Character> = new Map<String, Character>();
	/**
	 * Map containing all precached characters the opponent character will change to (with the Change Character event).
	*/
	public var dadMap:Map<String, Character> = new Map<String, Character>();
	/**
	 * Map containing all precached characters the speakers (middle) character will change to (with the Change Character event).
	*/
	public var gfMap:Map<String, Character> = new Map<String, Character>();
	public var extraCharacterMap:Map<String, Character> = new Map<String, Character>();
	public var extraCharacterGroups:Map<String, FlxSpriteGroup> = new Map<String, FlxSpriteGroup>(); // XIXI COCO BUCETA. NUM FUNFA
	public var extraCharacterNoteTypes:Map<String, String> = new Map<String, String>();
	var extraCharacterIsPlayer:Map<String, Bool> = new Map<String, Bool>();
	var extraCharacterUsePlayerOffsets:Map<String, Null<Bool>> = new Map<String, Null<Bool>>();
	var pendingExtraCharacterScroll:Map<String, Array<Float>> = new Map<String, Array<Float>>();
	

	var BF_X:Float = 770;
	var BF_Y:Float = 100;
	var DAD_X:Float = 100;
	var DAD_Y:Float = 100;
	var GF_X:Float = 400;
	var GF_Y:Float = 130;

	/**
	 * Scroll speed for the current song.
	*/
	public var songSpeed(default, set):Float = 1;
	/**
	 * Scroll speed type, used in Gameplay Modifiers.
	*/
	public var songSpeedType:String = "multiplicative";
	/**
	 * Time (in milliseconds) past a note's hit time at which it will despawn.
	*/
	public var noteKillOffset:Float = 350;
	@:dox(hide) var songSpeedTween:FlxTween;

	/**
	 * The speed multiplier for the song and gameplay. 2x means 200% speed.
	*/
	public var playbackRate(default, set):Float = 1;

	/**
	 * Group containing all precached characters the player character will change to (with the Change Character event).
	*/
	public var boyfriendGroup:FlxSpriteGroup;
	/**
	 * Group containing all precached characters the player character will change to (with the Change Character event). Shorthand for `boyfriendGroup`.
	*/
	public var bfGroup(get, never):FlxSpriteGroup;
	/**
	 * Group containing all precached characters the opponent character will change to (with the Change Character event).
	*/
	public var dadGroup:FlxSpriteGroup;
	/**
	 * Group containing all precached characters the speakers (middle) character will change to (with the Change Character event).
	*/
	public var gfGroup:FlxSpriteGroup;
	
	/**
	 * The name of the current stage, defined in the song's JSON.
	*/
	public static var curStage:String = '';
	/**
	 * The name of the current stage UI, defined in the stage's JSON.
	 * This changes the image path of UI elements such as the notes and the rating pop ups.
	*/
	public static var stageUI(default, set):String = "normal";
	public static var uiPrefix:String = "";
	public static var uiPostfix:String = "";
	public static var isPixelStage(get, never):Bool;

	@:noCompletion
	static function set_stageUI(value:String):String
	{
		uiPrefix = uiPostfix = "";
		if (value != "normal" && value != '')
		{
			uiPrefix = value.split("-pixel")[0].trim() + 'UI/';
			if (value == "pixel" || value.endsWith("-pixel")) uiPostfix = "-pixel";
		}
		return stageUI = value;
	}
	public static function formatUI(key:String):String {
		return '$uiPrefix$key$uiPostfix';
	}

	@:noCompletion
	static function get_isPixelStage():Bool
		return stageUI == "pixel" || stageUI.endsWith("-pixel");
	
	@:noCompletion function get_bf():Character
		return boyfriend;
	@:noCompletion function get_bfGroup():FlxSpriteGroup
		return boyfriendGroup;
	
	/**
	 * Holds data of the current song chart.
	*/
	public static var SONG:SwagSong = null;
	/**
	 * Holds data of the current events chart (if available).
	*/
	public static var EVENTS:SwagSong = null;
	/**
	 * Name of the current song, as defined in the chart JSON.
	*/
	public var curSong:String = '';
	/**
	 * Name of the current song, as defined in the chart JSON, formatted to match the data folder.
	*/
	public var songName:String;
	
	/**
	 * Whether this state was entered to from Story Mode.
	*/
	public static var isStoryMode:Bool = false;
	/**
	 * Whether this state was entered to from Story Mode.
	*/
	public static var storyPlaylist:Array<String> = [];
	/**
	 * Holds data of the current story week (if entered to from Story Mode).
	*/
	public static var storyWeekData:WeekData = null;
	/**
	 * Variables that will persist between Story Mode songs.
	 * This map is cleared after a story week.
	*/
	public static var storyVariables:Map<String, Dynamic> = [];
	/**
	 * The ID of the current difficulty selected for this song.
	*/
	public static var storyDifficulty:Int = 1;
	/**
	 * The ID of the current story week (if entered to from Story Mode).
	*/
	public static var storyWeek:Int = 0;
	
	/**
	 * The time (in milliseconds) a note can spawn earlier to it's hit time.
	*/
	public var spawnTime:Float = 2000;
	/**
	 * Whether missing notes should play a sound or not.
	*/
	public var playMissSound:Bool = true;

	/**
	 * The instrumental of the song.
	*/
	public var inst:FlxSound;
	/**
	 * The [player] vocals of the song.
	*/
	public var vocals:FlxSound;
	/**
	 * The opponent vocals of the song (if available).
	*/
	public var opponentVocals:FlxSound;
	/**
	 * The extra characters vocals of the song (if available).
	*/
	public var extraVocals:Map<String, FlxSound> = new Map<String, FlxSound>(); // shiho se cê não terminar isso em menos de 1 semana você será assassinada -Shiho
	
	/**
	 * The player side character.
	*/
	public var boyfriend:Character = null;
	/**
	 * The player side character. Shorthand for `boyfriend`.
	*/
	public var bf(get, never):Character;
	/**
	 * The opponent side character.
	*/
	public var dad:Character = null;
	/**
	 * The speakers (middle) character.
	*/
	public var gf:Character = null;
	
	/**
	 * Group containing all notes currently on-screen.
	*/
	public var notes:FlxTypedGroup<Note>;
	/**
	 * Array containing all notes queued to spawn later.
	*/
	public var unspawnNotes:Array<Note> = [];
	/**
	 * Array containing all events queued to be triggered later.
	*/
	public var eventNotes:Array<EventNote> = [];

	/**
	 * Acts as the camera focus. The game camera will follow this object.
	*/
	public var camFollow:FlxObject;
	@:dox(hide) private static var prevCamFollow:FlxObject;

	/**
	 * Group containing all note receptors.
	*/
	public var strumLineNotes:FlxTypedSpriteGroup<StrumNote> = new FlxTypedSpriteGroup<StrumNote>();
	/**
	 * Group containing the player's note receptors.
	*/
	public var playerStrums:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	/**
	 * Group containing the opponent's note receptors.
	*/
	public var opponentStrums:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	public var strumSkinOverrides:Array<String> = [for (_ in 0...8) null];
	public var noteSkinOverrides:Array<String> = [for (_ in 0...8) null];
	public var strumRGBOverrides:Array<Null<FlxColor>> = [for (_ in 0...8) null];
	public var noteRGBOverrides:Array<Null<FlxColor>> = [for (_ in 0...8) null];
	public var strumRGBAllowedOverrides:Array<Null<Bool>> = [for (_ in 0...8) null];
	public var noteRGBAllowedOverrides:Array<Null<Bool>> = [for (_ in 0...8) null];
	/**
	 * Group containing all note splashes.
	*/
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash> = new FlxTypedGroup<NoteSplash>();
	/**
	 * Group containing all note hold splashes.
	*/
	public var grpHoldSplashes:FlxTypedGroup<SustainSplash> = new FlxTypedGroup<SustainSplash>();

	/**
	 * Whether the camera should bop every measure or not.
	 * This is set to true for every opponent note hit, if `camZoomingDisabled` is false.
	*/
	public var camZooming:Bool = false;
	/**
	 * If true, opponent note hits will not set `camZooming` to true.
	*/
	public var camZoomingDisabled:Bool = false;
	/**
	 * Multiplier for the camera bopping.
	*/
	public var camZoomingMult:Float = 1;
	/**
	 * Multiplier for the decay time of the camera bopping.
	*/
	public var camZoomingDecay:Float = 1;
	/**
	 * Disables the default section camera bop while a scripted camera bop event is active.
	*/
	public var scriptedCameraBopActive:Bool = false;
	public var scriptedCameraBopRate:Float = 4;
	public var scriptedCameraBopOffset:Float = 0;
	public var scriptedCameraBopIntensity:Float = 1;
	public var scriptedCameraBopUnit:String = 'beat';
	public var scriptedCameraBopGame:Float = 0.015;
	public var scriptedCameraBopHUD:Float = 0.03;
	public var scriptedCameraBopPattern:Array<Int> = null;
	public var scriptedCameraBopBlocksDefault:Bool = false;
	var camGameBaseZoom:Float = 1.05;
	var camGameBopZoom:Float = 0;
	var camHUDBopZoom:Float = 0;

	/**
	 * How frequently the speakers (middle) character should bop every beat.
	 * 1 is every one beat, 2 is every two beats, and so on.
	*/
	public var gfSpeed:Int = 1;
	/**
	 * The health of the player.
	 * 0 is 0% health, and 2 is 100% health.
	*/
	public var health(default, set):Float = 1;
	/**
	 * The note combo of the player.
	*/
	public var combo:Int = 0;

	/**
	 * The current song's length (in milliseconds).
	*/
	public var songLength:Float = 0;
	/**
	 * The current song's progress represented as a `Float`.
	 * 0 is 0% progressed, and 1 is 100% progressed.
	*/
	var songPercent:Float = 0;
	public var healthBar:Bar;
	public var timeBar:Bar;

	/**
	 * Data for the ratings, used to judge note hits.
	*/
	public var ratingsData:Array<Rating> = Rating.loadDefault();

	/**
	 * If the player changed difficulty in the Pause Menu.
	*/
	public static var changedDifficulty:Bool = false;
	/**
	 * If the player is in Charting Mode.
	*/
	public static var chartingMode:Bool = false;
	public var generatedMusic:Bool = false;
	public var endingSong:Bool = false;
	public var startingSong:Bool = false;
	public var updateTime:Bool = true;

	//Gameplay settings
	/**
	 * Multiplier for the health gained by hitting a note successfully.
	*/
	public var healthGain:Float = 1;
	/**
	 * Multiplier for the health lost by missing a note.
	*/
	public var healthLoss:Float = 1;

	/**
	 * Whether or not Sustains as One Note is enabled.
	*/
	public var guitarHeroSustains:Bool = false;
	/**
	 * Whether or not the "Instakill on miss" Gameplay modifier is enabled.
	*/
	public var instakillOnMiss:Bool = false;
	/**
	 * Whether or not Bot Play is enabled.
	*/
	public var cpuControlled:Bool = false;
	/**
	 * Whether or not Practice Mode is enabled.
	*/
	public var practiceMode:Bool = false;
	/**
	 * Whether or not Ghost Tapping is enabled.
	*/
	public var ghostTapping:Bool = false;
	/**
	 * The default damage caused by missing a note.
	*/
	public var pressMissDamage:Float = 0.05;

	public var botplayTxt:FlxText;
	public var botplaySine:Float = 0;

	/**
	 * The player character's healthbar icon.
	*/
	public var iconP1:HealthIcon;
	/**
	 * The opponent character's healthbar icon.
	*/
	public var iconP2:HealthIcon;
	/**
	 * The camera used for the HUD.
	*/
	public var camHUD:FlxCamera;
	/**
	 * The camera used for the game.
	*/
	public var camGame:FlxCamera;
	/**
	 * Speed multiplier for the camera to shift towards its focus.
	*/
	public var cameraSpeed:Float = 1;
	public var cameraFocus:String = 'dad';
	public var cameraFocusOffsetX:Float = 0;
	public var cameraFocusOffsetY:Float = 0;
	public var cameraMoveEnabled:Bool = false;
	public var cameraMoveIntensity:Float = 1;
	public var cameraMoveSpeed:Float = 1;
	public var cameraMoveOffset:Float = 30;
	@:dox(hide) var cameraFocusTween:FlxTween;
	@:dox(hide) var cameraMoveTween:FlxTween;
	@:dox(hide) var cameraZoomTween:FlxTween;
	var cameraAngleTweens:Map<FlxCamera, FlxTween> = [];
	var cameraFocusBaseX:Float = 0;
	var cameraFocusBaseY:Float = 0;
	var cameraMoveOffsetX:Float = 0;
	var cameraMoveOffsetY:Float = 0;
	var cameraMoveReturning:Bool = false;

	/**
	 * The player's current score.
	*/
	public var songScore:Int = 0;
	/**
	 * How many notes have been successfully hit since the start of the song.
	*/
	public var songHits:Int = 0;
	/**
	 * How many notes have been missed since the start of the song.
	*/
	public var songMisses:Int = 0;
	/**
	 * The text that displays the player's current score and rating.
	*/
	public var scoreTxt:FlxText;
	public var timeTxt:FlxText;
	var scoreTxtTween:FlxTween;

	/**
	 * The player's accumulated score since the start of the week (in Story Mode).
	*/
	public static var campaignScore:Int = 0;
	/**
	 * The player's accumulated miss count since the start of the week (in Story Mode).
	*/
	public static var campaignMisses:Int = 0;
	/**
	 * The amount of times the player has died in this song.
	*/
	public static var deathCounter:Int = 0;
	/**
	 * Whether or not the player has seen the current song's cutscene.
	*/
	public static var seenCutscene:Bool = false;

	public var defaultCamZoom:Float = 1.05;

	// how big to stretch the pixel art assets
	public static var daPixelZoom:Float = 6;
	private var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	/**
	 * Whether or not the player is currently viewing a cutscene.
	 * Setting to true pauses certain gameplay inputs and logic.
	*/
	public var inCutscene:Bool = false;
	/**
	 * Whether or not the game should skip the countdown sequence.
	 * Only effective if changed during state creation!
	*/
	public var skipCountdown:Bool = false;

	/**
	 * The player character's camera offset, as defined in the stage JSON.
	*/
	public var boyfriendCameraOffset:Array<Float> = null;
	/**
	 * The opponent character's camera offset, as defined in the stage JSON.
	*/
	public var opponentCameraOffset:Array<Float> = null;
	/**
	 * The speakers (middle) character's camera offset, as defined in the stage JSON.
	*/
	public var girlfriendCameraOffset:Array<Float> = null;

	#if DISCORD_ALLOWED
	// Discord RPC variables
	var storyDifficultyText:String = "";
	var detailsText:String = "";
	var detailsPausedText:String = "";
	#end

	//Achievement shit
	@:dox(hide) var keysPressed:Array<Int> = [];
	@:dox(hide) var boyfriendIdleTime:Float = 0.0;
	@:dox(hide) var boyfriendIdled:Bool = false;

	// Lua shit
	/**
	 * The current PlayState instance.
	*/
	public static var instance:PlayState;
	
	/**
	 * Suffix for the sounds played during the countdown.
	*/
	public var introSoundsSuffix:String = '';

	// Less laggy controls
	private var keysArray:Array<String>;

	// Callbacks for stages
	/**
	 * Function called before the countdown starts.
	*/
	public var startCallback:Void->Void = null;
	/**
	 * Function called before the song finishes.
	*/
	public var endCallback:Void->Void = null;

	private static var _lastLoadedModDirectory:String = '';
	public static var nextReloadAll:Bool = false;
	override public function create()
	{
		//trace('Playback Rate: ' + playbackRate);
		_lastLoadedModDirectory = Mods.getAssetContextKey();
		Paths.clearStoredMemory();
		if(nextReloadAll)
		{
			Paths.clearUnusedMemory();
			Language.reloadPhrases();
		}
		nextReloadAll = false;

		startCallback = () -> stagesFunc(function(stage:BaseStage) stage.startCountdown());
		endCallback = () -> stagesFunc(function(stage:BaseStage) stage.endSong());

		// for lua
		instance = this;

		PauseSubState.songName = null; //Reset to default
		playbackRate = ClientPrefs.getGameplaySetting('songspeed');

		keysArray = [
			'note_left',
			'note_down',
			'note_up',
			'note_right'
		];

		if(FlxG.sound.music != null)
			FlxG.sound.music.stop();

		// Gameplay settings
		ghostTapping = ClientPrefs.data.ghostTapping;
		healthGain = ClientPrefs.getGameplaySetting('healthgain');
		healthLoss = ClientPrefs.getGameplaySetting('healthloss');
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill');
		practiceMode = ClientPrefs.getGameplaySetting('practice');
		cpuControlled = ClientPrefs.getGameplaySetting('botplay');
		guitarHeroSustains = ClientPrefs.data.guitarHeroSustains;

		// var gameCam:FlxCamera = FlxG.camera;
		camGame = initPsychCamera();
		camHUD = new backend.PsychCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);

		persistentUpdate = true;
		persistentDraw = true;

		Conductor.mapBPMChanges(SONG);
		Conductor.bpm = SONG.bpm;

		#if DISCORD_ALLOWED
		// String that contains the mode defined here so it isn't necessary to call changePresence for each mode
		storyDifficultyText = Difficulty.getString();

		if (isStoryMode)
			detailsText = "Story Mode: " + WeekData.getCurrentWeek().weekName;
		else
			detailsText = "Freeplay";

		// String for when the game is paused
		detailsPausedText = "Paused - " + detailsText;
		#end

		GameOverSubstate.resetVariables();
		songName = Paths.formatToSongPath(SONG.song);
		if(SONG.stage == null || SONG.stage.length < 1)
			SONG.stage = StageData.vanillaSongStage(Paths.formatToSongPath(Song.loadedSongName));

		curStage = SONG.stage;

		var stageData:StageFile = StageData.getStageFile(curStage);
		defaultCamZoom = stageData.defaultZoom;

		stageUI = "normal";
		if (stageData.stageUI != null && stageData.stageUI.trim().length > 0)
			stageUI = stageData.stageUI;
		else if (stageData.isPixelStage == true) //Backward compatibility
			stageUI = "pixel";

		BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];
		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

		if(stageData.camera_speed != null)
			cameraSpeed = stageData.camera_speed;

		boyfriendCameraOffset = stageData.camera_boyfriend;
		if(boyfriendCameraOffset == null) //Fucks sake should have done it since the start :rolling_eyes:
			boyfriendCameraOffset = [0, 0];

		opponentCameraOffset = stageData.camera_opponent;
		if(opponentCameraOffset == null)
			opponentCameraOffset = [0, 0];

		girlfriendCameraOffset = stageData.camera_girlfriend;
		if(girlfriendCameraOffset == null)
			girlfriendCameraOffset = [0, 0];
		loadCameraMoveData();

		boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
		gfGroup = new FlxSpriteGroup(GF_X, GF_Y);

		switch (curStage) {
			case 'stage': new StageWeek1(); 						//Week 1
			case 'spooky': new Spooky();							//Week 2
			case 'philly': new Philly();							//Week 3
			case 'limo': new Limo();								//Week 4
			case 'mall': new Mall();								//Week 5 - Cocoa, Eggnog
			case 'mallEvil': new MallEvil();						//Week 5 - Winter Horrorland
			case 'school': new School();							//Week 6 - Senpai, Roses
			case 'schoolEvil': new SchoolEvil();					//Week 6 - Thorns
			case 'tank': new Tank();								//Week 7 - Ugh, Guns, Stress
			case 'phillyStreets': new PhillyStreets(); 				//Weekend 1 - Darnell, Lit Up, 2Hot
			case 'phillyBlazin': new PhillyBlazin();				//Weekend 1 - Blazin
			case 'mallErect': new MallErect();						//Week 5 (Erect) - Cocoa Erect, Eggnog Erect, Cocoa (Pico Mix), Eggnog (Pico Mix)
			case 'phillyStreetsErect': new PhillyStreetsErect(); 	//Weekend 1 (Erect) - Darnell Erect, Darnell (BF Mix), Lit Up (BF Mix) // se mata shiho te amo
			default: new BaseStage();
		}
		if(isPixelStage) introSoundsSuffix = '-pixel';

		if (!stageData.hide_girlfriend) {
			if(SONG.gfVersion == null || SONG.gfVersion.length < 1) SONG.gfVersion = 'gf'; //Fix for the Chart Editor
			gf = new Character(0, 0, SONG.gfVersion);
			startCharacterPos(gf);
			gfGroup.scrollFactor.set(0.95, 0.95);
			gfGroup.add(gf);
		}

		dad = new Character(0, 0, SONG.player2);
		startCharacterPos(dad, true);
		dadGroup.add(dad);

		boyfriend = new Character(0, 0, SONG.player1, true);
		startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);
		
		if(stageData.objects != null && stageData.objects.length > 0) {
			var list:Map<String, FlxSprite> = StageData.addObjectsToState(stageData.objects, !stageData.hide_girlfriend ? gfGroup : null, dadGroup, boyfriendGroup, this);
			for (key => spr in list)
				if(!StageData.reservedNames.contains(key))
					variables.set(key, spr);
		}
		else {
			add(gfGroup);
			add(dadGroup);
			add(boyfriendGroup);
		}
		
		generateStaticArrows(false);
		generateStaticArrows(true);
		
		preCreate();
		setVar('camGame', camGame);
		setVar('camMain', camGame);
		setVar('camHUD', camHUD);
		setVar('camOther', camOther);
		setVar('camPause', camOther);

		backend.CameraResizeFix.aplyAll();
		
		#if (SCRIPTS_ALLOWED)
		// "SCRIPTS FOLDER" SCRIPTS
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'data/scripts/'))
			for (file in FileSystem.readDirectory(folder))
			{
				#if LUA_ALLOWED
				if(file.toLowerCase().endsWith('.lua') && !milyMC.MilyMC.shouldSkipRegularLua('$folder$file', songName))
					initLuaScript('$folder$file');
				#end

				#if HSCRIPT_ALLOWED
				if(HScript.hasScriptExtension(file))
					initHScript('$folder$file');
				#end
			}
		#end

		var camPos:FlxPoint = FlxPoint.get(girlfriendCameraOffset[0], girlfriendCameraOffset[1]);
		if(gf != null)
		{
			camPos.x += gf.getGraphicMidpoint().x + gf.cameraPosition[0];
			camPos.y += gf.getGraphicMidpoint().y + gf.cameraPosition[1];
		}

		if(dad.curCharacter.startsWith('gf')) {
			dad.setPosition(GF_X, GF_Y);
			if(gf != null)
				gf.visible = false;
		}
		
		#if (SCRIPTS_ALLOWED)
		// LEVEL / STAGE SCRIPTS
		var levelScript:String = WeekData.getWeekFileName();
		if(levelScript != null && levelScript.length > 0)
		{
			#if LUA_ALLOWED startLuasNamed(WeekData.LEVELS_PATH + levelScript + '.lua'); #end
			#if HSCRIPT_ALLOWED startHScriptsNamed(WeekData.LEVELS_PATH + levelScript + '.hx'); #end
		}

		#if LUA_ALLOWED startLuasNamed('data/stages/' + curStage + '.lua'); #end
		#if HSCRIPT_ALLOWED startHScriptsNamed('data/stages/' + curStage + '.hx'); #end

		// CHARACTER SCRIPTS
		if(gf != null) startCharacterScripts(gf);
		startCharacterScripts(dad);
		startCharacterScripts(boyfriend);
		#end

        // Dropshadow 
        dropshadowData = DropShadowData.getDropshadowFile(curStage);
        setDropshadow();


        

		uiGroup = new FlxSpriteGroup();
		comboGroup = new FlxSpriteGroup();
		noteGroup = new FlxTypedGroup<FlxBasic>();
		add(comboGroup);
		add(uiGroup);
		add(noteGroup);
		
		lastBeatHit = -6;
		lastStepHit = lastBeatHit * 4;
		Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
		
		var showTime:Bool = (ClientPrefs.data.timeBarType != 'Disabled');
		timeTxt = new FlxText(STRUM_X + (FlxG.width / 2) - 248, 19, 400, "", 14);
		timeTxt.setFormat(Paths.font("better-vcr.ttf"), 14, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.alpha = 0;
		timeTxt.borderSize = 1;
		timeTxt.visible = updateTime = showTime;
		if(ClientPrefs.data.downScroll) timeTxt.y = 660;
		else timeTxt.y = 28;
		if(ClientPrefs.data.timeBarType == 'Song Name') timeTxt.text = remixesPorraMerda(SONG.song);

		timeBar = new Bar(0, timeTxt.y - 1, 'timeBar', function() return songPercent, 0, 1);
		timeBar.scrollFactor.set();
		timeBar.screenCenter(X);
		timeBar.alpha = 0;
		timeBar.visible = showTime;
		uiGroup.add(timeBar);
		uiGroup.add(timeTxt);

		noteGroup.add(strumLineNotes);

		/*if(ClientPrefs.data.timeBarType == 'Song Name') //VOCÊÊÊÊÊÊÊÊÊÊÊÊÊÊÊÊÊÊÊÊÊÊÊÊÊÊÊÊÊÊÊÊÊÊ
		{
			timeTxt.size = 24;
			timeTxt.y += 3;
		}*/

		generateSong();

		noteGroup.add(grpNoteSplashes);
		noteGroup.add(grpHoldSplashes);

		camFollow = new FlxObject();
		camFollow.setPosition(camPos.x, camPos.y);
		camPos.put();

		if (prevCamFollow != null)
		{
			camFollow = prevCamFollow;
			prevCamFollow = null;
		}
		add(camFollow);

		FlxG.camera.follow(camFollow, LOCKON, 0);
		FlxG.camera.zoom = defaultCamZoom;
		camGameBaseZoom = defaultCamZoom;
		camGameBopZoom = 0;
		camHUDBopZoom = 0;
		FlxG.camera.snapToTarget();

		FlxG.worldBounds.set(0, 0, FlxG.width, FlxG.height);
		moveCameraSection();

		healthBar = new Bar(0, FlxG.height * (!ClientPrefs.data.downScroll ? 0.89 : 0.11), 'healthBar', function() return health, 0, 2);
		healthBar.screenCenter(X);
		healthBar.leftToRight = false;
		healthBar.scrollFactor.set();
		healthBar.visible = !ClientPrefs.data.hideHud;
		healthBar.alpha = ClientPrefs.data.healthBarAlpha;
		reloadHealthBarColors();
		uiGroup.add(healthBar);

		iconP1 = new HealthIcon(boyfriend.healthIcon, true);
		iconP1.y = healthBar.y - 75;
		iconP1.visible = !ClientPrefs.data.hideHud;
		iconP1.alpha = ClientPrefs.data.healthBarAlpha;
		uiGroup.add(iconP1);

		iconP2 = new HealthIcon(dad.healthIcon, false);
		iconP2.y = healthBar.y - 75;
		iconP2.visible = !ClientPrefs.data.hideHud;
		iconP2.alpha = ClientPrefs.data.healthBarAlpha;
		uiGroup.add(iconP2);

		scoreTxt = new FlxText(0, healthBar.y + 40, FlxG.width, "", 13);
		scoreTxt.setFormat(Paths.font("better-vcr.ttf"), 13, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1;
		scoreTxt.antialiasing = true;
		scoreTxt.visible = !ClientPrefs.data.hideHud;
		scoreTxt.updateHitbox();
		uiGroup.add(scoreTxt);
		
		if (ClientPrefs.data.downScroll) scoreTxt.y = 100;
		else scoreTxt.y = 680;

		setVar('playFields', noteGroup);
		setVar('playHUD', {
			healthBar: healthBar,
			iconP1: iconP1,
			iconP2: iconP2,
			scoreTxt: scoreTxt,
			timeBar: timeBar,
			timeTxt: timeTxt
		});

		botplayTxt = new FlxText(400, healthBar.y - 90, FlxG.width - 800, Language.getPhrase("Botplay").toUpperCase(), 32);
		botplayTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		botplayTxt.scrollFactor.set();
		botplayTxt.borderSize = 1.25;
		botplayTxt.visible = cpuControlled;
		uiGroup.add(botplayTxt);
		if(ClientPrefs.data.downScroll)
			botplayTxt.y = healthBar.y + 70;

		uiGroup.cameras = [camHUD];
		noteGroup.cameras = [camHUD];
		comboGroup.cameras = [camHUD];

		startingSong = true;

		#if LUA_ALLOWED
		for (notetype in noteTypes)
			startLuasNamed('data/notetypes/' + notetype + '.lua');
		for (event in eventsPushed)
			startLuasNamed('data/events/' + event + '.lua');
		#end

		#if HSCRIPT_ALLOWED
		for (notetype in noteTypes)
			startHScriptsNamed('data/notetypes/' + notetype + '.hx');
		for (event in eventsPushed)
			startHScriptsNamed('data/events/' + event + '.hx');
		#end
		noteTypes = null;
		eventsPushed = null;

		// SONG SPECIFIC SCRIPTS
		#if (SCRIPTS_ALLOWED)
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'songs/$songName/'))
			for (file in FileSystem.readDirectory(folder))
			{
				#if LUA_ALLOWED
				if(file.toLowerCase().endsWith('.lua') && !milyMC.MilyMC.shouldSkipRegularLua(folder + file, songName))
					initLuaScript(folder + file);
				#end

				#if HSCRIPT_ALLOWED
				if(HScript.hasScriptExtension(file))
					initHScript(folder + file);
				#end
			}

		#if LUA_ALLOWED
		milyMC.MilyMC.load(this);
		#end
		#end

		if(eventNotes.length > 0)
		{
			for (event in eventNotes) event.strumTime -= eventEarlyTrigger(event);
			eventNotes.sort(sortByTime);
		}
		
		//PRECACHING THINGS THAT GET USED FREQUENTLY TO AVOID LAGSPIKES
		var splash:NoteSplash = new NoteSplash();
		grpNoteSplashes.add(splash);
		splash.alpha = 0.0001; //cant make it invisible or it won't allow precaching

		SustainSplash.startCrochet = Conductor.stepCrochet;
		SustainSplash.frameRate = Math.floor(24 / 100 * SONG.bpm);
		var holdSplash:SustainSplash = new SustainSplash();
		holdSplash.alpha = 0.0001;
		
		if (ClientPrefs.data.hitsoundVolume > 0) Paths.hitsound();
		if (!ghostTapping) for (i in 1...4) Paths.missnote(i);
		Paths.image('alphabet');
		
		cacheCountdown();
		cachePopUpScore();
		
		startCallback();
		RecalculateRating(false, false);
		
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		
		if (PauseSubState.songName != null)
			Paths.pauseMusic(PauseSubState.songName, boyfriend?.curCharacter, stageUI);
		else if(Paths.formatToSongPath(ClientPrefs.data.pauseMusic) != 'none')
			Paths.pauseMusic(ClientPrefs.data.pauseMusic, boyfriend?.curCharacter, stageUI);
		
		resetRPC();
		
		stagesFunc(function(stage:BaseStage) stage.createPost());
		super.create();
		Paths.clearUnusedMemory();
		
		if(eventNotes.length < 1) checkEventNote();
	}

    var dropshadowData:DropShadowFile;
    function setDropshadow()
    {
        for(i in 0...dadGroup.length)
        {
            var character:Character = cast dadGroup.members[i];
            character.dropShadow.enabled = dropshadowData.dad.enabled;
            character.dropShadow.color = cast FlxColor.fromString(dropshadowData.color);
            character.dropShadow.distance = dropshadowData.distance;
            character.dropShadow.strength = dropshadowData.strength;
            character.dropShadow.antialiasAmt = dropshadowData.antialiasAmt;
            character.dropShadow.baseHue = dropshadowData.hue;
            character.dropShadow.baseBrightness = dropshadowData.brightness;
            character.dropShadow.baseContrast = dropshadowData.contrast;
            character.dropShadow.baseSaturation  = dropshadowData.saturation;
            character.dropShadow.threshold = dropshadowData.threshold;

            if(dropshadowData.dad.useAltMask) character.dropShadow.loadAltMask(dropshadowData.dad.altMaskImage);
            character.dropShadow.angle = dropshadowData.dad.angle;
            character.dropShadow.maskThreshold = dropshadowData.dad.maskThreshold;
        }

        for(i in 0...gfGroup.length)
        {
            var character:Character = cast gfGroup.members[i];
            character.dropShadow.enabled = dropshadowData.girlfriend.enabled;
            character.dropShadow.color = cast FlxColor.fromString(dropshadowData.color);
            character.dropShadow.distance = dropshadowData.distance;
            character.dropShadow.strength = dropshadowData.strength;
            character.dropShadow.antialiasAmt = dropshadowData.antialiasAmt;
            character.dropShadow.baseHue = dropshadowData.hue;
            character.dropShadow.baseBrightness = dropshadowData.brightness;
            character.dropShadow.baseContrast = dropshadowData.contrast;
            character.dropShadow.baseSaturation  = dropshadowData.saturation;
            character.dropShadow.threshold = dropshadowData.threshold;

            if(dropshadowData.girlfriend.useAltMask)character.dropShadow.loadAltMask(dropshadowData.girlfriend.altMaskImage);
            character.dropShadow.angle = dropshadowData.girlfriend.angle;
            character.dropShadow.maskThreshold = dropshadowData.girlfriend.maskThreshold;
        }

        for(i in 0...bfGroup.length)
        {
            var character:Character = cast bfGroup.members[i];
            character.dropShadow.enabled = dropshadowData.boyfriend.enabled;
            character.dropShadow.color = cast FlxColor.fromString(dropshadowData.color);
            character.dropShadow.distance = dropshadowData.distance;
            character.dropShadow.strength = dropshadowData.strength;
            character.dropShadow.antialiasAmt = dropshadowData.antialiasAmt;
            character.dropShadow.baseHue = dropshadowData.hue;
            character.dropShadow.baseBrightness = dropshadowData.brightness;
            character.dropShadow.baseContrast = dropshadowData.contrast;
            character.dropShadow.baseSaturation  = dropshadowData.saturation;
            character.dropShadow.threshold = dropshadowData.threshold;

            if(dropshadowData.boyfriend.useAltMask) character.dropShadow.loadAltMask(dropshadowData.boyfriend.altMaskImage);
            character.dropShadow.angle = dropshadowData.boyfriend.angle;
            character.dropShadow.maskThreshold = dropshadowData.boyfriend.maskThreshold;
        }
    }
	
	#if LUA_ALLOWED
	public override function implementLua(lua:FunkinLua):Void {
		// VARIABLES
		// Song/Week shit
		lua.set('curBpm', Conductor.bpm);
		lua.set('bpm', SONG.bpm);
		lua.set('scrollSpeed', SONG.speed);
		lua.set('crochet', Conductor.crochet);
		lua.set('stepCrochet', Conductor.stepCrochet);
		lua.set('songLength', FlxG.sound.music.length);
		lua.set('songName', SONG.song);
		lua.set('songPath', Paths.formatToSongPath(SONG.song));
		lua.set('loadedSongName', Song.loadedSongName);
		lua.set('loadedSongPath', Paths.formatToSongPath(Song.loadedSongName));
		lua.set('chartPath', Song.chartPath);
		lua.set('startedCountdown', false);
		lua.set('curStage', SONG.stage);
		
		lua.set('isStoryMode', isStoryMode);
		lua.set('difficulty', storyDifficulty);
		
		lua.set('difficultyName', Difficulty.getString(false));
		lua.set('difficultyPath', Difficulty.getFilePath());
		lua.set('difficultyNameTranslation', Difficulty.getString(true));
		lua.set('weekRaw', storyWeek);
		lua.set('week', WeekData.getWeekFileName());
		lua.set('seenCutscene', seenCutscene);
		lua.set('hasVocals', SONG.needsVoices);
		
		// Gameplay variables
		lua.set('score', songScore);
		lua.set('misses', songMisses);
		lua.set('hits', songHits);
		lua.set('combo', combo);
		lua.set('deaths', deathCounter);
		
		lua.set('rating', ratingPercent);
		lua.set('ratingName', ratingName);
		lua.set('ratingFC', ratingFC);
		lua.set('totalPlayed', totalPlayed);
		lua.set('totalNotesHit', totalNotesHit);
		lua.set('inGameOver', false);
		
		var curSection:SwagSection = SONG.notes[curSection];
		lua.set('mustHitSection', curSection != null ? (curSection.mustHitSection == true) : false);
		lua.set('altAnim', curSection != null ? (curSection.altAnim == true) : false);
		lua.set('gfSection', curSection != null ? (curSection.gfSection == true) : false);

		lua.set('healthGainMult', healthGain);
		lua.set('healthLossMult', healthLoss);

		#if FLX_PITCH
		lua.set('playbackRate', playbackRate);
		#else
		lua.set('playbackRate', 1);
		#end

		lua.set('guitarHeroSustains', guitarHeroSustains);
		lua.set('instakillOnMiss', instakillOnMiss);
		lua.set('botPlay', cpuControlled);
		lua.set('practice', practiceMode);
		
		for (i in 0...4) {
			lua.set('defaultPlayerStrumX' + i, 0);
			lua.set('defaultPlayerStrumY' + i, 0);
			lua.set('defaultOpponentStrumX' + i, 0);
			lua.set('defaultOpponentStrumY' + i, 0);
		}
		
		// Default character data
		lua.set('defaultBoyfriendX', BF_X);
		lua.set('defaultBoyfriendY', BF_Y);
		lua.set('defaultOpponentX', DAD_X);
		lua.set('defaultOpponentY', DAD_Y);
		lua.set('defaultGirlfriendX', GF_X);
		lua.set('defaultGirlfriendY', GF_Y);
		
		lua.set('boyfriendName', boyfriend != null ? boyfriend.curCharacter : SONG.player1);
		lua.set('dadName', dad != null ? dad.curCharacter : SONG.player2);
		lua.set('gfName', gf != null ? gf.curCharacter : SONG.gfVersion);
		
		// Other settings
		// nosso
		lua.set('mechanics', ClientPrefs.data.mechanics);
		lua.set('modchart', ClientPrefs.data.modchart);
		lua.set('pixelRender', ClientPrefs.data.weekpixel);
		lua.set('allowMiku', ClientPrefs.data.mikudside);
		lua.set('sustainAlpha', ClientPrefs.data.sustainAlpha);
		lua.set('extra', ClientPrefs.data.extra);
		lua.set('stageUI', stageUI);
		lua.set('opaqueStrums', ClientPrefs.data.opaqueSustains);
		lua.set('allowNeat', ClientPrefs.data.neatRating);
		
		// deles
		lua.set('downscroll', ClientPrefs.data.downScroll);
		lua.set('middlescroll', ClientPrefs.data.middleScroll);
		lua.set('framerate', ClientPrefs.data.framerate);
		lua.set('ghostTapping', ClientPrefs.data.ghostTapping);
		lua.set('hideHud', ClientPrefs.data.hideHud);
		lua.set('antialiasing', ClientPrefs.data.antialiasing);
		lua.set('timeBarType', ClientPrefs.data.timeBarType);
		lua.set('scoreZoom', ClientPrefs.data.scoreZoom);
		lua.set('cameraZoomOnBeat', ClientPrefs.data.camZooms);
		lua.set('flashingLights', ClientPrefs.data.flashing);
		lua.set('noteOffset', ClientPrefs.data.noteOffset);
		lua.set('healthBarAlpha', ClientPrefs.data.healthBarAlpha);
		lua.set('noResetButton', ClientPrefs.data.noReset);
		lua.set('lowQuality', ClientPrefs.data.lowQuality);
		lua.set('shadersEnabled', ClientPrefs.data.shaders);

		// Noteskin/Splash
		lua.set('noteSkin', ClientPrefs.data.noteSkin);
		lua.set('noteSkinPostfix', Note.getNoteSkinPostfix());
		lua.set('splashSkin', ClientPrefs.data.splashSkin);
		lua.set('splashSkinPostfix', NoteSplash.getSplashSkinPostfix());
		lua.set('splashAlpha', ClientPrefs.data.splashAlpha);
	}
	#end

	public function addModchart(modchart:String):Dynamic
		return callOnScripts('addModchart', [modchart], true);

	public function clearModchart(modchart:String):Dynamic
		return callOnScripts('clearModchart', [modchart], true);

	public function setModchart(modchart:String, value:Dynamic, ?target:Dynamic):Dynamic
		return callOnScripts('setModchart', [modchart, value, target], true);

	public function easeModchart(modchart:String, value:Dynamic, duration:Float, ?ease:String = 'linear', ?target:Dynamic):Dynamic
		return callOnScripts('easeModchart', [modchart, value, duration, ease, target], true);

	public function queueSetModchart(step:Float, modchart:String, value:Dynamic, ?target:Dynamic):Dynamic
		return callOnScripts('queueSet', [step, modchart, value, target], true);

	public function queueEaseModchart(step:Float, endStep:Float, modchart:String, value:Dynamic, ?ease:String = 'linear', ?target:Dynamic):Dynamic
		return callOnScripts('queueEase', [step, endStep, modchart, value, ease, target], true);

	function set_songSpeed(value:Float):Float
	{
		songSpeed = value;
		noteKillOffset = Math.max(Conductor.stepCrochet, 350 / songSpeed * playbackRate);
		return value;
	}

	function set_playbackRate(value:Float):Float
	{
		#if FLX_PITCH
		if(generatedMusic)
		{
			vocals.pitch = value;
			opponentVocals.pitch = value;
			FlxG.sound.music.pitch = value;
		}
		playbackRate = value;
		FlxG.animationTimeScale = value;
		Conductor.offset = Reflect.hasField(PlayState.SONG, 'offset') ? (PlayState.SONG.offset / value) : 0;
		Conductor.safeZoneOffset = (ClientPrefs.data.safeFrames / 60) * 1000 * value;
		#if VIDEOS_ALLOWED
		if(videoCutscene != null)
			videoCutscene.setPlaybackRate(value);
		#end
		setOnScripts('playbackRate', playbackRate);
		#else
		playbackRate = 1.0; // ensuring -Crow
		#end
		return playbackRate;
	}

	function reloadHealthBarColors() {
		healthBar.setColors(FlxColor.fromRGB(dad.healthColorArray[0], dad.healthColorArray[1], dad.healthColorArray[2]),
			FlxColor.fromRGB(boyfriend.healthColorArray[0], boyfriend.healthColorArray[1], boyfriend.healthColorArray[2]));
	}

	public function setStrumSkin(target:Dynamic, skinName:String):Bool
	{
		if (skinName == null || skinName.trim().length < 1)
			return false;

		var parsed:StrumRuntimeTarget = parseStrumRuntimeTarget(target, true, true);
		for (index in parsed.staticIndices)
		{
			strumSkinOverrides[index] = skinName;
			applyStrumSkinOverride(index, skinName);
		}

		for (index in parsed.noteIndices)
			noteSkinOverrides[index] = skinName;

		forEachGameplayNote(function(note:Note) {
			var index:Int = getRuntimeNoteIndex(note);
			if (parsed.noteIndices.contains(index))
			{
				applyNoteSkinOverride(note, skinName);
				applyRuntimeNoteRGBState(note, index);
			}
		});
		return parsed.staticIndices.length > 0 || parsed.noteIndices.length > 0;
	}

	public function setPlayerSplash(splashName:String):Bool
	{
		if (splashName == null || splashName.trim().length < 1)
			return false;

		var resolvedSplash:String = NoteSplash.resolveSplashPath(splashName);
		if (SONG != null)
			SONG.splashSkin = resolvedSplash;

		forEachGameplayNote(function(note:Note) {
			if (note.mustPress)
				note.noteSplashData.texture = resolvedSplash;
		});
		return true;
	}

	public function setStrumRGB(target:Dynamic, colorHex:String):Bool
	{
		var color:FlxColor = CoolUtil.colorFromString(colorHex);
		var parsed:StrumRuntimeTarget = parseStrumRuntimeTarget(target, true, true);
		applyRuntimeRGBAllowed(parsed, true);
		applyRuntimeRGB(parsed, color);
		return parsed.staticIndices.length > 0 || parsed.noteIndices.length > 0;
	}

	public function allowStrumRGB(target:Dynamic, enabled:Bool = true):Bool
	{
		var parsed:StrumRuntimeTarget = parseStrumRuntimeTarget(target, true, true);
		applyRuntimeRGBAllowed(parsed, enabled);
		return parsed.staticIndices.length > 0 || parsed.noteIndices.length > 0;
	}

	public function tweenStrumRGB(tag:String, target:Dynamic, seconds:Float, colorHex:String, ease:String = 'linear'):String
	{
		var parsed:StrumRuntimeTarget = parseStrumRuntimeTarget(target, true, true);
		if (parsed.staticIndices.length < 1 && parsed.noteIndices.length < 1)
			return null;

		applyRuntimeRGBAllowed(parsed, true);
		var targetColor:FlxColor = CoolUtil.colorFromString(colorHex);
		var staticStart:Array<FlxColor> = [for (index in parsed.staticIndices) getRuntimeStrumRGB(index)];
		var noteStart:Array<FlxColor> = [for (index in parsed.noteIndices) getRuntimeNoteRGB(index)];
		var tweenTag:String = tag != null && tag.length > 0 ? 'tween_' + formatRuntimeTweenTag(tag) : null;

		if (tweenTag != null)
		{
			var oldTween:FlxTween = MusicBeatState.getVariables().get(tweenTag);
			if (oldTween != null)
			{
				oldTween.cancel();
				oldTween.destroy();
			}
		}

		var tween:FlxTween = FlxTween.num(0, 1, Math.max(seconds, 0), {
			ease: getRuntimeTweenEase(ease),
			onComplete: function(twn:FlxTween) {
				if (tweenTag != null)
					MusicBeatState.getVariables().remove(tweenTag);
				#if LUA_ALLOWED
				if (tag != null && tag.length > 0)
					FunkinLua.luaCallGlobal('onTweenCompleted', [tag]);
				#end
			}
		}, function(value:Float) {
			for (i in 0...parsed.staticIndices.length)
				applyRuntimeRGBToStatic(parsed.staticIndices[i], FlxColor.interpolate(staticStart[i], targetColor, value));
			for (i in 0...parsed.noteIndices.length)
				applyRuntimeRGBToNotes(parsed.noteIndices[i], FlxColor.interpolate(noteStart[i], targetColor, value));
		});

		if (tweenTag != null)
			MusicBeatState.getVariables().set(tweenTag, tween);
		return tweenTag;
	}

	function applyRuntimeNoteOverrides(note:Note):Void
	{
		var index:Int = getRuntimeNoteIndex(note);
		var skin:String = noteSkinOverrides[index];
		if (skin != null && skin.length > 0)
			applyNoteSkinOverride(note, skin);

		applyRuntimeNoteRGBState(note, index);
	}

	function applyRuntimeNoteRGBState(note:Note, index:Int):Void
	{
		var allowed:Null<Bool> = noteRGBAllowedOverrides[index];
		if (allowed != null)
			note.useRGBShader = allowed;

		var color:Null<FlxColor> = noteRGBOverrides[index];
		if (color != null && note.useRGBShader)
			note.setRGBOverride(color);
	}

	function applyStrumSkinOverride(index:Int, skinName:String):Void
	{
		var strum:StrumNote = strumLineNotes.members[index];
		if (strum == null)
			return;

		var downscrollGap:Null<Float> = strum.downScroll ? Math.max(0, FlxG.height - strum.y - strum.height) : null;
		strum.texture = skinName;
		if (downscrollGap != null)
			strum.y = FlxG.height - strum.height - downscrollGap;

		var allowed:Null<Bool> = strumRGBAllowedOverrides[index];
		if (allowed != null)
			strum.setRGBAllowed(allowed);

		var color:Null<FlxColor> = strumRGBOverrides[index];
		if (color != null && strum.useRGBShader)
			strum.setRGBOverride(color);

		if (strum.animation.curAnim == null)
			strum.playAnim('static', true);
	}

	function applyNoteSkinOverride(note:Note, skinName:String):Void
	{
		if (note == null || note.noteData < 0)
			return;

		note.texture = skinName;
		note.applyNoteSkinOffsets();
	}

	function applyRuntimeRGB(target:StrumRuntimeTarget, color:FlxColor):Void
	{
		for (index in target.staticIndices)
			applyRuntimeRGBToStatic(index, color);
		for (index in target.noteIndices)
			applyRuntimeRGBToNotes(index, color);
	}

	function applyRuntimeRGBToStatic(index:Int, color:FlxColor):Void
	{
		strumRGBOverrides[index] = color;
		if (strumRGBAllowedOverrides[index] == false)
			return;

		var strum:StrumNote = strumLineNotes.members[index];
		if (strum != null)
			strum.setRGBOverride(color);
	}

	function applyRuntimeRGBToNotes(index:Int, color:FlxColor):Void
	{
		noteRGBOverrides[index] = color;
		if (noteRGBAllowedOverrides[index] == false)
			return;

		forEachGameplayNote(function(note:Note) {
			if (getRuntimeNoteIndex(note) == index)
				note.setRGBOverride(color);
		});
	}

	function applyRuntimeRGBAllowed(target:StrumRuntimeTarget, enabled:Bool):Void
	{
		for (index in target.staticIndices)
			applyRuntimeRGBAllowedToStatic(index, enabled);
		for (index in target.noteIndices)
			applyRuntimeRGBAllowedToNotes(index, enabled);
	}

	function applyRuntimeRGBAllowedToStatic(index:Int, enabled:Bool):Void
	{
		strumRGBAllowedOverrides[index] = enabled;
		var strum:StrumNote = strumLineNotes.members[index];
		if (strum == null)
			return;

		strum.setRGBAllowed(enabled);
		if (enabled && strumRGBOverrides[index] != null)
			strum.setRGBOverride(strumRGBOverrides[index]);
	}

	function applyRuntimeRGBAllowedToNotes(index:Int, enabled:Bool):Void
	{
		noteRGBAllowedOverrides[index] = enabled;
		forEachGameplayNote(function(note:Note) {
			if (getRuntimeNoteIndex(note) == index)
			{
				note.useRGBShader = enabled;
				if (enabled && noteRGBOverrides[index] != null)
					note.setRGBOverride(noteRGBOverrides[index]);
			}
		});
	}

	function getRuntimeStrumRGB(index:Int):FlxColor
	{
		var colorOverride:Null<FlxColor> = strumRGBOverrides[index];
		if (colorOverride != null)
			return colorOverride;

		var strum:StrumNote = strumLineNotes.members[index];
		if (strum != null && strum.rgbOverride != null)
			return strum.rgbOverride;

		var noteData:Int = Std.int(Math.abs(index) % 4);
		var arr:Array<FlxColor> = PlayState.isPixelStage ? ClientPrefs.data.arrowRGBPixel[noteData] : ClientPrefs.data.arrowRGB[noteData];
		return arr != null && arr.length > 0 ? arr[0] : FlxColor.WHITE;
	}

	function getRuntimeNoteRGB(index:Int):FlxColor
	{
		var colorOverride:Null<FlxColor> = noteRGBOverrides[index];
		if (colorOverride != null)
			return colorOverride;
		return getRuntimeStrumRGB(index);
	}

	function forEachGameplayNote(callback:Note->Void):Void
	{
		if (callback == null)
			return;

		for (note in unspawnNotes)
			if (note != null)
				callback(note);

		if (notes != null)
		{
			for (note in notes.members)
				if (note != null)
					callback(note);
		}
	}

	function getRuntimeNoteIndex(note:Note):Int
		return note.noteData + (note.mustPress ? 4 : 0);

	static function parseStrumRuntimeTarget(target:Dynamic, defaultStatic:Bool, defaultNotes:Bool):StrumRuntimeTarget
	{
		var result:StrumRuntimeTarget = {staticIndices: [], noteIndices: []};
		if (target == null)
		{
			addIndices(result.staticIndices, [0, 1, 2, 3, 4, 5, 6, 7]);
			addIndices(result.noteIndices, [0, 1, 2, 3, 4, 5, 6, 7]);
			return result;
		}

		if (Std.isOfType(target, String))
		{
			var raw:String = Std.string(target).toLowerCase().trim();
			switch (raw)
			{
				case 'notes' | 'note':
					addIndices(result.noteIndices, [0, 1, 2, 3, 4, 5, 6, 7]);
					return result;
				case 'static' | 'strum' | 'strums' | 'receptor' | 'receptors':
					addIndices(result.staticIndices, [0, 1, 2, 3, 4, 5, 6, 7]);
					return result;
			}
		}

		if (Std.isOfType(target, Array))
		{
			var indices:Array<Int> = selectorToIndices(target);
			if (defaultStatic) addIndices(result.staticIndices, indices);
			if (defaultNotes) addIndices(result.noteIndices, indices);
			return result;
		}

		if (Type.typeof(target) == TObject)
		{
			var hasStatic:Bool = Reflect.hasField(target, 'static') || Reflect.hasField(target, 'strums');
			var hasNotes:Bool = Reflect.hasField(target, 'notes') || Reflect.hasField(target, 'note');
			var loose:Array<Int> = selectorObjectLooseIndices(target);

			if (hasStatic)
			{
				var value:Dynamic = Reflect.hasField(target, 'static') ? Reflect.field(target, 'static') : Reflect.field(target, 'strums');
				addIndices(result.staticIndices, selectorToIndices(value));
				addIndices(result.staticIndices, loose);
			}
			if (hasNotes)
			{
				var value:Dynamic = Reflect.hasField(target, 'notes') ? Reflect.field(target, 'notes') : Reflect.field(target, 'note');
				addIndices(result.noteIndices, selectorToIndices(value));
				if (!hasStatic)
					addIndices(result.noteIndices, loose);
			}
			if (!hasStatic && !hasNotes)
			{
				var indices:Array<Int> = selectorToIndices(target);
				if (defaultStatic) addIndices(result.staticIndices, indices);
				if (defaultNotes) addIndices(result.noteIndices, indices);
			}
			return result;
		}

		var indices:Array<Int> = selectorToIndices(target);
		if (defaultStatic) addIndices(result.staticIndices, indices);
		if (defaultNotes) addIndices(result.noteIndices, indices);
		return result;
	}

	static function selectorToIndices(selector:Dynamic):Array<Int>
	{
		if (selector == null)
			return [];

		if (Std.isOfType(selector, Array))
		{
			var result:Array<Int> = [];
			for (value in (cast selector:Array<Dynamic>))
				addIndices(result, selectorToIndices(value));
			return result;
		}

		if (Std.isOfType(selector, String))
			return selectorStringToIndices(Std.string(selector));

		var parsed:Null<Int> = dynamicToInt(selector);
		if (parsed != null)
			return clampStrumIndex(parsed);

		if (Type.typeof(selector) == TObject)
			return selectorObjectLooseIndices(selector);

		return [];
	}

	static function selectorStringToIndices(value:String):Array<Int>
	{
		value = value.toLowerCase().trim();
		if (value.contains(',') || value.contains(' '))
		{
			var result:Array<Int> = [];
			var parts:Array<String> = value.replace(',', ' ').split(' ');
			for (part in parts)
				if (part.trim().length > 0)
					addIndices(result, selectorStringToIndices(part));
			return result;
		}

		return switch (value)
		{
			case 'bf' | 'boyfriend' | 'player': [4, 5, 6, 7];
			case 'dad' | 'opponent' | 'opp': [0, 1, 2, 3];
			case 'both' | 'all' | 'gen' | 'strum_gen': [0, 1, 2, 3, 4, 5, 6, 7];
			case 'left': [0, 4];
			case 'down': [1, 5];
			case 'up': [2, 6];
			case 'right': [3, 7];
			default:
				var parsed:Null<Int> = Std.parseInt(value);
				parsed != null ? clampStrumIndex(parsed) : [];
		}
	}

	static function selectorObjectLooseIndices(selector:Dynamic):Array<Int>
	{
		var result:Array<Int> = [];
		for (field in Reflect.fields(selector))
		{
			if (field == 'static' || field == 'strums' || field == 'notes' || field == 'note')
				continue;
			addIndices(result, selectorToIndices(Reflect.field(selector, field)));
		}
		return result;
	}

	static function addIndices(target:Array<Int>, source:Array<Int>):Void
	{
		if (source == null)
			return;
		for (index in source)
			if (index >= 0 && index < 8 && !target.contains(index))
				target.push(index);
	}

	static function clampStrumIndex(index:Int):Array<Int>
		return index >= 0 && index < 8 ? [index] : [];

	static function dynamicToInt(value:Dynamic):Null<Int>
	{
		if (value == null)
			return null;

		return switch (Type.typeof(value))
		{
			case TInt: Std.int(value);
			case TFloat:
				var parsed:Float = value;
				Math.isNaN(parsed) ? null : Std.int(parsed);
			default:
				var parsed:Null<Int> = Std.parseInt(Std.string(value));
				parsed;
		}
	}

	static function getRuntimeTweenEase(ease:String):Dynamic
	{
		if (ease == null || ease.length < 1)
			return FlxEase.linear;
		var tweenEase:Dynamic = Reflect.field(FlxEase, ease);
		return tweenEase != null ? tweenEase : FlxEase.linear;
	}

	static function formatRuntimeTweenTag(tag:String):String
		return tag.trim().replace(' ', '_').replace('.', '');

	/**
	 * Precaches a character.
	 * 
	 * @param 	type 	Side to precache the character on. 0: Player. 1: Opponent. 2: Speakers (middle)
	*/
	public function addCharacterToList(newCharacter:String, type:Int) {
		switch(type) {
			case 0:
				if(!boyfriendMap.exists(newCharacter)) {
					var newBoyfriend:Character = new Character(0, 0, newCharacter, true);
					boyfriendMap.set(newCharacter, newBoyfriend);
					boyfriendGroup.add(newBoyfriend);
					startCharacterPos(newBoyfriend);
					newBoyfriend.alpha = 0.00001;
					startCharacterScripts(newBoyfriend);
				}

			case 1:
				if(!dadMap.exists(newCharacter)) {
					var newDad:Character = new Character(0, 0, newCharacter);
					dadMap.set(newCharacter, newDad);
					dadGroup.add(newDad);
					startCharacterPos(newDad, true);
					newDad.alpha = 0.00001;
					startCharacterScripts(newDad);
				}

			case 2:
				if(gf != null && !gfMap.exists(newCharacter)) {
					var newGf:Character = new Character(0, 0, newCharacter);
					newGf.scrollFactor.set(0.95, 0.95);
					gfMap.set(newCharacter, newGf);
					gfGroup.add(newGf);
					startCharacterPos(newGf);
					newGf.alpha = 0.00001;
					startCharacterScripts(newGf);
				}
		}
	}

	function extraCharacterTag(characterName:String):String
	{
		if(characterName == null)
			return null;

		var normalized:String = characterName.replace('\\', '/');
		var split:Array<String> = normalized.split('/');
		var tag:String = split[split.length - 1].trim();
		return tag.length > 0 ? tag.replace('.', '') : null;
	}

	function insertExtraCharacterGroup(group:FlxSpriteGroup):Void
	{
		if(group == null || members.contains(group))
			return;

		var targetGroup:FlxSpriteGroup = boyfriendGroup;
		var targetIndex:Int = targetGroup != null ? members.indexOf(targetGroup) : -1;
		if(targetIndex < 0)
			add(group);
		else
			insert(targetIndex, group);
	}

	public function getExtraCharacterTag(characterName:String):String
		return extraCharacterTag(characterName);

	public function getCharacterGroupByName(name:String):FlxSpriteGroup
	{
		var target:String = normalizeCharacterTarget(name);
		return switch(target)
		{
			case 'boyfriend': boyfriendGroup;
			case 'dad': dadGroup;
			case 'gf': gfGroup;
			default: extraCharacterGroups.get(target);
		}
	}

	public function getCharacterByName(name:String):Character
	{
		var target:String = normalizeCharacterTarget(name);
		return switch(target)
		{
			case 'boyfriend': boyfriend;
			case 'dad': dad;
			case 'gf': gf;
			default: extraCharacterMap.get(target);
		}
	}

	public function queueExtraCharacterScroll(target:String, scrollX:Null<Float>, scrollY:Null<Float>):Bool
	{
		var tag:String = normalizeCharacterTarget(target);
		switch(tag)
		{
			case 'boyfriend' | 'dad' | 'gf':
				return false;
			default:
		}

		if(scrollX == null || Math.isNaN(scrollX)) scrollX = 1;
		if(scrollY == null || Math.isNaN(scrollY)) scrollY = scrollX;
		pendingExtraCharacterScroll.set(tag, [scrollX, scrollY]);
		return true;
	}

	function applyPendingExtraCharacterScroll(tag:String, group:FlxSpriteGroup):Void
	{
		if(tag == null || group == null || !pendingExtraCharacterScroll.exists(tag))
			return;

		var scroll:Array<Float> = pendingExtraCharacterScroll.get(tag);
		group.scrollFactor.set(scroll[0], scroll[1]);
		pendingExtraCharacterScroll.remove(tag);
	}

	function normalizeCharacterTarget(target:String):String
	{
		if(target == null) return 'dad';

		var raw:String = target.trim();
		return switch(raw.toLowerCase())
		{
			case 'bf' | 'boyfriend' | 'player' | '0':
				'boyfriend';
			case 'gf' | 'girlfriend' | '2':
				'gf';
			case 'dad' | 'opponent' | '1':
				'dad';
			default:
				extraCharacterTag(raw) ?? raw;
		}
	}

	function parseExtraCharacterOffsetSide(value:String):Null<Bool>
	{
		if(value == null)
			return null;

		switch(value.toLowerCase().trim())
		{
			case '' | 'default' | 'auto' | 'normal':
				return null;
			case 'player' | 'bf' | 'boyfriend' | 'p1' | 'true' | '1':
				return true;
			case 'opponent' | 'opp' | 'dad' | 'p2' | 'false' | '0':
				return false;
			default:
				return null;
		}
	}

	function applyExtraCharacterOffsetSide(character:Character, usePlayerOffsets:Null<Bool>):Void
	{
		if(character == null)
			return;

		character.usePlayerOffsetsOverride = usePlayerOffsets;
		character.refreshOffsets();
		var anim:String = character.getAnimationName();
		if(anim != null && character.hasAnimation(anim))
			character.playAnim(anim, true);
	}

	function assignExtraCharacterToNote(note:Note):Void
	{
		if(note == null || note.noteType == null)
			return;

		for(tag => noteType in extraCharacterNoteTypes)
		{
			if(noteType != null && noteType.length > 0 && note.noteType == noteType)
			{
				var character:Character = extraCharacterMap.get(tag);
				if(character != null)
					note.character = character;
				return;
			}
		}
	}

	function assignExtraCharacterToExistingNotes(tag:String):Void
	{
		var noteType:String = extraCharacterNoteTypes.get(tag);
		if(noteType == null || noteType.length < 1)
			return;

		var character:Character = extraCharacterMap.get(tag);
		if(character == null)
			return;

		for(note in unspawnNotes)
			if(note != null && note.noteType == noteType)
				note.character = character;

		if(notes != null)
			for(note in notes.members)
				if(note != null && note.noteType == noteType)
					note.character = character;
	}

	public function createChar(characterName:String, x:Float = 0, y:Float = 0, noteType:String = '', isPlayer:Bool = false, offsetSide:String = null):String
	{
		var tag:String = extraCharacterTag(characterName);
		if(tag == null)
			return null;

		var group:FlxSpriteGroup = extraCharacterGroups.get(tag);
		if(group == null)
		{
			group = new FlxSpriteGroup(x, y);
			extraCharacterGroups.set(tag, group);
			variables.set(tag, group);
			variables.set(tag + 'Group', group);
			setVar(tag, group);
			setVar(tag + 'Group', group);
			insertExtraCharacterGroup(group); // eu esqueci de colocarisso
		}
		else
		{
			group.setPosition(x, y);
			insertExtraCharacterGroup(group);
		}
		applyPendingExtraCharacterScroll(tag, group);

		var oldCharacter:Character = extraCharacterMap.get(tag);
		if(oldCharacter != null)
			group.remove(oldCharacter, true);

		var usePlayerOffsets:Null<Bool> = parseExtraCharacterOffsetSide(offsetSide);
		var character:Character = new Character(0, 0, characterName, isPlayer);
		applyExtraCharacterOffsetSide(character, usePlayerOffsets);
		startCharacterPos(character);
		group.add(character);
		extraCharacterMap.set(tag, character);
		extraCharacterIsPlayer.set(tag, isPlayer);
		extraCharacterUsePlayerOffsets.set(tag, usePlayerOffsets);

		if(noteType != null && noteType.length > 0)
			extraCharacterNoteTypes.set(tag, noteType);
		else
			extraCharacterNoteTypes.remove(tag);

		variables.set(tag + 'Character', character);
		setVar(tag + 'Character', character);
		startCharacterScripts(character);
		assignExtraCharacterToExistingNotes(tag);
		setOnScripts('extraCharacterNames', [for(tag in extraCharacterMap.keys()) tag]);
		return tag;
	}

	public function changeExtraCharacter(tag:String, newCharacter:String):Bool
	{
		tag = normalizeCharacterTarget(tag);
		if(!extraCharacterGroups.exists(tag))
			return false;

		var group:FlxSpriteGroup = extraCharacterGroups.get(tag);
		var oldCharacter:Character = extraCharacterMap.get(tag);
		var alpha:Float = oldCharacter != null ? oldCharacter.alpha : 1;
		var shader = oldCharacter != null ? oldCharacter.shader : null;
		var isPlayer:Bool = extraCharacterIsPlayer.exists(tag) ? extraCharacterIsPlayer.get(tag) : false;
		var usePlayerOffsets:Null<Bool> = extraCharacterUsePlayerOffsets.exists(tag) ? extraCharacterUsePlayerOffsets.get(tag) : null;

		if(oldCharacter != null)
			group.remove(oldCharacter, true);

		var character:Character = new Character(0, 0, newCharacter, isPlayer);
		applyExtraCharacterOffsetSide(character, usePlayerOffsets);
		startCharacterPos(character);
		character.alpha = alpha;
		character.shader = shader;
		group.add(character);
		extraCharacterMap.set(tag, character);
		variables.set(tag + 'Character', character);
		setVar(tag + 'Character', character);
		startCharacterScripts(character);
		assignExtraCharacterToExistingNotes(tag);
		return true;
	}

	public function setIconFrame(side:Int, frame:Int):Bool
	{
		var icon:HealthIcon = side == 1 ? iconP1 : iconP2;
		if(icon == null)
			return false;
		icon.setIconFrame(frame);
		return true;
	}

	public function changeHealthIcon(iconName:String, side:Int = 0):Bool
	{
		var icon:HealthIcon = side == 1 ? iconP1 : iconP2;
		if(icon == null)
			return false;
		icon.changeIcon(iconName);
		return true;
	}

	public function snapCamFollowToPos(x:Float, y:Float):Void
	{
		if(camFollow == null)
			return;
		camFollow.setPosition(x, y);
		if(camGame != null)
			camGame.snapToTarget();
	}

	@:dox(hide) function startCharacterScripts(character:Character)
	{
		if(character == null)
			return;

		var name:String = character.curCharacter;
		// Lua
		#if LUA_ALLOWED
		var doPush:Bool = false;
		var luaFile:String = getCharacterScriptPath(name, 'lua');
		if(luaFile != null) doPush = true;

		if(doPush)
		{
			for (script in luaArray)
			{
				if(script.scriptName == luaFile)
				{
					script.configureCharacterScript(character, name);
					callCharacterScriptPostCreate(script, character);
					doPush = false;
					break;
				}
			}
			if(doPush)
			{
				var lua:FunkinLua = FunkinLua.initFromFile(luaFile, this, function(script:FunkinLua) {
					script.configureCharacterScript(character, name);
				});
				if(lua != null)
				{
					luaArray.push(lua);
					callCharacterScriptPostCreate(lua, character);
				}
			}
		}
		#end

		// HScript
		#if HSCRIPT_ALLOWED
		var doPush:Bool = false;
		var scriptFile:String = getCharacterScriptPath(name, 'hx');
		if(scriptFile != null) doPush = true;

		if(doPush)
		{
			var existing:HScript = cast crowplexus.iris.Iris.instances.get(scriptFile);
			if(existing != null)
			{
				existing.configureCharacterScript(character, name);
				callCharacterScriptPostCreate(existing, character);
				doPush = false;
			}

			if(doPush)
			{
				var script:HScript = HScript.initFromFileWithVars(scriptFile, this, null, null, function(script:HScript) {
					script.configureCharacterScript(character, name);
				});
				if(script != null)
				{
					hscriptArray.push(script);
					callCharacterScriptPostCreate(script, character);
				}
			}
		}
		#end
	}

	@:dox(hide) function callCharacterScriptPostCreate(script:Dynamic, character:Character):Void
	{
		if(script == null || character == null)
			return;

		try
		{
			#if HSCRIPT_ALLOWED
			if(Std.isOfType(script, HScript))
			{
				var hscript:HScript = cast script;
				if(hscript.exists('getAtlasSettings'))
				{
					var call = hscript.call('getAtlasSettings');
					backend.AtlasUtil.applySettings(character, call != null ? call.returnValue : null);
				}
				if(hscript.exists('postCreate'))
					hscript.call('postCreate');
				return;
			}
			#end

			#if LUA_ALLOWED
			if(Std.isOfType(script, FunkinLua))
			{
				var lua:FunkinLua = cast script;
				if(lua.exists('postCreate'))
					lua.call('postCreate');
			}
			#end
		}
		catch(e:Dynamic)
		{
			trace('Error while calling character postCreate for ${character.curCharacter}: $e');
		}
	}

	function getCharacterScriptPath(name:String, extension:String):String
	{
		for(folder in Character.CHARACTER_FILE_FOLDERS)
		{
			var scriptFiles:Array<String> = [folder + name + '.' + extension];
			#if HSCRIPT_ALLOWED
			if(extension == 'hx')
				scriptFiles = [for(ext in HScript.SCRIPT_EXTENSIONS) folder + name + ext];
			#end
			for(scriptFile in scriptFiles)
			{
				#if ADDONS_ALLOWED
				var replacePath:String = Paths.modFolders(scriptFile);
				if(FileSystem.exists(replacePath))
					return replacePath;
				#end

				var sharedPath:String = Paths.getSharedPath(scriptFile);
				#if sys
				if(FileSystem.exists(sharedPath))
					return sharedPath;
				#else
				if(OpenFlAssets.exists(sharedPath))
					return sharedPath;
				#end
			}
		}
		return null;
	}

	function getNoteSpawnTime(note:Note):Float
	{
		var time:Float = spawnTime * playbackRate;
		if(songSpeed < 1) time /= songSpeed;
		if(note != null && note.multSpeed < 1) time /= note.multSpeed;

		if(ClientPrefs.data.downScroll)
			time += getDownscrollNoteSpawnOffset(note);

		return time;
	}

	function getDownscrollNoteSpawnOffset(note:Note):Float
	{
		var extraDistance:Float = getDownscrollNoteSpawnExtraDistance();
		if(extraDistance <= 0)
			return 0;

		var noteSpeed:Float = (songSpeed * (note != null ? note.multSpeed : 1)) / Math.max(0.001, playbackRate);
		return extraDistance / (0.45 * Math.max(0.001, noteSpeed));
	}

	public function getDownscrollNoteSpawnExtraDistance():Float
	{
		if(!ClientPrefs.data.downScroll)
			return 0;

		var hudHeight:Float = camHUD != null ? camHUD.height : FlxG.height;
		return Math.max(0, hudHeight - FlxG.height) * 0.5;
	}

	public function getDownscrollNoteCullPadding(note:Note):Float
	{
		var padding:Float = backend.PsychCamera.DEFAULT_ZOOM_CULL_PADDING + getDownscrollNoteSpawnExtraDistance();
		if(note != null)
			padding = Math.max(padding, Math.abs(note.distance) + note.frameHeight + getDownscrollNoteSpawnExtraDistance());
		return padding;
	}

	public function refreshScreenScriptVariables(?camera:FlxCamera):Void
	{
		if(camera == null)
			camera = camOther != null ? camOther : FlxG.camera;

		var fullX:Float = backend.CameraResizeFix.pegarFSX(camera);
		var fullY:Float = backend.CameraResizeFix.pegarFSY(camera);
		var fullWidth:Float = backend.CameraResizeFix.pegarFSL(camera);
		var fullHeight:Float = backend.CameraResizeFix.pegarFSA(camera);

		setOnScripts('screenWidth', FlxG.width);
		setOnScripts('screenHeight', FlxG.height);
		setOnScripts('windowWidth', backend.VignetteUtil.windowWidth());
		setOnScripts('windowHeight', backend.VignetteUtil.windowHeight());
		setOnScripts('windowPixelWidth', backend.VignetteUtil.windowPixelWidth());
		setOnScripts('windowPixelHeight', backend.VignetteUtil.windowPixelHeight());
		setOnScripts('fullScreenX', fullX);
		setOnScripts('fullScreenY', fullY);
		setOnScripts('fullScreenWidth', fullWidth);
		setOnScripts('fullScreenHeight', fullHeight);
		setOnScripts('fullscreenX', fullX);
		setOnScripts('fullscreenY', fullY);
		setOnScripts('fullscreenWidth', fullWidth);
		setOnScripts('fullscreenHeight', fullHeight);
	}
	
	/**
	 * Gets an object defined in the `variables` map (ex. from Lua scripts)
	 * 
	 * @param 	tag 	`String` tag for this object.
	*/
	public function getLuaObject(tag:String):Dynamic
		return variables.get(tag);

	override public function addCamera(tag:String, bgColor:String = '00000000', x:Float = 0, y:Float = 0, width:Int = -1, height:Int = -1, zoom:Float = 1, front:Bool = false):FlxCamera
	{
		if(tag == null)
			return null;

		tag = tag.trim();
		if(tag.length < 1 || variables.exists(tag))
			return null;

		var autoSize:Bool = width <= 0 || height <= 0;
		if(width <= 0) width = FlxG.width;
		if(height <= 0) height = FlxG.height;

		var camera:backend.PsychCamera = new backend.PsychCamera();
		camera.setSize(width, height);
		camera.x = x;
		camera.y = y;
		camera.zoom = zoom;
		camera.bgColor = CoolUtil.colorFromString(bgColor);

		if(front || FlxG.cameras.list.length < 1)
			FlxG.cameras.add(camera, false);
		else
			insertCameraBehindHUD(camera);

		variables.set(tag, camera);
		customCameras.set(tag, camera);
		customCameraAutoSize.set(tag, autoSize);
		if(autoSize)
			resizeAutoCamera(camera);
		return camera;
	}

	function insertCameraBehindHUD(camera:FlxCamera):Void
	{
		var index:Int = FlxG.cameras.list.indexOf(camHUD);
		if(index < 0)
			index = Std.int(Math.max(0, FlxG.cameras.list.length - 1));
		FlxG.cameras.insert(camera, index, false);
	}


	@:dox(hide) function startCharacterPos(char:Character, ?gfCheck:Bool = false) {
		if(gfCheck && char.curCharacter.startsWith('gf')) { //IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	/**
	 * Video instance used when playing cutscenes.
	*/
	public var videoCutscene:VideoSprite = null;

	function videoFileExists(fileName:String):Bool
	{
		#if sys
		return FileSystem.exists(fileName);
		#else
		return OpenFlAssets.exists(fileName);
		#end
	}

	/**
	 * Creates a scriptable video object. The returned object is stored in the state variables map,
	 * so Lua/HScript can tween and edit it like a sprite.
	*/
	public function createVideo(tag:String, name:String, x:Float = 0, y:Float = 0, camera:String = 'other', canSkip:Bool = false, pauseWithGame:Bool = true, loop:Bool = false, playOnLoad:Bool = true, syncWithSong:Bool = false):VideoSprite
	{
		#if VIDEOS_ALLOWED
		if(tag == null || tag.trim().length < 1)
			return null;

		tag = tag.replace('.', '');
		var fileName:String = Paths.video(name);
		if(!videoFileExists(fileName))
		{
			#if (SCRIPTS_ALLOWED)
			addTextToDebug("Video not found: " + fileName, FlxColor.RED);
			#else
			FlxG.log.error("Video not found: " + fileName);
			#end
			return null;
		}

		removeVideo(tag);
		LoadingState.preloadVideo(name);

		var video:VideoSprite = new VideoSprite(fileName, true, canSkip, loop);
		video.tag = tag;
		video.pauseWithGame = pauseWithGame;
		video.syncWithSong = syncWithSong;
		video.setPosition(x, y);
		video.cameras = [LuaUtils.cameraFromString(camera)];
		var vars:Map<String, Dynamic> = MusicBeatState.getVariables();
		vars.set(tag, video);

		video.finishCallback = function()
		{
			if(vars.get(tag) == video)
				vars.remove(tag);
			callOnScripts('onVideoCompleted', [tag, name]);
		};
		video.onSkip = function()
		{
			if(vars.get(tag) == video)
				vars.remove(tag);
			callOnScripts('onVideoSkipped', [tag, name]);
		};
		video.errorCallback = function(message:String)
		{
			if(vars.get(tag) == video)
				vars.remove(tag);
			callOnScripts('onVideoError', [tag, name, message]);
			video.destroy();
		};

		if(playOnLoad)
			video.play();
		return video;
		#else
		FlxG.log.warn('Platform not supported!');
		return null;
		#end
	}

	public function removeVideo(tag:String, destroy:Bool = true):Bool
	{
		#if VIDEOS_ALLOWED
		if(tag == null)
			return false;

		tag = tag.replace('.', '');
		var vars:Map<String, Dynamic> = MusicBeatState.getVariables();
		var obj:Dynamic = vars.get(tag);
		if((obj == null || !Std.isOfType(obj, VideoSprite)) && tag == 'videoCutscene')
			obj = videoCutscene;
		if(obj == null || !Std.isOfType(obj, VideoSprite))
			return false;

		var video:VideoSprite = cast obj;
		if(videoCutscene == video)
			videoCutscene = null;
		if(members.contains(video))
			remove(video, true);
		vars.remove(tag);
		if(destroy)
			video.destroy();
		return true;
		#else
		return false;
		#end
	}

	function forEachVideo(func:VideoSprite->Void, onlyPauseManaged:Bool = false):Void
	{
		#if VIDEOS_ALLOWED
		var handled:Array<VideoSprite> = [];
		function handle(video:VideoSprite):Void
		{
			if(video != null && !handled.contains(video) && (!onlyPauseManaged || video.pauseWithGame))
			{
				handled.push(video);
				func(video);
			}
		}

		handle(videoCutscene);
		for(value in variables)
			if(value != null && Std.isOfType(value, VideoSprite))
				handle(cast value);
		#end
	}

	function forEachManagedVideo(func:VideoSprite->Void):Void
	{
		#if VIDEOS_ALLOWED
		forEachVideo(func, true);
		#end
	}

	function syncVideosToSongTime():Void
	{
		#if VIDEOS_ALLOWED
		var videoTime:Float = Math.max(0, Conductor.songPosition - Conductor.offset);
		forEachVideo((video) -> {
			if(video.syncWithSong)
				video.setTime(videoTime);
		});
		#end
	}

	function pauseManagedVideos():Void
	{
		#if VIDEOS_ALLOWED
		forEachManagedVideo((video) -> video.pause());
		#end
	}

	function resumeManagedVideos():Void
	{
		#if VIDEOS_ALLOWED
		forEachManagedVideo((video) -> video.resume());
		#end
	}

	/**
	 * Starts a video cutscene.
	 * 
	 * @param 	name 		Name of the video to play (should be in the `videos/` folder)
	 * @param 	forMidSong  Whether or not the game should be paused until the cutscene finishes.
	 * @param 	canSkip 	Whether this cutscene can be skipped.
	 * @param 	loop 		Whether the cutscene video should loop.
	 * @param 	playOnLoad 	Whether or not the cutscene should be played instantly after loading.
	 * 
	 * @return 	The video cutscene.
	*/
	public function startVideo(name:String, forMidSong:Bool = false, canSkip:Bool = true, loop:Bool = false, playOnLoad:Bool = true, pauseWithGame:Bool = true)
	{
		#if VIDEOS_ALLOWED
		inCutscene = !forMidSong;
		canPause = forMidSong;

		var fileName:String = Paths.video(name);

		if (videoFileExists(fileName))
		{
			LoadingState.preloadVideo(name);
			videoCutscene = new VideoSprite(fileName, forMidSong, canSkip, loop);
			videoCutscene.pauseWithGame = pauseWithGame;
			videoCutscene.syncWithSong = forMidSong;
			if(forMidSong) videoCutscene.setPlaybackRate(playbackRate);
			var curVideo:VideoSprite = videoCutscene;
			// Finish callback
			if (!forMidSong)
			{
				function onVideoEnd()
				{
					if (!isDead && generatedMusic && PlayState.SONG.notes[Std.int(curStep / 16)] != null && !endingSong && !isCameraOnForcedPos)
					{
						moveCameraSection();
						FlxG.camera.snapToTarget();
					}
					videoCutscene = null;
					canPause = true;
					inCutscene = false;
					startAndEnd();
				}
				videoCutscene.finishCallback = onVideoEnd;
				videoCutscene.onSkip = onVideoEnd;
				videoCutscene.errorCallback = function(message:String)
				{
					trace('WARNING! Video failed to play: $fileName -> $message');
					if(videoCutscene == curVideo)
						videoCutscene = null;
					curVideo.destroy();
					canPause = true;
					inCutscene = false;
					startAndEnd();
				};
			}
			else
			{
				function onMidSongVideoEnd()
				{
					if(videoCutscene == curVideo)
						videoCutscene = null;
				}
				videoCutscene.finishCallback = onMidSongVideoEnd;
				videoCutscene.onSkip = onMidSongVideoEnd;
				videoCutscene.errorCallback = function(message:String)
				{
					trace('WARNING! Mid-song video failed to play: $fileName -> $message');
					if(videoCutscene == curVideo)
						videoCutscene = null;
					curVideo.destroy();
				};
			}
			if (GameOverSubstate.instance != null && isDead) GameOverSubstate.instance.add(videoCutscene);
			else add(videoCutscene);
			if (playOnLoad)
				videoCutscene.play();
			return videoCutscene;
		}
		#if (SCRIPTS_ALLOWED)
		else addTextToDebug("Video not found: " + fileName, FlxColor.RED);
		#else
		else FlxG.log.error("Video not found: " + fileName);
		#end
		#else
		FlxG.log.warn('Platform not supported!');
		startAndEnd();
		#end
		return null;
	}

	@:dox(hide) function startAndEnd() {
		if (endingSong) {
			endSong();
		} else {
			startCountdown();
		}
	}
	
	/**
	 * Restarts this song.
	 * 
	 * @param 	skipTransition 	Whether the fade transition should be skipped when restarting.
	*/
	public static function restartSong(skipTransition:Bool = false):Void {
		if (instance == null || instance.callOnScripts('onRestartSong', null, true) == LuaUtils.Function_Stop) return;
		
		PlayState.instance.paused = true; // For lua
		FlxG.sound.music.volume = 0;
		PlayState.instance.vocals.volume = 0;

		if (skipTransition) {
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
		}
		MusicBeatState.resetState();
	}
	/**
	 * Exits from this song to the menu.
	 * Does not save highscore or any achievements obtained from completing the song.
	 * 
	 * @param 	skipTransition 	Whether the fade transition should be skipped when exiting.
	*/
	function exitSong(skipTransition:Bool = false):Void {
		if (instance == null || instance.callOnScripts('onExitSong', null, true) == LuaUtils.Function_Stop) return;
		
		if (skipTransition) {
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
		}
		
		#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
		
		PlayState.deathCounter = 0;
		PlayState.seenCutscene = false;
		
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
		PlayState.instance.canResync = false;
		PlayState.changedDifficulty = false;
		PlayState.chartingMode = false;
		FlxG.camera.followLerp = 0;
	}

	var dialogueCount:Int = 0;
	public var psychDialogue:DialogueBoxPsych;
	#if HSCRIPT_ALLOWED
	public var dialoguePlusScript:HScript = null;
	#end
	public var dialoguePlusController:DialoguePlusRuntime = null;
	//You don't have to add a song, just saying. You can just do "startDialogue(DialogueBoxPsych.parseDialogue(Paths.json(songName + '/dialogue')))" and it should load dialogue.json
	/**
	 * Starts a dialogue cutscene.
	 * 
	 * @param 	dialogueFile 	Dialogue file used to play the cutscene. Use `DialogueBoxPsych.parseDialogue(path)` to parse a file!
	 * @param 	song 			If specified, plays music with this name. Should be in the `music/` folder.
	*/
	public function startDialogue(dialogueFile:DialogueFile, ?song:String = null, callFirstCallback:Bool = false):Void
	{
		// TO DO: Make this more flexible, maybe?
		if(psychDialogue != null) return;

		if(dialogueFile.dialogue.length > 0) {
			inCutscene = true;
			dialogueCount = 0;
			psychDialogue = new DialogueBoxPsych(dialogueFile, song, !callFirstCallback);
			psychDialogue.scrollFactor.set();
			if(endingSong) {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					#if HSCRIPT_ALLOWED
					finishDialoguePlusScript();
					#end
					endSong();
				}
			} else {
				psychDialogue.finishThing = function() {
					psychDialogue = null;
					#if HSCRIPT_ALLOWED
					finishDialoguePlusScript();
					#end
					startCountdown();
				}
			}
			psychDialogue.nextDialogueThing = startNextDialogue;
			psychDialogue.lineStartThing = function(line:DialogueLine, index:Int) {
				if(dialoguePlusController != null)
					dialoguePlusController.onLine(index + 1, index, line);
			}
			psychDialogue.skipDialogueThing = skipDialogue;
			psychDialogue.cameras = [camHUD];
			add(psychDialogue);
			if(dialoguePlusController != null)
				dialoguePlusController.applySettings();
			if(callFirstCallback)
				psychDialogue.startNextDialog();
		} else {
			FlxG.log.warn('Your dialogue file is badly formatted!');
			#if HSCRIPT_ALLOWED
			finishDialoguePlusScript(false);
			#end
			startAndEnd();
		}
	}

	public function startDialoguePlus(dialogueFile:String = 'dialogue', ?music:String = null):Bool
	{
		var started:Bool = DialoguePlus.start(this, dialogueFile, music);
		if(!started)
		{
			#if (SCRIPTS_ALLOWED)
			addTextToDebug('Dialogue Plus file not found: $dialogueFile', FlxColor.RED);
			#else
			FlxG.log.warn('Dialogue Plus file not found: $dialogueFile');
			#end
			finishDialoguePlusCutscene(false);
		}
		return started;
	}

	#if HSCRIPT_ALLOWED
	public function startDialoguePlusScript(path:String, dialogueName:String = 'dialogue', ?music:String = null):Bool
	{
		if(dialoguePlusScript != null && !dialoguePlusScript.closed)
			return false;

		inCutscene = true;
		var controller:DialoguePlusRuntime = new DialoguePlusRuntime(this, dialogueName, music, path);
		dialoguePlusController = controller;
		var script:HScript = HScript.initFromFileWithVars(path, this, {
			dialogueName: dialogueName,
			dialogueMusic: music,
			dialoguePath: path,
			dialoguePlus: controller,
			loadXml: controller.loadXml,
			addLine: controller.addLine,
			addLines: controller.addLines,
			clearLines: controller.clearLines,
			stopDialogueMusic: controller.stopDialogueMusic,
			playDialogueMusic: controller.playDialogueMusic,
			setCanContinue: controller.setCanContinue,
			setCanSkip: controller.setCanSkip,
			setDialogueVisible: controller.setDialogueVisible,
			setBoxVisible: controller.setBoxVisible,
			setTextVisible: controller.setTextVisible,
			setBackgroundVisible: controller.setBackgroundVisible,
			setSkipTextVisible: controller.setSkipTextVisible,
			dialogueTimer: controller.dialogueTimer
		}, null, function(newScript:HScript) {
			dialoguePlusScript = newScript;
			if(hscriptArray != null && !hscriptArray.contains(newScript))
				hscriptArray.push(newScript);
		});
		if(script == null)
		{
			if(dialoguePlusScript != null && hscriptArray != null)
				hscriptArray.remove(dialoguePlusScript);
			dialoguePlusScript = null;
			dialoguePlusController = null;
			finishDialoguePlusCutscene(false);
			return false;
		}
		if(script.closed)
			return true;

		var data:Dynamic = null;
		if(script.exists('create'))
		{
			var call = script.call('create', [controller]);
			if(call != null)
				data = call.returnValue;
		}
		if(script.closed)
			return true;
		if(script.exists('buildDialogue'))
		{
			var call = script.call('buildDialogue', [dialogueName, music]);
			if(call != null)
				data = call.returnValue;
		}
		if(data == null && script.exists('dialogueFile'))
			data = script.get('dialogueFile');
		if(data == null && script.exists('dialogue'))
			data = script.get('dialogue');

		var parsed:DialogueFile = DialoguePlus.normalizeDialogue(data);
		if(DialoguePlus.isValidDialogue(parsed))
			controller.addLines(parsed, controller.hasLines());

		if(controller.hasLines())
			startDialogue(controller.getDialogueFile(), music, true);
		else if(psychDialogue == null && !script.exists('onUpdate') && !script.exists('onCreate') && !script.exists('create'))
			finishDialoguePlusCutscene(false);

		return true;
	}

	public function finishDialoguePlusScript(callFinish:Bool = true):Void
	{
		if(dialoguePlusScript == null)
			return;

		var script:HScript = dialoguePlusScript;
		dialoguePlusScript = null;
		dialoguePlusController = null;
		if(callFinish && script.exists('onDialogueFinish'))
			script.call('onDialogueFinish');

		if(hscriptArray != null)
			hscriptArray.remove(script);
		script.destroy();
	}
	#end

	public function finishDialoguePlusCutscene(callFinish:Bool = true):Void
	{
		#if HSCRIPT_ALLOWED
		finishDialoguePlusScript(callFinish);
		#end
		dialoguePlusController = null;
		psychDialogue = null;
		inCutscene = false;

		if(endingSong)
			endSong();
		else
			startCountdown();
	}

	var startTimer:FlxTimer;
	var finishTimer:FlxTimer = null;

	// For being able to mess with the sprites on Lua
	/**
	 * Countdown "Ready" sprite. Useful for Lua scripts.
	*/
	public var countdownReady:FlxSprite;
	/**
	 * Countdown "Set" sprite. Useful for Lua scripts.
	*/
	public var countdownSet:FlxSprite;
	/**
	 * Countdown "Go" sprite. Useful for Lua scripts.
	*/
	public var countdownGo:FlxSprite;
	/**
	 * Time (in milliseconds) for the song to start at. Useful for playtesting.
	*/
	public static var startOnTime:Float = 0;

	@:dox(hide) function cacheCountdown()
	{
		var introAssets:Map<String, Array<String>> = new Map<String, Array<String>>();
		var introImagesArray:Array<String> = [formatUI('ready'), formatUI('set'), formatUI('go')];
		introAssets.set(stageUI, introImagesArray);
		var introAlts:Array<String> = introAssets.get(stageUI);
		for (asset in introAlts) Paths.image(asset);

		Paths.countdownSound(stageUI, 'intro3');
		Paths.countdownSound(stageUI, 'intro2');
		Paths.countdownSound(stageUI, 'intro1');
		Paths.countdownSound(stageUI, 'introGo');
	}

	/**
	 * Prepares the game and starts the countdown.
	*/
	public function startCountdown()
	{
		if (startedCountdown) {
			callOnScripts('onStartCountdown');
			return false;
		}
		
		inCutscene = false;
		seenCutscene = true;
		
		strumLineNotes.revive();
		
		var ret:Dynamic = callOnScripts('onStartCountdown', null, true);
		if (ret != LuaUtils.Function_Stop) {
			if (skipCountdown || startOnTime > 0) skipArrowStartTween = true;

			canPause = true;
			for (i in 0...playerStrums.length) {
				setOnScripts('defaultPlayerStrumX' + i, playerStrums.members[i].x);
				setOnScripts('defaultPlayerStrumY' + i, playerStrums.members[i].y);
			}
			for (i in 0...opponentStrums.length) {
				setOnScripts('defaultOpponentStrumX' + i, opponentStrums.members[i].x);
				setOnScripts('defaultOpponentStrumY' + i, opponentStrums.members[i].y);
				//if(ClientPrefs.data.middleScroll) opponentStrums.members[i].visible = false;
			}
			
			if (!skipArrowStartTween && !isStoryMode && startOnTime <= 0)
				tweenInArrows();

			startedCountdown = true;
			Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
			setOnScripts('startedCountdown', true);
			callOnScripts('onCountdownStarted');

			var swagCounter:Int = 0;
			if (startOnTime > 0) {
				if (startOnTime > 700) clearNotesBefore(startOnTime);
				setSongTime(startOnTime - 700);
				return true;
			}
			else if (skipCountdown)
			{
				setSongTime(0);
				return true;
			}
			moveCameraSection();
		} else {
			strumLineNotes.kill();
		}
		
		return true;
	}
	
	@:dox(hide) static var introAssets:Map<String, Array<String>> = [];
	public function countdownTick(tick:Countdown):Void {
		if (skipCountdown) return;
		
		var introImagesArray:Array<String> = [formatUI('ready'), formatUI('set'), formatUI('go')];
		introAssets.set(stageUI, [formatUI('ready'), formatUI('set'), formatUI('go')]);
		
		var introAlts:Array<String> = introAssets.get(stageUI);
		var antialias:Bool = (ClientPrefs.data.antialiasing && !isPixelStage);
		
		var counter:Int = switch (tick) {
			case THREE:
				FlxG.sound.play(Paths.countdownSound(stageUI, 'intro3'), .6);
				0;
			case TWO:
				countdownReady = createCountdownSprite(introAlts[0], antialias);
				FlxG.sound.play(Paths.countdownSound(stageUI, 'intro2'), .6);
				1;
			case ONE:
				countdownSet = createCountdownSprite(introAlts[1], antialias);
				FlxG.sound.play(Paths.countdownSound(stageUI, 'intro1'), .6);
				2;
			case GO:
				countdownGo = createCountdownSprite(introAlts[2], antialias);
				FlxG.sound.play(Paths.countdownSound(stageUI, 'introGo'), .6);
				3;
			case START:
				4;
		}

		stagesFunc(function(stage:BaseStage) stage.countdownTick(tick, counter));
		callOnLuas('onCountdownTick', [counter]);
		callOnHScript('onCountdownTick', [tick, counter]);
	}

	inline private function createCountdownSprite(image:String, antialias:Bool):FlxSprite
	{
		var spr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(image));
		spr.cameras = [camHUD];
		spr.scrollFactor.set();
		spr.updateHitbox();

		if (PlayState.isPixelStage)
			spr.setGraphicSize(Std.int(spr.width * daPixelZoom));

		spr.screenCenter();
		spr.antialiasing = antialias;
		insert(members.indexOf(noteGroup), spr);
		FlxTween.tween(spr, {/*y: spr.y + 100,*/ alpha: 0}, Conductor.crochet / 1000, {
			ease: FlxEase.cubeInOut,
			onComplete: function(twn:FlxTween)
			{
				remove(spr);
				spr.destroy();
			}
		});
		return spr;
	}

	/**
	 * Adds a sprite behind `gfGroup`.
	 * 
	 * @param 	obj 	The object to add.
	*/
	public function addBehindGF(obj:FlxBasic)
	{
		insert(members.indexOf(gfGroup), obj);
	}
	/**
	 * Adds a sprite behind `boyfriendGroup`.
	 * 
	 * @param 	obj 	The object to add.
	*/
	public function addBehindBF(obj:FlxBasic)
	{
		insert(members.indexOf(boyfriendGroup), obj);
	}
	/**
	 * Adds a sprite behind `dadGroup`.
	 * 
	 * @param 	obj 	The object to add.
	*/
	public function addBehindDad(obj:FlxBasic)
	{
		insert(members.indexOf(dadGroup), obj);
	}

	/**
	 * Clears all notes before the specified time (in milliseconds).
	 * 
	 * @param 	time 	The time to clear all notes until.
	*/
	public function clearNotesBefore(time:Float)
	{
		var i:Int = unspawnNotes.length - 1;
		while (i >= 0) {
			var daNote:Note = unspawnNotes[i];
			if(daNote.strumTime - ClientPrefs.data.noteOffset < time - 1)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;

				daNote.kill();
				unspawnNotes.remove(daNote);
				daNote.destroy();
			}
			--i;
		}

		i = notes.length - 1;
		while (i >= 0) {
			var daNote:Note = notes.members[i];
			if(daNote.strumTime - ClientPrefs.data.noteOffset < time - 1)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;
				invalidateNote(daNote);
			}
			--i;
		}
	}

	// fun fact: Dynamic Functions can be overriden by just doing this
	// `updateScore = function(miss:Bool = false) { ... }
	// its like if it was a variable but its just a function!
	// cool right? -Crow
	/**
	 * Updates the score and calls `preUpdateScore` and `onUpdateScore` on Lua.
	 * 
	 * @param 	miss 		Whether or not the score was updated from a note miss.
	 * @param 	scoreBop 	Whether or not the score text should have a bopping animation.
	*/
	public dynamic function updateScore(miss:Bool = false, scoreBop:Bool = true)
	{
		var ret:Dynamic = callOnScripts('preUpdateScore', [miss], true);
		if (ret == LuaUtils.Function_Stop)
			return;

		updateScoreText();

		callOnScripts('onUpdateScore', [miss]);
	}

	/**
	 * Updates the score text.
	*/
	public dynamic function updateScoreText()
	{
		var accText:String = "0.00%";
		if (totalPlayed != 0)
			accText = '${FlxStringUtil.formatMoney(ratingPercent * 100, true, true)}%';

		var currentFC:String = (ratingFC == "") ? "?" : ratingFC;

		var tudo:String = Language.getPhrase('score_text', "SCORE: {1} | MISSES: {2} | ACC: {3} ({4})", [songScore, songMisses, accText, currentFC]);
		scoreTxt.text = tudo;
		scoreTxt.clearFormats();

		var indexAcc:Int = tudo.indexOf(accText);
		if (indexAcc != -1)
			scoreTxt.addFormat(new flixel.text.FlxTextFormat(0xFF57FFFF), indexAcc, indexAcc + accText.length);

		if (currentFC != "?")
		{
			var color:Int = 0xFFFFFFFF;
			if (currentFC == "SFC" || currentFC == "GFC" || currentFC == "NFC")
				color = 0xFFFFBA0D;

			var indexFc:Int = tudo.indexOf(currentFC);
			if (indexFc != -1)
				scoreTxt.addFormat(new flixel.text.FlxTextFormat(color), indexFc, indexFc + currentFC.length);
		}
	}

	public var bucetaTira:Array<String> = [];

	public function remixesPorraMerda(name:String):String {
		var remixes:Array<String> = [' erect', '-erect', '(erect)', ' nightmare', '-nightmare', '(nightmare)'];

		if (bucetaTira != null && bucetaTira.length > 0) // fazer isso softcoded pra ser lindo e ngm reclamar
			remixes = remixes.concat(bucetaTira);
		var lowered:String = name.toLowerCase();

		for (suffix in remixes) {
			if (StringTools.endsWith(lowered, suffix.toLowerCase())) {
				return name.substring(0, name.length - suffix.length);
			}
		}

		return name;
	}

	public function refreshSongNameText():Void
	{
		if(timeTxt != null && SONG != null && ClientPrefs.data.timeBarType == 'Song Name')
			timeTxt.text = remixesPorraMerda(SONG.song);
	}

	/**
	 * Updates the FC status and saves it in the `ratingFC` variable.
	*/
	public dynamic function fullComboFunction()
	{
		var neats:Int = getRatingHits('neat'); // preguiça da porra
		var sicks:Int = getRatingHits('sick');
		var goods:Int = getRatingHits('good');
		var bads:Int = getRatingHits('bad');
		var shits:Int = getRatingHits('shit');

		ratingFC = "";
		if(songMisses == 0)
		{
			if (bads > 0 || shits > 0) ratingFC = 'FC';
			else if (goods > 0) ratingFC = 'GFC';
			else if (sicks > 0) ratingFC = 'SFC';
			else if (neats > 0) ratingFC = 'NFC';
		}
		else {
			if (songMisses < 10) ratingFC = 'SDCB';
			else ratingFC = 'Clear';
		}
	}

	function getRatingHits(name:String):Int
	{
		for(rating in ratingsData)
			if(rating != null && rating.name == name)
				return rating.hits;
		return 0;
	}

	/**
	 * Makes the score text do a bopping animation.
	*/
	public function doScoreBop():Void {
		if(scoreTxtTween != null)
			scoreTxtTween.cancel();

		scoreTxtTween = null;
		if(scoreTxt != null)
			scoreTxt.scale.set(1, 1);
	}

	/**
	 * Changes the song time.
	 * 
	 * @param 	time 	The time (in milliseconds) to change the song time to.
	 * @param 	offset 	Whether or not the time should consider the Conductor offset.
	*/
	public function setSongTime(time:Float, offset:Bool = true)
	{
		FlxG.sound.music.pause();
		vocals.pause();
		opponentVocals.pause();
		
		if (time >= 0) {
			FlxG.sound.music.time = (time - (offset ? 0 : Conductor.offset));
			#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
			FlxG.sound.music.play();

			if (Conductor.songPosition < vocals.length)
			{
				vocals.time = FlxG.sound.music.time;
				#if FLX_PITCH vocals.pitch = playbackRate; #end
				vocals.play();
			}
			else vocals.pause();

			if (Conductor.songPosition < opponentVocals.length)
			{
				opponentVocals.time = FlxG.sound.music.time;
				#if FLX_PITCH opponentVocals.pitch = playbackRate; #end
				opponentVocals.play();
			}
			else opponentVocals.pause();
		}
		
		Conductor.songPosition = (time + (offset ? Conductor.offset : 0));
		syncVideosToSongTime();
	}

	public function startNextDialogue() {
		dialogueCount++;
		callOnScripts('onNextDialogue', [dialogueCount]);
	}

	public function skipDialogue() {
		callOnScripts('onSkipDialogue', [dialogueCount]);
	}

	function startSong():Void
	{
		startingSong = false;
		strumLineNotes.revive();

		@:privateAccess
		FlxG.sound.playMusic(inst._sound, 1, false);
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		FlxG.sound.music.onComplete = finishSong.bind();
		vocals.play();
		opponentVocals.play();
		
		var startPos:Float = Math.max(0, startOnTime - 700);
		setSongTime(startPos, startOnTime <= 0);
		startOnTime = 0;

		if(paused) {
			//trace('Oopsie doopsie! Paused sound');
			FlxG.sound.music.pause();
			vocals.pause();
			opponentVocals.pause();
		}

		stagesFunc(function(stage:BaseStage) stage.startSong());

		// Song duration in a float, useful for the time left feature
		songLength = FlxG.sound.music.length;
		FlxTween.tween(timeBar, {alpha: 1}, 0.5, {ease: FlxEase.circOut});
		FlxTween.tween(timeTxt, {alpha: 1}, 0.5, {ease: FlxEase.circOut});

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence (with Time Left)
		if(autoUpdateRPC) DiscordClient.changePresence(detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter(), true, songLength);
		#end
		setOnScripts('songLength', songLength);
		callOnScripts('onSongStart', [startPos]);
	}

	/**
	 * Array containing all unique note types found in the chart.
	*/
	public var noteTypes:Array<String> = [];
	/**
	 * Array containing all unique events found in the chart.
	*/
	public var eventsPushed:Array<String> = [];
	/**
	 * The total amount of columns per strumline.
	*/
	public var totalColumns: Int = 4;

	@:dox(hide) private function generateSong():Void
	{

		// FlxG.log.add(ChartParser.parse());
		songSpeed = PlayState.SONG.speed;
		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype');
		switch(songSpeedType)
		{
			case "multiplicative":
				songSpeed = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed');
			case "constant":
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed');
		}

		var songData = SONG;
		Conductor.bpm = songData.bpm;

		curSong = songData.song;

		vocals = new FlxSound();
		opponentVocals = new FlxSound();
		try
		{
			if (songData.needsVoices)
			{
				var playerVocals = Paths.voices(songData.song, (boyfriend.vocalsFile == null || boyfriend.vocalsFile.length < 1) ? 'Player' : boyfriend.vocalsFile);
				vocals.loadEmbedded(playerVocals != null ? playerVocals : Paths.voices(songData.song));
				
				var oppVocals = Paths.voices(songData.song, (dad.vocalsFile == null || dad.vocalsFile.length < 1) ? 'Opponent' : dad.vocalsFile);
				if(oppVocals != null && oppVocals.length > 0) opponentVocals.loadEmbedded(oppVocals);
			}
		}
		catch (e:Dynamic) {}

		#if FLX_PITCH
		vocals.pitch = playbackRate;
		opponentVocals.pitch = playbackRate;
		#end
		FlxG.sound.list.add(vocals);
		FlxG.sound.list.add(opponentVocals);

		inst = new FlxSound();
		try
		{
			inst.loadEmbedded(Paths.inst(songData.song));
		}
		catch (e:Dynamic) {}
		FlxG.sound.list.add(inst);

		notes = new FlxTypedGroup<Note>();
		noteGroup.add(notes);

		try
		{
			EVENTS = Song.getChart('events', songName, 'events');
			
			if (EVENTS != null)
				for (event in EVENTS.events) //Event Notes
					for (i in 0...event[1].length)
						makeEvent(event, i);
		} catch(e:Dynamic) {
			EVENTS = null;
		}

		var oldNote:Note = null;
		var sectionsData:Array<SwagSection> = PlayState.SONG.notes;
		var ghostNotesCaught:Int = 0;
		var daBpm:Float = Conductor.bpm;
	
		for (sectionI => section in sectionsData)
		{
			if (section.changeBPM != null && section.changeBPM && section.bpm != null && daBpm != section.bpm)
				daBpm = section.bpm;

			for (i => songNotes in section.sectionNotes) {
				var spawnTime: Float = songNotes[0];
				var noteColumn: Int = Std.int(songNotes[1] % totalColumns);
				var holdLength: Float = songNotes[2];
				var noteType: String = !Std.isOfType(songNotes[3], String) ? Note.defaultNoteTypes[songNotes[3]] : songNotes[3];
				if (Math.isNaN(holdLength))
					holdLength = 0.0;

				var gottaHitNote:Bool = (songNotes[1] < totalColumns);

				if (i > 0) {
					var matches:Bool = false;
					for (evilNote in unspawnNotes) {
						if (noteColumn == evilNote.noteData && gottaHitNote == evilNote.mustPress && evilNote.noteType == noteType) {
							if (Math.abs(spawnTime - evilNote.strumTime + delay) > FlxMath.EPSILON) continue;
							ghostNotesCaught ++;
							matches = true;
							break;
						}
					}
					if (matches)
						continue;
				}

				var swagNote:Note = new Note(spawnTime, noteColumn, oldNote);
				var isAlt: Bool = section.altAnim && !gottaHitNote;
				swagNote.gfNote = (section.gfSection && gottaHitNote == section.mustHitSection);
				swagNote.animSuffix = isAlt ? "-alt" : "";
				swagNote.sustainLength = holdLength;
				swagNote.mustPress = gottaHitNote;
				swagNote.noteType = noteType;
				assignExtraCharacterToNote(swagNote);
				swagNote.section = sectionI;
				applyRuntimeNoteOverrides(swagNote);
	
				swagNote.scrollFactor.set();
				unspawnNotes.push(swagNote);
				
				var curStepCrochet:Float = 60 / daBpm * 1000 / 4.0;
				final roundSus:Int = Math.round(swagNote.sustainLength / curStepCrochet);
				if(roundSus > 0)
				{
					for (susNote in 0...roundSus) {
						oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];

						var sustainNote:Note = new Note(spawnTime + (curStepCrochet * susNote), noteColumn, oldNote, true);
						sustainNote.sustainLength = curStepCrochet;
						sustainNote.animSuffix = swagNote.animSuffix;
						sustainNote.mustPress = swagNote.mustPress;
						sustainNote.noteType = swagNote.noteType;
						assignExtraCharacterToNote(sustainNote);
						sustainNote.gfNote = swagNote.gfNote;
						sustainNote.scrollFactor.set();
						sustainNote.section = sectionI;
						sustainNote.parent = swagNote;
						applyRuntimeNoteOverrides(sustainNote);
						unspawnNotes.push(sustainNote);
						swagNote.tail.push(sustainNote);
						
						if (sustainNote.mustPress) sustainNote.x += FlxG.width / 2; // general offset
						else if(ClientPrefs.data.middleScroll)
						{
							sustainNote.x += 310;
							if(noteColumn > 1) //Up and Right
								sustainNote.x += FlxG.width / 2 + 25;
						}
					}
				}

				if (swagNote.mustPress)
				{
					swagNote.x += FlxG.width / 2; // general offset
				}
				else if(ClientPrefs.data.middleScroll)
				{
					swagNote.x += 310;
					if(noteColumn > 1) //Up and Right
					{
						swagNote.x += FlxG.width / 2 + 25;
					}
				}
				if(!noteTypes.contains(swagNote.noteType))
					noteTypes.push(swagNote.noteType);

				oldNote = swagNote;
			}
		}
		
		if (ghostNotesCaught > 0)
			trace('(${SONG.song}) $ghostNotesCaught duplicate notes ignored');
		
		if(Song.hasEventsNamed(EVENTS, Song.CAMERA_FOCUS_EVENT))
			Song.removeEventsByName(songData, Song.CAMERA_FOCUS_EVENT);

		for (event in songData.events) //Event Notes
			for (i in 0...event[1].length)
				makeEvent(event, i);
		
		if (!skipArrowStartTween && !isStoryMode) {
			notes.forEachAlive(function(note:Note) {
				if (ClientPrefs.data.opponentStrums || note.mustPress) {
					note.copyAlpha = false;
					note.alpha = note.multAlpha;
					if(ClientPrefs.data.middleScroll && !note.mustPress)
						note.alpha *= 0.35;
				}
			});
		}

		unspawnNotes.sort(sortByTime);
		generatedMusic = true;
	}

	// called only once per different event (Used for precaching)
	/**
	 * Called once every time an event is found in the chart.
	 * 
	 * @param 	event 	The `EventNote` of the found event.
	*/
	function eventPushed(event:EventNote) {
		eventPushedUnique(event);
		if(eventsPushed.contains(event.event)) {
			return;
		}

		stagesFunc(function(stage:BaseStage) stage.eventPushed(event));
		eventsPushed.push(event.event);
	}

	// called by every event with the same name
	/**
	 * Called every time an event is found in the chart.
	 * 
	 * @param 	event 	The `EventNote` of the found event.
	*/
	function eventPushedUnique(event:EventNote) {
		switch(event.event) {
			case "Change Character":
				var target:String = normalizeCharacterTarget(event.value1);
				var charType:Int = switch(target) {
					case 'gf': 2;
					case 'dad': 1;
					case 'boyfriend': 0;
					default: -1;
				}
				var newCharacter:String = event.value2;
				if(charType >= 0)
					addCharacterToList(newCharacter, charType);

			case 'Play Sound':
				Paths.sound(event.value1); //Precache sound
		}
		stagesFunc(function(stage:BaseStage) stage.eventPushedUnique(event));
	}

	/**
	 * Called every time an event is found in the chart.
	 * 
	 * @param 	event 	The `EventNote` of the found event.
	 * 
	 * @return 	The time (in milliseconds) of how early the event should play to it's chart time.
	*/
	function eventEarlyTrigger(event:EventNote):Float {
		var returnedValue:Dynamic = callOnScripts('eventEarlyTrigger', buildEventCallbackArgs(event.event, event.value1, event.value2, event.strumTime, event.values), true);
		if (returnedValue != null && Std.isOfType(returnedValue, Float) && returnedValue != 0) {
			return returnedValue;
		}

		switch(event.event) {
			case 'Kill Henchmen': //Better timing so that the kill sound matches the beat intended
				return 280; //Plays 280ms before the actual position
		}
		return 0;
	}

	/**
	 * Sorts two objects by their `strumTime` in ascending order.
	 * 
	 * @param 	a 	First object to sort.
	 * @param 	b 	Second object to sort.
	 * 
	 * @return 	Sort order.
	*/
	public static function sortByTime(a:Dynamic, b:Dynamic):Int
		return FlxSort.byValues(FlxSort.ASCENDING, a.strumTime, b.strumTime);

	@:dox(hide) function makeEvent(event:Array<Dynamic>, i:Int)
	{
		var eventData:Array<Dynamic> = cast event[1][i];
		var eventValues:Array<String> = [];
		for(valueIndex in 1...eventData.length)
			eventValues.push(eventData[valueIndex] != null ? Std.string(eventData[valueIndex]) : '');
		while(eventValues.length < 2)
			eventValues.push('');

		var subEvent:EventNote = {
			strumTime: event[0] + ClientPrefs.data.noteOffset,
			event: eventData[0] != null ? Std.string(eventData[0]) : '',
			value1: eventValues[0],
			value2: eventValues[1],
			values: eventValues
		};
		eventNotes.push(subEvent);
		eventPushed(subEvent);
		callOnScripts('onEventPushed', buildEventCallbackArgs(subEvent.event, subEvent.value1, subEvent.value2, subEvent.strumTime, subEvent.values));
	}
	
	/**
	 * Whether or not the note fade-in animation should be skipped at the start of a song. Ignored in Story Mode or when `skipCountdown` is true.
	*/
	public var skipArrowStartTween:Bool = false; //for lua

	function getDownscrollStrumY(strum:StrumNote):Float
		return FlxG.height - strum.height - 50;

	private function generateStaticArrows(player:Bool):Void
	{
		var strumLineX:Float = ClientPrefs.data.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X;
		var strumLineY:Float = 50;
		
		for (i in 0 ... 4) {
			var babyArrow:StrumNote = new StrumNote(strumLineX, strumLineY, i, player ? 1 : 0);
			babyArrow.downScroll = ClientPrefs.data.downScroll;
			
			if (babyArrow.downScroll)
				babyArrow.y = getDownscrollStrumY(babyArrow);
			
			if (!player) {
				if (!ClientPrefs.data.opponentStrums) babyArrow.alpha = 0;
				else if (ClientPrefs.data.middleScroll) babyArrow.alpha = 0.35;
			}

			if (player) {
				playerStrums.add(babyArrow);
			} else {
				if (ClientPrefs.data.middleScroll) {
					babyArrow.x += 310;
					if (i > 1) { //Up and Right
						babyArrow.x += FlxG.width / 2 + 25;
					}
				}
				opponentStrums.add(babyArrow);
			}

			strumLineNotes.add(babyArrow);
			babyArrow.playerPosition();

			var runtimeIndex:Int = i + (player ? 4 : 0);
			if (strumSkinOverrides[runtimeIndex] != null)
				applyStrumSkinOverride(runtimeIndex, strumSkinOverrides[runtimeIndex]);
			else
			{
				var allowed:Null<Bool> = strumRGBAllowedOverrides[runtimeIndex];
				if (allowed != null)
					babyArrow.setRGBAllowed(allowed);
			}

			if (strumRGBOverrides[runtimeIndex] != null && babyArrow.useRGBShader)
				babyArrow.setRGBOverride(strumRGBOverrides[runtimeIndex]);
		}
	}
	function tweenInArrows():Void {
		for (group in [playerStrums, opponentStrums]) {
			for (i => strum in group.members) {
				
				var targetY:Float = strum.y;
				var targetAlpha:Float = strum.alpha;
				
				strum.revive();
				strum.alpha = 0;
				strum.y += (ClientPrefs.data.downScroll ? 10 : -10);
				FlxTween.tween(strum, {y: targetY, alpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: .5 + .2 * i});
			}
		}
	}

	override function openSubState(SubState:FlxSubState)
	{
		stagesFunc(function(stage:BaseStage) stage.openSubState(SubState));
		
		if (paused) {
			FlxG.sound.music?.pause();
			opponentVocals?.pause();
			vocals?.pause();
			pauseManagedVideos();
			
			FlxTimer.globalManager.forEach(function(tmr:FlxTimer) if(!tmr.finished) tmr.active = false);
			FlxTween.globalManager.forEach(function(twn:FlxTween) if(!twn.finished) twn.active = false);
		}

		super.openSubState(SubState);
	}

	public var canResync:Bool = true;
	override function closeSubState()
	{
		super.closeSubState();
		
		stagesFunc(function(stage:BaseStage) stage.closeSubState());
		if (paused)
		{
			if (FlxG.sound.music != null && !startingSong && canResync)
			{
				resyncVocals();
			}
			FlxTimer.globalManager.forEach(function(tmr:FlxTimer) if(!tmr.finished) tmr.active = true);
			FlxTween.globalManager.forEach(function(twn:FlxTween) if(!twn.finished) twn.active = true);
			resumeManagedVideos();

			paused = false;
			callOnScripts('onResume');
			resetRPC(startTimer != null && startTimer.finished);
		}
	}

	#if DISCORD_ALLOWED
	override public function onFocus():Void {
		super.onFocus();
		resetRPC(Conductor.songPosition > 0);
	}

	override public function onFocusLost():Void {
		super.onFocusLost();
		if (health > 0)
			resetRPC(false);
	}
	#end
	
	override function updatePresence():Void {
		if (autoUpdateRPC)
			resetRPC(Conductor.songPosition > 0);
	}

	// Updating Discord Rich Presence.
	function resetRPC(showTime:Bool = false) {
		#if DISCORD_ALLOWED
		if (!autoUpdateRPC) return;
		
		var detailsText:String = (paused ? this.detailsPausedText : this.detailsText);
		var stateText:String = SONG.song + ' ($storyDifficultyText)';
		
		if (showTime && !paused) {
			DiscordClient.changePresence(detailsText, stateText, iconP2.getCharacter(), true, songLength - Conductor.songPosition - ClientPrefs.data.noteOffset);
		} else {
			DiscordClient.changePresence(detailsText, stateText, iconP2.getCharacter());
		}
		#end
	}

	function resyncVocals():Void
	{
		if(finishTimer != null) return;

		trace('resynced vocals at ' + Math.floor(Conductor.songPosition));

		FlxG.sound.music.play();
		#if FLX_PITCH FlxG.sound.music.pitch = playbackRate; #end
		Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;

		var checkVocals = [vocals, opponentVocals];
		for (voc in checkVocals)
		{
			if (FlxG.sound.music.time < vocals.length)
			{
				voc.time = FlxG.sound.music.time;
				#if FLX_PITCH voc.pitch = playbackRate; #end
				voc.play();
			}
			else voc.pause();
		}
	}

	/**
	 * Whether or not the game is paused.
	*/
	public var paused:Bool = false;
	/**
	 * Whether or not the player can use the Reset button to die.
	*/
	public var canReset:Bool = true;
	/**
	 * Whether or not the countdown has started.
	*/
	public var startedCountdown:Bool = false;
	/**
	 * Whether or not the player can pause.
	*/
	public var canPause:Bool = true;
	/**
	 * Whether or not the camera should be frozen.
	*/
	public var freezeCamera:Bool = false;
	/**
	 * Whether or not the player can use the Debug keys to go to the Chart or Character editors.
	*/
	public var allowDebugKeys:Bool = true;

	override public function update(elapsed:Float)
	{
		if(!inCutscene && !paused && !freezeCamera) {
			FlxG.camera.followLerp = 0.04 * cameraSpeed * playbackRate;
			var idleAnim:Bool = (boyfriend.getAnimationName().startsWith('idle') || boyfriend.getAnimationName().startsWith('danceLeft') || boyfriend.getAnimationName().startsWith('danceRight'));
			if(!startingSong && !endingSong && idleAnim) {
				boyfriendIdleTime += elapsed;
				if(boyfriendIdleTime >= 0.15) { // Kind of a mercy thing for making the achievement easier to get as it's apparently frustrating to some playerss
					boyfriendIdled = true;
				}
			} else {
				boyfriendIdleTime = 0;
			}
		}
		else FlxG.camera.followLerp = 0;
		
		refreshScreenScriptVariables();
		preUpdate(elapsed);

		if(botplayTxt != null && botplayTxt.visible) {
			botplaySine += 180 * elapsed;
			botplayTxt.alpha = 1 - Math.sin((Math.PI * botplaySine) / 180);
		}

		if (controls.PAUSE && startedCountdown && canPause)
		{
			var ret:Dynamic = callOnScripts('onPause', null, true);
			if(ret != LuaUtils.Function_Stop) {
				openPauseMenu();
			}
		}

		if(!endingSong && !inCutscene && allowDebugKeys)
		{
			if (controls.justPressed('debug_1'))
				openChartEditor();
			else if (controls.justPressed('debug_2'))
				openCharacterEditor();
		}

		if (healthBar.bounds.max != null && health > healthBar.bounds.max)
			health = healthBar.bounds.max;

		if (startedCountdown && !paused)
		{
			Conductor.songPosition += elapsed * 1000 * playbackRate;
			
			if (!startingSong && FlxG.sound.music?.playing)
			{
				Conductor.songPosition = FlxMath.lerp(FlxG.sound.music.time + Conductor.offset, Conductor.songPosition, Math.exp(-elapsed * 5));
				var timeDiff:Float = Math.abs((FlxG.sound.music.time + Conductor.offset) - Conductor.songPosition);
				if (timeDiff > 1000 * playbackRate)
					Conductor.songPosition = Conductor.songPosition + 1000 * FlxMath.signOf(timeDiff);
			}
		}

		if (startingSong)
		{
			if (startedCountdown && Conductor.songPosition >= Conductor.offset)
				startSong();
			else if(!startedCountdown)
				Conductor.songPosition = -Conductor.crochet * 5 + Conductor.offset;
		}
		else if (!paused && updateTime)
		{
			var curTime:Float = Math.max(0, Conductor.songPosition- ClientPrefs.data.noteOffset);
			songPercent = (curTime / songLength);

			var songCalc:Float = (songLength - curTime);
			if(ClientPrefs.data.timeBarType == 'Time Elapsed') songCalc = curTime;

			var secondsTotal:Int = Math.floor(songCalc / 1000);
			if(secondsTotal < 0) secondsTotal = 0;
			
			var lengthTotal:Int = Math.floor(songLength / 1000);

			if(ClientPrefs.data.timeBarType != 'Song Name') {
				var curTimeStr:String = FlxStringUtil.formatTime(secondsTotal, false);
				var maxTimeStr:String = FlxStringUtil.formatTime(lengthTotal, false);
				
				timeTxt.text = curTimeStr + ' / ' + maxTimeStr;
			}
		}

		FlxG.watch.addQuick("secShit", curSection);
		FlxG.watch.addQuick("beatShit", curBeat);
		FlxG.watch.addQuick("stepShit", curStep);

		// RESET = Quick Game Over Screen
		if (!ClientPrefs.data.noReset && controls.RESET && canReset && !inCutscene && startedCountdown && !endingSong)
		{
			health = 0;
			trace("RESET = True");
		}
		doDeathCheck();
		
		super.update(elapsed);
		updateCameraMoveIdleReset();
		updateCameraBopZoom(elapsed);

		if (unspawnNotes[0] != null)
		{
			var time:Float = getNoteSpawnTime(unspawnNotes[0]);

			while (unspawnNotes.length > 0 && unspawnNotes[0].strumTime - Conductor.songPosition < time)
			{
				var dunceNote:Note = unspawnNotes[0];
				notes.insert(0, dunceNote);
				dunceNote.spawned = true;

				callOnLuas('onSpawnNote', [notes.members.indexOf(dunceNote), dunceNote.noteData, dunceNote.noteType, dunceNote.isSustainNote, dunceNote.strumTime]);
				callOnHScript('onSpawnNote', [dunceNote]);

				var index:Int = unspawnNotes.indexOf(dunceNote);
				unspawnNotes.splice(index, 1);
			}
		}

		if (generatedMusic)
		{
			if(!inCutscene)
			{
				if(!cpuControlled)
					keysCheck();
				else
					playerDance();

				if(notes.length > 0)
				{
					if(startedCountdown)
					{
						var noteInd:Int = 0;
						while (noteInd < notes.length) {
							var daNote:Note = notes.members[noteInd ++];
							if (daNote == null || !daNote.exists || !daNote.alive)
								continue;
							
							var strumGroup:FlxTypedGroup<StrumNote> = playerStrums;
							if(!daNote.mustPress) strumGroup = opponentStrums;

							var strum:StrumNote = strumGroup.members[daNote.noteData];
							daNote.followStrumNote(strum, songSpeed / playbackRate);

							if (daNote.mustPress) {
								if(cpuControlled && !daNote.blockHit && daNote.canBeHit && (daNote.isSustainNote || daNote.strumTime <= Conductor.songPosition))
									goodNoteHit(daNote);
							} else if (daNote.wasGoodHit && !daNote.hitByOpponent && !daNote.ignoreNote)
								opponentNoteHit(daNote);

							if (daNote.isSustainNote && strum.sustainReduce)
								daNote.clipToStrumNote(strum);

							// Kill extremely late notes and cause misses
							if (!daNote.canBeHit && !daNote.tooLate && !daNote.wasGoodHit && daNote.strumTime < Conductor.songPosition - Conductor.safeZoneOffset) {
								if (daNote.mustPress && !cpuControlled && !daNote.ignoreNote && !endingSong)
									noteMiss(daNote);
								daNote.tooLate = true;
							}
							
							if ((daNote.tooLate || daNote.wasGoodHit) && Conductor.songPosition - daNote.strumTime - daNote.sustainLength > noteKillOffset) {
								daNote.active = daNote.visible = false;
								invalidateNote(daNote);
							}
							
							if (!daNote.exists || !daNote.alive)
								noteInd --;
						}
					}
					else
					{
						for (note in notes)
							note.canBeHit = false;
					}
				}
			}
			checkEventNote();
		}

		#if debug
		if(!endingSong && !startingSong) {
			if (FlxG.keys.justPressed.ONE) {
				KillNotes();
				FlxG.sound.music.onComplete();
			}
			if(FlxG.keys.justPressed.TWO) { //Go 10 seconds into the future :O
				setSongTime(Conductor.songPosition + 10000);
				clearNotesBefore(Conductor.songPosition);
			}
		}
		#end
		
		setOnScripts('botPlay', cpuControlled);

		updateIconsScale(elapsed);
		updateIconsPosition();
		
		postUpdate(elapsed);
	}

	// Health icon updaters
	/**
	 * Updates the scale of the icons.
	 * 
	 * @param 	elapsed 	Elapsed time (in seconds) since last frame.
	*/
	public dynamic function updateIconsScale(elapsed:Float)
	{
		var mult:Float = FlxMath.lerp(1, iconP1.scale.x, Math.exp(-elapsed * 9 * playbackRate));
		iconP1.scale.set(mult, mult);
		iconP1.updateHitbox();

		var mult:Float = FlxMath.lerp(1, iconP2.scale.x, Math.exp(-elapsed * 9 * playbackRate));
		iconP2.scale.set(mult, mult);
		iconP2.updateHitbox();
	}

	/**
	 * Updates the position of the icons.
	*/
	public dynamic function updateIconsPosition()
	{
		var iconOffset:Int = 26;
		if(healthBar.flipped)
		{
			iconP1.flipX = true;
			iconP2.flipX = true;
			iconP1.x = healthBar.barCenter - (150 * iconP1.scale.x) / 2 - iconOffset * 2;
			iconP2.x = healthBar.barCenter + (150 * iconP2.scale.x - 150) / 2 - iconOffset; // hi unholywanderer4 thank yu
		}
		else
		{
			iconP1.flipX = false;
			iconP2.flipX = false;
			iconP1.x = healthBar.barCenter + (150 * iconP1.scale.x - 150) / 2 - iconOffset;
			iconP2.x = healthBar.barCenter - (150 * iconP2.scale.x) / 2 - iconOffset * 2;
		}
	}

	/**
	 * Whether or not the icons can change their animation frame when setting health.
	*/
	var iconsAnimations:Bool = true;
	function set_health(value:Float):Float // You can alter how icon animations work here
	{
		value = FlxMath.roundDecimal(value, 5); //Fix Float imprecision
		if(!iconsAnimations || healthBar == null || !healthBar.enabled || healthBar.valueFunction == null)
		{
			health = value;
			return health;
		}

		// update health bar
		health = value;
		var newPercent:Null<Float> = FlxMath.remapToRange(FlxMath.bound(healthBar.valueFunction(), healthBar.bounds.min, healthBar.bounds.max), healthBar.bounds.min, healthBar.bounds.max, 0, 100);
		if(!healthBar.smooth) healthBar.percent = (newPercent != null ? newPercent : 0);

		var iconPercent:Float = (newPercent != null ? newPercent : 0);
		iconP1.setIconFrame((iconPercent < 20) ? 1 : 0); //If health is under 20%, change player icon to frame 1 (losing icon), otherwise, frame 0 (normal)
		iconP2.setIconFrame((iconPercent > 80) ? 1 : 0); //If health is over 80%, change opponent icon to frame 1 (losing icon), otherwise, frame 0 (normal)
		return health;
	}

	/**
	 * Pauses the game and opens the Pause menu.
	*/
	function openPauseMenu()
	{
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		persistentDraw = true;
		paused = true;
		
		if(!cpuControlled)
		{
			for (note in playerStrums)
				if(note.animation.curAnim != null && note.animation.curAnim.name != 'static')
				{
					note.playAnim('static');
					note.resetAnim = 0;
				}
		}
		openSubState(new PauseSubState());

		#if DISCORD_ALLOWED
		if(autoUpdateRPC) DiscordClient.changePresence(detailsPausedText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
		#end
	}

	/**
	 * Opens the Chart Editor.
	*/
	function openChartEditor()
	{
		canResync = false;
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		chartingMode = true;
		paused = true;

		if(FlxG.sound.music != null)
			FlxG.sound.music.stop();
		if(vocals != null)
			vocals.pause();
		if(opponentVocals != null)
			opponentVocals.pause();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Chart Editor", null, null, true);
		DiscordClient.resetClientID();
		#end

		MusicBeatState.switchState(new ChartingState());
	}

	/**
	 * Opens the Character Editor.
	*/
	function openCharacterEditor()
	{
		canResync = false;
		FlxG.camera.followLerp = 0;
		persistentUpdate = false;
		paused = true;

		if(FlxG.sound.music != null)
			FlxG.sound.music.stop();
		if(vocals != null)
			vocals.pause();
		if(opponentVocals != null)
			opponentVocals.pause();

		#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
		MusicBeatState.switchState(new CharacterEditorState(SONG.player2));
	}

	/**
	 * Whether or not the player is dead.
	*/
	public var isDead:Bool = false; //Don't mess with this on Lua!!!
	@:dox(hide) var gameOverTimer:FlxTimer;
	function doDeathCheck(?skipHealthCheck:Bool = false) {
		if (((skipHealthCheck && instakillOnMiss) || health <= 0) && !practiceMode && !isDead && gameOverTimer == null)
		{
			stagesFunc((stage:BaseStage) -> stage.onGameOver());
			var ret:Dynamic = callOnScripts('onGameOver', null, true);
			if(ret != LuaUtils.Function_Stop)
			{
				FlxG.animationTimeScale = 1;
				boyfriend.stunned = true;
				deathCounter++;

				paused = true;
				canResync = false;
				canPause = false;
				#if VIDEOS_ALLOWED
				if(videoCutscene != null)
				{
					videoCutscene.destroy();
					videoCutscene = null;
				}
				#end

				persistentUpdate = false;
				persistentDraw = false;
				FlxTimer.globalManager.clear();
				FlxTween.globalManager.clear();
				FlxG.camera.filters = [];

				if(GameOverSubstate.deathDelay > 0)
				{
					gameOverTimer = new FlxTimer().start(GameOverSubstate.deathDelay, function(_)
					{
						vocals.stop();
						opponentVocals.stop();
						FlxG.sound.music.stop();
						openSubState(new GameOverSubstate(boyfriend));
						gameOverTimer = null;
					});
				}
				else
				{
					vocals.stop();
					opponentVocals.stop();
					FlxG.sound.music.stop();
					openSubState(new GameOverSubstate(boyfriend));
				}

				// MusicBeatState.switchState(new GameOverState(boyfriend.getScreenPosition().x, boyfriend.getScreenPosition().y));

				#if DISCORD_ALLOWED
				// Game Over doesn't get his its variable because it's only used here
				if(autoUpdateRPC) DiscordClient.changePresence("Game Over - " + detailsText, SONG.song + " (" + storyDifficultyText + ")", iconP2.getCharacter());
				#end
				isDead = true;
				return true;
			}
		}
		return false;
	}

	function checkEventNote() {
		while(eventNotes.length > 0) {
			var leStrumTime:Float = eventNotes[0].strumTime;
			if(Conductor.songPosition < leStrumTime) {
				return;
			}

			var value1:String = '';
			if(eventNotes[0].value1 != null)
				value1 = eventNotes[0].value1;

			var value2:String = '';
			if(eventNotes[0].value2 != null)
				value2 = eventNotes[0].value2;

			triggerEvent(eventNotes[0].event, value1, value2, leStrumTime, eventNotes[0].values);
			eventNotes.shift();
		}
	}


	function cancelSongSpeedTween():Void
	{
		if(songSpeedTween != null)
		{
			songSpeedTween.cancel();
			songSpeedTween = null;
		}
		FlxTween.cancelTweensOf(this, ['songSpeed']);
	}

	function cancelCameraZoomTween():Void
	{
		if(cameraZoomTween != null)
		{
			cameraZoomTween.cancel();
			cameraZoomTween = null;
		}
		FlxTween.cancelTweensOf(this, ['defaultCamZoom']);
	}

	function updateCameraBopZoom(elapsed:Float):Void
	{
		if(!camZooming)
			return;

		var decay:Float = Math.exp(-elapsed * 3.125 * camZoomingDecay * playbackRate);
		decayCameraBaseZoom(decay);
		decayCameraBopZoom(FlxG.camera, 'game', decay);
		decayCameraBopZoom(camHUD, 'hud', decay);
	}

	function decayCameraBaseZoom(decay:Float):Void
	{
		var oldZoom:Float = camGameBaseZoom;
		if(Math.isNaN(oldZoom))
			oldZoom = defaultCamZoom;

		var newZoom:Float = defaultCamZoom + (oldZoom - defaultCamZoom) * decay;
		if(Math.abs(newZoom - defaultCamZoom) < 0.0001)
			newZoom = defaultCamZoom;
		applyCameraBaseZoomDelta(newZoom - oldZoom);
	}

	function applyCameraBaseZoomDelta(delta:Float):Void
	{
		if(Math.isNaN(delta) || delta == 0)
			return;

		camGameBaseZoom += delta;
		if(FlxG.camera != null)
			FlxG.camera.zoom += delta;
	}

	function decayCameraBopZoom(camera:FlxCamera, target:String, decay:Float):Void
	{
		var oldZoom:Float = target == 'game' ? camGameBopZoom : camHUDBopZoom;
		var newZoom:Float = oldZoom * decay;
		if(Math.abs(newZoom) < 0.0001)
			newZoom = 0;
		applyCameraBopZoomDelta(camera, target, newZoom - oldZoom);
	}

	function applyCameraBopZoomDelta(camera:FlxCamera, target:String, delta:Float):Void
	{
		if(Math.isNaN(delta) || delta == 0)
			return;

		if(target == 'game')
			camGameBopZoom += delta;
		else
			camHUDBopZoom += delta;

		if(camera != null)
			camera.zoom += delta;
	}

	function setDefaultCamZoomTarget(value:Float):Void
	{
		if(Math.isNaN(value))
			return;
		defaultCamZoom = value;
		if(Math.isNaN(camGameBaseZoom))
			camGameBaseZoom = value;
	}

	function setDefaultCamZoomVisual(value:Float):Void
	{
		if(Math.isNaN(value))
			return;

		var oldZoom:Float = camGameBaseZoom;
		if(Math.isNaN(oldZoom))
			oldZoom = defaultCamZoom;

		defaultCamZoom = value;
		camGameBaseZoom = value;
		if(FlxG.camera != null)
			FlxG.camera.zoom += value - oldZoom;
	}

	function addCameraZoomBop(gameZoom:Float, hudZoom:Float):Void
	{
		if(!ClientPrefs.data.camZooms || FlxG.camera == null || camHUD == null)
			return;
		if(camGameBopZoom >= 0.35)
			return;

		var gameDelta:Float = gameZoom;
		if(gameDelta > 0)
			gameDelta = Math.min(gameDelta, 0.35 - camGameBopZoom);

		applyCameraBopZoomDelta(FlxG.camera, 'game', gameDelta);
		applyCameraBopZoomDelta(camHUD, 'hud', hudZoom);
	}

		function getCameraZoomEase(ease:String):Float->Float
			{
				switch ((ease ?? '').toLowerCase().trim())
				{
					case 'linear':
						return FlxEase.linear;

					case 'sinein':
						return FlxEase.sineIn;
					case 'sineout':
						return FlxEase.sineOut;
					case 'sineinout':
						return FlxEase.sineInOut;

					case 'quadin':
						return FlxEase.quadIn;
					case 'quadout':
						return FlxEase.quadOut;
					case 'quadinout':
						return FlxEase.quadInOut;

					case 'cubein':
						return FlxEase.cubeIn;
					case 'cubeout':
						return FlxEase.cubeOut;
					case 'cubeinout':
						return FlxEase.cubeInOut;

					case 'quartin':
						return FlxEase.quartIn;
					case 'quartout':
						return FlxEase.quartOut;
					case 'quartinout':
						return FlxEase.quartInOut;

					case 'quintin':
						return FlxEase.quintIn;
					case 'quintout':
						return FlxEase.quintOut;
					case 'quintinout':
						return FlxEase.quintInOut;

					case 'expoin':
						return FlxEase.expoIn;
					case 'expoout':
						return FlxEase.expoOut;
					case 'expoinout':
						return FlxEase.expoInOut;

					case 'circin':
						return FlxEase.circIn;
					case 'circout':
						return FlxEase.circOut;
					case 'circinout':
						return FlxEase.circInOut;

					case 'backin':
						return FlxEase.backIn;
					case 'backout':
						return FlxEase.backOut;
					case 'backinout':
						return FlxEase.backInOut;

					case 'bouncein':
						return FlxEase.bounceIn;
					case 'bounceout':
						return FlxEase.bounceOut;
					case 'bounceinout':
						return FlxEase.bounceInOut;

					case 'elasticin':
						return FlxEase.elasticIn;
					case 'elasticout':
						return FlxEase.elasticOut;
					case 'elasticinout':
						return FlxEase.elasticInOut;

					default:
						return FlxEase.linear;
				}
			}




	/**
	 * Triggers an event.
	 * 
	 * @param 	eventName 	The name of the event.
	 * @param 	value1 		The first value of the event.
	 * @param 	value2 		The second value of the event.
	 * @param 	strumTime 	The time (in milliseconds) this event is triggered on.
	*/
	public function applyCameraZoom(zoom:Float, steps:Float = 0, ease:String = 'classic', type:String = 'nll'):Float
	{
		if (Math.isNaN(zoom)) zoom = defaultCamZoom;
		if (Math.isNaN(steps)) steps = 0;
		if (ease == null || ease.trim().length < 1) ease = 'classic';
		if (type == null || type.trim().length < 1) type = 'nll';

		var baseZoom:Float = defaultCamZoom;
		var targetZoom:Float = baseZoom;
		switch (type.toLowerCase().trim())
		{
			case 'nll' | 'set' | 'absolute':
				targetZoom = zoom;
			case 'mr' | 'add' | 'relative' | '+':
				targetZoom = baseZoom + zoom;
			case 'lss' | 'subtract' | 'sub' | '-':
				targetZoom = baseZoom - zoom;
			default:
				targetZoom = zoom;
		}

		var zoomMode:String = ease.toLowerCase().trim();
		cancelCameraZoomTween();

		switch (zoomMode)
		{
			case 'instant':
				setDefaultCamZoomVisual(targetZoom);
			case 'classic' | 'og':
				setDefaultCamZoomTarget(targetZoom);
			default:
				if (steps <= 0)
				{
					setDefaultCamZoomVisual(targetZoom);
				}
				else
				{
					var time:Float = (steps * Conductor.stepCrochet / 1000) / playbackRate;
					var startZoom:Float = Math.isNaN(camGameBaseZoom) ? defaultCamZoom : camGameBaseZoom;
					cameraZoomTween = FlxTween.num(startZoom, targetZoom, time, {
						ease: getCameraZoomEase(ease),
						onComplete: function(twn:FlxTween)
						{
							setDefaultCamZoomVisual(targetZoom);
							if(cameraZoomTween == twn)
								cameraZoomTween = null;
						}
					}, function(value:Float)
					{
						setDefaultCamZoomVisual(value);
					});
				}
		}
		return targetZoom;
	}

	public function applyCameraZoomEvent(value1:String, value2:String):Float
	{
		var v1:Array<String> = (value1 ?? '').split(',');
		var v2:Array<String> = (value2 ?? '').split(',');

		var zoom:Float = Std.parseFloat(v1[0].trim());
		var steps:Float = 0;
		if (v1.length > 1)
			steps = Std.parseFloat(v1[1].trim());

		var ease:String = 'OG';
		var type:String = 'nll';
		if (v2.length > 0 && v2[0].trim() != '')
			ease = v2[0].trim();
		if (v2.length > 1 && v2[1].trim() != '')
			type = v2[1].trim();

		return applyCameraZoom(zoom, steps, ease, type);
	}

	public function triggerEvent(eventName:String, value1:String, value2:String, strumTime:Float, ?values:Array<String>) {
		var flValue1:Null<Float> = Std.parseFloat(value1);
		var flValue2:Null<Float> = Std.parseFloat(value2);
		if(Math.isNaN(flValue1)) flValue1 = null;
		if(Math.isNaN(flValue2)) flValue2 = null;

		switch(eventName) {
			case 'Hey!':
				var rawTarget:String = value1.toLowerCase().trim();
				var targetName:String = switch(rawTarget) {
					case 'bf' | 'boyfriend' | '0': 'boyfriend';
					case 'gf' | 'girlfriend' | '1': 'gf';
					case 'dad' | 'opponent': 'dad';
					default: normalizeCharacterTarget(value1);
				}
				var target:Character = getCharacterByName(targetName);
				var value:Int = 2;
				switch(targetName) {
					case 'boyfriend':
						value = 0;
					case 'gf':
						value = 1;
				}

				if(flValue2 == null || flValue2 <= 0) flValue2 = 0.6;

				if(target != null && rawTarget != 'both' && rawTarget.length > 0) {
					for(animCheck in ['hey', 'cheer']) {
						if(target.hasAnimation(animCheck)) {
							target.playAnim(animCheck, true);
							target.specialAnim = true;
							target.heyTimer = flValue2;
							break;
						}
					}
				}
				else if(value != 0) {
					if(dad.curCharacter.startsWith('gf')) { //Tutorial GF is actually Dad! The GF is an imposter!! ding ding ding ding ding ding ding, dindinding, end my suffering
						dad.playAnim('cheer', true);
						dad.specialAnim = true;
						dad.heyTimer = flValue2;
					} else if (gf != null) {
						gf.playAnim('cheer', true);
						gf.specialAnim = true;
						gf.heyTimer = flValue2;
					}
				}
				if(value != 1) {
					boyfriend.playAnim('hey', true);
					boyfriend.specialAnim = true;
					boyfriend.heyTimer = flValue2;
				}

			case 'Set GF Speed':
				if(flValue1 == null || flValue1 < 1) flValue1 = 1;
				gfSpeed = Math.round(flValue1);

			case 'Add Camera Zoom':
				if(flValue1 == null) flValue1 = 0.015;
				if(flValue2 == null) flValue2 = 0.03;
				addCameraZoomBop(flValue1, flValue2);

			case 'Camera Module Bop':
				applyCameraModuleBopEvent(value1, value2, values);

			case 'Modify Camera Move' | 'ModifyCameraMove': // desculpa Shiho
				applyModifyCameraMoveEvent(value1, value2, values);

			case 'Set Camera Bop' | 'SetCameraBop':
				applySetCameraBopEvent(value1, value2, values);

			case 'Play Animation' | 'PlayAnimation':
				//trace('Anim to play: ' + value1);
				if(eventName == 'PlayAnimation')
				{
					var targetName:String = value1;
					value1 = value2;
					value2 = targetName;
				}
				var forceAnim:Bool = values == null || values.length < 3 ? true : parseNullableEventBool(values[2]) != false;
				var char:Character = switch((value2 ?? '').toLowerCase().trim()) {
					case '1': boyfriend;
					case '2': gf;
					case '0': dad;
					default: getCharacterByName(value2);
				}
				if(char == null)
					char = dad;

				if (char != null)
				{
					char.playAnim(value1, forceAnim);
					char.specialAnim = true;
				}

			case 'Camera Follow Pos':
				if(camFollow != null)
				{
					isCameraOnForcedPos = false;
					if(flValue1 != null || flValue2 != null)
					{
						isCameraOnForcedPos = true;
						if(cameraMoveTween != null)
						{
							cameraMoveTween.cancel();
							cameraMoveTween = null;
						}
						cameraMoveOffsetX = 0;
						cameraMoveOffsetY = 0;
						cameraMoveReturning = false;
						if(flValue1 == null) flValue1 = 0;
						if(flValue2 == null) flValue2 = 0;
						camFollow.x = flValue1;
						camFollow.y = flValue2;
					}
				}

			case 'Focus Camera' | 'FocusCamera' | 'Change Focus' | 'ChangeFocus':
				var focus:Array<String> = parseCameraFocusEvent(value1, value2);
				changeFocus(focus[0], Std.parseFloat(focus[1]), Std.parseFloat(focus[2]), focus[3], Std.parseFloat(focus[4]));

			case 'Alt Idle Animation':
				var char:Character = switch((value1 ?? '').toLowerCase().trim()) {
					case '1': boyfriend;
					case '2': gf;
					case '0': dad;
					default: getCharacterByName(value1);
				}
				if(char == null)
					char = dad;

				if (char != null)
				{
					char.idleSuffix = value2;
					char.recalculateDanceIdle();
				}

			case 'Screen Shake':
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length) {
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0;
					var intensity:Float = 0;
					if(split[0] != null) duration = Std.parseFloat(split[0].trim());
					if(split[1] != null) intensity = Std.parseFloat(split[1].trim());
					if(Math.isNaN(duration)) duration = 0;
					if(Math.isNaN(intensity)) intensity = 0;

					if(duration > 0 && intensity != 0) {
						targetsArray[i].shake(intensity, duration);
					}
				}


			case 'Change Character':
				var target:String = normalizeCharacterTarget(value1);
				var charType:Int = switch(target) {
					case 'gf': 2;
					case 'dad': 1;
					case 'boyfriend': 0;
					default: -1;
				}

				switch(charType) {
					case 0:
						if(boyfriend.curCharacter != value2) {
							if(!boyfriendMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var lastAlpha:Float = boyfriend.alpha;
							var lastShader = boyfriend.shader;
							boyfriend.alpha = 0.00001;
							boyfriend.shader = null;
							boyfriend = boyfriendMap.get(value2);
							boyfriend.alpha = lastAlpha;
							boyfriend.shader = lastShader;
							iconP1.changeIcon(boyfriend.healthIcon);
						}
						setOnScripts('boyfriendName', boyfriend.curCharacter);

					case 1:
						if(dad.curCharacter != value2) {
							if(!dadMap.exists(value2)) {
								addCharacterToList(value2, charType);
							}

							var wasGf:Bool = dad.curCharacter.startsWith('gf-') || dad.curCharacter == 'gf';
							var lastAlpha:Float = dad.alpha;
							var lastShader = dad.shader;
							dad.alpha = 0.00001;
							dad.shader = null;
							dad = dadMap.get(value2);
							if(!dad.curCharacter.startsWith('gf-') && dad.curCharacter != 'gf') {
								if(wasGf && gf != null) {
									gf.visible = true;
								}
							} else if(gf != null) {
								gf.visible = false;
							}
							dad.alpha = lastAlpha;
							dad.shader = lastShader;
							iconP2.changeIcon(dad.healthIcon);
						}
						setOnScripts('dadName', dad.curCharacter);

					case 2:
						if(gf != null)
						{
							if(gf.curCharacter != value2)
							{
								if(!gfMap.exists(value2)) {
									addCharacterToList(value2, charType);
								}

								var lastAlpha:Float = gf.alpha;
								var lastShader = gf.shader;
								gf.alpha = 0.00001;
								gf.shader = null;
								gf = gfMap.get(value2);
								gf.alpha = lastAlpha;
								gf.shader = lastShader;
							}
							setOnScripts('gfName', gf.curCharacter);
						}
					default:
						changeExtraCharacter(target, value2);
				}
				reloadHealthBarColors();

			case 'Set Health Icon' | 'SetHealthIcon':
				applySetHealthIconEvent(value1, value2, values);

			case 'Change Scroll Speed':
				if (songSpeedType != "constant")
				{
					if(flValue1 == null) flValue1 = 1;
					if(flValue2 == null) flValue2 = 0;

					var newValue:Float = SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed') * flValue1;
					cancelSongSpeedTween();
					if(flValue2 <= 0)
						songSpeed = newValue;
					else
						songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, flValue2 / playbackRate, {ease: FlxEase.linear, onComplete:
							function (twn:FlxTween)
							{
								if(songSpeedTween == twn)
									songSpeedTween = null;
							}
						});
				}

			case 'Change Scroll Speed GOOD':
				if (songSpeedType != "constant")
					{
						if(flValue1 == null) flValue1 = 1;
						if(flValue2 == null) flValue2 = 0;

						var newValue:Float = flValue1;

						cancelSongSpeedTween();
						if(flValue2 <= 0)
						{
							songSpeed = newValue;
						}
						else
						{
							songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, flValue2 / playbackRate, {
								ease: FlxEase.linear,
								onComplete: function (twn:FlxTween)
								{
									if(songSpeedTween == twn)
										songSpeedTween = null;
								}
							});
						}
					}

			case 'Camera Zoom':
				applyCameraZoomEvent(value1, value2);

			case 'Camera Angle' | 'Camera Rotate' | 'Camera Rotation':
				var angleData:Array<String> = splitCameraEventValues(value1);
				var tweenData:Array<String> = splitCameraEventValues(value2);
				var cameraName:String = angleData[0] ?? 'game';
				var angle:Float = Std.parseFloat(angleData[1] ?? '0');
				var mode:String = angleData[2] ?? 'set';
				var ease:String = tweenData[0] ?? angleData[3] ?? 'instant';
				var steps:Float = Std.parseFloat(tweenData[1] ?? angleData[4] ?? '0');
				var rotateSprite:Null<Bool> = null;

				if(values != null && values.length > 2)
					rotateSprite = parseNullableEventBool(values[2]);

				applyCameraAngleEvent(cameraName, angle, mode, ease, steps, rotateSprite);

			case 'Set Property':
				try {
					var set:Dynamic = value2.trim();
					
					if (set == 'true' || set == 'false') {
						set = (set == 'true');
					} else if (flValue2 != null) {
						set = flValue2;
					} else {
						set = value2;
					}
					
					LuaUtils.setPropertyLoop(value1, set, false, this);
				} catch(e:haxe.Exception) {
					var mes:String = e.message;
					if (mes.indexOf('\n') >= 0) mes = mes.substr(0, mes.indexOf('\n'));
					
					var message:String = 'Set Property Event: $mes';
					
					#if (SCRIPTS_ALLOWED)
					Log.print(message, ERROR);
					#else
					FlxG.log.warn(message);
					#end
				}

			case 'Play Sound':
				if(flValue2 == null) flValue2 = 1;
				FlxG.sound.play(Paths.sound(value1), flValue2);
		}

		stagesFunc(function(stage:BaseStage) stage.eventCalled(eventName, value1, value2, flValue1, flValue2, strumTime));
		callOnScripts('onEvent', buildEventCallbackArgs(eventName, value1, value2, strumTime, values));
	}

	function resetScriptedCameraBop(blockDefault:Bool = false):Void
	{
		scriptedCameraBopActive = false;
		scriptedCameraBopBlocksDefault = blockDefault;
		scriptedCameraBopRate = 4;
		scriptedCameraBopOffset = 0;
		scriptedCameraBopIntensity = 1;
		scriptedCameraBopUnit = 'beat';
		scriptedCameraBopGame = 0.015;
		scriptedCameraBopHUD = 0.03;
		scriptedCameraBopPattern = null;
	}

	function applySetCameraBopEvent(value1:String, value2:String, ?values:Array<String>):Void
	{
		var hasValues:Bool = false;
		if(values != null)
		{
			for(value in values)
			{
				if(value != null && value.trim().length > 0)
				{
					hasValues = true;
					break;
				}
			}
		}
		else
			hasValues = (value1 != null && value1.trim().length > 0) || (value2 != null && value2.trim().length > 0);

		if(!hasValues)
		{
			resetScriptedCameraBop();
			return;
		}

		scriptedCameraBopIntensity = parseEventFloat(values, 0, value1, 1);
		scriptedCameraBopRate = parseEventFloat(values, 1, value2, 4);
		scriptedCameraBopOffset = parseEventFloat(values, 2, null, 0);
		if(Math.isNaN(scriptedCameraBopIntensity)) scriptedCameraBopIntensity = 1;
		if(Math.isNaN(scriptedCameraBopRate) || scriptedCameraBopRate < 0) scriptedCameraBopRate = 0;
		if(Math.isNaN(scriptedCameraBopOffset)) scriptedCameraBopOffset = 0;
		scriptedCameraBopUnit = 'beat';
		scriptedCameraBopGame = 0.015;
		scriptedCameraBopHUD = 0.03;
		scriptedCameraBopPattern = null;
		scriptedCameraBopActive = scriptedCameraBopRate > 0 && scriptedCameraBopIntensity != 0;
		scriptedCameraBopBlocksDefault = scriptedCameraBopActive;
	}

	function applyCameraModuleBopEvent(value1:String, value2:String, ?values:Array<String>):Void
	{
		var timingValue:String = getEventValue(values, 0, value1);
		var zoomValue:String = getEventValue(values, 1, value2);

		if(zoomValue == null || zoomValue.trim().length < 1)
		{
			resetScriptedCameraBop();
			return;
		}
		if(isCameraBopDisableValue(zoomValue))
		{
			resetScriptedCameraBop(true);
			return;
		}

		var timing:Array<String> = splitCameraEventValues(timingValue);
		var zoom:Array<String> = splitCameraEventValues(zoomValue);

		scriptedCameraBopRate = parseFloatOr(timing.length > 0 ? timing[0] : null, 1);
		if(Math.isNaN(scriptedCameraBopRate) || scriptedCameraBopRate <= 0)
			scriptedCameraBopRate = 1;

		scriptedCameraBopUnit = normalizeCameraBopUnit(timing.length > 1 ? timing[1] : 'beat');
		scriptedCameraBopOffset = 0;
		scriptedCameraBopIntensity = 1;
		scriptedCameraBopGame = parseFloatOr(zoom.length > 0 ? zoom[0] : null, 0);
		scriptedCameraBopHUD = parseFloatOr(zoom.length > 1 ? zoom[1] : null, 0);
		scriptedCameraBopPattern = null;

		if(timing.length > 2)
		{
			var mode:String = (timing[2] ?? '').toLowerCase().trim();
			if(isCameraBopPatternValue(timing[2]) || mode == 'pattern' || mode == 'patterns' || mode == 'inconsistent' || mode == 'irregular')
				scriptedCameraBopPattern = parseCameraBopPattern(isCameraBopPatternValue(timing[2]) ? timing[2] : (timing.length > 3 ? timing[3] : ''));
			else
				scriptedCameraBopOffset = parseFloatOr(timing[2], 0);
		}

		if(timing.length > 4)
			scriptedCameraBopOffset = parseFloatOr(timing[4], scriptedCameraBopOffset);

		if(Math.isNaN(scriptedCameraBopGame)) scriptedCameraBopGame = 0;
		if(Math.isNaN(scriptedCameraBopHUD)) scriptedCameraBopHUD = 0;
		if(Math.isNaN(scriptedCameraBopOffset)) scriptedCameraBopOffset = 0;

		scriptedCameraBopActive = scriptedCameraBopRate > 0 && (scriptedCameraBopGame != 0 || scriptedCameraBopHUD != 0);
		scriptedCameraBopBlocksDefault = true;
		if(scriptedCameraBopPattern != null && scriptedCameraBopPattern.length < 1)
			scriptedCameraBopActive = false;
	}

	function applyModifyCameraMoveEvent(value1:String, value2:String, ?values:Array<String>):Void
	{
		var data:Array<String> = [];
		if(values != null && values.length > 2)
		{
			for(raw in values)
			{
				var parts:Array<String> = splitCameraEventValues(raw);
				if(parts.length > 1)
				{
					for(part in parts)
						data.push(part);
				}
				else
					data.push(raw != null ? raw : '');
			}
		}
		else
		{
			var rawValues:Array<String> = [value1, value2];
			for(raw in rawValues)
			{
				var parts:Array<String> = splitCameraEventValues(raw);
				for(part in parts)
					data.push(part);
			}
		}
		while(data.length < 4)
			data.push('');

		var enabled:Null<Bool> = parseNullableEventBool(data[0]);
		if(enabled == null)
		{
			for(i in 1...data.length)
			{
				enabled = parseCameraMoveToggleKeyword(data[i]);
				if(enabled != null)
				{
					data[i] = '';
					break;
				}
			}
		}
		var intensity:Null<Float> = parseOptionalEventFloat(data[1]);
		var speed:Null<Float> = parseOptionalEventFloat(data[2]);
		var offset:Null<Float> = parseOptionalEventFloat(data[3]);

		if(intensity != null)
			cameraMoveIntensity = intensity;
		if(speed != null)
			cameraMoveSpeed = Math.max(0, speed);
		if(offset != null)
			cameraMoveOffset = Math.max(0, offset);
		if(enabled != null)
			cameraMoveEnabled = enabled;
		if(enabled == true)
			cameraMoveReturning = false;

		if(Math.isNaN(cameraMoveIntensity))
			cameraMoveIntensity = 1;
		if(Math.isNaN(cameraMoveSpeed) || cameraMoveSpeed < 0)
			cameraMoveSpeed = 1;
		if(Math.isNaN(cameraMoveOffset) || cameraMoveOffset < 0)
			cameraMoveOffset = 30;

		setOnScripts('cameraMoveEnabled', cameraMoveEnabled);
		setOnScripts('cameraMoveIntensity', cameraMoveIntensity);
		setOnScripts('cameraMoveSpeed', cameraMoveSpeed);
		setOnScripts('cameraMoveOffset', cameraMoveOffset);

		if((!cameraMoveEnabled || cameraMoveIntensity == 0 || cameraMoveOffset == 0) && (cameraMoveOffsetX != 0 || cameraMoveOffsetY != 0 || cameraMoveTween != null))
			setCameraMoveTarget(0, 0);
	}

	function parseCameraMoveToggleKeyword(value:String):Null<Bool>
	{
		if(value == null)
			return null;

		return switch(value.toLowerCase().trim())
		{
			case 'on' | 'enable' | 'enabled' | 'true' | 'yes' | 'y':
				true;
			case 'off' | 'disable' | 'disabled' | 'false' | 'no' | 'n':
				false;
			default:
				null;
		}
	}

	function applySetHealthIconEvent(value1:String, value2:String, ?values:Array<String>):Void
	{
		var target:String = getEventValue(values, 0, value1);
		var icon:String = getEventValue(values, 1, value2);
		if(icon == null || icon.trim().length < 1)
			return;

		switch((target ?? '0').toLowerCase().trim())
		{
			case '0' | 'bf' | 'boyfriend' | 'player':
				iconP1?.changeIcon(icon);
			case '1' | 'dad' | 'opponent':
				iconP2?.changeIcon(icon);
		}
	}

	function getEventValue(?values:Array<String>, index:Int = 0, fallback:String = null):String
	{
		if(values != null && index >= 0 && index < values.length && values[index] != null)
			return values[index];
		return fallback;
	}

	function parseEventFloat(?values:Array<String>, index:Int = 0, fallbackValue:String = null, fallback:Float = 0):Float
	{
		var raw:String = getEventValue(values, index, fallbackValue);
		return parseFloatOr(raw, fallback);
	}

	function parseFloatOr(value:String, fallback:Float = 0):Float
	{
		var parsed:Float = Std.parseFloat(value ?? '');
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	function parseOptionalEventFloat(value:String):Null<Float>
	{
		if(isEventKeepValue(value))
			return null;

		var parsed:Float = Std.parseFloat(value);
		return Math.isNaN(parsed) ? null : parsed;
	}

	function isEventKeepValue(value:String):Bool
	{
		if(value == null)
			return true;

		return switch(value.toLowerCase().trim())
		{
			case '' | 'keep' | 'same' | 'unchanged' | '-':
				true;
			default:
				false;
		}
	}

	function normalizeCameraBopUnit(unit:String):String
	{
		return switch((unit ?? '').toLowerCase().trim())
		{
			case 'step' | 'steps' | 's':
				'step';
			default:
				'beat';
		}
	}

	function isCameraBopPatternValue(value:String):Bool
	{
		if(value == null)
			return false;

		var raw:String = value.trim();
		return (raw.startsWith('{') && raw.endsWith('}')) || (raw.startsWith('[') && raw.endsWith(']'));
	}

	function isCameraBopDisableValue(value:String):Bool
	{
		if(value == null)
			return false;

		var raw:String = value.toLowerCase().trim();
		return switch(raw)
		{
			case 'off' | 'disable' | 'disabled' | 'false' | 'no' | 'none':
				true;
			default:
				false;
		}
	}

	function parseCameraBopPattern(value:String):Array<Int>
	{
		var pattern:Array<Int> = [];
		if(value == null)
			return pattern;

		var raw:String = value.trim();
		for(chars in ['{', '}', '[', ']'])
			raw = raw.replace(chars, ' ');

		var splitter:EReg = ~/[,\s;|]+/g;
		for(part in splitter.split(raw))
		{
			var parsed:Null<Int> = Std.parseInt(part.trim());
			if(parsed != null && !pattern.contains(parsed))
				pattern.push(parsed);
		}
		return pattern;
	}

	function buildEventCallbackArgs(eventName:String, value1:String, value2:String, strumTime:Float, ?values:Array<String>):Array<Dynamic>
	{
		var args:Array<Dynamic> = [eventName];
		if(values != null)
		{
			for(value in values)
				args.push(value != null ? value : '');
		}
		else
		{
			args.push(value1 != null ? value1 : '');
			args.push(value2 != null ? value2 : '');
		}
		return args;
	}

	function parseNullableEventBool(value:String):Null<Bool> {
		if(value == null) return null;

		return switch(value.toLowerCase().trim())
		{
			case 'true' | '1' | 'yes' | 'y' | 'on' | 'enable' | 'enabled':
				true;
			case 'false' | '0' | 'no' | 'n' | 'off' | 'disable' | 'disabled':
				false;
			default:
				null;
		}
	}

	function applyCameraAngleEvent(cameraName:String, angle:Float, mode:String, ease:String, steps:Float, rotateSprite:Null<Bool>):Void {
		if(cameraName == null || cameraName.trim().length < 1)
			cameraName = 'game';
		if(Math.isNaN(angle))
			angle = 0;
		if(Math.isNaN(steps) || steps < 0)
			steps = 0;
		if(mode == null || mode.trim().length < 1)
			mode = 'set';
		if(ease == null || ease.trim().length < 1)
			ease = 'instant';

		var camera:FlxCamera = LuaUtils.cameraFromString(cameraName.trim());
		if(camera == null) return;

		if(rotateSprite != null && Std.isOfType(camera, backend.PsychCamera))
			cast(camera, backend.PsychCamera).rotateSprite = rotateSprite;

		var targetAngle:Float = angle;
		switch(mode.toLowerCase().trim())
		{
			case 'add' | 'relative' | 'mr' | '+':
				targetAngle = camera.angle + angle;
			case 'subtract' | 'sub' | 'lss' | '-':
				targetAngle = camera.angle - angle;
			case 'reset' | 'zero':
				targetAngle = 0;
			default:
				targetAngle = angle;
		}

		var oldTween:FlxTween = cameraAngleTweens.get(camera);
		if(oldTween != null)
		{
			oldTween.cancel();
			cameraAngleTweens.remove(camera);
		}

		var easeMode:String = ease.toLowerCase().trim();
		if(steps <= 0 || easeMode == 'instant' || easeMode == 'classic' || easeMode == 'og')
		{
			camera.angle = targetAngle;
			return;
		}

		var duration:Float = (steps * Conductor.stepCrochet / 1000) / playbackRate;
		var tween:FlxTween = FlxTween.tween(camera, {angle: targetAngle}, duration, {
			ease: getCameraZoomEase(easeMode),
			onComplete: function(twn:FlxTween)
			{
				if(cameraAngleTweens.get(camera) == twn)
					cameraAngleTweens.remove(camera);
			}
		});
		cameraAngleTweens.set(camera, tween);
	}

	function parseCameraFocusEvent(value1:String, value2:String):Array<String> {
		var targetData:Array<String> = splitCameraEventValues(value1);
		var easeData:Array<String> = splitCameraEventValues(value2);

		var target:String = targetData[0] ?? 'dad';
		var x:String = targetData[1] ?? '0';
		var y:String = targetData[2] ?? '0';
		var ease:String = easeData[0] ?? targetData[3] ?? 'classic';
		var steps:String = easeData[1] ?? targetData[4] ?? '0';
		if(easeData.length > 1 && isNumericString(easeData[0]) && !isNumericString(easeData[1]))
		{
			steps = easeData[0];
			ease = easeData[1];
		}

		return [target, x, y, ease, steps];
	}

	function splitCameraEventValues(value:String):Array<String> {
		if(value == null || value.length < 1)
			return [];

		var values:Array<String> = [];
		var current:String = '';
		var depth:Int = 0;
		for(i in 0...value.length)
		{
			var char:String = value.charAt(i);
			switch(char)
			{
				case '{' | '[' | '(':
					depth++;
					current += char;
				case '}' | ']' | ')':
					depth = Std.int(Math.max(0, depth - 1));
					current += char;
				case ',':
					if(depth <= 0)
					{
						values.push(current.trim());
						current = '';
					}
					else
						current += char;
				default:
					current += char;
			}
		}
		values.push(current.trim());

		return values;
	}

	function isNumericString(value:String):Bool
	{
		if(value == null || value.trim().length < 1)
			return false;

		var parsed:Float = Std.parseFloat(value);
		return !Math.isNaN(parsed);
	}

	public function moveCameraSection(?sec:Null<Int>):Void {
		if (sec == null) sec = curSection;
		if (sec < 0) sec = 0;

		if (SONG.notes[sec] == null) return;

		if (gf != null && SONG.notes[sec].gfSection) {
			moveCameraToGirlfriend();
		} else {
			moveCamera(SONG.notes[sec].mustHitSection != true);
		}
	}
	
	/**
	 * Focuses the camera on `gf`.
	*/
	public function moveCameraToGirlfriend() {
		changeFocus('gf');
	}
	
	/**
	 * Focuses the camera on a character.
	 * 
	 * @param 	isDad 	If the camera should be focused on the opponent character.
	 * @param 	isGf 	If the camera should be focused on the speakers (middle) character.
	*/
	public function moveCamera(isDad:Bool, isGf:Bool = false) {
		changeFocus(isGf ? 'gf' : (isDad ? 'dad' : 'bf'));
	}

	function loadCameraMoveData():Void
	{
		var data:Dynamic = Song.ensureCameraMoveData(SONG);
		cameraMoveEnabled = data != null && data.enabled == true;
		cameraMoveIntensity = data != null ? data.intensity : 1;
		cameraMoveSpeed = data != null ? data.speed : 1;
		cameraMoveOffset = data != null ? data.offset : 30;

		if(Math.isNaN(cameraMoveIntensity)) cameraMoveIntensity = 1;
		if(Math.isNaN(cameraMoveSpeed) || cameraMoveSpeed < 0) cameraMoveSpeed = 1;
		if(Math.isNaN(cameraMoveOffset) || cameraMoveOffset < 0) cameraMoveOffset = 30;
	}

	public function changeFocus(target:String, ?x:Float = 0, ?y:Float = 0, ?ease:String = 'classic', ?steps:Float = 0):Void {
		if(camFollow == null) return;
		if(Math.isNaN(x)) x = 0;
		if(Math.isNaN(y)) y = 0;
		if(Math.isNaN(steps)) steps = 0;

		var character:String = normalizeCameraTarget(target);
		var focusChanged:Bool = (character != cameraFocus);
		var point:FlxPoint = getCameraFocusPoint(character, x, y);
		if(point == null) return;

		if(cameraFocusTween != null)
		{
			cameraFocusTween.cancel();
			cameraFocusTween = null;
		}
		if(focusChanged && cameraMoveTween != null)
		{
			cameraMoveTween.cancel();
			cameraMoveTween = null;
		}

		var startX:Float = camFollow.x;
		var startY:Float = camFollow.y;

		cameraFocus = character;
		cameraFocusOffsetX = x;
		cameraFocusOffsetY = y;
		if(focusChanged)
		{
			cameraMoveOffsetX = 0;
			cameraMoveOffsetY = 0;
			cameraMoveReturning = false;
		}
		isCameraOnForcedPos = false;
		setOnScripts('cameraFocus', character);
		setOnScripts('cameraFocusOffsetX', x);
		setOnScripts('cameraFocusOffsetY', y);

		camFollow.setPosition(point.x, point.y);
		point.put();

		stagesFunc((stage:BaseStage) -> stage.onMoveCamera(character));
		callOnScripts('onMoveCamera', [character]);

		cameraFocusBaseX = camFollow.x;
		cameraFocusBaseY = camFollow.y;
		var targetX:Float = cameraFocusBaseX + cameraMoveOffsetX;
		var targetY:Float = cameraFocusBaseY + cameraMoveOffsetY;
		var easeMode:String = normalizeCameraEase(ease);

		switch(easeMode)
		{
			case 'instant':
				camFollow.setPosition(targetX, targetY);
				FlxG.camera.snapToTarget();

			case 'classic':
				camFollow.setPosition(targetX, targetY);
				if(cameraSpeed <= 0)
					FlxG.camera.snapToTarget();

			default:
				if(steps <= 0)
				{
					camFollow.setPosition(targetX, targetY);
					if(cameraSpeed <= 0)
						FlxG.camera.snapToTarget();
					return;
				}

				camFollow.setPosition(startX, startY);
				cameraFocusTween = FlxTween.tween(camFollow, {x: targetX, y: targetY}, (steps * Conductor.stepCrochet / 1000) / playbackRate, {
					ease: LuaUtils.getTweenEaseByString(easeMode),
					onUpdate: (_) -> if(cameraSpeed <= 0) FlxG.camera.snapToTarget(),
					onComplete: (_) ->
					{
						if(cameraSpeed <= 0)
							FlxG.camera.snapToTarget();
						cameraFocusTween = null;
					}
				});
		}
	}

	function normalizeCameraTarget(target:String):String {
		var normalized:String = normalizeCharacterTarget(target);
		return switch(normalized)
		{
			case '-1' | 'position' | 'pos':
				'position';
			case 'boyfriend':
				'boyfriend';
			case 'gf':
				'gf';
			case 'dad':
				'dad';
			default:
				normalized;
		}
	}

	function normalizeCameraEase(ease:String):String {
		if(ease == null || ease.trim().length < 1) return 'classic';

		return switch(ease.toLowerCase().trim())
		{
			case 'classic' | 'og':
				'classic';
			case 'instant' | 'inst':
				'instant';
			default:
				ease;
		}
	}

	function getCameraFocusPoint(character:String, ?x:Float = 0, ?y:Float = 0):FlxPoint {
		var point:FlxPoint = FlxPoint.get();

		switch(character)
		{
			case 'position':
				point.set(0, 0);

			case 'gf':
				if(gf == null)
				{
					point.put();
					return null;
				}

				point.set(gf.getMidpoint().x, gf.getMidpoint().y);
				point.x += gf.cameraPosition[0] + girlfriendCameraOffset[0];
				point.y += gf.cameraPosition[1] + girlfriendCameraOffset[1];

			case 'dad':
				if(dad == null)
				{
					point.put();
					return null;
				}

				point.set(dad.getMidpoint().x + 150, dad.getMidpoint().y - 100);
				point.x += dad.cameraPosition[0] + opponentCameraOffset[0];
				point.y += dad.cameraPosition[1] + opponentCameraOffset[1];

			case 'boyfriend':
				if(boyfriend == null)
				{
					point.put();
					return null;
				}

				point.set(boyfriend.getMidpoint().x - 100, boyfriend.getMidpoint().y - 100);
				point.x -= boyfriend.cameraPosition[0] - boyfriendCameraOffset[0];
				point.y += boyfriend.cameraPosition[1] + boyfriendCameraOffset[1];

			default:
				var characterObj:Character = extraCharacterMap.get(character);
				if(characterObj == null)
				{
					point.put();
					return null;
				}

				point.set(characterObj.getMidpoint().x, characterObj.getMidpoint().y);
				point.x += characterObj.cameraPosition[0];
				point.y += characterObj.cameraPosition[1];
		}

		point.x += x;
		point.y += y;
		return point;
	}

	function getCameraFocusCharacter():Character
	{
		return switch(cameraFocus)
		{
			case 'gf': gf;
			case 'boyfriend': boyfriend;
			case 'dad': dad;
			default: extraCharacterMap.get(cameraFocus);
		}
	}

	function cameraTargetFromCharacter(character:Character):String
	{
		if(character == null) return null;
		if(character == boyfriend) return 'boyfriend';
		if(character == gf) return 'gf';
		if(character == dad) return 'dad';
		for(tag => extraCharacter in extraCharacterMap)
			if(character == extraCharacter)
				return tag;
		return null;
	}

	function getCameraMoveDuration():Float
	{
		if(cameraMoveSpeed <= 0) return 0;
		return (Conductor.stepCrochet / 1000) / cameraMoveSpeed / playbackRate;
	}

	function setCameraMoveTarget(x:Float, y:Float):Void
	{
		if(camFollow == null) return;
		if(cameraFocusTween != null)
		{
			cameraFocusTween.cancel();
			cameraFocusTween = null;
		}
		if(cameraMoveTween != null)
		{
			cameraMoveTween.cancel();
			cameraMoveTween = null;
		}

		cameraMoveReturning = (x == 0 && y == 0);
		var duration:Float = getCameraMoveDuration();
		if(duration <= 0)
		{
			cameraMoveOffsetX = x;
			cameraMoveOffsetY = y;
			cameraMoveReturning = false;
			refreshCameraMovePosition();
			return;
		}

		cameraMoveTween = FlxTween.tween(this, {cameraMoveOffsetX: x, cameraMoveOffsetY: y}, duration, {
			ease: FlxEase.quadOut,
			onUpdate: (_) -> refreshCameraMovePosition(),
			onComplete: (_) ->
			{
				cameraMoveOffsetX = x;
				cameraMoveOffsetY = y;
				cameraMoveReturning = false;
				cameraMoveTween = null;
				refreshCameraMovePosition();
			}
		});
	}

	function refreshCameraMovePosition():Void
	{
		if(camFollow == null || isCameraOnForcedPos) return;
		camFollow.setPosition(cameraFocusBaseX + cameraMoveOffsetX, cameraFocusBaseY + cameraMoveOffsetY);
	}

	function applyCameraMove(note:Note, character:Character):Void
	{
		if(!cameraMoveEnabled || note == null || character == null || note.isSustainNote || isCameraOnForcedPos) return;
		if(cameraTargetFromCharacter(character) != cameraFocus) return;

		var amount:Float = cameraMoveOffset * cameraMoveIntensity;
		if(amount == 0) return;

		var x:Float = 0;
		var y:Float = 0;
		switch(Std.int(Math.abs(note.noteData)) % 4)
		{
			case 0: x = -amount;
			case 1: y = amount;
			case 2: y = -amount;
			case 3: x = amount;
		}

		setCameraMoveTarget(x, y);
	}

	function resetCameraMoveForCharacter(character:Character):Void
	{
		if(!cameraMoveEnabled || character == null || cameraMoveReturning) return;
		if(cameraMoveOffsetX == 0 && cameraMoveOffsetY == 0) return;
		if(cameraTargetFromCharacter(character) != cameraFocus) return;

		setCameraMoveTarget(0, 0);
	}

	function updateCameraMoveIdleReset():Void
	{
		if(!cameraMoveEnabled || cameraMoveReturning || (cameraMoveOffsetX == 0 && cameraMoveOffsetY == 0)) return;

		var character:Character = getCameraFocusCharacter();
		if(character == null) return;

		var anim:String = character.getAnimationName();
		if(anim != null && (anim.startsWith('idle') || anim.startsWith('danceLeft') || anim.startsWith('danceRight')))
			resetCameraMoveForCharacter(character);
	}

	/**
	 * Finishes the song.
	 * 
	 * @param 	ignoreNoteOffset 	Whether or not to ignore the note delay.
	*/
	public function finishSong(?ignoreNoteOffset:Bool = false):Void
	{
		updateTime = false;
		FlxG.sound.music.volume = 0;

		vocals.volume = 0;
		vocals.pause();
		opponentVocals.volume = 0;
		opponentVocals.pause();

		if(ClientPrefs.data.noteOffset <= 0 || ignoreNoteOffset) {
			endCallback();
		} else {
			finishTimer = new FlxTimer().start(ClientPrefs.data.noteOffset / 1000, function(tmr:FlxTimer) {
				endCallback();
			});
		}
	}
	
	public var transitioning = false;
	public function endSong()
	{
		//Should kill you if you tried to cheat
		if(!startingSong)
		{
			notes.forEachAlive(function(daNote:Note)
			{
				if(daNote.strumTime < songLength - Conductor.safeZoneOffset)
					health -= 0.05 * healthLoss;
			});
			for (daNote in unspawnNotes)
			{
				if(daNote != null && daNote.strumTime < songLength - Conductor.safeZoneOffset)
					health -= 0.05 * healthLoss;
			}

			if(doDeathCheck()) {
				return false;
			}
		}

		timeBar.visible = false;
		timeTxt.visible = false;
		canPause = false;
		endingSong = true;
		camZooming = false;
		inCutscene = false;
		updateTime = false;

		deathCounter = 0;
		seenCutscene = false;

		#if ACHIEVEMENTS_ALLOWED
		var weekNoMiss:String = WeekData.getWeekFileName() + '_nomiss';
		checkForAchievement([weekNoMiss, 'ur_bad', 'ur_good', 'hype', 'two_keys', 'toastie', 'debugger']);
		#end

		var ret:Dynamic = callOnScripts('onEndSong', null, true);
		if(ret != LuaUtils.Function_Stop && !transitioning)
		{
			#if !switch
			var percent:Float = ratingPercent;
			if(Math.isNaN(percent)) percent = 0;
			Highscore.saveScore(Song.loadedSongName, songScore, storyDifficulty, percent);
			#end
			playbackRate = 1;

			if (chartingMode)
			{
				openChartEditor();
				return false;
			}

			if (isStoryMode)
			{
				campaignScore += songScore;
				campaignMisses += songMisses;

				storyPlaylist.remove(storyPlaylist[0]);

				if (storyPlaylist.length <= 0)
				{
					Mods.loadTopMod();
					FlxG.sound.playMusic(Paths.menuMusic('mainMenu'));
					#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end

					canResync = false;
					if (Mods.modUsesStickerTrans()) {
						openSubState(new StickerSubState(null, (sticker) -> new StoryMenuState(sticker)));
					} else {
						MusicBeatState.switchState(new StoryMenuState());
						FlxG.sound.playMusic(Paths.menuMusic('mainMenu'));
					}

					// if ()
					if(!ClientPrefs.getGameplaySetting('practice') && !ClientPrefs.getGameplaySetting('botplay')) {
						StoryMenuState.weekCompleted.set(WeekData.weeksList[storyWeek], true);
						Highscore.saveWeekScore(WeekData.getWeekFileName(), campaignScore, storyDifficulty);
					}
					changedDifficulty = false;
				}
				else
				{
					var nextSong:String = Paths.formatToSongPath(PlayState.storyPlaylist[0]);
					var difficulty:String = Highscore.formatSong(nextSong, storyDifficulty);
					
					trace('LOADING NEXT SONG');
					trace('$nextSong/$difficulty');

					FlxTransitionableState.skipNextTransIn = true;
					FlxTransitionableState.skipNextTransOut = true;
					prevCamFollow = camFollow;

					Song.loadFromJson(difficulty, nextSong);
					FlxG.sound.music.stop();

					canResync = false;
					LoadingState.prepareToSong();
					LoadingState.loadAndSwitchState(new PlayState(), false, false);
				}
			}
			else
			{
				trace('WENT BACK TO FREEPLAY??');
				Mods.loadTopMod();
				#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end

				canResync = false;
				if (Mods.modUsesStickerTrans()) {
					openSubState(new StickerSubState(null, (sticker) -> new FreeplayState(sticker)));
				} else {
					MusicBeatState.switchState(new FreeplayState());
					FlxG.sound.playMusic(Paths.menuMusic('mainMenu'));
				}
				changedDifficulty = false;
			}
			transitioning = true;
		}
		
		Highscore.saveScores();
		FlxG.save.flush();
		
		return true;
	}
	
	public function KillNotes() {
		while(notes.length > 0) {
			var daNote:Note = notes.members[0];
			daNote.active = false;
			daNote.visible = false;
			invalidateNote(daNote);
		}
		unspawnNotes = [];
		eventNotes = [];
	}
	
	/**
	 * The total amount of notes hit or missed since the start of the song.
	*/
	public var totalPlayed:Int = 0;
	/**
	 * The rating factor for all notes hit since the start of the song.
	*/
	public var totalNotesHit:Float = 0.0;

	/**
	 * Whether the combo graphic should be shown on combo pop-ups.
	*/
	public var showCombo:Bool = false;
	/**
	 * Whether the combo numbers should be shown on combo pop-ups.
	*/
	public var showComboNum:Bool = true;
	/**
	 * Whether the rating graphic should be shown on combo pop-ups.
	*/
	public var showRating:Bool = true;

	// Stores Ratings and Combo Sprites in a group
	/**
	 * Group containing the combo sprites.
	*/
	public var comboGroup:FlxSpriteGroup;
	// Stores HUD Objects in a Group
	/**
	 * Group containing the UI sprites.
	*/
	public var uiGroup:FlxSpriteGroup;
	// Stores Note Objects in a Group
	/**
	 * Group containing the notes sprites, including the strumlines.
	*/
	public var noteGroup:FlxTypedGroup<FlxBasic>;

	@:dox(hide) private function cachePopUpScore()
	{
		for (rating in ratingsData)
			Paths.image(formatUI(rating.image));
		for (i in 0...10)
			Paths.image(formatUI('num$i'));
	}

	private function popUpScore(note:Note = null):Void
	{
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.data.ratingOffset);
		vocals.volume = 1;

		if (!ClientPrefs.data.comboStacking && comboGroup.members.length > 0)
		{
			for (spr in comboGroup)
			{
				if(spr == null) continue;

				comboGroup.remove(spr);
				spr.destroy();
			}
		}

		var placement:Float = FlxG.width * 0.35;
		var rating:FlxSprite = new FlxSprite();
		var score:Int = 350;

		//tryna do MS based judgment due to popular demand
		var daRating:Rating = Conductor.judgeNote(ratingsData, noteDiff / playbackRate);

		totalNotesHit += daRating.ratingMod;
		note.ratingMod = daRating.ratingMod;
		if(!note.ratingDisabled) daRating.hits++;
		note.rating = daRating.name;
		score = daRating.score;

		if (daRating.noteSplash && !note.noteSplashData.disabled)
			note.noteSplash = spawnNoteSplashOnNote(note);

		if(!cpuControlled) {
			songScore += score;
			if(!note.ratingDisabled)
			{
				songHits++;
				totalPlayed++;
				RecalculateRating(false);
			}
		}

		var antialias:Bool = (ClientPrefs.data.antialiasing && !isPixelStage);

		rating.loadGraphic(Paths.image(formatUI(daRating.image)));
		rating.screenCenter();
		rating.x = placement - 40;
		rating.y -= 60;
		rating.acceleration.y = 550 * playbackRate * playbackRate;
		rating.velocity.y -= FlxG.random.int(140, 175) * playbackRate;
		rating.velocity.x -= FlxG.random.int(0, 10) * playbackRate;
		rating.visible = (!ClientPrefs.data.hideHud && showRating);
		rating.x += ClientPrefs.data.comboOffset[0];
		rating.y -= ClientPrefs.data.comboOffset[1];
		rating.antialiasing = antialias;

		var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(formatUI('combo')));
		comboSpr.screenCenter();
		comboSpr.x = placement;
		comboSpr.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
		comboSpr.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
		comboSpr.visible = (!ClientPrefs.data.hideHud && showCombo);
		comboSpr.x += ClientPrefs.data.comboOffset[0];
		comboSpr.y -= ClientPrefs.data.comboOffset[1];
		comboSpr.antialiasing = antialias;
		comboSpr.y += 60;
		comboSpr.velocity.x += FlxG.random.int(1, 10) * playbackRate;
		comboGroup.add(rating);

		if (!PlayState.isPixelStage)
		{
			rating.setGraphicSize(Std.int(rating.width * 0.7));
			comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.7));
		}
		else
		{
			rating.setGraphicSize(Std.int(rating.width * daPixelZoom * 0.85));
			comboSpr.setGraphicSize(Std.int(comboSpr.width * daPixelZoom * 0.85));
		}

		comboSpr.updateHitbox();
		rating.updateHitbox();
		if(daRating.name == 'neat')
			bumpRatingSprite(rating, playbackRate);

		var daLoop:Int = 0;
		var xThing:Float = 0;
		if (showCombo)
			comboGroup.add(comboSpr);

		var separatedScore:String = Std.string(combo).lpad('0', 3);
		for (i in 0...separatedScore.length)
		{
			var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.image(formatUI('num${separatedScore.charAt(i)}')));
			numScore.screenCenter();
			numScore.x = placement + (43 * daLoop) - 90 + ClientPrefs.data.comboOffset[2];
			numScore.y += 80 - ClientPrefs.data.comboOffset[3];

			if (!PlayState.isPixelStage) numScore.setGraphicSize(Std.int(numScore.width * 0.5));
			else numScore.setGraphicSize(Std.int(numScore.width * daPixelZoom));
			numScore.updateHitbox();

			numScore.acceleration.y = FlxG.random.int(200, 300) * playbackRate * playbackRate;
			numScore.velocity.y -= FlxG.random.int(140, 160) * playbackRate;
			numScore.velocity.x = FlxG.random.float(-5, 5) * playbackRate;
			numScore.visible = !ClientPrefs.data.hideHud;
			numScore.antialiasing = antialias;

			//if (combo >= 10 || combo == 0)
			if(showComboNum)
				comboGroup.add(numScore);

			FlxTween.tween(numScore, {alpha: 0}, 0.2 / playbackRate, {
				onComplete: function(tween:FlxTween)
				{
					numScore.destroy();
				},
				startDelay: Conductor.crochet * 0.002 / playbackRate
			});

			daLoop++;
			if(numScore.x > xThing) xThing = numScore.x;
		}
		comboSpr.x = xThing + 50;
		FlxTween.tween(rating, {alpha: 0}, 0.2 / playbackRate, {
			startDelay: Conductor.crochet * 0.001 / playbackRate
		});

		FlxTween.tween(comboSpr, {alpha: 0}, 0.2 / playbackRate, {
			onComplete: function(tween:FlxTween)
			{
				comboSpr.destroy();
				rating.destroy();
			},
			startDelay: Conductor.crochet * 0.002 / playbackRate
		});
	}

	public static function bumpRatingSprite(rating:FlxSprite, playbackRate:Float = 1):Void
	{
		if(rating == null) return;

		var baseScaleX:Float = rating.scale.x;
		var baseScaleY:Float = rating.scale.y;
		rating.scale.set(baseScaleX * 1.28, baseScaleY * 1.28);
		FlxTween.tween(rating.scale, {x: baseScaleX, y: baseScaleY}, 0.16 / playbackRate, {ease: FlxEase.backOut}); // REMINDER do that shit less strong
	}

	public var strumsblockedFNF:Array<Bool> = [];
	private function onKeyPress(event:KeyboardEvent):Void
	{

		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);

		if (!controls.controllerMode)
		{
			#if debug
			//Prevents crash specifically on debug without needing to try catch shit
			@:privateAccess if (!FlxG.keys._keyListMap.exists(eventKey)) return;
			#end

			if(FlxG.keys.checkStatus(eventKey, JUST_PRESSED)) keyPressed(key);
		}
	}

	private function keyPressed(key:Int)
	{
		if (cpuControlled || paused || inCutscene || key < 0 || key >= playerStrums.length || !generatedMusic || endingSong || boyfriend.stunned) return;
		
		var ret:Dynamic = callOnScripts('onKeyPressPre', [key]);
		if(ret == LuaUtils.Function_Stop) return;
		
		// more accurate hit time for the ratings?
		var lastTime:Float = Conductor.songPosition;
		if (Conductor.songPosition >= 0 && !startingSong && FlxG.sound.music?.playing)
			Conductor.songPosition = FlxG.sound.music.time + Conductor.offset;
		
		// obtain notes that the player can hit
		var highestNote:Note = null;
		for (n in notes) {
			if (n != null && !n.isSustainNote && n.noteData == key && !strumsblockedFNF[n.noteData] && n.canBeHit && n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit) {
				if (highestNote == null || n.hitPriority > highestNote.hitPriority || (n.hitPriority == highestNote.hitPriority && n.strumTime < highestNote.strumTime))
					highestNote = n;
			}
		}
		
		if (highestNote != null) {
			goodNoteHit(highestNote);
		} else {
			var spr:StrumNote = playerStrums.members[key];
			if (strumsblockedFNF[key] != true && spr != null) {
				spr.playAnim('pressed');
				spr.resetAnim = 0;
			}
			
			if (ghostTapping) {
				callOnScripts('onGhostTap', [key]);
			} else {
				noteMissPress(key);
			}
		}
		
		// Needed for the  "Just the Two of Us" achievement.  - Shadow Mario
		if(!keysPressed.contains(key)) keysPressed.push(key);
		
		//more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
		Conductor.songPosition = lastTime;
		
		callOnScripts('onKeyPress', [key]);
	}
	
	private function onKeyRelease(event:KeyboardEvent):Void
	{
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(keysArray, eventKey);
		if(!controls.controllerMode && key > -1) keyReleased(key);
	}

	private function keyReleased(key:Int)
	{
		if(cpuControlled || !startedCountdown || paused || key < 0 || key >= playerStrums.length) return;

		var ret:Dynamic = callOnScripts('onKeyReleasePre', [key]);
		if(ret == LuaUtils.Function_Stop) return;

		var spr:StrumNote = playerStrums.members[key];
		if(spr != null)
		{
			spr.playAnim('static');
			spr.resetAnim = 0;
		}
		callOnScripts('onKeyRelease', [key]);
	}

	public static function getKeyFromEvent(arr:Array<String>, key:FlxKey):Int
	{
		if(key != NONE)
		{
			for (i in 0...arr.length)
			{
				var note:Array<FlxKey> = Controls.instance.keyboardBinds[arr[i]];
				for (noteKey in note)
					if(key == noteKey)
						return i;
			}
		}
		return -1;
	}

	// Hold notes
	private function keysCheck():Void
	{
		// HOLDING
		var holdArray:Array<Bool> = [];
		var pressArray:Array<Bool> = [];
		var releaseArray:Array<Bool> = [];
		for (key in keysArray)
		{
			holdArray.push(controls.pressed(key));
			pressArray.push(controls.justPressed(key));
			releaseArray.push(controls.justReleased(key));
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if(controls.controllerMode && pressArray.contains(true))
			for (i in 0...pressArray.length)
				if(pressArray[i] && strumsblockedFNF[i] != true)
					keyPressed(i);

		if (startedCountdown && !inCutscene && !boyfriend.stunned && generatedMusic)
		{
			if (notes.length > 0) {
				for (n in notes) { // I can't do a filter here, that's kinda awesome
					var canHit:Bool = (n != null && !strumsblockedFNF[n.noteData] && n.canBeHit
						&& n.mustPress && !n.tooLate && !n.wasGoodHit && !n.blockHit);

					if (guitarHeroSustains)
						canHit = canHit && n.parent != null && n.parent.wasGoodHit;

					if (canHit && n.isSustainNote) {
						var released:Bool = !holdArray[n.noteData];

						if (!released)
							goodNoteHit(n);
					}
				}
			}

			if (!holdArray.contains(true) || endingSong)
				playerDance();

			#if ACHIEVEMENTS_ALLOWED
			else checkForAchievement(['oversinging']);
			#end
		}

		// TO DO: Find a better way to handle controller inputs, this should work for now
		if((controls.controllerMode || strumsblockedFNF.contains(true)) && releaseArray.contains(true))
			for (i in 0...releaseArray.length)
				if(releaseArray[i] || strumsblockedFNF[i] == true)
					keyReleased(i);
	}

	/**
	 * Called whenever a note is missed.
	 * 
	 * @param 	daNote 	The missed note.
	*/
	function noteMiss(daNote:Note):Void { //You didn't hit the key and let it go offscreen, also used by Hurt Notes
		var result:Dynamic = callOnLuas('noteMissPre', [notes.members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote]);
		if (result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) result = callOnHScript('noteMissPre', [daNote]);
		if (result == LuaUtils.Function_Stop) return;
		
		//Dupe note remove
		notes.forEachAlive(function(note:Note) {
			if (daNote != note && daNote.mustPress && daNote.noteData == note.noteData && daNote.isSustainNote == note.isSustainNote && Math.abs(daNote.strumTime - note.strumTime) < 1)
				invalidateNote(note);
		});

		final end:Note = daNote.isSustainNote ? daNote.parent.tail[daNote.parent.tail.length - 1] : daNote.tail[daNote.tail.length - 1];
		if (end != null && end.extraData['holdSplash'] != null)
		{
			end.extraData['holdSplash'].visible = false;
		}

		noteMissCommon(daNote.noteData, daNote);
		stagesFunc(function(stage:BaseStage) stage.noteMiss(daNote));
		
		var result:Dynamic = callOnLuas('noteMiss', [notes.members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote]);
		if (result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) callOnHScript('noteMiss', [daNote]);
	}

	/**
	 * Called whenever a miss happens by ghost tapping (a key was pressed when there was no notes to hit).
	 * 
	 * @param 	direction 	The direction ID of the miss.
	*/
	function noteMissPress(direction:Int = 1):Void
	{
		if (ghostTapping) return; //fuck it

		noteMissCommon(direction);
		if (playMissSound)
			FlxG.sound.play(Paths.missnoteRandom(), FlxG.random.float(0.1, 0.2));
		stagesFunc(function(stage:BaseStage) stage.noteMissPress(direction));
		callOnScripts('noteMissPress', [direction]);
	}

	function noteMissCommon(direction:Int, ?note:Note)
	{
		// score and data
		var subtract:Float = pressMissDamage;
		if(note != null) subtract = note.missHealth;

		// GUITAR HERO SUSTAIN CHECK LOL!!!!
		if (note != null && guitarHeroSustains && note.parent == null) {
			if (note.tail.length > 0) {
				note.alpha = 0.35;
				for (childNote in note.tail) {
					childNote.alpha = note.alpha;
					childNote.missed = true;
					childNote.canBeHit = false;
					childNote.ignoreNote = true;
					childNote.tooLate = true;
				}
				note.missed = true;
				note.canBeHit = false;

				//subtract += 0.385; // you take more damage if playing with this gameplay changer enabled.
				// i mean its fair :p -Crow
				subtract *= note.tail.length + 1;
				// i think it would be fair if damage multiplied based on how long the sustain is -Tahir
			}

			if (note.missed)
				return;
		}
		if (note != null && guitarHeroSustains && note.parent != null && note.isSustainNote) {
			if (note.missed)
				return;

			var parentNote:Note = note.parent;
			if (parentNote.wasGoodHit && parentNote.tail.length > 0) {
				for (child in parentNote.tail) if (child != note) {
					child.missed = true;
					child.canBeHit = false;
					child.ignoreNote = true;
					child.tooLate = true;
				}
			}
		}

		if (note != null && note.playMissSound)
			FlxG.sound.play(Paths.missnoteRandom(), FlxG.random.float(0.1, 0.2));
		if(instakillOnMiss)
		{
			vocals.volume = 0;
			opponentVocals.volume = 0;
			doDeathCheck(true);
		}
		
		var lastCombo:Int = combo;
		combo = 0;

		health -= subtract * healthLoss;
		if (!endingSong) songMisses ++;
		songScore -= 10;
		totalPlayed ++;
		RecalculateRating(true);

		// play character anims
		var char:Character = getNoteCharacter(note, boyfriend);
		if (char != null) {
			if ((note == null || !note.noMissAnimation) && char.hasMissAnimations) {
				var postfix:String = '';
				if (note != null) postfix = note.animSuffix;

				var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length-1, direction)))] + 'miss' + postfix;
				char.playAnim(animToPlay, true);
			}
			
			if (gf != null && char != gf)
				gf.playComboDropAnim(combo);
			if (dad != null && char != dad)
				dad.playComboDropAnim(combo);
			if (boyfriend != null && char != boyfriend)
				boyfriend.playComboDropAnim(combo);
		}
		vocals.volume = 0;
	}

	/**
	 * Called whenever a note is hit by the opponent.
	 * 
	 * @param 	note 	The note that was hit.
	*/
	function opponentNoteHit(note:Note):Void
	{
		var result:Dynamic = callOnLuas('opponentNoteHitPre', [notes.members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) result = callOnHScript('opponentNoteHitPre', [note]);

		if(result == LuaUtils.Function_Stop) return;

		if (!camZoomingDisabled)
			camZooming = true;
		
		var char:Character = getNoteCharacter(note, dad);
		if (char != null) {
			if (note.noteType == 'Hey!' && char.hasAnimation('hey')) {
				char.playAnim('hey', true);
				applyCameraMove(note, char);
				char.specialAnim = true;
				char.heyTimer = 0.6;
			} else if(!note.noAnimation) {
				var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length-1, note.noteData)))] + note.animSuffix;

				if (char.playSingAnimation(animToPlay, note.isSustainNote))
					applyCameraMove(note, char);
				
				char.holdTimer = 0;
			}
		}

		if(opponentVocals.length <= 0) vocals.volume = 1;
		strumPlayAnim(true, Std.int(Math.abs(note.noteData)), Conductor.stepCrochet * 1.25 / 1000 / playbackRate);
		note.hitByOpponent = true;
		
		stagesFunc(function(stage:BaseStage) stage.opponentNoteHit(note));
		var result:Dynamic = callOnLuas('opponentNoteHit', [notes.members.indexOf(note), Math.abs(note.noteData), note.noteType, note.isSustainNote]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) callOnHScript('opponentNoteHit', [note]);
		callOnCharacterNoteHit(char, note, Std.int(Math.abs(note.noteData)), note.noteType, note.isSustainNote);

		spawnHoldSplashOnNote(note);

		if (!note.isSustainNote) invalidateNote(note);
	}

	/**
	 * Called whenever a note is hit by the player.
	 * 
	 * @param 	note 	The note that was hit.
	*/
	public function goodNoteHit(note:Note):Void
	{
		if(note.wasGoodHit) return;
		if(cpuControlled && note.ignoreNote) return;

		var isSus:Bool = note.isSustainNote; //GET OUT OF MY HEAD, GET OUT OF MY HEAD, GET OUT OF MY HEAD
		var leData:Int = Math.round(Math.abs(note.noteData));
		var leType:String = note.noteType;

		var result:Dynamic = callOnLuas('goodNoteHitPre', [notes.members.indexOf(note), leData, leType, isSus]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) result = callOnHScript('goodNoteHitPre', [note]);

		if(result == LuaUtils.Function_Stop) return;

		note.wasGoodHit = true;

		//trace('essa porra pode hitsoundear?  Volume do hitsound é maior que 0? ${note.hitsoundVolume > 0} | hitsound tá ativo? ${!note.hitsoundDisabled}');
		if (note.hitsoundVolume > 0 && !isSus)
			FlxG.sound.play(note.hitsound == 'hitsound' ? Paths.hitsound() : Paths.sound(note.hitsound), note.hitsoundVolume);
		
		var noteCharacter:Character = getNoteCharacter(note, boyfriend);
		var char:Character = null;
		if (!note.hitCausesMiss) { //Common notes
			if (!note.noAnimation) {
				var animToPlay:String = singAnimations[Std.int(Math.abs(Math.min(singAnimations.length-1, note.noteData)))] + note.animSuffix;
				
				char = noteCharacter;
				if (char != null) {
					if (char.playSingAnimation(animToPlay, note.isSustainNote))
						applyCameraMove(note, char);
					char.holdTimer = 0;
					
					if (note.noteType == 'Hey!') {
						for (animCheck in ['hey', 'cheer']) {
							if (char.hasAnimation(animCheck)) {
								char.playAnim(animCheck, true);
								char.specialAnim = true;
								char.heyTimer = 0.6;
								break;
							}
						}
					}
				}
			}

			if (!cpuControlled) {
				var spr = playerStrums.members[note.noteData];
				if (spr != null) spr.playAnim('confirm', true);
				spr.animation.finishCallback = (name:String) ->
				{
					if (name == 'confirm')
					{
						spr.playAnim('pressed');
					}
				};
			} else {
				strumPlayAnim(false, Std.int(Math.abs(note.noteData)), Conductor.stepCrochet * 1.25 / 1000 / playbackRate);
			}
			vocals.volume = 1;

			if (!note.isSustainNote) {
				combo ++;
				popUpScore(note);
				
				if (gf != null && char != gf)
					gf.playComboAnim(combo);
				if (dad != null && char != dad)
					dad.playComboAnim(combo);
				if (boyfriend != null && char != boyfriend)
					boyfriend.playComboAnim(combo);
			}
			var gainHealth:Bool = true; // prevent health gain, *if* sustains are treated as a singular note
			if (guitarHeroSustains && note.isSustainNote) gainHealth = false;
			if (gainHealth) health += note.hitHealth * healthGain;

		} else { //Notes that count as a miss if you hit them (Hurt notes for example)
			char = noteCharacter;
			
			if (!note.noMissAnimation) {
				switch (note.noteType) {
					case 'Hurt Note':
						if (char != null && char.hasAnimation('hurt')) {
							char.playAnim('hurt', true);
							char.specialAnim = true;
						}
				}
			}

			noteMiss(note);
			if (!note.noteSplashData.disabled && !note.isSustainNote)
				note.noteSplash = spawnNoteSplashOnNote(note);
		}

		stagesFunc(function(stage:BaseStage) stage.goodNoteHit(note));
		var result:Dynamic = callOnLuas('goodNoteHit', [notes.members.indexOf(note), leData, leType, isSus]);
		if(result != LuaUtils.Function_Stop && result != LuaUtils.Function_StopHScript && result != LuaUtils.Function_StopAll) callOnHScript('goodNoteHit', [note]);
		callOnCharacterNoteHit(noteCharacter, note, leData, leType, isSus);
		spawnHoldSplashOnNote(note);
		if(!note.isSustainNote) invalidateNote(note);
	}

	function callOnCharacterNoteHit(character:Character, note:Note, direction:Int, noteType:String, isSustainNote:Bool):Void
	{
		if(character == null)
			return;

		var args:Array<Dynamic> = [character, notes.members.indexOf(note), direction, noteType, isSustainNote];
		#if LUA_ALLOWED
		if(luaArray != null)
		{
			for(script in luaArray)
			{
				if(script == null || script.closed || !script.matchesCharacterScript(character))
					continue;
				script.call('characterNoteHit', args);
			}
		}
		#end

		#if HSCRIPT_ALLOWED
		if(hscriptArray != null)
		{
			for(script in hscriptArray)
			{
				if(script == null || script.closed || !script.matchesCharacterScript(character) || !script.exists('characterNoteHit'))
					continue;
				script.call('characterNoteHit', args);
			}
		}
		#end
	}
	
	/**
	 * Gets the character assigned to a note.
	 * 
	 * @param 	note 				The note to check.
	 * @param 	defaultCharacter	The character to fall back to if none is assigned.
	 * 
	 * @return 	The `Character` assigned to a note.
	*/
	public function getNoteCharacter(?note:Note, ?defaultCharacter:Character):Character {
		if (note == null) return defaultCharacter;
		
		if (note.character == null)
			return (note.gfNote ? gf : defaultCharacter);
		
		return note.character;
	}

	/**
	 * Destroys a note. Also calls `onDestroyNote` in Lua.
	 * 
	 * @param 	note 	The note to destroy.
	*/
	public function invalidateNote(note:Note):Void {
		// i dont think preventing the note from being destroyed would do the game any good
		callOnLuas('onDestroyNote', [notes.members.indexOf(note), note.noteData, note.noteType, note.isSustainNote]);
		callOnHScript('onDestroyNote', [note]);
		
		note.kill();
		notes.remove(note, true);
		note.destroy();
	}

	/**
	 * Spawns a note splash on the note's receptor (strum).
	 * 
	 * @param 	note 	The note to use.
	*/
	public function spawnNoteSplashOnNote(note:Note):NoteSplash {
		if(note != null) {
			var strum:StrumNote = playerStrums.members[note.noteData];
			if(strum != null)
				return spawnNoteSplash(strum.x, strum.y, note.noteData, note, strum);
		}
		return null;
	}

	public function spawnHoldSplashOnNote(note:Note)
		{
			if (ClientPrefs.data.holdSplashAlpha <= 0)
				return;

			if (note != null)
			{
				var strum:StrumNote = (note.mustPress ? playerStrums : opponentStrums).members[note.noteData];
				if (strum != null && note.tail.length > 1)
					spawnHoldSplash(note);
			}
		}

	public function spawnHoldSplash(note:Note)
		{
			var end:Note = note.isSustainNote ? note.parent.tail[note.parent.tail.length - 1] : note.tail[note.tail.length - 1];
			var splash:SustainSplash = grpHoldSplashes.recycle(SustainSplash);
			splash.setupSusSplash((note.mustPress ? playerStrums : opponentStrums).members[note.noteData], note, playbackRate);
			grpHoldSplashes.add(end.noteHoldSplash = splash);
		}

	/**
	 * Spawns a note splash.
	 * 
	 * @param 	x 		The x position of the note splash.
	 * @param 	y 		The y position of the note splash.
	 * @param 	data 	The note data ID of the note splash.
	 * @param 	note 	The note assigned to the note splash.
	 * @param 	strum 	The note receptor (strum) assigned to the note splash.
	 * 
	 * @return 	A new `NoteSplash` instance.
	*/
	public function spawnNoteSplash(x:Float = 0, y:Float = 0, ?data:Int = 0, ?note:Note, ?strum:StrumNote):NoteSplash {
		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.babyArrow = strum;
		splash.spawnSplashNote(x, y, data, note);
		grpNoteSplashes.add(splash);
		return splash;
	}

	override function destroy() {
		if (psychlua.CustomSubstate.instance != null) {
			closeSubState();
			resetSubState();
		}
		
		stagesFunc(function(stage:BaseStage) stage.destroy());

		#if VIDEOS_ALLOWED
		if(videoCutscene != null) {
			videoCutscene.destroy();
			videoCutscene = null;
		}
		#end

		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);

		FlxG.camera.filters = [];

		for(tag => camera in customCameras)
			if(camera != null)
				FlxG.cameras.remove(camera, true);
		customCameras.clear();
		customCameraAutoSize.clear();

		#if FLX_PITCH if (FlxG.sound.music != null) FlxG.sound.music.pitch = 1; #end
		FlxG.animationTimeScale = 1;

		Note.globalRgbShaders = [];
		backend.NoteTypesConfig.clearNoteTypesData();

		NoteSplash.configs.clear();
		instance = null;
		
		super.destroy();
	}

	var lastStepHit:Int;
	public override function stepHit(step:Int):Void {
		if (step == lastStepHit)
			return;
		
		super.stepHit(step);
		applyScriptedCameraBop(step, 'step');
		
		lastStepHit = step;
	}
	
	var lastBeatHit:Int;
	public override function beatHit(beat:Int):Void {
		if (lastBeatHit >= beat)
			return;
		
		if (startOnTime <= 0 && !skipCountdown && beat >= -4 && beat <= 0) {
			countdownTick(switch(beat) {
				default: START;
				case -4: THREE;
				case -3: TWO;
				case -2: ONE;
				case -1: GO;
			});
		}
		
		if (iconP1 != null && iconP1.bop) {
			iconP1.scale.set(1.2, 1.2);
			iconP1.updateHitbox();
		}
		if (iconP2 != null && iconP2.bop) {
			iconP2.scale.set(1.2, 1.2);
			iconP2.updateHitbox();
		}
		
		applyScriptedCameraBop(beat, 'beat');
		characterBopper(beat);
		
		super.beatHit(beat);
		lastBeatHit = beat;
	}

	function applyScriptedCameraBop(position:Int, unit:String):Void
	{
		if(!scriptedCameraBopActive || !ClientPrefs.data.camZooms || scriptedCameraBopRate <= 0)
			return;
		if(normalizeCameraBopUnit(unit) != scriptedCameraBopUnit)
			return;
		if(camGameBopZoom >= 0.35)
			return;

		if(!scriptedCameraBopHitsPosition(position))
			return;

		addCameraZoomBop(scriptedCameraBopGame * camZoomingMult * scriptedCameraBopIntensity, scriptedCameraBopHUD * camZoomingMult * scriptedCameraBopIntensity);
	}

	function scriptedCameraBopHitsPosition(position:Int):Bool
	{
		if(scriptedCameraBopPattern != null)
		{
			var cycle:Int = Math.round(scriptedCameraBopRate);
			if(cycle <= 0)
				return false;

			var local:Int = positiveModulo(Math.round(position - scriptedCameraBopOffset), cycle);
			for(hit in scriptedCameraBopPattern)
				if(positiveModulo(hit, cycle) == local)
					return true;
			return false;
		}

		var ratio:Float = (position - scriptedCameraBopOffset) / scriptedCameraBopRate;
		return Math.abs(ratio - Math.round(ratio)) <= 0.001;
	}

	function positiveModulo(value:Int, mod:Int):Int
	{
		if(mod == 0)
			return 0;
		var result:Int = value % mod;
		return result < 0 ? result + mod : result;
	}

	/**
	 * Handles the character bopping.
	 * 
	 * @param 	beat 	The current beat.
	*/
	public function characterBopper(beat:Int):Void {
		if (gf != null && beat % Math.round(gfSpeed * gf.danceEveryNumBeats) == 0 && !gf.getAnimationName().startsWith('sing') && !gf.stunned)
		{
			gf.dance();
			resetCameraMoveForCharacter(gf);
		}
		if (boyfriend != null && beat % boyfriend.danceEveryNumBeats == 0 && !boyfriend.getAnimationName().startsWith('sing') && !boyfriend.stunned)
		{
			boyfriend.dance();
			resetCameraMoveForCharacter(boyfriend);
		}
		if (dad != null && beat % dad.danceEveryNumBeats == 0 && !dad.getAnimationName().startsWith('sing') && !dad.stunned)
		{
			dad.dance();
			resetCameraMoveForCharacter(dad);
		}
		for(tag => extraCharacter in extraCharacterMap)
		{
			if(extraCharacter != null && beat % Math.max(1, extraCharacter.danceEveryNumBeats) == 0 && !extraCharacter.getAnimationName().startsWith('sing') && !extraCharacter.stunned)
			{
				extraCharacter.dance();
				resetCameraMoveForCharacter(extraCharacter);
			}
		}
	}

	function playerDance():Void {
		var anim:String = boyfriend.getAnimationName();
		if(boyfriend.holdTimer > Conductor.stepCrochet * (0.0011 #if FLX_PITCH / FlxG.sound.music.pitch #end) * boyfriend.singDuration && anim.startsWith('sing') && !anim.endsWith('miss'))
		{
			boyfriend.dance();
			resetCameraMoveForCharacter(boyfriend);
		}
	}

	public override function sectionHit(section:Int):Void {
		if (SONG.notes[section] != null) {
			if (!scriptedCameraBopActive && !scriptedCameraBopBlocksDefault && camZooming && camGameBopZoom < 0.35 && ClientPrefs.data.camZooms) {
				addCameraZoomBop(0.015 * camZoomingMult, 0.03 * camZoomingMult);
			}

			if (SONG.notes[section].changeBPM) {
				Conductor.bpm = SONG.notes[section].bpm;
				setOnScripts('curBpm', Conductor.bpm);
				setOnScripts('crochet', Conductor.crochet);
				setOnScripts('stepCrochet', Conductor.stepCrochet);
			}
			setOnScripts('altAnim', SONG.notes[section].altAnim);
			setOnScripts('gfSection', SONG.notes[section].gfSection);
			setOnScripts('mustHitSection', SONG.notes[section].mustHitSection);
		}
		
		super.sectionHit(section);
	}

	/**
	 * Plays the confirm animation on a note receptor (strum).
	 * 
	 * @param 	isDad 	Whether the strumline should be the opponent's or the player's.
	 * @param 	id 		The ID of the note receptor in the strumline.
	 * @param 	time 	The time (in seconds) until the animation resets.
	*/
	function strumPlayAnim(isDad:Bool, id:Int, time:Float) {
		var spr:StrumNote = null;
		if(isDad) {
			spr = opponentStrums.members[id];
		} else {
			spr = playerStrums.members[id];
		}

		if(spr != null) {
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	/**
	 * The name of the current rating.
	*/
	public var ratingName:String = '?';
	/**
	 * The player's accuracy, represented as a `Float`.
	 * 0 is 0% accuracy, and 1 is 100% accuracy.
	*/
	public var ratingPercent:Float;
	/**
	 * The player's FC status.
	*/
	public var ratingFC:String;
	/**
	 * Recalculates the rating and updates the score.
	 * 
	 * @param 	badHit 		Whether or not the rating was updated from a note miss.
	 * @param 	scoreBop 	Whether or not the score text should have a bopping animation.
	*/
	public function RecalculateRating(badHit:Bool = false, scoreBop:Bool = true) {
		setOnScripts('score', songScore);
		setOnScripts('misses', songMisses);
		setOnScripts('hits', songHits);
		setOnScripts('combo', combo);

		var ret:Dynamic = callOnScripts('onRecalculateRating', null, true);
		if(ret != LuaUtils.Function_Stop)
		{
			ratingName = '?';
			if(totalPlayed != 0) //Prevent divide by 0
			{
				// Rating Percent
				ratingPercent = Math.min(1, Math.max(0, totalNotesHit / totalPlayed));
				//trace((totalNotesHit / totalPlayed) + ', Total: ' + totalPlayed + ', notes hit: ' + totalNotesHit);

				// Rating Name
				ratingName = ratingStuff[ratingStuff.length-1][0]; //Uses last string
				if(ratingPercent < 1)
					for (i in 0...ratingStuff.length-1)
						if(ratingPercent < ratingStuff[i][1])
						{
							ratingName = ratingStuff[i][0];
							break;
						}
			}
			fullComboFunction();
		}
		setOnScripts('rating', ratingPercent);
		setOnScripts('ratingName', ratingName);
		setOnScripts('ratingFC', ratingFC);
		setOnScripts('totalPlayed', totalPlayed);
		setOnScripts('totalNotesHit', totalNotesHit);
		updateScore(badHit, scoreBop); // score will only update after rating is calculated, if it's a badHit, it shouldn't bounce
	}

	#if ACHIEVEMENTS_ALLOWED
	@:dox(hide) private function checkForAchievement(achievesToCheck:Array<String> = null)
	{
		if(chartingMode || cpuControlled) return;

		var usedPractice:Bool = (ClientPrefs.getGameplaySetting('practice') || ClientPrefs.getGameplaySetting('botplay'));

		for (name in achievesToCheck) {
			if(!Achievements.exists(name)) continue;

			var unlock:Bool = false;
			if (name != WeekData.getWeekFileName() + '_nomiss') // common achievements
			{
				switch(name)
				{
					case 'ur_bad':
						unlock = (ratingPercent < 0.2 && !usedPractice);

					case 'ur_good':
						unlock = (ratingPercent >= 1 && !usedPractice);

					case 'oversinging':
						unlock = (boyfriend.holdTimer >= 10 && !usedPractice);

					case 'hype':
						unlock = (!boyfriendIdled && !usedPractice);

					case 'two_keys':
						unlock = (!usedPractice && keysPressed.length <= 2);

					case 'toastie':
						unlock = (!ClientPrefs.data.cacheOnGPU && !ClientPrefs.data.shaders && ClientPrefs.data.lowQuality && !ClientPrefs.data.antialiasing);

					case 'debugger':
						unlock = (songName == 'test' && !usedPractice);
				}
			}
			else // any FC achievements, name should be "weekFileName_nomiss", e.g: "week3_nomiss";
			{
				if(isStoryMode && campaignMisses + songMisses < 1 && Difficulty.getString().toUpperCase() == 'HARD'
					&& storyPlaylist.length <= 1 && !changedDifficulty && !usedPractice)
					unlock = true;
			}

			if(unlock) Achievements.unlock(name);
		}
	}
	#end
}
