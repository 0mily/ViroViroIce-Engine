package states.editors;

import flixel.FlxSubState;
import flixel.util.FlxSave;
import flixel.util.FlxSort;
import flixel.util.FlxStringUtil;
import flixel.util.FlxDestroyUtil;
import flixel.input.keyboard.FlxKey;

import openfl.events.KeyboardEvent;

import lime.utils.Assets;
import lime.media.AudioBuffer;

import flash.media.Sound;
import flash.geom.Rectangle;
import flash.net.FileFilter;
import openfl.display.BitmapData;

import haxe.Json;
import haxe.Exception;
import haxe.io.Bytes;


import states.editors.content.MetaNote;
import states.editors.content.VSlice;
import states.editors.content.CoolNewSongSubState.ChartEditorSongChoice;
import states.editors.content.MoonchartConverters.MoonchartConversionResult;
import states.editors.content.MoonchartConverters.MoonchartOpcao;
import states.editors.content.Prompt;
import states.editors.content.*;

import backend.Song;
import backend.StageData;
import backend.Highscore;
import backend.Difficulty;
import backend.lists.ListLoader;
import backend.lists.ListLoader.ListCategoryData;
import backend.lists.ListLoader.ListKind;

import objects.Character;
import objects.HealthIcon;
import objects.Note;
import objects.StrumNote;

using DateTools;

typedef UndoStruct = {
	var action:UndoAction;
	var data:Dynamic;
}

typedef SelectedEventData = {
	var event:Array<String>;
	var note:EventMetaNote;
}

enum abstract UndoAction(String)
{
	var ADD_NOTE = 'Add Note';
	var DELETE_NOTE = 'Delete Note';
	var MOVE_NOTE = 'Move Note';
	var SELECT_NOTE = 'Select Note';
	
	var ADD_EVENT = 'Add Event';
	var DELETE_EVENT = 'Delete Event';
	var UPDATE_EVENT = 'Update Event';
}

enum abstract ChartingTheme(String)
{
	var LIGHT = 'light';
	var DARK = 'dark';
	var DEFAULT = 'default';
	var CUSTOM = 'custom';
}

enum abstract WaveformTarget(String)
{
	var INST = 'inst';
	var PLAYER = 'voc';
	var OPPONENT = 'opp';
	var EVERYTHING = 'all';
}

class ChartingState extends ScriptedState implements PsychUIEventHandler.PsychUIEvent
{
	public static var instance:ChartingState = null;
	public static var startOnTime:Float = 0;
	public static var keysArray:Array<FlxKey> = [ONE, TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT]; //Used for Vortex Editor
	public static var SHOW_EVENT_COLUMN = true;
	public static var GRID_COLUMNS_PER_PLAYER = 4;
	public static var GRID_PLAYERS = 2;
	public static var GRID_SIZE = 40;
	static inline final GRID_RIGHT_MARGIN:Float = 110;
	static inline final LEFT_PANEL_X:Float = 35;
	static inline final LEFT_PANEL_TOP:Float = 88;
	static inline final MAIN_BOX_WIDTH:Int = 420;
	static inline final MAIN_BOX_HEIGHT:Int = 360;
	static inline final INFO_BOX_WIDTH:Int = 300;
	static inline final INFO_BOX_HEIGHT:Int = 206;
	static inline final EDITOR_ICON_SCALE:Float = 0.58;
	static inline final EDITOR_ICON_BUMP_SCALE:Float = 0.16;
	static inline final SECTION_STEP_EPSILON:Float = 0.0001;
	final BACKUP_EXT = '.bkp';

	public var quantizations:Array<Int> = [
		4,
		8,
		12,
		16,
		20,
		24,
		32,
		48,
		64,
		96,
		192
	];
	public var quantColors:Array<FlxColor> = [
		0xFFDF0000,
		0xFF4040CF,
		0xFFAF00AF,
		0xFFFFAF00,
		0xFFFFFFFF,
		0xFFFFA0FF,
		0xFFFF6030,
		0xFF00CFCF,
		0xFF00CF00,
		0xFF9F9F9F,
		0xFF3F3F3F,
	];
	// buggy but workin
	var baseQuant:Int = 16;
	var curQuant(default, set):Int = 16;
	function set_curQuant(v:Int)
	{
		curQuant = v;
		updateVortexColor();
		return curQuant;
	}
	function updateQuantForZoom():Void
	{
		curQuant = Std.int(Math.max(1, Math.round(baseQuant * curZoom)));
		forceDataUpdate = true;
	}
	function updateVortexColor()
		vortexIndicator.color = quantColors[Std.int(FlxMath.bound(quantizations.indexOf(baseQuant), 0, quantColors.length - 1))];

	var sectionFirstNoteID:Int = 0;
	var sectionFirstEventID:Int = 0;
	var curSec:Int = 0;

	var chartEditorSave:FlxSave;
	var mainBox:PsychUIBox;
	var mainBoxPosition:FlxPoint = FlxPoint.get(LEFT_PANEL_X, LEFT_PANEL_TOP);
	var infoBox:PsychUIBox;
	var infoBoxPosition:FlxPoint = FlxPoint.get(LEFT_PANEL_X, LEFT_PANEL_TOP + MAIN_BOX_HEIGHT + 18);
	var upperBox:PsychUIBox;
	
	var camUI:FlxCamera;

	var prevGridBg:ChartingGridSprite;
	var gridBg:ChartingGridSprite;
	var nextGridBg:ChartingGridSprite;
	var waveformSprite:FlxSprite;
	var scrollY:Float = 0;
	
	var zoomList:Array<Float> = [
		0.25,
		0.5,
		1,
		2,
		3,
		4,
		6,
		8,
		12,
		16,
		24
	];
	var curZoom:Float = 1;

	var eventIcon:FlxSprite;
	var icons:Array<HealthIcon> = [];
	var iconBumpTimers:Array<Float> = [];

	var events:Array<EventMetaNote> = [];
	var notes:Array<MetaNote> = [];

	var behindRenderedNotes:FlxTypedGroup<MetaNote> = new FlxTypedGroup<MetaNote>();
	var curRenderedNotes:FlxTypedGroup<MetaNote> = new FlxTypedGroup<MetaNote>();
	var movingNotes:FlxTypedGroup<MetaNote> = new FlxTypedGroup<MetaNote>();
	var eventLockOverlay:FlxSprite;
	var vortexIndicator:FlxSprite;
	var strumLineNotes:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();
	var dummyArrow:FlxSprite;
	var isMovingNotes:Bool = false;
	var movingNotesLastData:Int = 0;
	var movingNotesLastY:Float = 0;
	var movingTempoOldMap:Array<BPMChangeEvent>;
	var directTempoDragOldMap:Array<BPMChangeEvent>;
	var downScroll:Bool = false;
	
	var vocals:FlxSound = new FlxSound();
	var opponentVocals:FlxSound = new FlxSound();
	var chartEditorMusic:FlxSound = new FlxSound();
	var chartEditorMusicTween:FlxTween;
	var chartEditorMusicDelayTimer:FlxTimer;

	var timeLine:FlxSprite;
	var infoText:FlxText;

	var autoSaveIcon:FlxSprite;
	var outputTxt:FlxText;

	var selectionStart:FlxPoint = FlxPoint.get();
	var selectionBox:FlxSprite;
	
	public function new(shouldReset:Bool = false) {
		if (shouldReset) startOnTime = 0;
		
		super();
	}

	var bgGradient:FlxSprite;
	var bg:FlxSprite;
	var theme:ChartingTheme = DEFAULT;
	var gradientTempo:Float = 0;
	var gradientRenderTimer:Float = 0;
	var gradientBitmap:BitmapData;
	var gradientemaneiro:Array<FlxColor> = [];
	var coresLegaisManeiras:Array<String> = ['6E1896', '57C785', 'EDDD53'];
	var gridNadaLegalENadaManeira:Array<String> = ['DFDFDF', 'BFBFBF'];

	var copiedNotes:Array<Dynamic> = [];
	var copiedEvents:Array<Dynamic> = [];
	
	var _keysPressedBuffer:Array<Bool> = [];
	var _heldNotes:Array<MetaNote> = [];

	var tipBg:FlxSprite;
	var fullTipText:FlxText;

	var autoLoadEvents:Bool = true;
	var vortexMoved:Bool = true;
	var allowInput:Bool = false;
	var vortexInput:Bool = false;
	var vortexEnabled:Bool = false;
	var waveformEnabled:Bool = false;
	var waveformTarget:WaveformTarget = INST;

	/*var lilStage:FlxSprite;
	var bfToy:Toy;
	var gfToy:Toy;
	var dadToy:Toy;
	var toyGroup:FlxTypedSpriteGroup<Toy>;*/

	var buddyStage:FlxSprite;
	var bfBuddy:EditorBuddy;
	var dadBuddy:EditorBuddy;
	var buddyLayout:Dynamic;
	var singAnimations:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];

	override function create() {
		if(Difficulty.list.length < 1) Difficulty.resetList();
		_keysPressedBuffer.resize(keysArray.length);
		_heldNotes.resize(keysArray.length);
		
		instance = this;
		ensureChartReadyForEditor();
		
		persistentUpdate = false;
		FlxG.mouse.visible = true;
		FlxG.sound.list.add(vocals);
		FlxG.sound.list.add(opponentVocals);
		FlxG.sound.list.add(chartEditorMusic);
		
		vocals.autoDestroy = false;
		vocals.looped = true;
		opponentVocals.autoDestroy = false;
		opponentVocals.looped = true;
		chartEditorMusic.autoDestroy = false;
		chartEditorMusic.looped = true;

		initPsychCamera();
		camUI = new FlxCamera();
		camUI.bgColor.alpha = 0;
		FlxG.cameras.add(camUI, false);

		chartEditorSave = new FlxSave();
		chartEditorSave.bind('chart_editor_data', CoolUtil.getSavePath());

		bgGradient = new FlxSprite();
		bgGradient.scrollFactor.set();
		add(bgGradient);

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set();
		bg.alpha = 0.23;
		add(bg);

		if(chartEditorSave.data.autoSave != null) autoSaveCap = chartEditorSave.data.autoSave;
		if(chartEditorSave.data.backupLimit != null) backupLimit = chartEditorSave.data.backupLimit;
		if(chartEditorSave.data.autoLoadEvents != null) autoLoadEvents = chartEditorSave.data.autoLoadEvents;
		if(chartEditorSave.data.downScroll != null) downScroll = chartEditorSave.data.downScroll;
		if(chartEditorSave.data.vortex != null) vortexEnabled = chartEditorSave.data.vortex;
		/*if(chartEditorSave.data.toys != null) toysEnabled = chartEditorSave.data.toys;

		if(chartEditorSave.data.customBgColor == null) chartEditorSave.data.customBgColor = '303030';*/

		if(chartEditorSave.data.customGridColors == null || chartEditorSave.data.customGridColors.length < 2) chartEditorSave.data.customGridColors = ['DFDFDF', 'BFBFBF']; else gridNadaLegalENadaManeira = [chartEditorSave.data.customGridColors[0], chartEditorSave.data.customGridColors[1]];

		/*if(chartEditorSave.data.customNextGridColors == null || chartEditorSave.data.customNextGridColors.length < 2)
			chartEditorSave.data.customNextGridColors = ['5F5F5F', '4A4A4A'];*/
		loadcoresLegaisManeiras();
		
		changeTheme(chartEditorSave.data.theme != null ? chartEditorSave.data.theme : DEFAULT, false);
		refreshSustains(chartEditorSave.data.texturedSustains ?? true);
		
		preCreate();
		createGrids();

		waveformSprite = new FlxSprite(gridBg.x + (SHOW_EVENT_COLUMN ? GRID_SIZE : 0), 0).makeGraphic(1, 1, 0x00FFFFFF);
		waveformSprite.scrollFactor.x = 0;
		waveformSprite.visible = false;
		add(waveformSprite);

		dummyArrow = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		dummyArrow.setGraphicSize(GRID_SIZE, GRID_SIZE);
		dummyArrow.updateHitbox();
		dummyArrow.scrollFactor.x = 0;
		add(dummyArrow);

		vortexIndicator = new FlxSprite(gridBg.x - GRID_SIZE, (FlxG.height - GRID_SIZE)/2).loadGraphic(Paths.image('editors/vortex_indicator'));
		vortexIndicator.antialiasing = ClientPrefs.data.antialiasing;
		vortexIndicator.setGraphicSize(GRID_SIZE);
		vortexIndicator.updateHitbox();
		vortexIndicator.scrollFactor.set();
		vortexIndicator.active = false;
		updateVortexColor();
		add(vortexIndicator);
		add(strumLineNotes);

		add(behindRenderedNotes);
		add(curRenderedNotes);
		add(movingNotes);

		eventLockOverlay = new FlxSprite(gridBg.x, 0).makeGraphic(1, 1, FlxColor.BLACK);
		eventLockOverlay.alpha = 0.6;
		eventLockOverlay.visible = false;
		eventLockOverlay.scrollFactor.x = 0;
		eventLockOverlay.scale.x = GRID_SIZE;
		eventLockOverlay.updateHitbox();
		add(eventLockOverlay);

		timeLine = new FlxSprite(gridBg.x, 0).makeGraphic(1, 1, FlxColor.WHITE);
		timeLine.setGraphicSize(Std.int(gridBg.width), 4);
		timeLine.updateHitbox();
		timeLine.scrollFactor.set();
		add(timeLine);
		
		var startX:Float = gridBg.x;
		var startY:Float = (FlxG.height - GRID_SIZE)/2;
		vortexIndicator.visible = strumLineNotes.visible = strumLineNotes.active = vortexEnabled;
		if(SHOW_EVENT_COLUMN) startX += GRID_SIZE;

		for (i in 0...Std.int(GRID_PLAYERS * GRID_COLUMNS_PER_PLAYER))
		{
			var note:StrumNote = new StrumNote(startX + (GRID_SIZE * i), startY, i % GRID_COLUMNS_PER_PLAYER, 0);
			note.scrollFactor.set();
			note.playAnim('static');
			note.alpha = 0.4;
			note.updateHitbox();
			if(note.width > note.height)
				note.setGraphicSize(GRID_SIZE);
			else
				note.setGraphicSize(0, GRID_SIZE);
	
			note.updateHitbox();
			note.x += GRID_SIZE/2 - note.width/2;
			note.y += GRID_SIZE/2 - note.height/2;
			strumLineNotes.add(note);
		}

		var columns:Int = 0;
		var iconX:Float = gridBg.x;
		var iconY:Float = 50;
		if(SHOW_EVENT_COLUMN)
		{
			eventIcon = new FlxSprite(0, iconY).loadGraphic(Paths.image('editors/lists/default-events'));
			eventIcon.antialiasing = ClientPrefs.data.antialiasing;
			eventIcon.alpha = 0.6;
			eventIcon.setGraphicSize(30, 30);
			eventIcon.updateHitbox();
			eventIcon.scrollFactor.set();
			add(eventIcon);
			eventIcon.x = iconX + (GRID_SIZE * 0.5) - eventIcon.width/2;
			iconX += GRID_SIZE;

			columns++;
		}

		var gridStripes:Array<Int> = [];
		for (i in 0...GRID_PLAYERS)
		{
			if(columns > 0) gridStripes.push(columns);
			columns += GRID_COLUMNS_PER_PLAYER;

			var icon:HealthIcon = new HealthIcon();
			icon.autoAdjustOffset = false;
			icon.alpha = 1;
			icon.scrollFactor.set();
			icon.scale.set(EDITOR_ICON_SCALE, EDITOR_ICON_SCALE);
			icon.updateHitbox();
			icon.centerIconOrigin();
			icon.ID = i+1;
			add(icon);
			icons.push(icon);
			iconBumpTimers.push(0);
			iconX += GRID_SIZE * GRID_COLUMNS_PER_PLAYER;
		}
		prevGridBg.stripes = nextGridBg.stripes = gridBg.stripes = gridStripes;
		positionEditorIcons();
		
		selectionBox = new FlxSprite().makeGraphic(1, 1, FlxColor.CYAN);
		selectionBox.alpha = 0.4;
		selectionBox.blend = ADD;
		selectionBox.scrollFactor.set();
		selectionBox.visible = false;
		add(selectionBox);

		carinhasCriar();

		infoBox = new PsychUIBox(infoBoxPosition.x, infoBoxPosition.y, INFO_BOX_WIDTH, INFO_BOX_HEIGHT, ['Information']);
		infoBox.scrollFactor.set();
		infoBox.cameras = [camUI];
		infoText = new FlxText(15, 12, INFO_BOX_WIDTH - 30, '', 16);
		infoText.scrollFactor.set();
		infoBox.getTab('Information').menu.add(infoText);
		infoBox.canMove = false;
		add(infoBox);

		mainBox = new PsychUIBox(mainBoxPosition.x, mainBoxPosition.y, MAIN_BOX_WIDTH, MAIN_BOX_HEIGHT, ['Charting', 'Data', 'Events', 'Note', 'Section', 'Song']);
		mainBox.selectedName = 'Song';
		mainBox.scrollFactor.set();
		mainBox.cameras = [camUI];
		mainBox.canMove = false;
		mainBox.fitSelectedTabContent = true;
		mainBox.minFitHeight = 150;
		mainBox.maxFitHeight = Std.int(Math.max(MAIN_BOX_HEIGHT, FlxG.height - mainBox.y - INFO_BOX_HEIGHT - 42));
		add(mainBox);
		
		autoSaveIcon = new FlxSprite(50).loadGraphic(Paths.image('editors/autosave'));
		autoSaveIcon.screenCenter(Y);
		autoSaveIcon.scale.set(0.6, 0.6);
		autoSaveIcon.antialiasing = ClientPrefs.data.antialiasing;
		autoSaveIcon.scrollFactor.set();
		autoSaveIcon.alpha = 0;
		add(autoSaveIcon);

		upperBox = new PsychUIBox(0, 0, 620, 300, ['File', 'Edit', 'Converters', 'Settings', 'Testing']);
		upperBox.scrollFactor.set();
		upperBox.isMinimized = true;
		upperBox.minimizeOnFocusLost = true;
		upperBox.canMove = false;
		upperBox.cameras = [camUI];
		upperBox.bg.visible = false;
		add(upperBox);

		outputTxt = new FlxText(25, FlxG.height - 50, FlxG.width - 50, '', 20);
		outputTxt.borderSize = 2;
		outputTxt.borderStyle = OUTLINE_FAST;
		outputTxt.scrollFactor.set();
		outputTxt.cameras = [camUI];
		outputTxt.alpha = 0;
		add(outputTxt);

		updateJsonData();
		
		// TABS
		////// for main box
		addChartingTab();
		addDataTab();
		addNoteTab();
		addSectionTab();
		addSongTab();
		
		////// for upper box
		loadEditorViewSettings();
		addFileTab();
		addEditTab();
		addConvertersTab();
		addSettingsTab();
		addTestingTab();
		//


		loadMusic();
		loadChartEditorMusic();
		reloadNotesDropdowns();
		
		var musicLength:Float = getEditorSongLength();
		Conductor.songPosition = Math.max(Math.min(ChartingState.startOnTime, musicLength + Conductor.offset), 0);
		opponentVocals.pause();
		vocals.pause();

		reloadNotes();
		updateGridVisibility();

		// CHARACTERS FOR THE DROP DOWNS
		var allCharacters:Array<String> = Character.appendCharacterFileList(Mods.mergeAllTextsNamed('data/characterList.txt'));
		characterVisualCategories = ListLoader.load(CHARACTER, this);
		ListLoader.appendNames(allCharacters, characterVisualCategories);
		var characterList:Array<String> = allCharacters.filter((name:String) -> (!name.endsWith('-dead') && !name.endsWith('-death')));
		playerDropDown.list = characterList;
		opponentDropDown.list = characterList;
		girlfriendDropDown.list = characterList;
		
		stageVisualCategories = ListLoader.load(STAGE, this);
		var stageList:Array<String> = loadFileList('data/stages/', 'data/stages/stageList.txt');
		ListLoader.appendNames(stageList, stageVisualCategories);
		stageDropDown.list = stageList;
		onChartLoaded();

		var tipText:FlxText = new FlxText(FlxG.width - 210, FlxG.height - 30, 200, 'Press F1 for Help', 20);
		tipText.cameras = [camUI];
		tipText.setFormat(null, 16, FlxColor.WHITE, RIGHT);
		tipText.borderColor = FlxColor.BLACK;
		tipText.scrollFactor.set();
		tipText.borderSize = 1;
		tipText.active = false;
		add(tipText);

		tipBg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		tipBg.cameras = [camUI];
		tipBg.scale.set(FlxG.width, FlxG.height);
		tipBg.updateHitbox();
		tipBg.scrollFactor.set();
		tipBg.visible = tipBg.active = false;
		tipBg.alpha = 0.6;
		add(tipBg);
		
		fullTipText = new FlxText(0, 0, FlxG.width - 200);
		fullTipText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER);
		fullTipText.cameras = [camUI];
		fullTipText.scrollFactor.set();
		fullTipText.visible = fullTipText.active = false;
		fullTipText.text = [
			"W/S/Mouse Wheel - Go Forward/Back in Song",
			"A/D - Move a Section Back/Forward",
			"Q/E - Decrease/Increase Note Sustain Length",
			"Hold Shift/Alt to Increase/Decrease move by 4x",
			"",
			"F12 - Preview Chart",
			"Enter - Playtest Chart",
			"Shift + Enter - Playtest Chart at Current Time",
			"Space - Stop/Resume Song",
			"",
			"Alt + Click - Select & Resize Note Sustains",
			"Shift + Click - Select/Unselect",
			"Right Click - Selection Box",
			"",
			"R - Jump to Start of current Section",
			"Home / Shift + R - Jump to Start of the Song",
			"End - Jump to End of the Song",
			"Z/X - Zoom in/out",
			"Left/Right - Change Snap (in Vortex Mode)",
			"Page/Arrows Up/Down - Scroll (in Vortex Mode)",
			#if FLX_PITCH
			"Left Bracket / Right Bracket - Change Song Playback Rate",
			"ALT + Left Bracket / Right Bracket - Reset Song Playback Rate",
			#end
			"",
			"Ctrl + Z - Undo",
			"Ctrl + Y - Redo",
			"Ctrl + X - Cut Selected Notes",
			"Ctrl + C - Copy Selected Notes",
			"Ctrl + V - Paste Copied Notes",
			"Ctrl + A - Select all in current Section",
			"Ctrl + S - Quicksave",
		].join('\n');
		fullTipText.screenCenter();
		add(fullTipText);
		
		super.create();
		
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, keyDown);
		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, keyUp);
	}

	function carinhasCriar() {
		var layout:Dynamic = loadBuddyLayout();
		var stageData:Dynamic = buddyLayoutSection(layout, 'stage');
		var opponentData:Dynamic = buddyLayoutSection(layout, 'opponent');
		var bfData:Dynamic = buddyLayoutSection(layout, 'bf');

		var defaultStageX:Float = LEFT_PANEL_X + MAIN_BOX_WIDTH + 25;
		var defaultStageY:Float = FlxG.height - 112;
		var defaultStageWidth:Float = Math.max(280, gridBg.x - defaultStageX - 42);
		var stageX:Float = buddyFloat(stageData, 'x', defaultStageX);
		var stageY:Float = buddyFloat(stageData, 'y', defaultStageY);
		var stageWidth:Float = buddyFloat(stageData, 'width', defaultStageWidth);
		var stageImage:String = buddyString(stageData, 'image', 'stage');

		buddyStage = new FlxSprite(stageX, stageY).loadGraphic(Paths.image('editors/friends/$stageImage'));
		buddyStage.antialiasing = ClientPrefs.data.antialiasing;
		if(stageWidth > 0)
			buddyStage.setGraphicSize(Std.int(stageWidth));
		else
		{
			var stageScale:Float = buddyFloat(stageData, 'scale', 1);
			buddyStage.scale.set(stageScale, stageScale);
		}
		buddyStage.updateHitbox();
		buddyStage.scrollFactor.set();
		add(buddyStage);

		dadBuddy = new EditorBuddy(
			buddyFloat(opponentData, 'x', buddyStage.x + 24),
			buddyFloat(opponentData, 'y', buddyStage.y - 98),
			buddyString(opponentData, 'image', 'opp'),
			opponentData);
		dadBuddy.scrollFactor.set();
		add(dadBuddy);

		bfBuddy = new EditorBuddy(
			buddyFloat(bfData, 'x', buddyStage.x + buddyStage.width - 132),
			buddyFloat(bfData, 'y', buddyStage.y - 98),
			buddyString(bfData, 'image', 'dingalingdemon'),
			bfData);
		bfBuddy.scrollFactor.set();
		add(bfBuddy);
	}

	function loadBuddyLayout():Dynamic
	{
		if(buddyLayout != null)
			return buddyLayout;

		var raw:String = Paths.getTextFromFile('images/editors/friends/buddies.json');
		if(raw != null)
		{
			try
			{
				buddyLayout = Json.parse(raw);
			}
			catch(e:Dynamic)
			{
				trace('Could not parse chart editor buddies.json: $e');
			}
		}
		return buddyLayout;
	}

	function buddyLayoutSection(layout:Dynamic, field:String):Dynamic
	{
		if(layout != null && Reflect.hasField(layout, field))
			return Reflect.field(layout, field);
		return null;
	}

	function buddyString(data:Dynamic, field:String, fallback:String):String
	{
		if(data == null || !Reflect.hasField(data, field))
			return fallback;

		var value:Dynamic = Reflect.field(data, field);
		return value == null ? fallback : Std.string(value);
	}

	function buddyFloat(data:Dynamic, field:String, fallback:Float):Float
	{
		if(data == null || !Reflect.hasField(data, field))
			return fallback;

		var value:Dynamic = Reflect.field(data, field);
		var parsed:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}
	
	var texturedSustains:Bool;
	var gridColors:Array<FlxColor>;
	var gridColorsOther:Array<FlxColor>;
	function refreshSustains(useTextured:Bool):Bool {
		for (note in notes)
			note.useBlandSustains = !useTextured;
		return texturedSustains = useTextured;
	}
	function changeTheme(changeTo:ChartingTheme, ?doSave:Bool = true)
	{
		var oldTheme:ChartingTheme = theme;
		theme = switch(changeTo)
		{
			case LIGHT, DARK, DEFAULT, CUSTOM: changeTo;
			default: DEFAULT;
		}
		chartEditorSave.data.theme = theme;
		if(doSave) chartEditorSave.flush();

		switch(theme)
		{
			case LIGHT:
				applyGradientEditoridkimtired(['D369F0', '438DE0', 'FC6DA4']);
				gridColors = [0xFFDFDFDF, 0xFFBFBFBF];
				gridColorsOther = [0xFF5F5F5F, 0xFF4A4A4A];
			case DARK:
				applyGradientEditoridkimtired(['38273B', '24384F', '354A32']);
				gridColors = [0xFF3F3F3F, 0xFF2F2F2F];
				gridColorsOther = [0xFF1F1F1F, 0xFF111111];
			case CUSTOM:
				applyGradientEditoridkimtired(coresLegaisManeiras);
				gridColors = [CoolUtil.colorFromString(chartEditorSave.data.customGridColors[0]), CoolUtil.colorFromString(chartEditorSave.data.customGridColors[1])];
				gridColorsOther = [CoolUtil.colorFromString(chartEditorSave.data.customGridColors[0]).getDarkened(0.6), CoolUtil.colorFromString(chartEditorSave.data.customGridColors[1]).getDarkened(0.6)];
			default:
				applyGradientEditoridkimtired(['6E1896', '57C785', 'EDDD53']);
				gridColors = [0xFFF3D5FF, 0xFFAC92B7];
				gridColorsOther = [CoolUtil.colorFromString('F3D5FF').getDarkened(0.6), CoolUtil.colorFromString('AC92B7').getDarkened(0.6)]; // eu até ia pegar o hex manualmente mas tipo... pra que? -Shiho
		}

		bg.color = FlxColor.WHITE;

		if(theme != oldTheme || theme == CUSTOM) // eu acho que isso funciona -Shiho (PS. Funciona sim)
		{
			if(gridBg != null)
			{
				gridBg.loadGrid(gridColors[0], gridColors[1]);
				gridBg.vortexLineEnabled = vortexEnabled;
				gridBg.vortexLineSpace = GRID_SIZE * 4 * curZoom;
			}
			if(prevGridBg != null)
			{
				prevGridBg.loadGrid(gridColorsOther[0], gridColorsOther[1]);
				prevGridBg.vortexLineEnabled = vortexEnabled;
				prevGridBg.vortexLineSpace = GRID_SIZE * 4 * curZoom;
			}
			if(nextGridBg != null)
			{
				nextGridBg.loadGrid(gridColorsOther[0], gridColorsOther[1]);
				nextGridBg.vortexLineEnabled = vortexEnabled;
				nextGridBg.vortexLineSpace = GRID_SIZE * 4 * curZoom;
			}
		}
	}

	function loadcoresLegaisManeiras():Void
	{
		var fallback:Array<String> = coresLegaisManeiras.copy();
		if(chartEditorSave.data.coresLegaisManeiras != null)
		{
			try
			{
				var saved:Array<Dynamic> = cast chartEditorSave.data.coresLegaisManeiras;
				for(i in 0...Std.int(Math.min(3, saved.length)))
					coresLegaisManeiras[i] = normalizar(saved[i], fallback[i]); // Cara, se não crashou,
			}
			catch(e:Dynamic) {}
		}
		chartEditorSave.data.coresLegaisManeiras = coresLegaisManeiras.copy();
	}

	function serManeiro(index:Int, value:String):Void
	{
		if(index < 0 || index >= coresLegaisManeiras.length)
			return;

		coresLegaisManeiras[index] = normalizar(value, coresLegaisManeiras[index]);
		chartEditorSave.data.coresLegaisManeiras = coresLegaisManeiras.copy();
		chartEditorSave.flush();
		if(theme == CUSTOM)
			changeTheme(CUSTOM, false);
	}

	function changeGridColors(index:Int, color:String)
	{
		if(index < 0 || index >= gridNadaLegalENadaManeira.length)
			return;

		gridNadaLegalENadaManeira[index] = color;
		chartEditorSave.data.customGridColors = gridNadaLegalENadaManeira.copy();
		chartEditorSave.flush();

		if(theme == CUSTOM)
			changeTheme(CUSTOM, false);
	}

	function PresetGradOpen(?onApplied:Void->Void):Void
	{
		if(!fileDialog.completed)
			return;

		fileDialog.open(null, 'Open Gradient Preset', [new FileFilter('Gradient XML', '*.xml')], function()
		{
			if(loadPresetGrad(fileDialog.data))
			{
				changeTheme(CUSTOM);
				if(onApplied != null)
					onApplied();
				showOutput('Gradient preset loaded!');
			}
			else
				showOutput('Invalid gradient preset!', true);
		});
	}

	function PresetGradSave():Void
	{
		if(!fileDialog.completed)
			return;

		fileDialog.save('gradient-preset.xml', PresetGradBuild(), function()
		{
			showOutput('Gradient preset saved!');
		});
	}

	function PresetGradBuild():String
	{
		var lines:Array<String> = ['<?xml version="1.0" encoding="utf-8"?>', '<gradientPreset>'];
		for(i in 0...coresLegaisManeiras.length)
			lines.push('\t<color index="${i + 1}">#${coresLegaisManeiras[i]}</color>');
		for(i in 0...gridNadaLegalENadaManeira.length)
			lines.push('\t<gridColor index="${i + 1}">#${gridNadaLegalENadaManeira[i]}</gridColor>');
		lines.push('</gradientPreset>');
		return lines.join('\n'); // pronto amor @Shiho // obrigada amor mwamwa
	}

	function loadPresetGrad(data:String):Bool
	{
		if(data == null || data.trim().length < 1)
			return false;

		try
		{
			var parsed:Xml = Xml.parse(data);
			var root:Xml = parsed.firstElement();
			if(root == null)
				return false;

			var colors:Array<String> = [];
			var customGridColors:Array<String> = [];
			for(field in ['color1', 'color2', 'color3'])
			{
				if(root.exists(field))
					colors.push(normalizar(root.get(field), coresLegaisManeiras[Std.int(Math.min(colors.length, coresLegaisManeiras.length - 1))]));
			}
			for(field in ['gridColor1', 'gridColor2', 'customGridColor1', 'customGridColor2'])
			{
				if(root.exists(field))
					customGridColors.push(normalizar(root.get(field), gridNadaLegalENadaManeira[Std.int(Math.min(customGridColors.length, gridNadaLegalENadaManeira.length - 1))]));
			}

			for(child in root.elements())
			{
				var nodeName:String = child.nodeName.toLowerCase();
				if(nodeName == 'color' || nodeName == 'color1' || nodeName == 'color2' || nodeName == 'color3')
				{
					var textNode:Xml = child.firstChild();
					var raw:String = textNode != null ? textNode.nodeValue : child.get('value');
					if(raw != null)
						colors.push(normalizar(raw, coresLegaisManeiras[Std.int(Math.min(colors.length, coresLegaisManeiras.length - 1))]));
				}
				else if(nodeName == 'gridcolor' || nodeName == 'grid-color' || nodeName == 'customgridcolor' || nodeName == 'custom-grid-color')
				{
					var textNode:Xml = child.firstChild();
					var raw:String = textNode != null ? textNode.nodeValue : child.get('value');
					if(raw != null)
						customGridColors.push(normalizar(raw, gridNadaLegalENadaManeira[Std.int(Math.min(customGridColors.length, gridNadaLegalENadaManeira.length - 1))]));
				}
				else if(nodeName == 'grid' || nodeName == 'customgrid')
				{
					for(gridChild in child.elements())
					{
						var gridNodeName:String = gridChild.nodeName.toLowerCase();
						if(gridNodeName == 'color' || gridNodeName == 'gridcolor' || gridNodeName == 'grid-color')
						{
							var textNode:Xml = gridChild.firstChild();
							var raw:String = textNode != null ? textNode.nodeValue : gridChild.get('value');
							if(raw != null)
								customGridColors.push(normalizar(raw, gridNadaLegalENadaManeira[Std.int(Math.min(customGridColors.length, gridNadaLegalENadaManeira.length - 1))]));
						}
					}
				}
			}

			if(colors.length < 3)
				return false;

			for(i in 0...coresLegaisManeiras.length)
				coresLegaisManeiras[i] = normalizar(colors[i], coresLegaisManeiras[i]);
			if(customGridColors.length >= gridNadaLegalENadaManeira.length)
			{
				for(i in 0...gridNadaLegalENadaManeira.length)
					gridNadaLegalENadaManeira[i] = normalizar(customGridColors[i], gridNadaLegalENadaManeira[i]);
				chartEditorSave.data.customGridColors = gridNadaLegalENadaManeira.copy();
			}

			chartEditorSave.data.coresLegaisManeiras = coresLegaisManeiras.copy();
			chartEditorSave.flush();
			return true;
		}
		catch(e:Dynamic)
		{
			trace('Could not load gradient preset XML: $e');
		}
		return false;
	}

	function normalizar(value:Dynamic, fallback:String):String
	{
		if(value == null)
			return fallback;

		var str:String = StringTools.trim(Std.string(value));
		str = StringTools.replace(str, '#', '');
		str = StringTools.replace(str, '0x', '');
		str = StringTools.replace(str, '0X', '');
		if(str.length != 6)
			return fallback;

		for(i in 0...str.length)
		{
			var code:Int = str.charCodeAt(i);
			var isNumber:Bool = code >= 48 && code <= 57;
			var isUpper:Bool = code >= 65 && code <= 70;
			var isLower:Bool = code >= 97 && code <= 102;
			if(!isNumber && !isUpper && !isLower)
				return fallback;
		}
		return str.toUpperCase();
	}

	function applyGradientEditoridkimtired(hexColors:Array<String>):Void
	{
		if(bgGradient == null)
			return;

		gradientemaneiro = [for(hex in hexColors) CoolUtil.colorFromString(hex)];
		var w:Int = 160;
		var h:Int = 90;
		if(gradientBitmap == null || gradientBitmap.width != w || gradientBitmap.height != h)
		gradientBitmap = new BitmapData(w, h, true, 0xFF000000);

		renderGrad(gradientTempo);
		bgGradient.loadGraphic(gradientBitmap);
		bgGradient.setGraphicSize(Std.int(FlxG.width + 180), Std.int(FlxG.height + 140));
		bgGradient.updateHitbox();
		updateGrad(0);
	}

	function updateGrad(elapsed:Float):Void
	{
		if(bgGradient == null || bgGradient.graphic == null)
			return;

		gradientTempo += elapsed;
		gradientRenderTimer += elapsed;
		if(gradientRenderTimer >= 0.045)
		{
			gradientRenderTimer = 0; // e isso vai funcionar?
			renderGrad(gradientTempo);
		} // E NÉ QUE DEU?!?!?!!

		var padX:Float = Math.max(0, (bgGradient.width - FlxG.width) * 0.5);
		var padY:Float = Math.max(0, (bgGradient.height - FlxG.height) * 0.5);
		bgGradient.x = -padX + Math.sin(gradientTempo * 0.36) * Math.min(50, padX * 0.6);
		bgGradient.y = -padY + Math.cos(gradientTempo * 0.31) * Math.min(38, padY * 0.6);
		bgGradient.angle = 0;
	}

	function renderGrad(time:Float):Void
	{
		if(gradientBitmap == null || gradientemaneiro == null || gradientemaneiro.length < 3)
			return;

		var w:Int = gradientBitmap.width;
		var h:Int = gradientBitmap.height;
		var c0x:Float = 0.18 + Math.sin(time * 0.46) * 0.2;
		var c0y:Float = 0.2 + Math.cos(time * 0.39) * 0.18;
		var c1x:Float = 0.72 + Math.cos(time * 0.34) * 0.2;
		var c1y:Float = 0.45 + Math.sin(time * 0.42) * 0.2;
		var c2x:Float = 0.5 + Math.sin(time * 0.29 + 1.8) * 0.22;
		var c2y:Float = 0.86 + Math.cos(time * 0.37 + 0.8) * 0.2;

		gradientBitmap.lock();
		for(y in 0...h)
		{
			var ny:Float = y / Math.max(1, h - 1);
			for(x in 0...w)
			{
				var nx:Float = x / Math.max(1, w - 1);
				var flowX:Float = nx + Math.sin((ny * 7.0) + time * 0.82) * 0.075 + Math.cos((nx * 5.0) - time * 0.48) * 0.045;
				var flowY:Float = ny + Math.cos((nx * 6.0) + time * 0.67) * 0.065 + Math.sin((ny * 4.0) - time * 0.52) * 0.04;
				var w0:Float = radialWeight(flowX, flowY, c0x, c0y, 1.0);
				var w1:Float = radialWeight(flowX, flowY, c1x, c1y, 0.95);
				var w2:Float = radialWeight(flowX, flowY, c2x, c2y, 0.9);
				var total:Float = Math.max(0.0001, w0 + w1 + w2);
				gradientBitmap.setPixel32(x, y, blendThree(gradientemaneiro[0], gradientemaneiro[1], gradientemaneiro[2], w0 / total, w1 / total, w2 / total));
			}
		}
		gradientBitmap.unlock();

		if(bgGradient != null && bgGradient.graphic != null)
			bgGradient.pixels = gradientBitmap;
	}

	function radialWeight(nx:Float, ny:Float, cx:Float, cy:Float, radius:Float):Float
	{
		var dx:Float = nx - cx;
		var dy:Float = ny - cy;
		var dist:Float = (dx * dx) + (dy * dy);
		return 1 / (0.035 + dist * radius);
	}

	function blendThree(a:FlxColor, b:FlxColor, c:FlxColor, wa:Float, wb:Float, wc:Float):Int
	{
		var r:Int = Std.int((a.red * wa) + (b.red * wb) + (c.red * wc));
		var g:Int = Std.int((a.green * wa) + (b.green * wb) + (c.green * wc));
		var bl:Int = Std.int((a.blue * wa) + (b.blue * wb) + (c.blue * wc));
		return FlxColor.fromRGB(r, g, bl, 255);
	}

	function ensureChartReadyForEditor():Void
	{
		if(PlayState.SONG == null)
		{
			//trace('teste o meu saco');
			openNewChart();
			return;
		}

		PlayState.SONG = sanitizeEditorChart(PlayState.SONG);
		Song.ensureCameraMoveData(PlayState.SONG);
		StageData.loadDirectory(PlayState.SONG);
		Conductor.bpm = PlayState.SONG.bpm;
	}

	function sanitizeEditorChart(song:SwagSong):SwagSong
	{
		if(song == null)
			return createDefaultChart();

		if(song.song == null || song.song.trim().length < 1) song.song = 'Test';
		song.bpm = sanitizeEditorFloat(Reflect.field(song, 'bpm'), 150, true);
		song.speed = sanitizeEditorFloat(Reflect.field(song, 'speed'), 1, true);
		if(song.player1 == null || song.player1.trim().length < 1) song.player1 = 'bf';
		if(song.player2 == null || song.player2.trim().length < 1) song.player2 = 'dad';
		if(song.gfVersion == null || song.gfVersion.trim().length < 1) song.gfVersion = 'gf';
		if(song.stage == null || song.stage.trim().length < 1) song.stage = 'stage';
		if(song.events == null) song.events = [];
		if(song.notes == null) song.notes = [];
		if(song.notes.length < 1)
			song.notes.push(createDefaultSection(song.bpm));

		Song.normalizeChart(song);
		if(song.notes.length < 1)
			song.notes.push(createDefaultSection(song.bpm));
		return song;
	}

	function sanitizeEditorFloat(value:Dynamic, fallback:Float, mustBePositive:Bool = false):Float
	{
		var parsed:Float = Std.parseFloat(Std.string(value ?? ''));
		if(Math.isNaN(parsed) || (mustBePositive && parsed <= 0))
			return fallback;
		return parsed;
	}

	function createDefaultChart():SwagSong
	{
		return {
			song: 'Test',
			notes: [createDefaultSection(150)],
			events: [],
			bpm: 150,
			needsVoices: false,
			speed: 1,
			offset: 0,

			player1: 'bf',
			player2: 'dad',
			gfVersion: 'gf',
			stage: 'stage',
			format: Song.VIRO_FORMAT,
			cameraMove: {
				enabled: true,
				intensity: 2.4,
				speed: 1,
				offset: 15
			}
		};
	}

	function createDefaultSection(bpm:Float):SwagSection
	{
		return {
			sectionNotes: [],
			sectionBeats: 4,
			mustHitSection: true,
			bpm: bpm,
			changeBPM: false,
			altAnim: false,
			gfSection: false
		};
	}

	function openNewChart()
	{
		Song.chartPath = null;
		loadChart(createDefaultChart());
	}

	function getEditorSongLength():Float
	{
		if(FlxG.sound.music != null)
			return Math.max(0, FlxG.sound.music.length);
		if(cachedSectionTimes != null && cachedSectionTimes.length > 0)
			return Math.max(0, cachedSectionTimes[cachedSectionTimes.length - 1]);
		return 0;
	}

	function getEditorSongEndTime():Float
	{
		return Math.max(0, getEditorSongLength() + Conductor.offset + delay - 1);
	}

	function clearEditorMusic():Void
	{
		if(FlxG.sound.music == null)
			return;
		FlxG.sound.music.stop();
		FlxG.sound.music.destroy();
		FlxG.sound.music = null;
	}

	function prepareReload()
	{
		updateJsonData();
		loadMusic();
		reloadNotes();
		onChartLoaded();
		updateHeads(true);
		
		autoSaveTime = 0;
		Conductor.songPosition = 0;
		if (FlxG.sound.music != null) FlxG.sound.music.time = 0;
		curSec = 0;
		loadSection();
		forceDataUpdate = true;
	}

	function onChartLoaded()
	{
		if(PlayState.SONG == null) return;

		// SONG TAB
		songNameInputText.text = PlayState.SONG.song;
		allowVocalsCheckBox.checked = (PlayState.SONG.needsVoices != false); //If the song for some reason does not have this value, it will be set to true

		bpmStepper.value = PlayState.SONG.bpm;
		scrollSpeedStepper.value = PlayState.SONG.speed;
		audioOffsetStepper.value = Reflect.hasField(PlayState.SONG, 'offset') ? PlayState.SONG.offset : 0;
		Conductor.offset = audioOffsetStepper.value;

		playerDropDown.selectedLabel = PlayState.SONG.player1;
		opponentDropDown.selectedLabel = PlayState.SONG.player2;
		girlfriendDropDown.selectedLabel = PlayState.SONG.gfVersion;
		stageDropDown.selectedLabel = PlayState.SONG.stage;
		StageData.loadDirectory(PlayState.SONG);

		// DATA TAB
		noRGBCheckBox.checked = (PlayState.SONG.disableNoteRGB == true);

		noteTextureInputText.text = PlayState.SONG.arrowSkin;
		noteSplashesInputText.text = PlayState.SONG.splashSkin;
		holdSplashesInputText.text = PlayState.SONG.holdSplashSkin;
		refreshCameraMoveControls();
	}
	
	var noteSelectionSine:Float = 0;
	var selectedNotes:Array<MetaNote> = [];
	var selectedEvents:Array<SelectedEventData> = [];
	var ignoreClickForThisFrame:Bool = false;
	var outputAlpha:Float = 0;
	var songFinished:Bool = false;

	var fileDialog:FileDialogHandler = new FileDialogHandler();
	var lastFocus:PsychUIInputText;
	
	var autoSaveTime:Float = 0;
	var autoSaveCap:Int = 2; //in minutes
	var backupLimit:Int = 10;
	
	var lastSongTime:Float = 0;
	
	var closestNote:MetaNote = null;
	function updateEditorBoxLayout():Void
	{
		if(mainBox == null || infoBox == null || mainBox.bg == null || infoBox.bg == null)
			return;

		mainBox.maxFitHeight = Std.int(Math.max(MAIN_BOX_HEIGHT, FlxG.height - mainBox.y - infoBox.bg.height - 42));
		infoBox.y = Math.min(mainBox.y + mainBox.bg.height + 18, FlxG.height - infoBox.bg.height - 12);
	}

	#if sys
	function createAutosaveBackup(?showIcon:Bool = true):Void
	{
		if(showIcon && autoSaveIcon != null)
		{
			FlxTween.cancelTweensOf(autoSaveIcon);
			autoSaveIcon.alpha = 0;
		}
		autoSaveTime = 0;
		updateChartData();

		var chartName:String = 'unknown';
		if(Song.chartPath != null)
		{
			chartName = Song.chartPath.replace('\\', '/');
			chartName = chartName.substring(chartName.lastIndexOf('/') + 1, chartName.lastIndexOf('.'));
		}
		chartName += DateTools.format(Date.now(), '_%Y-%m-%d_%H-%M-%S');

		var songCopy:SwagSong = Reflect.copy(PlayState.SONG);
		Reflect.setField(songCopy, '__original_path', Song.chartPath);
		var dataToSave:String = haxe.Json.stringify(songCopy);

		if(!FileSystem.isDirectory('backups')) FileSystem.createDirectory('backups');
		File.saveContent('backups/$chartName.$BACKUP_EXT', dataToSave);

		if(backupLimit > 0)
		{
			var files:Array<String> = FileSystem.readDirectory('backups/').filter((file:String) -> file.endsWith('.$BACKUP_EXT'));
			if(files.length > backupLimit)
			{
				var incorrect:Array<String> = [];
				var map:Map<String, Float> = [];
				for(file in files)
				{
					var split:Array<String> = file.split('_');
					if(split.length > 2)
					{
						try
						{
							var timeStr:String = split[split.length - 1].replace('-', ':');
							timeStr = timeStr.substr(0, timeStr.indexOf('.'));

							var fileJoin:String = split[split.length - 2] + ' ' + timeStr;
							var date:Date = Date.fromString(fileJoin);
							map.set(file, date.getTime());
						}
						catch(e:Exception)
						{
							incorrect.push(file);
						}
					}
					else incorrect.push(file);
				}

				if(incorrect.length > 0) files = files.filter((file:String) -> !incorrect.contains(file));
				files.sort(function(a:String, b:String) return map.get(a) > map.get(b) ? 1 : -1);

				while(files.length > backupLimit)
				{
					var file = files.shift();
					try
					{
						FileSystem.deleteFile('backups/$file');
					}
					catch(e:Exception) {}
				}
			}
		}

		if(showIcon && autoSaveIcon != null)
		{
			FlxTween.tween(autoSaveIcon, {alpha: 1}, 0.5, {onComplete: function(_)
				FlxTween.tween(autoSaveIcon, {alpha: 0}, 0.5, {startDelay: 2})
			});
		}
	}
	#end

	override function update(elapsed:Float)
	{
		preUpdate(elapsed);
		updateGrad(elapsed);
		updateEditorIcons(elapsed);
		updateEditorBoxLayout();
		
		vortexInput = false;
		if(!fileDialog.completed)
		{
			lastFocus = PsychUIInputText.focusOn;
			return;
		}
		updateScriptCharacterDropdownData(elapsed);
		var charterFocus:Bool = focusedOnEditor();
		
		#if sys
		if(autoSaveCap > 0)
		{
			autoSaveTime += elapsed / 60.0;
			//trace(autoSaveTime);
			//#if debug if(FlxG.keys.justPressed.J) autoSaveTime += 20/60.0; #end
			if(autoSaveTime >= autoSaveCap #if debug || FlxG.keys.justPressed.NUMPADMULTIPLY #end)
				createAutosaveBackup(true);
		}
		#end

		ClientPrefs.toggleVolumeKeys(charterFocus);
		
		outputAlpha = Math.max(0, outputAlpha - elapsed);
		var holdingAlt:Bool = FlxG.keys.pressed.ALT;
		if(FlxG.sound.music != null)
		{
			if(charterFocus) //If not typing anything
			{
				if(FlxG.keys.justPressed.F12)
				{
					super.update(elapsed);
					openEditorPlayState();
					lastFocus = PsychUIInputText.focusOn;
					return;
				}
				else if(FlxG.keys.justPressed.F1)
				{
					var vis:Bool = !fullTipText.visible;
					tipBg.visible = tipBg.active = fullTipText.visible = fullTipText.active = vis;
				}

				var goingBack:Bool = false;
				if(FlxG.keys.pressed.RBRACKET || (FlxG.keys.pressed.LBRACKET && (goingBack = true)))
				{
					if(holdingAlt)
					{
						if(playbackRate != 1)
						{
							playbackRate = 1;
							setPitch();
						}
					}
					else
					{
						playbackRate = FlxMath.bound(playbackRate + elapsed * (!goingBack ? 1 : -1), playbackSlider.min, playbackSlider.max);
						setPitch();
					}
					playbackSlider.value = playbackRate;
				}
				
				if(FlxG.keys.justPressed.HOME)
				{
					setSongPlaying(false);
					Conductor.songPosition = 0;
					loadSection(0);
				}
				else if(FlxG.keys.justPressed.END)
				{
					setSongPlaying(false);
					Conductor.songPosition = getEditorSongEndTime();
					loadSection(PlayState.SONG.notes.length - 1);
				}
				else if(FlxG.keys.justPressed.R)
				{
					var timeToGoBack:Float = 0;
					if(!FlxG.keys.pressed.SHIFT) timeToGoBack = cachedSectionTimes[curSec] + (curSec > 0 ? 0.000001 : 0);
					else loadSection(0);
					
					Conductor.songPosition = timeToGoBack;
					setSongPlaying(songPlaying);
				}
				else if(FlxG.keys.pressed.W != FlxG.keys.pressed.S || FlxG.mouse.wheel != 0)
				{
					if (FlxG.sound.music.playing)
						setSongPlaying(false);
					
					var downScrollMult:Int = (downScroll ? -1 : 1);
					if(mouseSnapCheckBox.checked && FlxG.mouse.wheel != 0)
					{
						var stepAdd:Float = (FlxG.keys.pressed.SHIFT ? 4 : 1) / (holdingAlt ? 4 : 1) * FlxG.mouse.wheel * downScrollMult * getSnapStep();
						var nextStep:Float = Math.max(0, snapChartStep(Conductor.getStep(Conductor.songPosition)) - stepAdd);
						Conductor.songPosition = Conductor.stepToSeconds(nextStep);
					}
					else
					{
						var speedMult:Float = (FlxG.keys.pressed.SHIFT ? 4 : 1) * (FlxG.mouse.wheel != 0 ? 4 : 1) / (holdingAlt ? 4 : 1) * downScrollMult;
						var nextStep:Float = Conductor.getStep(Conductor.songPosition);
						if (FlxG.keys.pressed.W || FlxG.mouse.wheel > 0)
							nextStep -= speedMult * 6 * elapsed / curZoom;
						else if (FlxG.keys.pressed.S || FlxG.mouse.wheel < 0)
							nextStep += speedMult * 6 * elapsed / curZoom;
						Conductor.songPosition = Conductor.stepToSeconds(Math.max(0, nextStep));
					}

					Conductor.songPosition = FlxMath.bound(Conductor.songPosition, 0, getEditorSongEndTime());
				}
				if(FlxG.keys.justPressed.SPACE)
				{
					setSongPlaying(!FlxG.sound.music.playing);
				}
			}

			if(!songFinished && songPlaying && FlxG.sound.music != null && !FlxG.sound.music.playing
				&& FlxG.sound.music.length > 0 && FlxG.sound.music.time >= FlxG.sound.music.length - 2)
				songFinished = true;

			if (!songFinished && songPlaying) {
				if (FlxG.sound.music.playing) {
					Conductor.songPosition = FlxMath.bound(FlxG.sound.music.time + Conductor.offset + delay, 0, getEditorSongEndTime());
				} else {
					Conductor.songPosition += (elapsed * 1000);
					
					if (Conductor.songPosition >= Conductor.offset + delay) playMusic();
				}
			}
			updateScrollY();
			var virtualStep:Float = Conductor.getStep(Conductor.songPosition);
			if(Math.isNaN(lastVirtualizedStep) || Math.abs(virtualStep - lastVirtualizedStep) >= Math.max(0.125, 1 / curZoom))
			{
				softReloadNotes(true);
				updateWaveform();
			}
		}

		super.update(elapsed);
		charterFocus = focusedOnEditor(true);
		
		if(songFinished)
		{
			onSongComplete();
			if(FlxG.sound.music != null)
				lastSongTime = FlxG.sound.music.time;
			songFinished = false;
		}
		else if(FlxG.sound.music != null)
		{
			if(FlxG.sound.music.time >= vocals.length)
				vocals.pause();
			if(FlxG.sound.music.time >= opponentVocals.length)
				opponentVocals.pause();

			while(curSec > 0 && Conductor.songPosition < cachedSectionTimes[curSec] - 1)
				loadSection(curSec - 1);
			while(curSec < PlayState.SONG.notes.length - 1 && Conductor.songPosition >= cachedSectionTimes[curSec + 1])
				loadSection(curSec + 1);
		}
		
		if(charterFocus)
		{
			var doCut:Bool = false;
			var canContinue:Bool = true;
			if(FlxG.keys.justPressed.ENTER)
			{
				goToPlayState();
				return;
			}
			else if(FlxG.keys.pressed.CONTROL && !isMovingNotes && (FlxG.keys.justPressed.Z || FlxG.keys.justPressed.Y || FlxG.keys.justPressed.X ||
				FlxG.keys.justPressed.C || FlxG.keys.justPressed.V || FlxG.keys.justPressed.A || FlxG.keys.justPressed.S))
			{
				canContinue = false;
				if(FlxG.keys.justPressed.Z)
					undo();
				else if(FlxG.keys.justPressed.Y)
					redo();
				else if((doCut = FlxG.keys.justPressed.X) || FlxG.keys.justPressed.C) // Cut (Ctrl + X) and Copy (Ctrl + C)
				{
					var notesToCopy:Array<MetaNote> = getSelectedNotesWithEventGroups();

					if(notesToCopy.length > 0)
					{
						copiedNotes = [];
						copiedEvents = [];
						var pushedNotes:Array<Array<Dynamic>> = [];

						for (note in notesToCopy)
						{
							if(note == null) continue;

							var copied:Array<Dynamic> = makeNoteDataCopy(note.songData, note.isEvent);
							
							pushedNotes.push(copied);
							if (note.isEvent) { copiedEvents.push(copied); }
							else { copiedNotes.push(copied); }
						}
						pushedNotes.sort((a:Array<Dynamic>, b:Array<Dynamic>) -> FlxSort.byValues(FlxSort.ASCENDING, a[0], b[0]));
						
						var minTime:Float = Conductor.getStep(pushedNotes[0][0]);
						for (note in pushedNotes)
						{
							var noteStep:Float = Conductor.getStep(note[0]);
							if(note.length > 2 && !Std.isOfType(note[1], Array))
								note[2] = Conductor.getStep(note[0] + note[2]) - noteStep;
							note[0] = noteStep - minTime;
						}
					}
				}
				else if(FlxG.keys.justPressed.V) // Paste (Ctrl + V)
				{
					if(copiedNotes.length > 0 || copiedEvents.length > 0)
					{
						selectionBox.visible = false;
						stopMovingNotes();
						resetSelectedNotes();
						var pasteStep:Float = snapChartStep(Conductor.getStep(Conductor.songPosition));
						if(FlxG.mouse.x >= gridBg.x && FlxG.mouse.x < gridBg.x + gridBg.width &&
							FlxG.mouse.y >= gridBg.y && FlxG.mouse.y < gridBg.y + gridBg.height)
							pasteStep = Math.max(0, gridYToChartStep(FlxG.mouse.y));
						selectedNotes = pasteCopiedNotesToSection(true, true, true, pasteStep, false);
						selectedNotes.sort(PlayState.sortByTime);
					}
				}
				else if(FlxG.keys.justPressed.A) // Select All (Ctrl + A)
				{
					var sel = selectedNotes;
					selectedNotes = curRenderedNotes.members.copy();
					addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
					onSelectNote();
					trace('Notes selected: ' + selectedNotes.length);
				}
				else if(FlxG.keys.justPressed.S) // Save (Ctrl + S)
					saveChart();
			}
			
			vortexInput = (allowInput && canContinue && vortexEnabled);
			allowInput = true;
			if (vortexInput && FlxG.sound.music != null && FlxG.sound.music.playing) {
				updateVortexHolds();
				vortexMoved = true;
			}
			if(doCut || FlxG.keys.justPressed.DELETE || FlxG.keys.justPressed.BACKSPACE || (isMovingNotes && (FlxG.mouse.justPressedRight || FlxG.keys.justPressed.ESCAPE))) // Delete button
			{
				var deletedSomething:Bool = false;
				var removedTempo:Bool = false;
				var oldBPMMap:Array<BPMChangeEvent> = Conductor.copyBPMChanges();
				if(selectedNotes.length > 0)
				{
					var removedNotes:Array<MetaNote> = [];
					var removedEvents:Array<EventMetaNote> = [];
					while(selectedNotes.length > 0)
					{
						var note:MetaNote = selectedNotes[0];
						selectedNotes.shift();
						if(note == null) continue;
		
						var kind:String = !note.isEvent ? 'note' : 'event';
						trace('Removed $kind at time: ${note.strumTime}');
						if(!note.isEvent)
						{
							notes.remove(note);
							removedNotes.push(note);
						}
						else
						{
							var ev:EventMetaNote = cast (note, EventMetaNote);
							if(eventNoteHasBPMChange(ev)) removedTempo = true;
							events.remove(ev);
							removedEvents.push(ev);
						}
					}
					movingNotes.clear();
					isMovingNotes = false;
					selectedNotes = [];
					onSelectNote();
					softReloadNotes();
					updateSelectedEvents();
					addUndoAction(DELETE_NOTE, {notes: removedNotes, events: removedEvents});
					deletedSomething = (removedNotes.length > 0 || removedEvents.length > 0);
				}
				
				var removedEvents:Array<SelectedEventData> = [];
				
				while (selectedEvents.length > 0) {
					var event:SelectedEventData = selectedEvents.shift();
					if(eventDataIsBPMChange(cast event.event)) removedTempo = true;
					
					if (event.note.events.length > 1) {
						event.note.events.remove(event.event);
						event.note.updateEventInfo();
						
						curEventSelected = Std.int(Math.min(curEventSelected, event.note.events.length - 1));
						
						selectedEvents.remove(event);
					} else {
						events.remove(event.note);
						selectedNotes.remove(event.note);
						curRenderedNotes.remove(event.note, true);
					}
					
					removedEvents.push(event);
				}
				
				addUndoAction(DELETE_EVENT, {events: removedEvents});
				if(removedEvents.length > 0)
					deletedSomething = true;
				if(removedTempo) adaptNotes(oldBPMMap, false);
				if(deletedSomething)
					EditorSFX.playChartSound('note_delete', 0.75);
			}
		}

		if (selectionBox.visible) {
			if (FlxG.mouse.releasedRight) {
				var sel = selectedNotes.copy();
				updateSelectionBox();
				if(!FlxG.keys.pressed.SHIFT)
					resetSelectedNotes();

				var selectionBounds = selectionBox.getScreenBounds(null, camUI);
				selectionBounds.setPosition(selectionBounds.x + GRID_SIZE * .5, selectionBounds.y + GRID_SIZE * .5);
				selectionBounds.setSize(selectionBounds.width - GRID_SIZE, selectionBounds.height - GRID_SIZE);
				for (note in curRenderedNotes)
				{
					if(note == null) continue;
					
					if (note.isEvent) {
						var eventNote:EventMetaNote = cast note;
						
						eventNote.gui.select(selectionBounds);
					}

					if(!selectedNotes.contains(note))
					{
						var noteBounds = note.getScreenBounds(null, camUI);
						noteBounds.top -= scrollY;
						noteBounds.bottom -= scrollY;

						if(selectionBounds.overlaps(noteBounds))
						{
							if(holdingAlt && selectedNotes.contains(note))
							{
								selectedNotes.remove(note);
								note.setColorTransform();
								if(note.animation.curAnim != null) note.animation.curAnim.curFrame = 0;
							}
							else selectedNotes.push(note);
							onSelectNote();
						}
					}
				}
				selectionBox.visible = false;
				addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
			} else if (FlxG.mouse.justMoved)
				updateSelectionBox();
		}
		else if (FlxG.mouse.pressedRight && (FlxG.mouse.deltaViewX != 0 || FlxG.mouse.deltaViewY != 0))
		{
			selectionBox.setPosition(FlxG.mouse.viewX, FlxG.mouse.viewY);
			selectionStart.set(FlxG.mouse.viewX, FlxG.mouse.viewY);
			selectionBox.visible = true;
			updateSelectionBox();
		}
		
		for (note in curRenderedNotes) {
			if (note.isEvent) {
				if (cast(note, EventMetaNote).gui.hovering) {
					ignoreClickForThisFrame = true;
					break;
				}
			}
		}
		if(FlxG.mouse.justPressed && (FlxG.mouse.overlaps(mainBox.bg, camUI) || FlxG.mouse.overlaps(infoBox.bg, camUI)))
			ignoreClickForThisFrame = true;

		var minX:Float = gridBg.x;
		if(SHOW_EVENT_COLUMN && lockedEvents) minX += GRID_SIZE;

		if(isMovingNotes && FlxG.mouse.justReleased)
			stopMovingNotes();

		var prevNote = closestNote;
		closestNote = null;
		
		if(FlxG.mouse.x >= minX && FlxG.mouse.x < gridBg.x + gridBg.width)
		{
			var diffX:Float = FlxG.mouse.x - gridBg.x;
			var mouseStep:Float = gridYToChartStep(FlxG.mouse.y, !FlxG.keys.pressed.SHIFT);
			mouseStep = FlxMath.bound(mouseStep, 0, cachedSectionRow[cachedSectionRow.length - 1]);

			var noteData:Int = Math.floor(diffX / GRID_SIZE);
			dummyArrow.visible = (!selectionBox.visible && !FlxG.mouse.pressed);
			dummyArrow.x = gridBg.x + noteData * GRID_SIZE;
			if(SHOW_EVENT_COLUMN)
				noteData--;

			dummyArrow.y = chartStepToGridY(mouseStep);
			
			var mouseInGrid:Bool = (FlxG.mouse.x >= gridBg.x && FlxG.mouse.x < gridBg.x + gridBg.width);
			
			if (!isMovingNotes && mouseInGrid) {
				for (note in curRenderedNotes) {
					var chartY:Float = (FlxG.mouse.y - calculateY(note));
					
					if (!((note.isEvent && noteData < 0) || (!note.isEvent && note.songData[1] == noteData)) || chartY < 0 || chartY >= GRID_SIZE) continue;
					
					if (closestNote == null || Math.abs(chartY - GRID_SIZE * .5) < Math.abs(FlxG.mouse.y - calculateY(closestNote) - GRID_SIZE * .5))
						closestNote = note;
				}
			}
			
			if(isMovingNotes)
			{
				var movedSelection:Bool = false;

				// Move note data
				var nData:Int = Std.int(Math.max(0, noteData));
				if(movingNotesLastData != nData)
				{
					var isFirst:Bool = true;
					var movingNotesMinData:Int = 0;
					var movingNotesMaxData:Int = 0;
					for (note in selectedNotes) //Find boundaries first
					{
						if(note == null || note.isEvent) continue;
	
						var data:Int = note.songData[1];
						if(isFirst || data < movingNotesMinData) movingNotesMinData = data;
						if(data > movingNotesMaxData) movingNotesMaxData = data;
						isFirst = false;
					}

					var diff:Int = nData - movingNotesLastData;
					var maxn:Int = (GRID_PLAYERS * GRID_COLUMNS_PER_PLAYER) - 1;
					movingNotesMinData += diff;
					movingNotesMaxData += diff;
					if(movingNotesMinData < 0)
						diff -= movingNotesMinData;
					else if(movingNotesMaxData > maxn)
						diff -= movingNotesMaxData - maxn;

					if(diff != 0)
						movedSelection = true;

					for (note in movingNotes)
					{
						if(note == null || note.isEvent) continue; //Events shouldn't change note data as they don't have one

						note.changeNoteData(note.songData[1] + diff);
						positionNoteXByData(note);
					}
				}
				movingNotesLastData = nData;

				// Move note strum time
				if(dummyArrow.y != movingNotesLastY)
				{
					var pixelDiff:Float = dummyArrow.y - movingNotesLastY;
					var stepDiff:Float = pixelDiff / Math.max(0.0001, GRID_SIZE * curZoom) * (downScroll ? -1 : 1);
					if(stepDiff != 0)
						movedSelection = true;

					for (note in movingNotes)
					{
						if(note == null) continue;
						var nextStep:Float = Math.max(0, Conductor.getStep(note.strumTime) + stepDiff);
						note.setStrumTime(Conductor.stepToSeconds(nextStep));
						positionNoteYOnTime(note);
						if(note.isEvent) cast (note, EventMetaNote).updateEventInfo();
					}
					movingNotesLastY = dummyArrow.y;
				}

				if(movedSelection)
					EditorSFX.playChartSound('note_drag', 0.7);
			}
			else if (!ignoreClickForThisFrame && FlxG.mouse.justPressed)
			{
				if(FlxG.keys.pressed.CONTROL)
				{
					if(getSelectedNotesWithEventGroups().length > 0)
						moveSelectedNotes(noteData, dummyArrow.y);
					else
						showOutput('You must select notes to move them!', true);
				}
				else if(mouseInGrid)
				{
					var closest = closestNote;
					if(closest != null && (!closest.isEvent || !lockedEvents))
					{
						if (holdingAlt || FlxG.keys.pressed.SHIFT) // Select Note/Event
						{
							var sel = selectedNotes.copy();
							
							if (selectedNotes.contains(closest)) {
								if (FlxG.keys.pressed.SHIFT) {
									if (closest.isEvent) {
										var i:Int = selectedEvents.length;
										while (-- i >= 0) {
											var data:SelectedEventData = selectedEvents[i];
											if (data.note == closest) selectedEvents.remove(data);
										}
									}
									
									selectedNotes.remove(closest);
									closest.setColorTransform();
								} else {
									directTempoDragOldMap = null;
									for (note in selectedNotes)
									{
										if(note != null && note.isEvent && eventNoteHasBPMChange(cast note) && directTempoDragOldMap == null)
											directTempoDragOldMap = Conductor.copyBPMChanges();
										note.dragging = true;
									}
									EditorSFX.playChartSound('note_drag', 0.7);
								}
							} else {
								if (!FlxG.keys.pressed.SHIFT) resetSelectedNotes();
								
								selectedNotes.push(closest);
							}
							
							addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
							trace('Notes selected: ' + selectedNotes.length);
						}
						else if(!FlxG.keys.pressed.CONTROL) // Remove Note/Event
						{
							var removedTempo:Bool = closest.isEvent && eventNoteHasBPMChange(cast closest);
							var oldBPMMap:Array<BPMChangeEvent> = removedTempo ? Conductor.copyBPMChanges() : null;
							var kind:String = !closest.isEvent ? 'note' : 'event';
							trace('Removed $kind at time: ${closest.strumTime}');
							if(!closest.isEvent)
								notes.remove(closest);
							else
								events.remove(cast (closest, EventMetaNote));

							selectedNotes.remove(closest);
							curRenderedNotes.remove(closest, true);
							addUndoAction(DELETE_NOTE, !closest.isEvent ? {notes: [closest]} : {events: [closest]});
							EditorSFX.playChartSound('note_delete', 0.75);
							if(removedTempo) adaptNotes(oldBPMMap, false);
						}
						if(selectedNotes.length == 1) onSelectNote();
						forceDataUpdate = true;
					}
					else if (!holdingAlt && FlxG.mouse.y >= gridBg.y && FlxG.mouse.y < gridBg.y + gridBg.height) // Add note
					{
						var strumTime:Float = Conductor.stepToSeconds(mouseStep);
						var targetSection:Int = sectionAtTime(strumTime);
						if(noteData >= 0)
						{
							trace('Added note at time: $strumTime');
							var didAdd:Bool = false;

							var noteSetupData:Array<Dynamic> = [strumTime, noteData, 0];
							var typeSelected:String = noteTypes[noteTypeDropDown.selectedIndex];
							if(typeSelected != null && typeSelected.length > 0)
								noteSetupData.push(typeSelected);

							var noteAdded:MetaNote = createNote(noteSetupData, targetSection);
							for (num in sectionFirstNoteID...notes.length)
							{
								var note = notes[num];
								if(note.strumTime >= strumTime)
								{
									notes.insert(num, noteAdded);
									didAdd = true;
									break;
								}
							}
							if(!didAdd) notes.push(noteAdded);

							if(!holdingAlt)
								resetSelectedNotes();
							
							noteAdded.dragging = true;
							selectedNotes.push(noteAdded);
							addUndoAction(ADD_NOTE, {notes: [noteAdded]});
							EditorSFX.playChartSound('note_place', 0.75);
						}
						else if(!lockedEvents)
						{
							trace('Added event at time: $strumTime');
							var didAdd:Bool = false;
							// prob gonna do that at another code
							var eventSetup:Array<String> = ['', '', ''];
							var addsTempo:Bool = eventDataIsBPMChange(cast eventSetup);
							var oldBPMMap:Array<BPMChangeEvent> = addsTempo ? Conductor.copyBPMChanges() : null;
							var eventAdded:EventMetaNote = createEvent([strumTime, [eventSetup]]);
							for (num in sectionFirstEventID...events.length)
							{
								var event = events[num];
								if(event.strumTime >= strumTime)
								{
									events.insert(num, eventAdded);
									didAdd = true;
									break;
								}
							}
							if(!didAdd) events.push(eventAdded);

							if(!holdingAlt)
								resetSelectedNotes();
							
							eventAdded.dragging = true;
							selectedNotes.push(eventAdded);
							addUndoAction(ADD_NOTE, {events: [eventAdded]});
							EditorSFX.playChartSound('note_place', 0.75);
							if(addsTempo)
							{
								adaptNotes(oldBPMMap, false);
								directTempoDragOldMap = Conductor.copyBPMChanges();
							}
						}
						onSelectNote();
						softReloadNotes();
					}
				}
			}
		}
		else if(!ignoreClickForThisFrame)
		{
			if(FlxG.mouse.justPressed)
				resetSelectedNotes();

			dummyArrow.visible = false;
		}
		ignoreClickForThisFrame = false;
		
		updateSelectedEvents(); // TODO:  do this only on demand instead (this is Not gonna do wonders)

		if (Conductor.songPosition != lastSongTime || forceDataUpdate)
		{
			var curTime:String = FlxStringUtil.formatTime(Conductor.songPosition / 1000, true);
			var songLength:String = (FlxG.sound.music != null) ? FlxStringUtil.formatTime(FlxG.sound.music.length / 1000, true) : '???';
			var str:String =  '$curTime / $songLength' +
							  '\n\nSection: $curSec' +
							  '\nBeat: $curBeat' +
							  '\nStep: $curStep' +
							  '\n\nBeat Snap: ${curQuant} / 16' +
							  '\nSelected: ${selectedNotes.length}';

			if(str != infoText.text)
			{
				infoText.text = str;
				if(infoText.autoSize) infoText.autoSize = false;
			}
			
			for (note in curRenderedNotes)
			{
				if (note == null) continue;
				
				var offsetTime:Float = note.strumTime + 1;
				var hitAlpha:Float = (FlxG.sound.music != null && FlxG.sound.music.playing ? .4 : .6);
				note.alpha = (offsetTime > Conductor.songPosition) ? 1 : hitAlpha;
				if (!note.isEvent && Conductor.songPosition > offsetTime && lastSongTime <= offsetTime)
					hitNote(note);
			}
			forceDataUpdate = false;
		}
		
		if(selectedNotes.length > 0 || selectedEvents.length > 0)
		{
			noteSelectionSine += elapsed;
			var sineValue:Float = 0.75 + Math.cos(Math.PI * noteSelectionSine * (isMovingNotes ? 8 : 2)) / 4;
			//trace(sineValue);

			var qPress = FlxG.keys.justPressed.Q;
			var ePress = FlxG.keys.justPressed.E;
			var addSus = (FlxG.keys.pressed.SHIFT ? 4 : 1);
			if(qPress) addSus *= -1;

			var noteSec:Int = 0;
			for (note in selectedNotes)
			{
				if(note == null || !note.exists) continue;
				
				note.animation.update(elapsed); //let selected notes be animated for better visibility
				
				if (note.dragging) {
					if (!FlxG.mouse.pressed) {
						note.dragging = false;
						if(note.isEvent)
						{
							events.sort(PlayState.sortByTime);
							if(directTempoDragOldMap != null && eventNoteHasBPMChange(cast note))
							{
								var oldMap:Array<BPMChangeEvent> = directTempoDragOldMap;
								directTempoDragOldMap = null;
								adaptNotes(oldMap, false);
							}
						}
					} else if (note.isEvent) {
						var shift:Bool = FlxG.keys.pressed.SHIFT;
						var targetStep:Float = Math.max(0, gridYToChartStep(FlxG.mouse.y, !shift));
						var strumTime:Float = Conductor.stepToSeconds(targetStep);
						note.setStrumTime(Math.max(-5000, strumTime));
						positionNoteYOnTime(note);
						cast (note, EventMetaNote).updateEventInfo();
						note.setColorTransform(1, 1, 1, note.alpha, -32 - 64, 64 - 64, 0 - 64);
						continue;
					} else {
						var shift:Bool = FlxG.keys.pressed.SHIFT;
						var endStep:Float = gridYToChartStep(FlxG.mouse.y, !shift);
						var endMs:Float = Conductor.stepToSeconds(Math.max(Conductor.getStep(note.strumTime), endStep));
						
						note.setSustainLength(endMs - note.strumTime, curZoom);
						note.setColorTransform(1, 1, 1, note.alpha, -32 - 64, 64 - 64, 0 - 64);
						
						continue;
					}
				}

				if(!note.isEvent)
				{
					if(charterFocus && qPress != ePress)
					{
						while(cachedSectionTimes.length > noteSec + 1 && cachedSectionTimes[noteSec + 1] <= note.strumTime)
							noteSec++;
						
						note.setSustainLength(Conductor.stepToSeconds(Math.round(Conductor.getStep(note.strumTime + note.sustainLength) * 2 + addSus) / 2) - note.strumTime, curZoom);
						if (selectedNotes.length == 1)
							susLengthStepper.value = note.sustainLength;
					}
				}
				
				note.setColorTransform(sineValue, sineValue, sineValue, note.alpha, -32, 64, 0);
			}
		}
		else noteSelectionSine = 0;
		
		if (prevNote != null && !selectedNotes.contains(prevNote)) {
			prevNote.setColorTransform(1, 1, 1, prevNote.alpha);
		}
		if (closestNote != null) {
			var selected:Bool = selectedNotes.contains(closestNote);
			
			var deleting:Bool = (!FlxG.keys.pressed.SHIFT && !holdingAlt && !closestNote.dragging);
			var m:Int = (FlxG.mouse.pressed || closestNote.dragging ? -64 : 128);
			var redM:Int = (deleting ? -153 : 0);
			
			closestNote.setColorTransform(1, 1, 1, closestNote.alpha, (selected && !deleting ? -32 : 0) + m, (selected && !deleting ? 64 : 0) + m + redM, m + redM);
		}

		outputTxt.alpha = outputAlpha;
		outputTxt.visible = (outputAlpha > 0);
		FlxG.camera.scroll.y = scrollY;
		lastFocus = PsychUIInputText.focusOn;
		
		if (metronomeStepper.value > 0 && FlxG.sound.music?.playing) { // sync metronome with audio delay
			if (Std.int(Conductor.getBeat(lastSongTime - delay)) != Std.int(Conductor.getBeat(Conductor.songPosition - delay)))
				EditorSFX.playChartSound('metronome_tick', metronomeStepper.value);
		}
		
		lastSongTime = Conductor.songPosition;
		
		postUpdate(elapsed);
	}
	
	function updateSelectedEvents():Void {
		if (lockedEvents)
			return selectedEvents.resize(0);
		
		var i:Int = (selectedEvents.length);
		while (-- i >= 0) {
			var event:SelectedEventData = selectedEvents[i];
			
			if (!events.contains(event.note))
				selectedEvents.remove(event);
		}
	}
	
	function hitNote(note:MetaNote) {
		if (note.ignoreNote) return;
		
		var songPlaying:Bool = (FlxG.sound.music != null && FlxG.sound.music.playing);
		var canPlayHitSound:Bool = (songPlaying && note.hitsoundChartEditor);
		var hitSoundPlayer:Bool = (hitsoundPlayerStepper.value > 0);
		var hitSoundOpp:Bool = (hitsoundOpponentStepper.value > 0);
		
		if (canPlayHitSound) {
			if(hitSoundPlayer && note.mustPress) {
				FlxG.sound.play(Paths.hitsound(), hitsoundPlayerStepper.value);
				hitSoundPlayer = false;
			} else if(hitSoundOpp && !note.mustPress) {
				FlxG.sound.play(Paths.hitsound(), hitsoundOpponentStepper.value);
				hitSoundOpp = false;
			}
		}

		if (songPlaying) {
			if (vortexEnabled) {
				var strumNote:StrumNote = strumLineNotes.members[note.songData[1]];
				if (strumNote != null) {
					strumNote.playAnim('confirm', true);
					strumNote.resetAnim = Math.max(Conductor.stepCrochet * 1.25, note.sustainLength) / 1000 / playbackRate;
				}
			}
			
			if (note.shouldPlayAnim()) {
				var buddy:EditorBuddy = note.mustPress ? bfBuddy : dadBuddy;
				if(buddy != null)
					buddy.holdSing(singAnimations[note.noteData % 4], note.sustainLength / 1000);
			}

			bumpEditorIcon(note);
		}
	}

	public override function beatHit(beat:Int):Void {
		super.beatHit(beat);
		
		if(bfBuddy != null && beat % bfBuddy.danceEveryNumBeats == 0) bfBuddy.dance();
		if(dadBuddy != null && beat % dadBuddy.danceEveryNumBeats == 0) dadBuddy.dance();
	}
	
	public override function stepHit(step:Int):Void {
		super.stepHit(step);

		if(bfBuddy != null) bfBuddy.replayHeldSing();
		if(dadBuddy != null) dadBuddy.replayHeldSing();
	}

	function moveSelectedNotes(noteData:Int = 0, lastY:Float) //This turns selected notes into moving notes
	{
		selectedNotes = getSelectedNotesWithEventGroups();
		movingTempoOldMap = null;
		for(note in selectedNotes)
			if(note != null && note.isEvent && eventNoteHasBPMChange(cast note))
			{
				movingTempoOldMap = Conductor.copyBPMChanges();
				break;
			}
		if(selectedNotes.length > 0)
			EditorSFX.playChartSound('note_drag', 0.7);
		var originalNotes:Array<MetaNote> = [];
		var originalEvents:Array<EventMetaNote> = [];
		var movedNotes:Array<MetaNote> = [];
		var movedEvents:Array<EventMetaNote> = [];
		for (note in selectedNotes)
		{
			if(note == null) continue;

			if(!note.isEvent)
			{
				notes.remove(note);
				var secNum:Int = sectionAtTime(note.strumTime);
				originalNotes.push(note);
				var mov:MetaNote = createNote(makeNoteDataCopy(note.songData, false), secNum);
				movingNotes.add(mov);
				movedNotes.push(mov);
			}
			else
			{
				events.remove(cast (note, EventMetaNote));
				originalEvents.push(cast (note, EventMetaNote));
				var mov:EventMetaNote = createEvent(makeNoteDataCopy(note.songData, true));
				movingNotes.add(mov);
				movedEvents.push(mov);
			}
		}
		selectedNotes = movingNotes.members.copy();
		isMovingNotes = true;
		movingNotesLastY = lastY;
		movingNotesLastData = noteData;
		movingNotes.sort(#if static (order, a, b) -> FlxSort.byValues(order, a.strumTime, b.strumTime) #else cast PlayState.sortByTime #end);
		addUndoAction(MOVE_NOTE, {originalNotes: originalNotes, originalEvents: originalEvents, movedNotes: movedNotes, movedEvents: movedEvents});
		softReloadNotes();
	}

	function stopMovingNotes() //This turns moving notes into saved notes
	{
		var pushedNotes:Array<MetaNote> = [];
		var pushedEvents:Array<EventMetaNote> = [];
		movingNotes.forEachAlive(function(note:MetaNote)
		{
			if(!note.isEvent)
			{
				notes.push(note);
				pushedNotes.push(note);
			}
			else
			{
				events.push(cast (note, EventMetaNote));
				pushedEvents.push(cast (note, EventMetaNote));
			}
		});
		notes.sort(PlayState.sortByTime);
		events.sort(PlayState.sortByTime);
		movingNotes.clear();
		isMovingNotes = false;
		if(movingTempoOldMap != null)
		{
			var oldMap:Array<BPMChangeEvent> = movingTempoOldMap;
			movingTempoOldMap = null;
			adaptNotes(oldMap, false);
		}
		else softReloadNotes();
	}

	function makeNoteDataCopy(originalData:Array<Dynamic>, isEvent:Bool)
	{
		var dataCopy:Array<Dynamic> = originalData.copy();
		if(isEvent)
		{
			var eventGrp:Array<Array<Dynamic>> = cast dataCopy[1].copy();
			for (num => subEvent in eventGrp)
				eventGrp[num] = subEvent.copy();

			dataCopy[1] = eventGrp;
		}
		return dataCopy;
	}

	function getSelectedNotesWithEventGroups(?base:Array<MetaNote>):Array<MetaNote>
	{
		var result:Array<MetaNote> = [];
		var source:Array<MetaNote> = base != null ? base : selectedNotes;

		for (note in source)
			if(note != null && !result.contains(note))
				result.push(note);

		for (event in selectedEvents)
		{
			if(event == null || event.note == null || event.event == null) continue;
			if(!event.note.events.contains(event.event)) continue;

			if(!result.contains(event.note))
				result.push(event.note);
		}

		return result;
	}

	function updateScrollY()
	{
		var chartStep:Float = Conductor.getStep(Conductor.songPosition);
		var direction:Int = downScroll ? -1 : 1;
		scrollY = chartStep * GRID_SIZE * curZoom * direction - (FlxG.height + (downScroll ? GRID_SIZE : -GRID_SIZE)) / 2;
	}

	function updateSelectionBox()
	{
		var diffX:Float = FlxG.mouse.viewX - selectionStart.x;
		var diffY:Float = FlxG.mouse.viewY - selectionStart.y;
		selectionBox.setPosition(selectionStart.x, selectionStart.y);

		if(diffX < 0) //Fixes negative X scale
		{
			diffX = Math.abs(diffX);
			selectionBox.x -= diffX;
		}
		if(diffY < 0) //Fixes negative Y scale
		{
			diffY = Math.abs(diffY);
			selectionBox.y -= diffY;
		}
		selectionBox.scale.set(diffX, diffY);
		selectionBox.updateHitbox();
	}

	function showOutput(message:String, isError:Bool = false, ?playSound:Bool = true)
	{
		trace(message);
		outputTxt.text = message;
		outputTxt.y = FlxG.height - outputTxt.height - 30;
		outputAlpha = 4;
		if(isError)
		{
			if(playSound && ClientPrefs.data.editorSFX)
				FlxG.sound.play(Paths.uiSound('cancelMenu'), 0.6);
			outputTxt.color = FlxColor.RED;
		}
		else
		{
			if(playSound && ClientPrefs.data.editorSFX)
				FlxG.sound.play(Paths.uiSound('scrollMenu'), 0.6);
			outputTxt.color = FlxColor.WHITE;
		}
	}

	function resetSelectedNotes()
	{
		for (note in selectedNotes)
		{
			if(note == null || !note.exists) continue;

			note.setColorTransform();
			if(note.animation.curAnim != null) note.animation.curAnim.curFrame = 0;
		}
		selectedEvents.resize(0);
		selectedNotes.resize(0);
		onSelectNote();
		forceDataUpdate = true;
	}

	function onSelectNote()
	{
		if(selectedNotes.length == 1) //Only one note selected
		{
			var note:MetaNote = selectedNotes[0];
			strumTimeStepper.value = note.strumTime;
			if(!note.isEvent) //Normal note
			{
				if(!note.isEvent)
				{
					susLengthLastVal = susLengthStepper.value = note.sustainLength;
					noteTypeDropDown.selectedIndex = Std.int(Math.max(0, noteTypes.indexOf(note.noteType)));
				}
				else
				{
					susLengthLastVal = susLengthStepper.value = 0;
					noteTypeDropDown.selectedLabel = '';
				}
			}
			
			if (note.isEvent) {
				var eventNote:EventMetaNote = cast selectedNotes[0];
				
				curEventSelected = (eventNote.events.length - 1);
				
				if (eventNote.events.length > 0 && selectedEvents.length == 0)
					selectedEvents.push({event: eventNote.events[curEventSelected], note: eventNote});
			}
		}
		else if(selectedNotes.length > 1)
		{
			susLengthStepper.min = -susLengthStepper.max;
			susLengthLastVal = susLengthStepper.value = 0;
			strumTimeStepper.value = selectedNotes[0].strumTime;
			noteTypeDropDown.selectedLabel = '';
		}
		forceDataUpdate = true;
	}

	function createGrids()
	{
		var destroyed:Bool = false;
		var stripes:Array<Int> = null;
		if(prevGridBg != null)
		{
			stripes = prevGridBg.stripes;
			remove(prevGridBg);
			remove(gridBg);
			remove(nextGridBg);
			prevGridBg = FlxDestroyUtil.destroy(prevGridBg);
			gridBg = FlxDestroyUtil.destroy(gridBg);
			nextGridBg = FlxDestroyUtil.destroy(nextGridBg);
			destroyed = true;
		}

		var columnCount:Int = (GRID_COLUMNS_PER_PLAYER * GRID_PLAYERS) + (SHOW_EVENT_COLUMN ? 1 : 0);
		gridBg = new ChartingGridSprite(columnCount, gridColors[0], gridColors[1]);
		gridBg.x = getEditorGridX(gridBg.width);

		prevGridBg = new ChartingGridSprite(columnCount, gridColorsOther[0], gridColorsOther[1]);
		nextGridBg = new ChartingGridSprite(columnCount, gridColorsOther[0], gridColorsOther[1]);
		prevGridBg.x = nextGridBg.x = gridBg.x;
		prevGridBg.stripes = nextGridBg.stripes = gridBg.stripes = stripes;
		
		if(destroyed)
		{
			insert(getFirstNull(), prevGridBg);
			insert(getFirstNull(), nextGridBg);
			insert(getFirstNull(), gridBg);
			loadSection();
		}
		else
		{
			add(prevGridBg);
			add(nextGridBg);
			add(gridBg);
		}
	}

	function getEditorGridX(width:Float):Float
	{
		return Math.max(LEFT_PANEL_X + 500, FlxG.width - width - GRID_RIGHT_MARGIN);
	}

	var cachedSectionRow:Array<Int>;
	var cachedSectionTimes:Array<Float>;
	var cachedSectionCrochets:Array<Float>;
	var cachedSectionBPMs:Array<Float>;
	function loadChart(song:SwagSong, ?events:SwagSong)
	{
		ChartingState.startOnTime = 0;
		
		PlayState.SONG = sanitizeEditorChart(song);
		PlayState.EVENTS = events;
		Song.ensureCameraMoveData(PlayState.SONG);
		if(Song.hasEventsNamed(PlayState.EVENTS, Song.CAMERA_FOCUS_EVENT))
			Song.removeEventsByName(PlayState.SONG, Song.CAMERA_FOCUS_EVENT);
		StageData.loadDirectory(PlayState.SONG);
		Conductor.bpm = PlayState.SONG.bpm;
	}

	function loadMusic(?killAudio:Bool = false)
	{
		setSongPlaying(false);
		var time:Float = Conductor.songPosition;

		if(killAudio)
		{
			var sndsToKill:Array<String> = [];
			for (key => snd in Paths.currentTrackedSounds)
			{
				//trace(key, snd);
				if(key.contains('/songs/${Paths.formatToSongPath(PlayState.SONG.song)}/') && snd != null)
				{
					sndsToKill.push(key);
					snd.close();
				}
			}

			for (key in sndsToKill)
			{
				Assets.cache.clear(key);
				Paths.currentTrackedSounds.remove(key);
				Paths.localTrackedAssets.remove(key);
			}
		}

		try
		{
			FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0);
			if(FlxG.sound.music == null)
				throw 'Instrumental did not create a music sound';
			FlxG.sound.music.pause();
			Conductor.songPosition = time;
			FlxG.sound.music.onComplete = (function() songFinished = true);
		}
		catch(e:Dynamic)
		{
			FlxG.log.error('Error loading song: $e');
			clearEditorMusic();
			songPlaying = false;
			_cacheSections();
			updatePresence();
			return;
		}

		@:privateAccess vocals.cleanup(true);
		@:privateAccess opponentVocals.cleanup(true);
		if (PlayState.SONG.needsVoices)
		{
			try
			{
				var playerVocals:Sound = Paths.voices(PlayState.SONG.song, (characterData.vocalsP1 == null || characterData.vocalsP1.length < 1) ? 'Player' : characterData.vocalsP1);
				vocals.loadEmbedded(playerVocals != null ? playerVocals : Paths.voices(PlayState.SONG.song));
				vocals.volume = 0;
				vocals.play();
				vocals.pause();
				vocals.time = time;
				
				var oppVocals:Sound = Paths.voices(PlayState.SONG.song, (characterData.vocalsP2 == null || characterData.vocalsP2.length < 1) ? 'Opponent' : characterData.vocalsP2);
				if(oppVocals != null && oppVocals.length > 0)
				{
					opponentVocals.loadEmbedded(oppVocals);
					opponentVocals.volume = 0;
					opponentVocals.play();
					opponentVocals.pause();
					opponentVocals.time = time;
				}
			}
			catch (e:Dynamic) {}
		}
		
		updatePresence();
		updateAudioVolume();
		updateWaveform();
		setPitch();
		_cacheSections();
	}

	function loadChartEditorMusic():Void
	{
		try
		{
			chartEditorMusic.loadEmbedded(Paths.editorMusic('chartingEditor'), true, false);
			chartEditorMusic.volume = 0;
			chartEditorMusic.play(true);
			updateChartEditorMusicVolume(true);
		}
		catch(e:Dynamic)
		{
			FlxG.log.warn('Could not load chart editor music: $e');
		}
	}

	function getChartEditorMusicTargetVolume():Float
	{
		if(!ClientPrefs.data.chartEditorMusic || (FlxG.sound.music != null && (FlxG.sound.music.playing || songPlaying)))
			return 0;

		return FlxMath.bound(ClientPrefs.data.chartEditorMusicVolume, 0, 1);
	}

	function updateChartEditorMusicVolume(?instant:Bool = false, ?delayFadeIn:Bool = false):Void
	{
		if(chartEditorMusic == null)
			return;

		if(ClientPrefs.data.chartEditorMusic && !chartEditorMusic.playing)
			chartEditorMusic.play(false);

		var targetVolume:Float = getChartEditorMusicTargetVolume();
		if(chartEditorMusicDelayTimer != null)
		{
			chartEditorMusicDelayTimer.cancel();
			chartEditorMusicDelayTimer.destroy();
			chartEditorMusicDelayTimer = null;
		}
		if(chartEditorMusicTween != null)
			chartEditorMusicTween.cancel();
		FlxTween.cancelTweensOf(chartEditorMusic);

		if(instant)
		{
			chartEditorMusic.volume = targetVolume;
			return;
		}

		if(delayFadeIn && targetVolume > chartEditorMusic.volume)
		{
			chartEditorMusicDelayTimer = new FlxTimer().start(1.4, function(_)
			{
				chartEditorMusicDelayTimer = null;
				chartEditorMusicTween = FlxTween.tween(chartEditorMusic, {volume: getChartEditorMusicTargetVolume()}, 0.65, {ease: FlxEase.quadOut});
			});
			return;
		}

		chartEditorMusicTween = FlxTween.tween(chartEditorMusic, {volume: targetVolume}, 0.65, {ease: FlxEase.quadOut});
	}
	
	override function updatePresence() {
		#if DISCORD_ALLOWED
		DiscordClient.changePresence('Chart Editor', 'Song: ' + PlayState.SONG.song);
		#end
	}

	function onSongComplete()
	{
		if(FlxG.sound.music == null)
			return;

		trace('song completed');
		setSongPlaying(false);
		FlxG.sound.music.time = vocals.time = opponentVocals.time = (FlxG.sound.music.length - 1);
		Conductor.songPosition = (FlxG.sound.music.time + Conductor.offset + delay);
		curSec = PlayState.SONG.notes.length - 1;
		forceDataUpdate = true;
	}

	function updateAudioVolume()
	{
		if(FlxG.sound.music != null)
			FlxG.sound.music.volume = instVolumeStepper.value;
		vocals.volume = playerVolumeStepper.value;
		opponentVocals.volume = opponentVolumeStepper.value;
		if(instMuteCheckBox.checked && FlxG.sound.music != null) FlxG.sound.music.volume = 0;
		if(playerMuteCheckBox.checked) vocals.volume = 0;
		if(opponentMuteCheckBox.checked) opponentVocals.volume = 0;
		updateChartEditorMusicVolume();
	}

	var playbackRate:Float = 1;
	function setPitch(?value:Null<Float>)
	{
		#if FLX_PITCH
		if(FlxG.sound.music == null) return;
		if(value == null) value = playbackRate;
		FlxG.sound.music.pitch = value;
		vocals.pitch = value;
		opponentVocals.pitch = value;
		#end
	}
	
	var songPlaying:Bool = false;
	function setSongPlaying(doPlay:Bool)
	{
		forceDataUpdate = true;
		songPlaying = doPlay;
		if(FlxG.sound.music == null)
		{
			songPlaying = false;
			updateChartEditorMusicVolume();
			return;
		}

		vocals.time = FlxG.sound.music.time;
		opponentVocals.time = FlxG.sound.music.time;
		
		FlxG.sound.music.pause();
		vocals.pause();
		opponentVocals.pause();
		if (doPlay) {
			FlxG.sound.music.time = vocals.time = opponentVocals.time = (Conductor.songPosition - Conductor.offset - delay);
		}

		for (note in strumLineNotes)
		{
			note.alpha = doPlay ? 1 : 0.4;
			if(!doPlay)
			{
				note.playAnim('static');
				note.resetAnim = 0;
			}
		}
		updateChartEditorMusicVolume(false, !doPlay);
	}
	
	function playMusic():Void {
		if(FlxG.sound.music == null) return;
		FlxG.sound.music.play();
		if (FlxG.sound.music.time < vocals.length) vocals.play(true, FlxG.sound.music.time);
		if (FlxG.sound.music.time < opponentVocals.length) opponentVocals.play(true, FlxG.sound.music.time);
		
		updateAudioVolume();
	}

	function reloadNotes()
	{
		selectedNotes = [];
		for (note in notes) if(note != null) note.destroy();
		for (event in events) if(event != null) event.destroy();
		notes = [];
		events = [];
		undoActions = [];
		
		for (secNum => section in PlayState.SONG.notes)
			for (note in section.sectionNotes)
				if (note != null)
					notes.push(createNote(note, secNum));
		
		for (eventBlob in [PlayState.SONG, PlayState.EVENTS]) {
			if (eventBlob?.events == null) continue;
			
			for (eventNum => event in eventBlob.events)
				if(event != null && (cachedSectionTimes.length < 1 || event[0] < cachedSectionTimes[cachedSectionTimes.length-1])) //dont spawn events over the time limit
					events.push(createEvent(event));
		}

		notes.sort(PlayState.sortByTime);
		events.sort(PlayState.sortByTime);

		trace('Note count: ${notes.length}');
		trace('Events count: ${events.length}');
		scrollDirectionUpdated();
	}

	function createNote(note:Dynamic, ?secNum:Null<Int> = null)
	{
		if(secNum == null) secNum = sectionAtTime(note[0]);
		var section = PlayState.SONG.notes[secNum];

		var daStrumTime:Float = note[0];
		var daNoteData:Int = Std.int(note[1] % GRID_COLUMNS_PER_PLAYER);
		var gottaHitNote:Bool = (note[1] < GRID_COLUMNS_PER_PLAYER);

		var swagNote:MetaNote = new MetaNote(daStrumTime, daNoteData, note, this);
		if (secNum != null) swagNote.section = secNum;
		swagNote.mustPress = gottaHitNote;
		swagNote.setSustainLength(note[2], curZoom);
		swagNote.useBlandSustains = !texturedSustains;
		swagNote.noteType = note[3];
		swagNote.scrollFactor.x = 0;

		swagNote.updateHitbox();
		if(swagNote.width > swagNote.height)
			swagNote.setGraphicSize(GRID_SIZE);
		else
			swagNote.setGraphicSize(0, GRID_SIZE);

		swagNote.updateHitbox();
		swagNote.active = false;
		positionNoteXByData(swagNote);
		positionNoteYOnTime(swagNote);
		return swagNote;
	}

	function createEvent(event:Dynamic)
	{
		var daStrumTime:Float = event[0];
		var swagEvent:EventMetaNote = new EventMetaNote(daStrumTime, event, this);
		swagEvent.scrollFactor.x = 0;
		swagEvent.x = gridBg.x;
		
		positionNoteYOnTime(swagEvent);
		return swagEvent;
	}

	function removeEditorEventsByName(eventName:String):Void
	{
		var i:Int = events.length - 1;
		while(i >= 0)
		{
			var event:EventMetaNote = events[i];
			if(event != null && Song.eventArrayHasEvent([event.songData], eventName))
			{
				Song.removeEventsFromArray([event.songData], eventName);
				var pack:Array<Dynamic> = event.songData != null && event.songData.length > 1 ? cast event.songData[1] : [];
				if(pack.length < 1)
				{
					event.destroy();
					events.remove(event);
					selectedNotes.remove(event);

					var j:Int = selectedEvents.length - 1;
					while(j >= 0)
					{
						if(selectedEvents[j].note == event)
							selectedEvents.remove(selectedEvents[j]);
						j--;
					}
				}
				else
					event.updateEventInfo();
			}
			i--;
		}
	}

	function _cacheSections()
	{
		var row:Int = 0;
		cachedSectionRow = [];
		cachedSectionTimes = [];
		cachedSectionCrochets = [];
		cachedSectionBPMs = [];

		if(PlayState.SONG == null)
		{
			cachedSectionRow.push(0);
			cachedSectionTimes.push(0);
			cachedSectionCrochets.push(0);
			cachedSectionBPMs.push(0);
			return;
		}

		Conductor.mapBPMChanges(PlayState.SONG, PlayState.EVENTS);
		for (secNum => section in PlayState.SONG.notes)
		{
			var secs:Null<Float> = cast section.sectionBeats;
			if(secs == null || Math.isNaN(secs) || secs <= 0) section.sectionBeats = 4;

			var time:Float = Conductor.stepToSeconds(row);
			var bpm:Float = Conductor.getBPMFromStep(row).bpm;
			cachedSectionRow.push(row);
			cachedSectionTimes.push(time);
			cachedSectionCrochets.push(Conductor.calculateCrochet(bpm));
			cachedSectionBPMs.push(bpm);

			var rowRound:Int = Math.round(4 * section.sectionBeats);
			row += rowRound;
		}

		if(FlxG.sound.music != null) //Created sections to fill blank space
		{
			var lastSection = PlayState.SONG.notes[PlayState.SONG.notes.length-1];
			var sectionBeats:Int = lastSection != null ? lastSection.sectionBeats : 4;
			var rowRound:Int = Math.round(4 * sectionBeats);
			var mustHitSec:Bool = lastSection != null ? lastSection.mustHitSection : true;
			var altAnimSec:Bool = lastSection != null ? lastSection.altAnim : false;
			var gfSec:Bool = lastSection != null ? lastSection.gfSection : false;

			while(Conductor.stepToSeconds(row) < FlxG.sound.music.length)
			{
				var time:Float = Conductor.stepToSeconds(row);
				var bpm:Float = Conductor.getBPMFromStep(row).bpm;
				PlayState.SONG.notes.push({
					sectionNotes: [],
					sectionBeats: sectionBeats,
					mustHitSection: mustHitSec,
					bpm: bpm,
					changeBPM: false,
					altAnim: altAnimSec,
					gfSection: gfSec
				});

				cachedSectionRow.push(row);
				cachedSectionTimes.push(time);
				cachedSectionCrochets.push(Conductor.calculateCrochet(bpm));
				cachedSectionBPMs.push(bpm);

				row += rowRound;
			}
		}
		cachedSectionRow.push(row);
		cachedSectionTimes.push(Conductor.stepToSeconds(row));
	}

	var showPreviousSection:Bool = true;
	var showNextSection:Bool = true;
	var showNoteTypeLabels:Bool = true;
	var forceDataUpdate:Bool = true;
	var lastVirtualizedStep:Float = Math.NaN;
	function scrollDirectionUpdated() {
		timeLine.y = (FlxG.height + (downScroll ? GRID_SIZE : -GRID_SIZE) - timeLine.height) * .5;
		gridBg.flipY = prevGridBg.flipY = nextGridBg.flipY = waveformSprite.flipY = downScroll;
		waveformCacheZoom = -1;
		
		loadSection();
	}
	function loadSection(?sec:Null<Int> = null)
	{
		if(sec != null) curSec = sec;
		curSec = Std.int(FlxMath.bound(curSec, 0, PlayState.SONG.notes.length-1));
		Conductor.setCurrentBPM(Conductor.getBPMFromSeconds(Conductor.songPosition).bpm);

		// infinite grid
		prevGridBg.visible = nextGridBg.visible = false;
		var totalRows:Float = Math.max(1, cachedSectionRow[cachedSectionRow.length - 1] * curZoom);
		gridBg.rows = totalRows;
		gridBg.y = downScroll ? -gridBg.height : 0;
		gridBg.visible = true;
		gridBg.sectionLineRows = [for(row in cachedSectionRow) row * curZoom];
		gridBg.updateStripes();

		eventLockOverlay.y = gridBg.y;
		eventLockOverlay.scale.y = gridBg.height;
		eventLockOverlay.updateHitbox();

		softReloadNotes();
		updateHeads();
		
		forEachRenderedNote((note:MetaNote) -> refreshNotePosition(note));

		var sec = getCurChartSection();
		if(sec != null)
		{
			gfSectionCheckBox.checked = sec.gfSection;
			// altAnimSectionCheckBox.checked = sec.altAnim;
			changeBpmCheckBox.checked = false;
			changeBpmStepper.value = Conductor.getBPMFromSeconds(Conductor.songPosition).bpm;
			beatsPerSecStepper.value = sec.sectionBeats;

			strumTimeStepper.step = Conductor.getStepCrotchetAtTime(Conductor.songPosition);
			susLengthStepper.step = Conductor.getStepCrotchetAtTime(Conductor.songPosition) / 2;
			susLengthStepper.max = susLengthStepper.step * 128;
			if(selectedNotes.length > 1) susLengthStepper.min = -susLengthStepper.max;
			else susLengthStepper.min = 0;
		}
		gridBg.vortexLineEnabled = vortexEnabled;
		gridBg.vortexLineSpace = GRID_SIZE * 4 * curZoom;
		updateWaveform();
		updateScrollY();
	}

	function softReloadNotes(onlyCurrent:Bool = false)
	{
		behindRenderedNotes.clear();
		curRenderedNotes.clear();

		var centerStep:Float = Conductor.getStep(Conductor.songPosition);
		lastVirtualizedStep = centerStep;
		var visibleRadius:Float = (FlxG.height * 0.5 + GRID_SIZE * 3) / Math.max(1, GRID_SIZE * curZoom);
		var minStep:Float = centerStep - visibleRadius;
		var maxStep:Float = centerStep + visibleRadius;
		function visibleFilter(note:MetaNote)
		{
			var noteStep:Float = Conductor.getStep(note.strumTime);
			var endStep:Float = note.isEvent ? noteStep : Conductor.getStep(note.strumTime + note.sustainLength);
			return endStep >= minStep && noteStep <= maxStep;
		}

		var firstNote:Bool = false;
		var firstEvent:Bool = false;
		sectionFirstNoteID = 0;
		sectionFirstEventID = 0;
		for (num => note in notes)
		{
			if(note != null && visibleFilter(note))
			{
				if(!firstNote) sectionFirstNoteID = num;
				firstNote = true;
				note.revive();
				note.visible = true;
				curRenderedNotes.add(note);
				// NOTES DON'T WILL DISAPPEAR AGAIN
				refreshNotePosition(note);
				note.noteType = note.noteType;
				note.alpha = (Conductor.songPosition - 1 > note.strumTime) ? .6 : 1;
				if(note.hasSustain) note.updateSustainToZoom(curZoom);
			}
		}

		if(SHOW_EVENT_COLUMN)
		{
			for (num => event in events)
			{
				if(event != null && visibleFilter(event))
				{
					if(!firstEvent) sectionFirstEventID = num;
					firstEvent = true;
					event.revive();
					event.visible = true;
					curRenderedNotes.add(event);
					refreshNotePosition(event);
					event.alpha = (Conductor.songPosition - 1 > event.strumTime) ? .6 : 1;
				}
			}
		}
	}

	function getMinNoteTime(sec:Int)
	{
		var minTime:Float = Math.NEGATIVE_INFINITY;
		if(sec > 0)
			minTime = cachedSectionTimes[sec];
		return minTime;
	}

	function getMaxNoteTime(sec:Int)
	{
		var maxTime:Float = Math.POSITIVE_INFINITY;
		if(sec < cachedSectionTimes.length)
			maxTime = cachedSectionTimes[sec + 1];
		return maxTime;
	}

	function positionNoteXByData(note:MetaNote, ?data:Null<Int> = null)
	{
		if(data == null) data = note.songData[1];

		var noteX:Float = gridBg.x + (GRID_SIZE - note.width) / 2;
		if(SHOW_EVENT_COLUMN) noteX += GRID_SIZE;

		noteX += GRID_SIZE * data;
		note.x = noteX;
		//trace(gridBg.x, noteX);
	}
	
	function forEachRenderedNote(func:MetaNote -> Void) {
		for (grp in [curRenderedNotes, behindRenderedNotes]) {
			for (note in grp)
				func(note);
		}
	}
	function positionNoteYOnTime(note:MetaNote) {
		var noteY:Float = Conductor.getStep(note.strumTime);
		noteY = Math.max(noteY, -150);
		note.chartY = noteY;
		refreshNotePosition(note);
	}
	function refreshNotePosition(note:MetaNote) {
		note.y = calculateY(note);
		note.downScroll = downScroll;
	}
	function calculateY(note:MetaNote) {
		var y:Float = note.chartY * GRID_SIZE * curZoom * (downScroll ? -1 : 1) + (GRID_SIZE / 2 - note.height / 2);
		if (downScroll)
			y -= GRID_SIZE;
		return y;
	}

	inline function getSnapStep():Float
	{
		return 16 / curQuant;
	}

	inline function snapChartStep(step:Float):Float
	{
		var snap:Float = getSnapStep();
		return Math.round(step / snap) * snap;
	}

	function gridYToChartStep(worldY:Float, snap:Bool = true):Float
	{
		var pixels:Float = !downScroll
			? worldY - gridBg.y
			: gridBg.y + gridBg.height - worldY - GRID_SIZE;
		var step:Float = pixels / Math.max(0.0001, GRID_SIZE * curZoom);
		if(!snap) return step;

		// mf got me angry by just not going up
		var interval:Float = getSnapStep();
		var normalized:Float = step / interval;
		return (downScroll ? Math.ceil(normalized - 0.000001) : Math.floor(normalized + 0.000001)) * interval;
	}

	function chartStepToGridY(step:Float):Float
	{
		return !downScroll
			? gridBg.y + step * GRID_SIZE * curZoom
			: gridBg.y + gridBg.height - step * GRID_SIZE * curZoom - GRID_SIZE;
	}

	function sectionAtStep(step:Float):Int
	{
		var low:Int = 0;
		var high:Int = Std.int(Math.max(0, cachedSectionRow.length - 2));
		while(low < high)
		{
			var mid:Int = Math.ceil((low + high) * 0.5);
			if(cachedSectionRow[mid] <= step + SECTION_STEP_EPSILON) low = mid;
			else high = mid - 1;
		}
		return Std.int(FlxMath.bound(low, 0, PlayState.SONG.notes.length - 1));
	}

	inline function sectionAtTime(time:Float):Int
		return sectionAtStep(Conductor.getStep(time));

	inline function stepIsInSection(step:Float, section:Int):Bool
	{
		if(section < 0 || section + 1 >= cachedSectionRow.length) return false;
		return step >= cachedSectionRow[section] - SECTION_STEP_EPSILON &&
			step < cachedSectionRow[section + 1] - SECTION_STEP_EPSILON;
	}

	inline function noteIsInSection(note:MetaNote, section:Int):Bool
	{
		return note != null && stepIsInSection(Conductor.getStep(note.strumTime), section);
	}

	var characterData:Dynamic = {};
	function updateJsonData():Void
	{
		for (i in 1...GRID_PLAYERS+1)
		{
			//trace('adding iconP$i');
			var data:CharacterFile = loadCharacterFile(Reflect.field(PlayState.SONG, 'player$i'));
			Reflect.setField(characterData, 'iconP$i', data != null && data.healthicon != null ? data.healthicon : 'face');
			Reflect.setField(characterData, 'vocalsP$i', data != null && data.vocals_file != null ? data.vocals_file : '');
		}
	}
	
	var _lastSec:Int = -1;
	var _lastGfSection:Null<Bool> = null;
	function updateHeads(ignoreCheck:Bool = false):Void
	{
		var curSecData:SwagSection = PlayState.SONG.notes[curSec];
		var isGfSection:Bool = (curSecData != null && curSecData.gfSection == true);
		if(_lastGfSection == isGfSection && _lastSec == curSec && !ignoreCheck) return; //optimization

		for (i in 0...GRID_PLAYERS)
		{
			var icon:HealthIcon = icons[i];
			//trace('changing iconP${icon.ID}');
			var iconName:String = Reflect.field(characterData, 'iconP${icon.ID}');
			icon.changeIcon(iconName);
		}

		if(icons.length > 1)
		{
			var iconP1:HealthIcon = icons[0];
			var iconP2:HealthIcon = icons[1];
			var mustHitSection:Bool = (curSecData != null && curSecData.mustHitSection == true);
			if (isGfSection)
			{
				if (mustHitSection)
					iconP1.changeIcon('gf');
				else
					iconP2.changeIcon('gf');
			}

		}
		_lastGfSection = isGfSection;
		_lastSec = curSec;
		positionEditorIcons();
	}

	function positionEditorIcons():Void {
		if(icons == null || icons.length < 1 || gridBg == null)
			return;

		for (i in 0...icons.length)
		{
			var icon:HealthIcon = icons[i];
			if(icon == null) continue;

			var baseSize:Float = HealthIcon.ICON_SIZE * EDITOR_ICON_SCALE;
			var centerY:Float = 16 + baseSize * 0.5;
			var centerX:Float = (i == 0) ? gridBg.x - 20 - baseSize * 0.5 : gridBg.x + gridBg.width + 20 + baseSize * 0.5;
			icon.centerIconOn(centerX, centerY);
		}
	}

	function updateEditorIcons(elapsed:Float):Void {
		if(icons == null || icons.length < 1)
			return;

		for (i in 0...icons.length)
		{
			var icon:HealthIcon = icons[i];
			if(icon == null) continue;

			if(iconBumpTimers[i] > 0)
				iconBumpTimers[i] = Math.max(0, iconBumpTimers[i] - elapsed * 5.5);

			var targetScale:Float = EDITOR_ICON_SCALE + (EDITOR_ICON_BUMP_SCALE * iconBumpTimers[i]);
			icon.scale.set(targetScale, targetScale);
		}
		positionEditorIcons();

		for (icon in icons)
			if(icon != null)
				icon.alpha = FlxMath.lerp(icon.alpha, mouseOverEditorIcon(icon) ? 0.22 : 1, Math.min(1, elapsed * 12));
	}

	function mouseOverEditorIcon(icon:HealthIcon):Bool
	{
		var camera:FlxCamera = icon.camera ?? FlxG.camera;
		var pos:FlxPoint = icon.getScreenPosition(null, camera);
		var mouse:FlxPoint = FlxG.mouse.getScreenPosition(camera);
		var over:Bool = mouse.x >= pos.x && mouse.x <= pos.x + icon.width && mouse.y >= pos.y && mouse.y <= pos.y + icon.height;
		pos.put();
		mouse.put();
		return over;
	}

	function bumpEditorIcon(note:MetaNote):Void {
		var index:Int = note.mustPress ? 0 : 1;
		if(index >= 0 && index < iconBumpTimers.length)
			iconBumpTimers[index] = 1;
	}

	var playbackSlider:PsychUISlider;

	var mouseSnapCheckBox:PsychUICheckBox;
	var ignoreProgressCheckBox:PsychUICheckBox;
	var hitsoundPlayerStepper:PsychUINumericStepper;
	var hitsoundOpponentStepper:PsychUINumericStepper;
	var metronomeStepper:PsychUINumericStepper;

	var instVolumeStepper:PsychUINumericStepper;
	var instMuteCheckBox:PsychUICheckBox;
	var playerVolumeStepper:PsychUINumericStepper;
	var playerMuteCheckBox:PsychUICheckBox;
	var opponentVolumeStepper:PsychUINumericStepper;
	var opponentMuteCheckBox:PsychUICheckBox;
	
	var vortexEditorCheckBox:PsychUICheckBox;
	var autoloadEventCheckBox:PsychUICheckBox;
	function addChartingTab()
	{
		var tab_group = mainBox.getTab('Charting').menu;
		var objX = 10;
		var objY = 10;

		var txt = new FlxText(objX, objY, 280, "Any options here won't actually affect gameplay!");
		txt.alignment = CENTER;
		tab_group.add(txt);

		objY += 25;
		playbackSlider = new PsychUISlider(50, objY, function(v:Float) setPitch(playbackRate = v), 1, 0.1, 5.0, 200);
		playbackSlider.label = 'Playback Rate';
		
		objY += 60;
		mouseSnapCheckBox = new PsychUICheckBox(objX, objY, 'Mouse Scroll Snap', 100, function() chartEditorSave.data.mouseScrollSnap = mouseSnapCheckBox.checked);
		mouseSnapCheckBox.checked = chartEditorSave.data.mouseScrollSnap;

		ignoreProgressCheckBox = new PsychUICheckBox(objX + 150, objY, 'Ignore Progress Warnings', 100, function() chartEditorSave.data.ignoreProgressWarns = ignoreProgressCheckBox.checked);
		ignoreProgressCheckBox.checked = chartEditorSave.data.ignoreProgressWarns;

		objY += 45;
		metronomeStepper = new PsychUINumericStepper(objX, objY, 0.2, 0, 0, 1, 1);
		hitsoundPlayerStepper = new PsychUINumericStepper(objX + 100, objY, 0.2, 0, 0, 1, 1);
		hitsoundOpponentStepper = new PsychUINumericStepper(objX + 200, objY, 0.2, 0, 0, 1, 1);

		objY += 35;
		instVolumeStepper = new PsychUINumericStepper(objX, objY, 0.1, 0.6, 0, 1, 1);
		instVolumeStepper.onValueChange = updateAudioVolume;
		playerVolumeStepper = new PsychUINumericStepper(objX + 100, objY, 0.1, 1, 0, 1, 1);
		playerVolumeStepper.onValueChange = updateAudioVolume;
		opponentVolumeStepper = new PsychUINumericStepper(objX + 200, objY, 0.1, 1, 0, 1, 1);
		opponentVolumeStepper.onValueChange = updateAudioVolume;

		objY += 25;
		instMuteCheckBox = new PsychUICheckBox(objX, objY, 'Mute', 60, updateAudioVolume);
		playerMuteCheckBox = new PsychUICheckBox(objX + 100, objY, 'Mute', 60, updateAudioVolume);
		opponentMuteCheckBox = new PsychUICheckBox(objX + 200, objY, 'Mute', 60, updateAudioVolume);

		tab_group.add(playbackSlider);
		tab_group.add(mouseSnapCheckBox);
		tab_group.add(ignoreProgressCheckBox);

		tab_group.add(new FlxText(hitsoundPlayerStepper.x, hitsoundPlayerStepper.y - 13, 100, 'Player Hitsound:'));
		tab_group.add(new FlxText(hitsoundOpponentStepper.x, hitsoundOpponentStepper.y - 13, 100, 'Opp. Hitsound:'));
		tab_group.add(new FlxText(metronomeStepper.x, metronomeStepper.y - 13, 100, 'Metronome:'));
		tab_group.add(hitsoundPlayerStepper);
		tab_group.add(hitsoundOpponentStepper);
		tab_group.add(metronomeStepper);
		
		tab_group.add(new FlxText(instVolumeStepper.x, instVolumeStepper.y - 13, 100, 'Instrumental:'));
		tab_group.add(new FlxText(playerVolumeStepper.x, playerVolumeStepper.y - 13, 100, 'Player Vocals:'));
		tab_group.add(new FlxText(opponentVolumeStepper.x, opponentVolumeStepper.y - 13, 100, 'Opp. Vocals:'));
		tab_group.add(instVolumeStepper);
		tab_group.add(instMuteCheckBox);
		tab_group.add(playerVolumeStepper);
		tab_group.add(playerMuteCheckBox);
		tab_group.add(opponentVolumeStepper);
		tab_group.add(opponentMuteCheckBox);
		
		objY += 32;

		vortexEditorCheckBox = new PsychUICheckBox(objX, objY, 'Vortex Editor', 100, function() {
			setVortexEditorEnabled(vortexEditorCheckBox.checked);
		});
		vortexEditorCheckBox.checked = vortexEnabled;
		tab_group.add(vortexEditorCheckBox);

		autoloadEventCheckBox = new PsychUICheckBox(objX + 150, objY, 'Load Events Automatically', 100, function() {
			setAutoLoadEvents(autoloadEventCheckBox.checked);
		});
		autoloadEventCheckBox.checked = autoLoadEvents;
		tab_group.add(autoloadEventCheckBox);
	}

	function setVortexEditorEnabled(enabled:Bool):Void
	{
		vortexEnabled = enabled;
		if(vortexEditorCheckBox != null)
			vortexEditorCheckBox.checked = enabled;
		vortexIndicator.visible = strumLineNotes.visible = strumLineNotes.active = vortexEnabled;
		chartEditorSave.data.vortex = vortexEnabled;

		for (note in strumLineNotes) {
			note.playAnim('static');
			note.resetAnim = 0;
		}
		prevGridBg.vortexLineEnabled = gridBg.vortexLineEnabled = nextGridBg.vortexLineEnabled = vortexEnabled;
	}

	function setAutoLoadEvents(enabled:Bool):Void
	{
		autoLoadEvents = enabled;
		if(autoloadEventCheckBox != null)
			autoloadEventCheckBox.checked = enabled;
		chartEditorSave.data.autoLoadEvents = autoLoadEvents;
	}

	var noRGBCheckBox:PsychUICheckBox;
	var noteTextureInputText:PsychUIInputText;
	var noteSplashesInputText:PsychUIInputText;
	var holdSplashesInputText:PsychUIInputText;
	var cameraMoveCheckBox:PsychUICheckBox;
	var cameraMoveIntensityStepper:PsychUINumericStepper;
	var cameraMoveSpeedStepper:PsychUINumericStepper;
	var cameraMoveOffsetStepper:PsychUINumericStepper;
	var cameraMoveControls:Array<FlxSprite> = [];
	function addDataTab()
	{
		var tab_group = mainBox.getTab('Data').menu;
		var objX = 10;
		var objY = 25;
		noRGBCheckBox = new PsychUICheckBox(objX, objY, 'Disable Note RGB', 100, updateNotesRGB);
		
		objY += 40;
		noteTextureInputText = new PsychUIInputText(objX, objY, 120, '');
		noteTextureInputText.unfocus = function()
		{
			var changed:Bool = false;
			if(PlayState.SONG.arrowSkin != noteTextureInputText.text) changed = true;
			PlayState.SONG.arrowSkin = noteTextureInputText.text.trim();
			if(PlayState.SONG.arrowSkin.trim().length < 1) PlayState.SONG.arrowSkin = null;

			if(changed)
			{
				var textureLoad:String = noteTextureInputText.text;
				var changedTexture:Bool = false;
				
				for (note in notes) {
					if (note == null) continue;
					
					var oldTexture:String = note.graphic?.key;
					note.texture = textureLoad;
					if (note.graphic?.key == oldTexture) {
						break;
					} else {
						changedTexture = true;
					}
					
					if (note.width > note.height) {
						note.setGraphicSize(GRID_SIZE);
					} else {
						note.setGraphicSize(0, GRID_SIZE);
					}
					
					note.updateHitbox();
					positionNoteXByData(note);
				}
				
				if (changedTexture) {	
					var startX:Float = gridBg.x;
					var startY:Float = (FlxG.height - GRID_SIZE) / 2;
					
					for (i => strum in strumLineNotes.members) {
						if (strum == null) continue;
						var tex:String = noteTextureInputText.text;
						if (tex.trim() == '') { // ok
							tex = Note.defaultNoteSkin;
							var customSkin:String = tex + Note.getNoteSkinPostfix();
							if (Paths.fileExists('images/$customSkin.png', IMAGE)) tex = customSkin;
						}
						strum.texture = tex;
						
						if(strum.width > strum.height)
							strum.setGraphicSize(GRID_SIZE);
						else
							strum.setGraphicSize(0, GRID_SIZE);
						
						strum.playAnim('static');
						strum.updateHitbox();
						
						strum.x = startX + (i * GRID_SIZE) + (GRID_SIZE - strum.width) / 2;
						strum.y = startY + (GRID_SIZE - strum.height) / 2;
						if (SHOW_EVENT_COLUMN) strum.x += GRID_SIZE;
					}
					if(noteTextureInputText.text.trim().length > 0) showOutput('Reloaded notes to: "$textureLoad"');
					else showOutput('Reloaded notes to default texture');
					
				}
				else showOutput('ERROR: "$textureLoad" not found.', true);
			}
		};

		noteSplashesInputText = new PsychUIInputText(objX + 140, objY, 120, '');
		noteSplashesInputText.onChange = function(old:String, cur:String)
		{
			PlayState.SONG.splashSkin = cur;
			if(cur.trim().length < 1) PlayState.SONG.splashSkin = null;
		}

		holdSplashesInputText = new PsychUIInputText(objX + 280, objY, 120, '');
		holdSplashesInputText.onChange = function(old:String, cur:String)
		{
			PlayState.SONG.holdSplashSkin = cur;
			if(cur.trim().length < 1) PlayState.SONG.holdSplashSkin = null;
		}

		var camX:Float = objX + 195;
		var camY:Float = 25;
		cameraMoveCheckBox = new PsychUICheckBox(camX, camY, 'Camera Move', 115, function()
		{
			Song.ensureCameraMoveData(PlayState.SONG).enabled = cameraMoveCheckBox.checked;
			refreshCameraMoveControls();
		});

		camY = objY + 60;
		cameraMoveIntensityStepper = new PsychUINumericStepper(objX, camY, 0.1, 1, 0, 10, 2, 70);
		cameraMoveIntensityStepper.onValueChange = function()
			Song.ensureCameraMoveData(PlayState.SONG).intensity = cameraMoveIntensityStepper.value;

		cameraMoveSpeedStepper = new PsychUINumericStepper(objX + 140, camY, 0.1, 1, 0, 10, 2, 70);
		cameraMoveSpeedStepper.onValueChange = function()
			Song.ensureCameraMoveData(PlayState.SONG).speed = cameraMoveSpeedStepper.value;

		cameraMoveOffsetStepper = new PsychUINumericStepper(objX + 280, camY, 1, 30, 0, 999, 0, 70);
		cameraMoveOffsetStepper.onValueChange = function()
			Song.ensureCameraMoveData(PlayState.SONG).offset = cameraMoveOffsetStepper.value;

		var cameraMoveIntensityText:FlxText = new FlxText(cameraMoveIntensityStepper.x, cameraMoveIntensityStepper.y - 15, 90, 'Intensity:');
		var cameraMoveSpeedText:FlxText = new FlxText(cameraMoveSpeedStepper.x, cameraMoveSpeedStepper.y - 15, 90, 'Speed:');
		var cameraMoveOffsetText:FlxText = new FlxText(cameraMoveOffsetStepper.x, cameraMoveOffsetStepper.y - 15, 90, 'Offset:');
		cameraMoveControls = [
			cameraMoveIntensityText,
			cameraMoveIntensityStepper,
			cameraMoveSpeedText,
			cameraMoveSpeedStepper,
			cameraMoveOffsetText,
			cameraMoveOffsetStepper
		];
	
		tab_group.add(noRGBCheckBox);

		tab_group.add(new FlxText(noteTextureInputText.x, noteTextureInputText.y - 15, 100, 'Note Texture:'));
		tab_group.add(new FlxText(noteSplashesInputText.x, noteSplashesInputText.y - 15, 120, 'Note Splashes Texture:'));
		tab_group.add(new FlxText(holdSplashesInputText.x, holdSplashesInputText.y - 15, 120, 'Hold Splashes Texture:'));
		tab_group.add(noteTextureInputText);
		tab_group.add(noteSplashesInputText);
		tab_group.add(holdSplashesInputText);
		tab_group.add(cameraMoveCheckBox);
		for(control in cameraMoveControls)
			tab_group.add(control);

	}

	function openVisualListPicker(kind:ListKind, dropdown:PsychUIDropDownMenu, values:Array<String>, rawCategories:Array<ListCategoryData>,
		?displayNames:Map<String, String>):Bool
	{
		if(dropdown == null || values == null || values.length < 1 || !fileDialog.completed)
			return false;

		var nonEmptyValues:Array<String> = [];
		var hasEmpty:Bool = false;
		for(value in values)
		{
			var normalized:String = value == null ? '' : value.trim();
			if(normalized.length < 1)
				hasEmpty = true;
			else if(!nonEmptyValues.contains(normalized))
				nonEmptyValues.push(normalized);
		}

		var visualCategories:Array<ListCategoryData> = ListLoader.categorize(rawCategories, nonEmptyValues);
		if(hasEmpty)
			visualCategories.insert(0, {category: 'None', names: [''], source: '', modded: false});

		var selectedIndex:Int = dropdown.selectedIndex;
		var selected:String = selectedIndex >= 0 && selectedIndex < values.length ? values[selectedIndex] : '';
		upperBox.isMinimized = true;
		upperBox.bg.visible = false;
		openSubState(new VisualListSubState(kind, visualCategories, selected, function(value:String)
		{
			var index:Int = values.indexOf(value);
			if(index >= 0)
				dropdown.selectOption(index);
		}, chartEditorSave.data.visualListBlur ?? true, displayNames));
		return true;
	}

	function refreshCameraMoveControls():Void
	{
		if(PlayState.SONG == null || cameraMoveCheckBox == null) return;

		var data = Song.ensureCameraMoveData(PlayState.SONG);
		cameraMoveCheckBox.checked = data.enabled == true;
		if(cameraMoveIntensityStepper != null) cameraMoveIntensityStepper.value = data.intensity;
		if(cameraMoveSpeedStepper != null) cameraMoveSpeedStepper.value = data.speed;
		if(cameraMoveOffsetStepper != null) cameraMoveOffsetStepper.value = data.offset;

		for(control in cameraMoveControls)
			if(control != null) control.visible = cameraMoveCheckBox.checked;
	}

	var characterVisualCategories:Array<ListCategoryData> = [];
	var stageVisualCategories:Array<ListCategoryData> = [];
	var scriptCharacterScanTimer:Float = 0;
	var scriptCharacterSignature:String = null;
	var curEventSelected:Int = 0;

	inline function eventDataIsBPMChange(data:Array<Dynamic>):Bool
	{
		return data != null && data.length > 0 && Song.isBPMChangeEventName(Std.string(data[0]));
	}

	function eventNoteHasBPMChange(note:EventMetaNote):Bool
	{
		if(note?.events == null) return false;
		for(data in note.events)
			if(eventDataIsBPMChange(cast data)) return true;
		return false;
	}

	function characterTagFromScriptName(characterName:String):String
	{
		if(characterName == null)
			return null;

		var normalized:String = characterName.replace('\\', '/');
		var split:Array<String> = normalized.split('/');
		var tag:String = split[split.length - 1].trim();
		return tag.length > 0 ? tag.replace('.', '') : null;
	}

	function updateScriptCharacterDropdownData(elapsed:Float):Void
	{
		if(noteTypeDropDown == null)
			return;

		scriptCharacterScanTimer -= elapsed;
		if(scriptCharacterScanTimer > 0)
			return;
		scriptCharacterScanTimer = 0.75;

		var data = getScriptCreatedCharacterData();
		data.tags.sort(Reflect.compare);
		data.noteTypes.sort(Reflect.compare);
		var signature:String = data.tags.join('|') + '::' + data.noteTypes.join('|');
		if(scriptCharacterSignature == null)
		{
			scriptCharacterSignature = signature;
			return;
		}
		if(signature != scriptCharacterSignature)
		{
			scriptCharacterSignature = signature;
			reloadNotesDropdowns();
		}
	}

	function collectCreateCharMatches(text:String, tags:Array<String>, noteTypes:Array<String>):Void
	{
		if(text == null || text.length < 1)
			return;

		var tagRegex:EReg = ~/(?:createChar|createCharacter)\s*\(\s*(['"])([^'"]+)\1/;
		var rest:String = text;
		while(tagRegex.match(rest))
		{
			var tag:String = characterTagFromScriptName(tagRegex.matched(2));
			if(tag != null && !tags.contains(tag))
				tags.push(tag);
			rest = tagRegex.matchedRight();
		}

		var noteRegex:EReg = ~/(?:createChar|createCharacter)\s*\(\s*(['"])([^'"]+)\1\s*,\s*[^,\)]*\s*,\s*[^,\)]*\s*,\s*(['"])([^'"]+)\3/;
		rest = text;
		while(noteRegex.match(rest))
		{
			var noteType:String = noteRegex.matched(4).trim();
			if(noteType.length > 0 && !noteTypes.contains(noteType))
				noteTypes.push(noteType);
			rest = noteRegex.matchedRight();
		}
	}

	function getScriptCreatedCharacterData():{tags:Array<String>, noteTypes:Array<String>}
	{
		var tags:Array<String> = [];
		var noteTypes:Array<String> = [];
		var folders:Array<String> = [];
		var songFolder:String = Paths.formatToSongPath(PlayState.SONG != null ? PlayState.SONG.song : '');

		if(songFolder.length > 0)
			for(folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'songs/$songFolder/'))
				if(!folders.contains(folder))
					folders.push(folder);
		for(folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'data/scripts/'))
			if(!folders.contains(folder))
				folders.push(folder);

		if(Song.chartPath != null && Song.chartPath.length > 0)
		{
			var path:String = Song.chartPath.replace('\\', '/');
			var folder:String = path.substr(0, path.lastIndexOf('/') + 1);
			if(folder.length > 0 && FileSystem.exists(folder) && !folders.contains(folder))
				folders.push(folder);
		}

		for(folder in folders)
		{
			if(!FileSystem.exists(folder))
				continue;

			for(file in FileSystem.readDirectory(folder))
			{
				var lower:String = file.toLowerCase();
				if(!lower.endsWith('.lua') && !lower.endsWith('.hx'))
					continue;

				var path:String = haxe.io.Path.join([folder, file]);
				try
					collectCreateCharMatches(File.getContent(path), tags, noteTypes)
				catch(e:Dynamic) {}
			}
		}

		return {tags: tags, noteTypes: noteTypes};
	}

	var susLengthLastVal:Float = 0; //used for multiple notes selected
	var susLengthStepper:PsychUINumericStepper;
	var strumTimeStepper:PsychUINumericStepper;
	var noteTypeDropDown:PsychUIDropDownMenu;
	var noteTypes:Array<String>;
	function addNoteTab()
	{
		var tab_group = mainBox.getTab('Note').menu;
		var objX = 10;
		var objY = 25;

		susLengthStepper = new PsychUINumericStepper(objX, objY, Conductor.stepCrochet / 2, 0, 0, Conductor.stepCrochet * 128, 1, 80);
		susLengthStepper.onValueChange = function()
		{
			var halfStep:Float = (Conductor.stepCrochet / 2);
			trace(halfStep, susLengthStepper.value);
			var val:Float = Math.round(susLengthStepper.value / halfStep) * halfStep;
			susLengthStepper.value = val;
			if(susLengthLastVal != susLengthStepper.value)
			{
				if(selectedNotes.length > 1)
				{
					for (note in selectedNotes)
					{
						if(note == null && !note.isEvent) continue;
						note.setSustainLength(note.sustainLength + (susLengthStepper.value - susLengthLastVal), curZoom);
					}
				}
				else if(selectedNotes.length == 1) selectedNotes[0].setSustainLength(susLengthStepper.value, curZoom);
				susLengthLastVal = susLengthStepper.value;
			}
		};

		objY += 40;
		strumTimeStepper = new PsychUINumericStepper(objX, objY, Conductor.stepCrochet, 0, -5000, Math.POSITIVE_INFINITY, 3, 120);
		strumTimeStepper.onValueChange = function()
		{
			if(selectedNotes.length < 1) return;

			var firstTime:Float = selectedNotes[0].strumTime;
			for (note in selectedNotes)
			{
				if(note == null) continue;

				note.setStrumTime(Math.max(-5000, strumTimeStepper.value + (note.strumTime - firstTime)));
				positionNoteYOnTime(note);

				if(note.isEvent)
				{
					cast (note, EventMetaNote).updateEventInfo();
				}
			}
			softReloadNotes();
		};

		objY += 40;
		noteTypeDropDown = new PsychUIDropDownMenu(objX, objY, [], function(id:Int, changeToType:String)
		{
			var newSelected:Array<MetaNote> = [];
			var typeSelected:String = noteTypes[id].trim();
			for (note in selectedNotes)
			{
				if(note == null || note.isEvent) continue;

				if(typeSelected != null && typeSelected.length > 0) {
					note.noteType = typeSelected;
				} else {
					note.songData.remove(note.songData[3]);
				}
				
				var id:Int = notes.indexOf(note);
				if (id > -1) {
					notes[id] = createNote(note.songData, note.section);
					actionReplaceNotes(note, notes[id]);
					newSelected.push(notes[id]);
					note.destroy();
				}
			}
			selectedNotes = newSelected;
			softReloadNotes();
		}, 150);
		
		tab_group.add(new FlxText(susLengthStepper.x, susLengthStepper.y - 15, 80, 'Sustain length:'));
		tab_group.add(new FlxText(strumTimeStepper.x, strumTimeStepper.y - 15, 100, 'Note Hit time (ms):'));
		tab_group.add(new FlxText(noteTypeDropDown.x, noteTypeDropDown.y - 15, 80, 'Note Type:'));
		tab_group.add(susLengthStepper);
		tab_group.add(strumTimeStepper);
		tab_group.add(noteTypeDropDown);
	}

	var gfSectionCheckBox:PsychUICheckBox;
	// var altAnimSectionCheckBox:PsychUICheckBox;

	var changeBpmCheckBox:PsychUICheckBox;
	var changeBpmStepper:PsychUINumericStepper;
	var beatsPerSecStepper:PsychUINumericStepper;

	function addSectionTab()
	{
		var affectNotes:PsychUICheckBox = null;
		var affectEvents:PsychUICheckBox = null;
		var copyLastSecStepper:PsychUINumericStepper = null;
		var tab_group = mainBox.getTab('Section').menu;
		var objX = 10;
		var objY = 10;
		function copyNotesOnSection(?secOff:Int = 0, ?showMessage:Bool = true):Bool //Used on "Copy Section" and "Copy Last Section" buttons
		{
			var sourceSection:Int = curSec - secOff;
			if(sourceSection < 0 || sourceSection >= PlayState.SONG.notes.length || sourceSection + 1 >= cachedSectionRow.length)
			{
				if(showMessage) showOutput('That section does not exist!', true);
				return false;
			}

			var sectionStep:Float = cachedSectionRow[sourceSection];
			var notesCopyNum:Int = 0;
			if(affectNotes.checked)
			{
				copiedNotes = [];
				for (note in notes)
				{
					var noteStep:Float = Conductor.getStep(note.strumTime);
					if(stepIsInSection(noteStep, sourceSection))
					{
						var dataCopy:Array<Dynamic> = makeNoteDataCopy(note.songData, false);
						if(Math.abs(noteStep - sectionStep) < SECTION_STEP_EPSILON) noteStep = sectionStep;
						dataCopy[2] = Conductor.getStep(note.strumTime + note.sustainLength) - noteStep;
						dataCopy[0] = noteStep - sectionStep;
						
						copiedNotes.push(dataCopy);
						notesCopyNum++;
					}
				}
			}

			var eventsCopyNum:Int = 0;
			if(affectEvents.checked)
			{
				copiedEvents = [];
				for (event in events)
				{
					var eventStep:Float = Conductor.getStep(event.strumTime);
					if(stepIsInSection(eventStep, sourceSection))
					{
						var dataCopy:Array<Dynamic> = makeNoteDataCopy(event.songData, true);
						if(Math.abs(eventStep - sectionStep) < SECTION_STEP_EPSILON) eventStep = sectionStep;
						dataCopy[0] = eventStep - sectionStep;
						copiedEvents.push(dataCopy);
						eventsCopyNum++;
					}
				}
			}

			if(showMessage)
			{
				if(notesCopyNum == 0 && eventsCopyNum == 0)
				{
					showOutput('Nothing to copy!', true);
					return true;
				}

				var str:String = '';
				if(notesCopyNum > 0) str += 'Notes Copied: $notesCopyNum';
				if(eventsCopyNum > 0)
				{
					if(str.length > 0) str += '\n';
					str += 'Events Copied: $eventsCopyNum';
				}
	
				if(str.length > 0) showOutput(str);
			}
			return true;
		}

		gfSectionCheckBox = new PsychUICheckBox(objX, objY, 'Girlfriend Sings', 100, function()
		{
			var sec = getCurChartSection();
			if(sec != null) sec.gfSection = gfSectionCheckBox.checked;
			updateHeads(true);
		});
		/*altAnimSectionCheckBox = new PsychUICheckBox(objX + 200, objY, 'Alt Anim.', 80, function()
		{
			var sec = getCurChartSection();
			if(sec != null) sec.altAnim = altAnimSectionCheckBox.checked;
		});*/

		objY += 40;
		changeBpmStepper = new PsychUINumericStepper(objX + 40, objY, 1, 0, 1, 400, 3);
		changeBpmStepper.onValueChange = function() {
			var sec = getCurChartSection();
			if (sec != null) {
				var oldBPMMap:Array<BPMChangeEvent> = Conductor.copyBPMChanges();
				sec.changeBPM = true;
				sec.bpm = changeBpmStepper.value;
				changeBpmCheckBox.checked = true;
				adaptNotes(oldBPMMap);
			}
		};
		
		changeBpmCheckBox = new PsychUICheckBox(changeBpmStepper.x + 72, objY, 'Change?', 80, function() {
			var sec = getCurChartSection();
			if(sec != null) {
				var oldBPMMap:Array<BPMChangeEvent> = Conductor.copyBPMChanges();
				sec.changeBPM = changeBpmCheckBox.checked;
				if(!Reflect.hasField(sec, 'bpm')) sec.bpm = changeBpmStepper.value;
				adaptNotes(oldBPMMap);
			}
		});

		objY += 20;
		beatsPerSecStepper = new PsychUINumericStepper(changeBpmStepper.x, objY, 1, 4, 1, 16, 2);
		beatsPerSecStepper.onValueChange = function() {
			beatsPerSecStepper.value = Math.round(beatsPerSecStepper.value * 4) / 4;
			var sec = getCurChartSection();
			if (sec != null) {
				var oldBPMMap:Array<BPMChangeEvent> = Conductor.copyBPMChanges();
				sec.sectionBeats = Std.int(beatsPerSecStepper.value);
				adaptNotes(oldBPMMap);
			}
		};

		objY += 40;
		var copyButton:PsychUIButton = new PsychUIButton(objX, objY, 'Copy Section', function() {
			copyNotesOnSection();
		}, 74);
		
		affectNotes = new PsychUICheckBox(objX + 82, objY + 2, 'Notes', 60);
		affectNotes.checked = true;
		
		objY += 25;
		var pasteButton:PsychUIButton = new PsychUIButton(objX, objY, 'Paste Section', function() {
			pasteCopiedNotesToSection(affectNotes.checked, affectEvents.checked);
		}, 74);
		
		affectEvents = new PsychUICheckBox(objX + 82, objY + 2, 'Events', 60);

		objY += 25;
		var copyLastSecButton:PsychUIButton = new PsychUIButton(objX, objY, 'Clone Section', function()
		{
			var lastCopiedNotes = copiedNotes;
			var lastCopiedEvents = copiedEvents;
			if(copyNotesOnSection(Std.int(copyLastSecStepper.value), false))
				pasteCopiedNotesToSection(affectNotes.checked, affectEvents.checked);
			copiedNotes = lastCopiedNotes;
			copiedEvents = lastCopiedEvents;
		}, 74);
		
		var copyLastSecTooltip:FlxText = new FlxText(objX + 144, objY + 3, 100, 'sections before');
		copyLastSecStepper = new PsychUINumericStepper(objX + 82, objY + 2, 1, 1, -999, 999, 0, 52);
		copyLastSecStepper.onValueChange = function() {
			if (copyLastSecStepper.value == 0) {
				if (copyLastSecStepper.buttonPlus.animation.name == 'pressed') { // genius
					copyLastSecStepper.value = 1;
					copyLastSecTooltip.text = 'sections before';
				} else {
					copyLastSecStepper.value = -1;
					copyLastSecTooltip.text = 'sections later';
				}
			}
		}
		
		objY += 45;
		var swapSectionButton:PsychUIButton = new PsychUIButton(objX, objY, 'Swap Notes', function()
		{
			var maxData:Int = GRID_COLUMNS_PER_PLAYER * GRID_PLAYERS;
			for (note in curRenderedNotes)
			{
				if(note != null && !note.isEvent && noteIsInSection(note, curSec))
				{
					var data:Int = note.songData[1] + GRID_COLUMNS_PER_PLAYER;
					if(data >= maxData) data -= maxData;
					note.changeNoteData(data);
					positionNoteXByData(note);
				}
			}
			softReloadNotes(true);
		}, 74);
		var mirrorNotesButton:PsychUIButton = new PsychUIButton(swapSectionButton.x + 74 + 8, objY, 'Mirror Notes', function()
		{
			var maxData:Int = GRID_COLUMNS_PER_PLAYER * GRID_PLAYERS;
			for (note in curRenderedNotes)
			{
				if(note == null || note.isEvent || !noteIsInSection(note, curSec)) continue;

				var data:Int = Std.int(note.songData[1]);
				note.changeNoteData((Math.floor(data / GRID_COLUMNS_PER_PLAYER) * GRID_COLUMNS_PER_PLAYER) + GRID_COLUMNS_PER_PLAYER - note.noteData - 1);
				positionNoteXByData(note);
			}
			softReloadNotes(true);
		}, 74);
		var duetSectionButton:PsychUIButton = new PsychUIButton(mirrorNotesButton.x + 74 + 8, objY, 'Duet Section', function()
		{
			var side:Int = -1;
			for (note in curRenderedNotes.members)
			{
				if(note == null || note.isEvent || !noteIsInSection(note, curSec)) continue;

				//First figure out if there are notes on more than one player's sides to cancel operation early
				if(side > -1)
				{
					if(Math.floor(note.songData[1] / GRID_COLUMNS_PER_PLAYER) != side)
					{
						showOutput('You cannot press this button with notes on more than one side.');
						return;
					}
				}
				else side = Math.floor(note.songData[1] / GRID_COLUMNS_PER_PLAYER);
			}

			var pushedNotes:Array<MetaNote> = [];
			for (note in curRenderedNotes.members)
			{
				if(note == null || note.isEvent || !noteIsInSection(note, curSec)) continue;

				for (i in 0...GRID_PLAYERS)
				{
					if(i == side) continue;

					var songDataCopy:Array<Dynamic> = note.songData.copy();
					songDataCopy[1] = note.noteData + i * GRID_COLUMNS_PER_PLAYER;
					var newNote = createNote(songDataCopy, note.section);
					notes.push(newNote);
					pushedNotes.push(newNote);
				}
			}
			notes.sort(PlayState.sortByTime);
			softReloadNotes(true);
			
			addUndoAction(ADD_NOTE, {notes: pushedNotes});
		}, 74);
		
		for (button in [swapSectionButton, mirrorNotesButton, duetSectionButton])
			button.normalStyle.bgColor = 0xff5cb1a9;
		
		var clearButton:PsychUIButton = new PsychUIButton(300 - 34 - 10, objY, 'Wipe', function() {
			for (note in curRenderedNotes) {
				if(note == null || !noteIsInSection(note, curSec)) continue;

				if(!note.isEvent && affectNotes.checked)
					notes.remove(note);
				if(note.isEvent && affectEvents.checked)
					events.remove(cast (note, EventMetaNote));

				selectedNotes.remove(note);
			}
			softReloadNotes(true);
		}, 34);
		clearButton.normalStyle.bgColor = FlxColor.RED;
		clearButton.normalStyle.textColor = FlxColor.WHITE;

		tab_group.add(gfSectionCheckBox);
		// tab_group.add(altAnimSectionCheckBox);

		tab_group.add(new FlxText(beatsPerSecStepper.x - 40, beatsPerSecStepper.y + 1, 100, 'Beats:'));
		tab_group.add(beatsPerSecStepper);
		
		tab_group.add(copyButton);
		tab_group.add(pasteButton);
		tab_group.add(clearButton);
		tab_group.add(affectNotes);
		tab_group.add(affectEvents);

		tab_group.add(copyLastSecButton);
		tab_group.add(copyLastSecStepper);
		tab_group.add(copyLastSecTooltip);

		tab_group.add(swapSectionButton);
		tab_group.add(duetSectionButton);
		tab_group.add(mirrorNotesButton);
	}

	function reloadNotesDropdowns()
	{
		// Note type drop down
		if(noteTypeDropDown != null)
		{
			var exts:Array<String> = ['.txt'];
			#if LUA_ALLOWED exts.push('.lua'); #end
			#if HSCRIPT_ALLOWED exts.push('.hx'); #end
			noteTypes = loadFileList('data/notetypes/', exts);
			for (id => noteType in Note.defaultNoteTypes)
				if(!noteTypes.contains(noteType))
					noteTypes.insert(id, noteType);

			if(Song.chartPath != null && Song.chartPath.length > 0)
			{
				var parentFolder:String = Song.chartPath.replace('\\', '/');
				parentFolder = parentFolder.substr(0, parentFolder.lastIndexOf('/')+1);
				var notetypeFile:Array<String> = CoolUtil.coolTextFile(parentFolder + 'notetypes.txt');
				if(notetypeFile.length > 0)
				{
					for (ntTyp in notetypeFile)
					{
						var name:String = ntTyp.trim();
						if(!noteTypes.contains(name))
							noteTypes.push(name);
					}
				}
			}

			var scriptCharacterData = getScriptCreatedCharacterData();
			for(name in scriptCharacterData.noteTypes)
				if(!noteTypes.contains(name))
					noteTypes.push(name);
			
			var displayNoteTypes:Array<String> = noteTypes.copy();
			for (id => key in displayNoteTypes)
			{
				if(id == 0) continue;
				displayNoteTypes[id] = '$id. $key';
			}
			
			var lastSelected:String = noteTypeDropDown.selectedLabel;
			noteTypeDropDown.list = displayNoteTypes;
			noteTypeDropDown.selectedLabel = lastSelected;
		}
	}

	function pasteCopiedNotesToSection(?canCopyNotes:Bool = true, ?canCopyEvents:Bool = true, ?showMessage:Bool = true,
		?targetStep:Null<Float>, ?limitToSection:Bool = true)
	{
		var curSectionTime:Null<Float> = cachedSectionTimes[curSec];
		if(curSectionTime == null)
		{
			showOutput('ERROR: Unknown section??', true);
			return [];
		}
		
		var sectionStep:Float = targetStep != null ? targetStep : cachedSectionRow[curSec];
		var nextSectionStep:Float = limitToSection ? cachedSectionRow[curSec + 1] : Math.POSITIVE_INFINITY;
		var pastesTempo:Bool = false;
		if(canCopyEvents)
			for(blob in copiedEvents)
				if(blob != null && blob.length > 1 && blob[1] != null)
					for(data in (cast blob[1]:Array<Dynamic>))
						if(eventDataIsBPMChange(cast data)) pastesTempo = true;
		var oldBPMMap:Array<BPMChangeEvent> = pastesTempo ? Conductor.copyBPMChanges() : null;
		
		var pushedNotes:Array<MetaNote> = [];
		var nts:Array<MetaNote> = [];
		var evs:Array<EventMetaNote> = [];
		if(canCopyNotes && copiedNotes.length > 0)
		{
			for (note in copiedNotes)
			{
				if(note == null) continue;
				var dataCopy:Array<Dynamic> = makeNoteDataCopy(note, false);
				
				var noteStep:Float = dataCopy[0] + sectionStep;
				if(Math.abs(noteStep - sectionStep) < SECTION_STEP_EPSILON) noteStep = sectionStep;
				
				if(noteStep < nextSectionStep - SECTION_STEP_EPSILON)
				{
					var strumTime:Float = Conductor.stepToSeconds(noteStep);
					dataCopy[0] = strumTime;
					dataCopy[2] = Conductor.stepToSeconds(noteStep + dataCopy[2]) - strumTime;
					
					var createdNote = createNote(dataCopy, sectionAtStep(noteStep));
					notes.push(createdNote);
					pushedNotes.push(createdNote);
					nts.push(createdNote);
				}
			}
			notes.sort(PlayState.sortByTime);
		}

		if(canCopyEvents && copiedEvents.length > 0)
		{
			for (event in copiedEvents)
			{
				if(event == null) continue;
				var dataCopy:Array<Dynamic> = makeNoteDataCopy(event, true);
				var eventStep:Float = dataCopy[0] + sectionStep;
				if(Math.abs(eventStep - sectionStep) < SECTION_STEP_EPSILON) eventStep = sectionStep;

				if(eventStep < nextSectionStep - SECTION_STEP_EPSILON)
				{
					var strumTime:Float = Conductor.stepToSeconds(eventStep);
					dataCopy[0] = strumTime;
					
					var createdEvent = createEvent(dataCopy);
					events.push(createdEvent);
					pushedNotes.push(createdEvent);
					evs.push(createdEvent);
				}
			}
			events.sort(PlayState.sortByTime);
		}
		if(pastesTempo) adaptNotes(oldBPMMap, false);
		else loadSection();
		
		if(showMessage)
		{
			if(nts.length == 0 && evs.length == 0)
			{
				showOutput('Nothing to paste!', true);
				return [];
			}

			var str:String = '';
			if(nts.length > 0) str += 'Notes Added: ${nts.length}';
			if(evs.length > 0)
			{
				if(str.length > 0) str += '\n';
				str += 'Events Added: ${evs.length}';
			}

			if(str.length > 0) showOutput(str);
		}
		addUndoAction(ADD_NOTE, {notes: nts, events: evs});
		return pushedNotes;
	}

	var songNameInputText:PsychUIInputText;
	var allowVocalsCheckBox:PsychUICheckBox;

	var bpmStepper:PsychUINumericStepper;
	var scrollSpeedStepper:PsychUINumericStepper;
	var audioOffsetStepper:PsychUINumericStepper;

	var stageDropDown:PsychUIDropDownMenu;
	var playerDropDown:PsychUIDropDownMenu;
	var opponentDropDown:PsychUIDropDownMenu;
	var girlfriendDropDown:PsychUIDropDownMenu;
	
	function addSongTab()
	{
		var tab_group = mainBox.getTab('Song').menu;
		var objX = 10;
		var objY = 25;

		songNameInputText = new PsychUIInputText(objX, objY, 100, 'None', 8);
		songNameInputText.onChange = function(old:String, cur:String) PlayState.SONG.song = cur;

		allowVocalsCheckBox = new PsychUICheckBox(objX, objY + 20, 'Allow Vocals', 80, function()
		{
			PlayState.SONG.needsVoices = allowVocalsCheckBox.checked;
			loadMusic();
		});
		var reloadAudioButton:PsychUIButton = new PsychUIButton(objX + 120, objY, 'Reload Audio', function() loadMusic(true), 80);

		#if mac
		var reloadJsonButton:PsychUIButton = new PsychUIButton(objX + 205, objY, 'Reload JSON', function()
		{
			var cur = Paths.formatToSongPath(songNameInputText.text);
			var curdiff = Highscore.formatSong(cur, PlayState.storyDifficulty);
			var diff = false;
			var loadedChart:SwagSong = try {
				diff = true;
				Song.getChart(curdiff, cur);
			} catch (e) {
				diff = false;
				Song.getChart(cur, cur);
			}
			if(loadedChart == null || !Reflect.hasField(loadedChart, 'song')) //Check if chart is ACTUALLY a chart and valid
			{
				showOutput('Error: File loaded is not a Psych Engine/FNF 0.2.x.x chart.', true);
				return;
			}
			
			var eventsChart:SwagSong = PlayState.EVENTS;
			if (autoLoadEvents) eventsChart = try { Song.getChart('events', cur, 'events'); } catch (e) { null; }
			
			var func:Void->Void = function()
			{
				loadChart(loadedChart, eventsChart);
				Song.chartPath = diff ? curdiff : cur;
				reloadNotesDropdowns();
				prepareReload();
				showOutput('Opened chart "${diff ? curdiff : cur}" successfully!');
			}
					
			if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('Warning: Any unsaved progress\nwill be lost.', func));
			else func();
		}, 80);
		#end

		objY += 65;
		//(x:Float = 0, y:Float = 0, step:Float = 1, defValue:Float = 0, min:Float = -999, max:Float = 999, decimals:Int = 0, ?wid:Int = 60, ?isPercent:Bool = false)
		bpmStepper = new PsychUINumericStepper(objX, objY, 1, 1, 1, 400, 3);
		bpmStepper.onValueChange = function()
		{
			var oldBPMMap:Array<BPMChangeEvent> = Conductor.copyBPMChanges();
			PlayState.SONG.bpm = bpmStepper.value;
			adaptNotes(oldBPMMap);
		};

		scrollSpeedStepper = new PsychUINumericStepper(objX + 90, objY, 0.1, 1, 0.1, 10, 2);
		scrollSpeedStepper.onValueChange = function() PlayState.SONG.speed = scrollSpeedStepper.value;

		audioOffsetStepper = new PsychUINumericStepper(objX + 180, objY, 1, 0, -500, 500, 0);
		audioOffsetStepper.onValueChange = function()
		{
			PlayState.SONG.offset = audioOffsetStepper.value;
			Conductor.offset = audioOffsetStepper.value;
			updateWaveform();
		};

		tab_group.add(new FlxText(songNameInputText.x, songNameInputText.y - 15, 80, 'Song Name:'));
		tab_group.add(songNameInputText);
		tab_group.add(allowVocalsCheckBox);
		tab_group.add(reloadAudioButton);
		#if mac
		tab_group.add(reloadJsonButton);
		#end

		// Find characters
		var characters:Array<String> = [];
		//
		
		objY += 40;
		playerDropDown = new PsychUIDropDownMenu(objX, objY, [''], function(id:Int, character:String)
		{
			PlayState.SONG.player1 = character;
			updateJsonData();
			updateHeads(true);
			loadMusic();
			trace('selected $character');
		});
		stageDropDown = new PsychUIDropDownMenu(objX + 140, objY, [''], function(id:Int, stage:String)
		{
			PlayState.SONG.stage = stage;
			StageData.loadDirectory(PlayState.SONG);
			trace('selected $stage');
		});
		
		opponentDropDown = new PsychUIDropDownMenu(objX, objY + 40, [''], function(id:Int, character:String)
		{
			PlayState.SONG.player2 = character;
			updateJsonData();
			updateHeads(true);
			loadMusic();
			trace('selected $character');
		});
		
		girlfriendDropDown = new PsychUIDropDownMenu(objX, objY + 80, [''], function(id:Int, character:String)
		{
			PlayState.SONG.gfVersion = character;
			trace('selected $character');
		});

		playerDropDown.onVisualOpen = function():Bool
			return openVisualListPicker(CHARACTER, playerDropDown, playerDropDown.list.copy(), characterVisualCategories);
		opponentDropDown.onVisualOpen = function():Bool
			return openVisualListPicker(CHARACTER, opponentDropDown, opponentDropDown.list.copy(), characterVisualCategories);
		girlfriendDropDown.onVisualOpen = function():Bool
			return openVisualListPicker(CHARACTER, girlfriendDropDown, girlfriendDropDown.list.copy(), characterVisualCategories);
		stageDropDown.onVisualOpen = function():Bool
			return openVisualListPicker(STAGE, stageDropDown, stageDropDown.list.copy(), stageVisualCategories);
		
		tab_group.add(new FlxText(bpmStepper.x, bpmStepper.y - 15, 50, 'BPM:'));
		tab_group.add(new FlxText(scrollSpeedStepper.x, scrollSpeedStepper.y - 15, 80, 'Scroll Speed:'));
		tab_group.add(new FlxText(audioOffsetStepper.x, audioOffsetStepper.y - 15, 100, 'Audio Offset (ms):'));
		tab_group.add(bpmStepper);
		tab_group.add(scrollSpeedStepper);
		tab_group.add(audioOffsetStepper);

		//dropdowns
		tab_group.add(new FlxText(stageDropDown.x, stageDropDown.y - 15, 80, 'Stage:'));
		tab_group.add(new FlxText(playerDropDown.x, playerDropDown.y - 15, 80, 'Player:'));
		tab_group.add(new FlxText(opponentDropDown.x, opponentDropDown.y - 15, 80, 'Opponent:'));
		tab_group.add(new FlxText(girlfriendDropDown.x, girlfriendDropDown.y - 15, 80, 'Girlfriend:'));
		tab_group.add(stageDropDown);
		tab_group.add(girlfriendDropDown);
		tab_group.add(opponentDropDown);
		tab_group.add(playerDropDown);
	}

	function abrirConversor()
	{
		if(!fileDialog.completed) return;

		var options = MoonchartConverters.getExternalFormats();
		if(options.length < 1)
		{
			showOutput('No Moonchart converters are available.', true);
			return;
		}

		upperBox.isMinimized = true;
		upperBox.bg.visible = false;
		ClientPrefs.toggleVolumeKeys(false);

		openSubState(new BasePrompt(560, 325, 'Converters',
			function(state:BasePrompt)
			{
				var closeBtn:PsychUIButton = new PsychUIButton(state.bg.x + state.bg.width - 40, state.bg.y, 'X', state.close, 40);
				closeBtn.cameras = state.cameras;

				var labels:Array<String> = [for(option in options) option.label];
				var centerX:Float = state.bg.x + 55;
				var topY:Float = state.bg.y + 78;

				var directionText:FlxText = new FlxText(centerX, topY - 18, 120, 'Direction:');
				directionText.cameras = state.cameras;

				var directionGroup:PsychUIRadioGroup = new PsychUIRadioGroup(centerX, topY, ['From Engine', 'To Engine'], 25, 0, true, 120);
				directionGroup.checked = 0;
				directionGroup.cameras = state.cameras;

				var formatText:FlxText = new FlxText(centerX, topY + 48, 120, 'Format:');
				formatText.cameras = state.cameras;

				var formatDropDown:PsychUIDropDownMenu = new PsychUIDropDownMenu(centerX, topY + 66, labels, null, 300);
				var defaultConverterIndex:Int = labels.indexOf(ClientPrefs.data.chartEditorDefaultConverter);
				formatDropDown.selectedIndex = defaultConverterIndex >= 0 ? defaultConverterIndex : 0;
				formatDropDown.cameras = state.cameras;

				var diff:String = ClientPrefs.data.chartEditorDefaultConverterDifficulty;
				if(diff == null || diff.trim().length < 1)
					diff = Paths.formatToSongPath(Difficulty.getString(false));
				var difficultyText:FlxText = new FlxText(centerX + 330, topY + 48, 120, 'Difficulty:');
				difficultyText.cameras = state.cameras;

				var difficultyInput:PsychUIInputText = new PsychUIInputText(centerX + 330, topY + 66, 120, diff, 8);
				difficultyInput.forceCase = LOWER_CASE;
				difficultyInput.cameras = state.cameras;

				var convertBtn:PsychUIButton = new PsychUIButton(0, state.bg.y + state.bg.height - 48, 'Convert', function()
				{
					var selected = options[formatDropDown.selectedIndex];
					if(selected == null)
					{
						showOutput('Select a valid converter format.', true);
						return;
					}

					var difficulty = difficultyInput.text;
					var toEngine:Bool = directionGroup.checked == 0;
					state.close();

					if(selected.nightmareVision == true)
					{
						if(toEngine)
							startNightmareVisionToEngine(difficulty);
						else
							showOutput('Nightmare Vision can only be converted to the engine.', true);
					}
					else if(toEngine)
						startMoonchartToEngine(selected, difficulty);
					else
						startEngineToMoonchart(selected, difficulty);
				}, 100);
				convertBtn.normalStyle.bgColor = FlxColor.GREEN;
				convertBtn.normalStyle.textColor = FlxColor.WHITE;
				convertBtn.screenCenter(X);
				convertBtn.cameras = state.cameras;

				state.add(closeBtn);
				state.add(directionText);
				state.add(directionGroup);
				state.add(convertBtn);
				state.add(formatText);
				state.add(formatDropDown);
				state.add(difficultyText);
				state.add(difficultyInput);
			}
		));
	}

	function startNightmareVisionToEngine(difficulty:String)
	{
		if(!fileDialog.completed) return;

		upperBox.isMinimized = true;
		upperBox.bg.visible = false;

		fileDialog.open(null, 'Open Nightmare Vision Chart', [new FileFilter('Nightmare Vision JSON', '*.json')], function()
		{
			var chartPath:String = fileDialog.path.replace('\\', '/');
			fileDialog.openDirectory('Save Converted Engine JSON', function()
			{
				try
				{
					var result = MoonchartConverters.convertNightmareVisionToEngine(chartPath, fileDialog.path, difficulty);
					showOutput(moonchartResultMessage('Converted to engine', result));
				}
				catch(e:Exception)
				{
					showOutput('Nightmare Vision converter error: ${e.message}', true); // supostamente funciona melhor agora
					trace(e.stack);
				}
			});
		});
	}

	function startEngineToMoonchart(option:MoonchartOpcao, difficulty:String)
	{
		if(!fileDialog.completed) return;

		upperBox.isMinimized = true;
		upperBox.bg.visible = false;

		fileDialog.openDirectory('Save Converted ${option.label}', function()
		{
			try
			{
				updateChartData();
				var result = MoonchartConverters.convertEngineToFormat(PlayState.SONG, option.format, fileDialog.path, difficulty);
				showOutput(moonchartResultMessage('Converted from engine', result));
			}
			catch(e:Exception)
			{
				showOutput('Moonchart error: ${e.message}', true);
				trace(e.stack);
			}
		});
	}

	function startMoonchartToEngine(option:MoonchartOpcao, difficulty:String)
	{
		if(!fileDialog.completed) return;

		upperBox.isMinimized = true;
		upperBox.bg.visible = false;

		fileDialog.open(null, 'Open ${MoonchartConverters.getFormatName(option.format)} Chart', moonchartFileFilter(option), function()
		{
			var chartPath:String = fileDialog.path.replace('\\', '/');
			function chooseOutput(?metadataPath:String)
			{
				fileDialog.openDirectory('Save Converted Engine JSON', function()
				{
					try
					{
						var result = MoonchartConverters.convertFileToEngine(option.format, chartPath, metadataPath, fileDialog.path, difficulty);
						showOutput(moonchartResultMessage('Converted to engine', result));
					}
					catch(e:Exception)
					{
						showOutput('Moonchart error: ${e.message}', true);
						trace(e.stack);
					}
				});
			}

			if(MoonchartConverters.needsMetadata(option.format))
			{
				fileDialog.open(null, 'Open ${MoonchartConverters.getFormatName(option.format)} Metadata', [new FileFilter('JSON', '*.json')], function()
				{
					chooseOutput(fileDialog.path.replace('\\', '/'));
				});
			}
			else chooseOutput();
		});
	}

	function moonchartFileFilter(option:MoonchartOpcao):Array<FileFilter>
	{
		#if mac
		return null;
		#else
		return [new FileFilter(MoonchartConverters.getFormatName(option.format), '*.${option.extension}')];
		#end
	}

	function moonchartResultMessage(prefix:String, result:MoonchartConversionResult):String
	{
		var message = '$prefix as ${result.formatName}:\n${result.dataPath}';
		if(result.metaPath != null && result.metaPath.length > 0)
			message += '\n${result.metaPath}';
		return message;
	}

	#if sys
	function rememberLastChartPath(?path:String):Void
	{
		if(path == null || path.trim().length < 1)
			return;

		chartEditorSave.data.lastChartPath = path.replace('\\', '/');
		chartEditorSave.flush();
	}

	function loadChartFromPath(path:String, ?successMessage:String):Void
	{
		if(path == null || path.trim().length < 1 || !FileSystem.exists(path))
		{
			showOutput('Last chart could not be found.', true);
			return;
		}

		try
		{
			var normalizedPath:String = path.replace('\\', '/');
			var loadedChart:SwagSong = Song.parseJSON(Paths.getTextFromFile(normalizedPath), normalizedPath.substr(normalizedPath.lastIndexOf('/')));
			if(loadedChart == null || !Reflect.hasField(loadedChart, 'song'))
			{
				showOutput('Error: File loaded is not a Psych Engine/FNF 0.2.x.x chart.', true);
				return;
			}

			var cur:String = normalizedPath.substr(0, normalizedPath.lastIndexOf('/'));
			cur = cur.substr(cur.lastIndexOf('/') + 1);
			Song.loadedSongName = cur;

			var eventsChart:SwagSong = PlayState.EVENTS;
			if(autoLoadEvents) eventsChart = try { Song.getChart('events', cur, 'events'); } catch (e) { null; }

			loadChart(loadedChart, eventsChart);
			Song.chartPath = normalizedPath;
			rememberLastChartPath(normalizedPath);
			reloadNotesDropdowns();
			prepareReload();
			showOutput(successMessage ?? 'Opened chart "$normalizedPath" successfully!');
		}
		catch(e:Exception)
		{
			showOutput('Error: ${e.message}', true);
			trace(e.stack);
		}
	}

	function loadLastChart():Void
	{
		var lastPath:String = chartEditorSave.data.lastChartPath;
		if(lastPath == null || lastPath.trim().length < 1)
		{
			showOutput('There is no last chart saved yet.', true);
			return;
		}

		var func:Void->Void = function()
			loadChartFromPath(lastPath, 'Loaded last chart "$lastPath" successfully!');

		if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('Warning: Any unsaved progress\nwill be lost.', func));
		else func();
	}
	#end

	function addFileTab()
	{
		var tab = upperBox.getTab('File');
		var tab_group = tab.menu;
		var btnX = tab.x - upperBox.x;
		var btnY = 1;
		var btnWid = Std.int(tab.width);

		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  New Chart', function()
		{
			var openChooser:Void->Void = function()
			{
				openSubState(new CoolNewSongSubState(function()
				{
					openNewChart();
					reloadNotesDropdowns();
					prepareReload();
				}, function(choice:ChartEditorSongChoice)
				{
					if(!CoolNewSongSubState.loadChoiceIntoPlayState(choice))
					{
						showOutput('Could not open chart "${choice.label}".', true);
						return;
					}

					var eventsChart:SwagSong = PlayState.EVENTS;
					if(autoLoadEvents) eventsChart = try { Song.getChart('events', choice.song, 'events'); } catch (e) { null; }
					loadChart(PlayState.SONG, eventsChart);
					reloadNotesDropdowns();
					prepareReload();
					showOutput('Opened chart "${choice.label}" successfully!');
				}));
			}

			if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('Warning: Any unsaved progress\nwill be lost.', openChooser));
			else openChooser();
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Open Chart', function()
		{
			if(!fileDialog.completed) return;
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;

			fileDialog.open(function()
			{
				try
				{
					var filePath:String = fileDialog.path.replace('\\', '/');
					var loadedChart:SwagSong = Song.parseJSON(fileDialog.data, filePath.substr(filePath.lastIndexOf('/')));
					if(loadedChart == null || !Reflect.hasField(loadedChart, 'song')) //Check if chart is ACTUALLY a chart and valid
					{
						showOutput('Error: File loaded is not a Psych Engine/FNF 0.2.x.x chart.', true);
						return;
					}

					var func:Void->Void = function()
					{
						var cur:String = filePath.substr(0, filePath.lastIndexOf('/'));
						cur = cur.substr(cur.lastIndexOf('/') + 1);
						Song.loadedSongName = cur;
						
						var eventsChart:SwagSong = PlayState.EVENTS;
						if (autoLoadEvents) eventsChart = try { Song.getChart('events', cur, 'events'); } catch (e) { null; }
						
						loadChart(loadedChart, eventsChart);
						Song.chartPath = fileDialog.path;
						#if sys
						rememberLastChartPath(Song.chartPath);
						#end
						reloadNotesDropdowns();
						prepareReload();
						showOutput('Opened chart "${Song.chartPath}" successfully!');
					}
					
					if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('Warning: Any unsaved progress\nwill be lost.', func));
					else func();
				}
				catch(e:Exception)
				{
					showOutput('Error: ${e.message}', true);
					trace(e.stack);
				}
			});
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Open Autosave...', function()
		{
			if(!fileDialog.completed) return;
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;

			if(!FileSystem.exists('backups/'))
			{
				showOutput('The "backups" folder does not exist.', true);
				return;
			}
			
			var fileList:Array<String> = FileSystem.readDirectory('backups/').filter((file:String) -> file.endsWith('.$BACKUP_EXT'));
			if(fileList.length < 1)
			{
				showOutput('No autosave files found.', true);
				return;
			}

			fileList.sort((a:String, b:String) -> (a.toUpperCase() < b.toUpperCase()) ? 1 : -1); //Sort alphabetically descending
			var maxItems:Int = Std.int(Math.min(5, fileList.length));
			var radioGrp:PsychUIRadioGroup = new PsychUIRadioGroup(0, 0, fileList, 25, maxItems, false, 240);
			radioGrp.checked = 0;

			var hei:Float = radioGrp.height + 160;
			openSubState(new BasePrompt(420, hei, 'Choose an Autosave',
				function(state:BasePrompt) {
					upperBox.isMinimized = true;
					upperBox.bg.visible = false;

					var btn:PsychUIButton = new PsychUIButton(state.bg.x + state.bg.width - 40, state.bg.y, 'X', state.close, 40);
					btn.cameras = state.cameras;
					state.add(btn);

					radioGrp.screenCenter(X);
					radioGrp.y = state.bg.y + 80;
					radioGrp.cameras = state.cameras;
					state.add(radioGrp);

					var btn:PsychUIButton = new PsychUIButton(0, radioGrp.y + radioGrp.height + 20, 'Load', function()
					{
						var autosaveName:String = fileList[radioGrp.checked];
						var path:String = 'backups/$autosaveName';
						state.close();

						if(FileSystem.exists(path))
						{
							try
							{
								var loadedChart:SwagSong = Song.parseJSON(Paths.getTextFromFile(path), autosaveName, null);
								if(loadedChart == null || !Reflect.hasField(loadedChart, '__original_path'))
								{
									showOutput('Error: File loaded is not a valid Psych Engine autosave.', true);
									return;
	
								}
	
								var originalPath:String = Reflect.field(loadedChart, '__original_path');
								Reflect.deleteField(loadedChart, '__original_path');
	
								var func:Void->Void = function()
								{
									Song.chartPath = FileSystem.exists(originalPath) ? originalPath : null;
									loadChart(loadedChart);
									reloadNotesDropdowns();
									prepareReload();
	
									showOutput('Opened autosave "$autosaveName" successfully!');
								}
								
								if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('Warning: Any unsaved progress\nwill be lost.', func));
								else func();
							}
							catch(e:Exception)
							{
								showOutput('Error on loading autosave: ${e.message}', true);
							}
						}
						else showOutput('Error! Autosave file selected could not be found, huh??', true);
					});
					btn.cameras = state.cameras;
					btn.screenCenter(X);
					state.add(btn);
				}
			));
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		if(SHOW_EVENT_COLUMN)
		{
			btnY += 20;
			var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Open Events...', function()
			{
				if(!fileDialog.completed) return;
				upperBox.isMinimized = true;
				upperBox.bg.visible = false;
	
				fileDialog.open(function()
				{
					try
					{
						var filePath:String = fileDialog.path.replace('\\', '/');
						var eventsFile:SwagSong = Song.parseJSON(fileDialog.data, filePath.substr(filePath.lastIndexOf('/')));
						if(eventsFile == null || Reflect.hasField(eventsFile, 'scrollSpeed') || eventsFile.events == null)
						{
							showOutput('Error: File loaded is not a Psych Engine chart/events file.', true);
							return;
						}
	
						var loadedEvents:Array<Dynamic> = eventsFile.events;
						if(loadedEvents.length < 1)
						{
							showOutput('Events file loaded is empty.', true);
							return;
						}
	
						openSubState(new BasePrompt('Events Found! Choose an action.',
							function(state:BasePrompt)
							{
								var btnY = 390;
								var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Replace All', function()
								{
									for (event in events)
									{
										if(event != null)
										{
											event.destroy();
											selectedNotes.remove(event);
										}
									}
									undoActions = [];
									events = [];
	
									for (event in loadedEvents)
										events.push(createEvent(event));
	
									softReloadNotes();
									state.close();
									showOutput('Events loaded successfully!');
								});
								btn.normalStyle.bgColor = FlxColor.RED;
								btn.normalStyle.textColor = FlxColor.WHITE;
								btn.screenCenter(X);
								btn.x -= 125;
								btn.cameras = state.cameras;
								state.add(btn);
								
								var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Add', function()
								{
									if(Song.eventArrayHasEvent(loadedEvents, Song.CAMERA_FOCUS_EVENT))
										removeEditorEventsByName(Song.CAMERA_FOCUS_EVENT);

									for (event in loadedEvents)
										events.push(createEvent(event));
	
									softReloadNotes();
									state.close();
									showOutput('Events added successfully!');
								});
								btn.screenCenter(X);
								btn.cameras = state.cameras;
								state.add(btn);
						
								var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Cancel', state.close);
								btn.screenCenter(X);
								btn.x += 125;
								btn.cameras = state.cameras;
								state.add(btn);
							}
						));
					}
					catch(e:Exception)
					{
						showOutput('Error: ${e.message}', true);
						trace(e.stack);
					}
				});
			}, btnWid);
			btn.text.alignment = LEFT;
			tab_group.add(btn);
		}
		
		#if sys
		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Save Chart', function()
		{
			if(!fileDialog.completed) return;
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;

			saveChart();
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);
		#end

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, #if sys '  Save Chart as...' #else '  Download Chart' #end, function()
		{
			if(!fileDialog.completed) return;
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;

			saveChart(false);
		},btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		if(SHOW_EVENT_COLUMN)
		{
			btnY += 20;
			var btn:PsychUIButton = new PsychUIButton(btnX, btnY, #if sys '  Save Events' #else '  Download Events' #end, function()
			{
				if(!fileDialog.completed) return;
				upperBox.isMinimized = true;
	
				updateChartData();
				fileDialog.save('events.json', PsychJsonPrinter.print({events: PlayState.SONG.events, format: 'psych_v1'}, ['events']),
					function() showOutput('Events saved successfully to: ${fileDialog.path}'), null,
					function() showOutput('Error on saving events!', true));
			}, btnWid);
			btn.text.alignment = LEFT;
			tab_group.add(btn);
		}

		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Reload Chart', function()
		{
			var func:Void->Void = function()
			{
				if(Song.chartPath == null)
				{
					showOutput('You must save/load a Chart first to Reload it!', true);
					return;
				}
	
				if(FileSystem.exists(Song.chartPath))
				{
					try
					{
						var reloadedChart:SwagSong = Song.parseJSON(Paths.getTextFromFile(Song.chartPath));
						
						var eventsChart:SwagSong = PlayState.EVENTS;
						if (autoLoadEvents) eventsChart = try { Song.getChart('events', Song.chartPath, 'events'); } catch (e) { null; }
						
						loadChart(reloadedChart, eventsChart);
						reloadNotesDropdowns();
						prepareReload();
						showOutput('Chart reloaded successfully!');
					}
					catch(e:Exception)
					{
						showOutput('Error: ${e.message}', true);
						trace(e.stack);
					}
				}
				else showOutput('You must save/load a Chart first to Reload it!', true);
			}

			if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('Warning: Any unsaved progress will be lost', func));
			else func();
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		#if sys
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Load Last Chart', function()
		{
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;
			loadLastChart();
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);
		#end

		#if false
		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Save (V-Slice)...', function()
		{
			if(!fileDialog.completed) return;
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;

			fileDialog.openDirectory('Save V-Slice Chart/Metadata JSONs', function()
			{
				try
				{
					var path:String = fileDialog.path.replace('\\', '/');

					var chartName:String = Paths.formatToSongPath(PlayState.SONG.song) + '.json';
					chartName = chartName.substring(chartName.lastIndexOf('/')+1, chartName.lastIndexOf('.'));

					var chartFile:String = '$path/$chartName-chart.json';
					var metadataFile:String = '$path/$chartName-metadata.json';

					updateChartData();
					var pack:VSlicePackage = VSlice.export(PlayState.SONG);

					ClientPrefs.toggleVolumeKeys(false);
					openSubState(new BasePrompt('Metadata',
						function(state:BasePrompt)
						{
							var btnX = 640;
							var btnY = 400;
							var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'Save', function()
							{
								overwriteSavedSomething = false;
								overwriteCheck(chartFile, '$chartName-chart.json', PsychJsonPrinter.print(pack.chart, ['events', 'notes', 'scrollSpeed']), function()
								{
									overwriteCheck(metadataFile, '$chartName-metadata.json', PsychJsonPrinter.print(pack.metadata, ['characters', 'difficulties', 'timeChanges']), function()
									{
										if(overwriteSavedSomething)
											showOutput('Files saved successfully to: $path!');
									});
								});
								state.close();
							});
							btn.normalStyle.bgColor = FlxColor.GREEN;
							btn.normalStyle.textColor = FlxColor.WHITE;
							btn.cameras = state.cameras;
							state.add(btn);
							
							var btn:PsychUIButton = new PsychUIButton(btnX + 100, btnY, 'Cancel', state.close);
							btn.cameras = state.cameras;
							state.add(btn);
							
							var textX = FlxG.width/2 - 155;
							var textY = 360;
							var artistInput:PsychUIInputText = new PsychUIInputText(textX, textY, 120, pack.metadata.artist, 8);
							artistInput.cameras = state.cameras;
							artistInput.onChange = function(old:String, cur:String) pack.metadata.artist = cur;

							var charterInput:PsychUIInputText = new PsychUIInputText(textX + 190, textY, 120, pack.metadata.charter, 8);
							charterInput.cameras = state.cameras;
							charterInput.onChange = function(old:String, cur:String) pack.metadata.charter = cur;
							
							var artistTxt:FlxText = new FlxText(artistInput.x, artistInput.y - 15, 100, 'Artist/Composer:');
							artistTxt.cameras = state.cameras;
							var charterTxt:FlxText = new FlxText(charterInput.x, charterInput.y - 15, 100, 'Charter:');
							charterTxt.cameras = state.cameras;
							state.add(artistTxt);
							state.add(charterTxt);
							state.add(artistInput);
							state.add(charterInput);
						}
					));

					//trace(pack.chart);
					//trace(pack.metadata);
					//trace(chartName, chartFile, metadataFile);
				}
				catch(e:Exception)
				{
					showOutput('Error: ${e.message}', true);
					trace(e.stack);
				}
			});
		},btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Psych to V-Slice...', function()
		{
			if(!fileDialog.completed) return;
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;

			fileDialog.open('song.json', 'Open a Psych Engine Chart JSON', function()
			{
				var filePath:String = fileDialog.path.replace('\\', '/');
				var loadedChart:SwagSong = Song.parseJSON(fileDialog.data, filePath.substr(filePath.lastIndexOf('/')));
				if(loadedChart == null || !Reflect.hasField(loadedChart, 'song')) //Check if chart is ACTUALLY a chart and valid
				{
					showOutput('Error: File loaded is not a Psych Engine 0.x.x/FNF 0.2.x.x chart.', true);
					return;
				}

				var pack:VSlicePackage = VSlice.export(loadedChart);
				if(pack.chart == null || pack.metadata == null)
				{
					showOutput('Error: Chart loaded is invalid.', true);
					return;
				}

				ClientPrefs.toggleVolumeKeys(false);
				openSubState(new BasePrompt('Metadata',
					function(state:BasePrompt)
					{
						var songName:String = Paths.formatToSongPath(pack.metadata.songName);
						var parentFolder:String = filePath.substring(0, filePath.lastIndexOf('/')+1);
						var artistInput, charterInput, difficultiesInput:PsychUIInputText = null;

						var btnX = 640;
						var btnY = 400;
						var btn:PsychUIButton = new PsychUIButton(btnX, btnY, 'Save', function()
						{
							try
							{
								var diffs:Array<String> = pack.metadata.playData.difficulties;
								if(diffs != null && diffs.length > 0)
								{
									var diffsFound:Array<String> = [];
									var defaultDiff:String = Paths.formatToSongPath(Difficulty.getDefault());
									for (diff in diffs)
									{
										var diffPostfix:String = (diff != defaultDiff) ? '-$diff' : '';
										var chartToFind:String = parentFolder + songName + diffPostfix + '.json';
										if(FileSystem.exists(chartToFind))
										{
											var diffChart:SwagSong = Song.parseJSON(Paths.getTextFromFile(chartToFind), songName + diffPostfix);
											if(diffChart != null)
											{
												var subpack:VSlicePackage = VSlice.export(diffChart);
												var	diffSpeed:Null<Float> = subpack.chart.scrollSpeed.get(diff);
												var diffNotes:Array<VSliceNote> = subpack.chart.notes.get(diff);
												if(diffSpeed != null && diffNotes != null)
												{
													pack.chart.scrollSpeed.set(diff, diffSpeed);
													pack.chart.notes.set(diff, diffNotes);
												}
												//trace(diff, diffSpeed, diffNotes.length);
											}
										}
										else trace('File not found: $chartToFind');
									}
									
									var chartToFind:String = parentFolder + 'events/events.json';
									if(FileSystem.exists(chartToFind))
									{
										var eventsChart:SwagSong = Song.parseJSON(Paths.getTextFromFile(chartToFind), 'events');
										if(eventsChart != null)
										{
											var subpack:VSlicePackage = VSlice.export(eventsChart);
											if(subpack.chart.events != null && subpack.chart.events.length > 0)
											{
												for (event in subpack.chart.events)
												{
													if(event == null) continue;
													pack.chart.events.push(event);
												}
											}
											@:privateAccess pack.chart.events.sort(VSlice.sortByTime);
										}
									}

									fileDialog.openDirectory('Save V-Slice Chart/Metadata JSONs', function()
									{
										overwriteSavedSomething = false;
										var path:String = fileDialog.path.replace('\\', '/');
										if(path.endsWith('/')) path = path.substr(0, path.length-1);
										overwriteCheck('$path/$songName-chart.json', '$songName-chart.json', PsychJsonPrinter.print(pack.chart, ['events', 'notes', 'scrollSpeed']), function()
										{
											overwriteCheck('$path/$songName-metadata.json', '$songName-metadata.json', PsychJsonPrinter.print(pack.metadata, ['characters', 'difficulties', 'timeChanges']), function()
											{
												if(overwriteSavedSomething)
													showOutput('Files saved successfully to: $path!');
											});
										});
									});
								}
								else showOutput('Error: You need atleast one difficulty to export.', true);
							}
							catch(e:Exception)
							{
								showOutput('Error: ${e.message}', true);
								trace(e.stack);
							}
							state.close();
						});
						btn.normalStyle.bgColor = FlxColor.GREEN;
						btn.normalStyle.textColor = FlxColor.WHITE;
						btn.cameras = state.cameras;
						state.add(btn);
						
						var btn:PsychUIButton = new PsychUIButton(btnX + 100, btnY, 'Cancel', state.close);
						btn.cameras = state.cameras;
						state.add(btn);
						
						var textX = FlxG.width/2 - 180;
						var textY = 360;
						artistInput = new PsychUIInputText(textX, textY, 120, pack.metadata.artist, 8);
						artistInput.cameras = state.cameras;
						artistInput.onChange = function(old:String, cur:String) pack.metadata.artist = cur;
	
						charterInput = new PsychUIInputText(textX + 150, textY, 120, pack.metadata.charter, 8);
						charterInput.cameras = state.cameras;
						charterInput.onChange = function(old:String, cur:String) pack.metadata.charter = cur;

						var diffs:Array<String> = pack.metadata.playData.difficulties;
						if(diffs == null || diffs.length < 0) pack.metadata.playData.difficulties = diffs = ['easy', 'normal', 'hard'];
						difficultiesInput = new PsychUIInputText(textX, textY + 42, 160, diffs.join(', '), 8);
						difficultiesInput.cameras = state.cameras;
						difficultiesInput.forceCase = LOWER_CASE;
						difficultiesInput.onChange = function(old:String, cur:String)
						{
							pack.metadata.playData.difficulties = cur.split(',');

							var diffs:Array<String> = pack.metadata.playData.difficulties;
							for (num => diff in diffs)
								diffs[num] = Paths.formatToSongPath(diff);

							while(diffs.contains('')) //Clear invalids cuz people might be stupid
								diffs.remove('');
						}
						
						var artistTxt:FlxText = new FlxText(artistInput.x, artistInput.y - 15, 100, 'Artist/Composer:');
						artistTxt.cameras = state.cameras;
						var charterTxt:FlxText = new FlxText(charterInput.x, charterInput.y - 15, 100, 'Charter:');
						charterTxt.cameras = state.cameras;
						var difficultiesTxt:FlxText = new FlxText(difficultiesInput.x, difficultiesInput.y - 15, 100, 'Difficulties:');
						difficultiesTxt.cameras = state.cameras;
						state.add(artistTxt);
						state.add(charterTxt);
						state.add(difficultiesTxt);
						state.add(artistInput);
						state.add(charterInput);
						state.add(difficultiesInput);
					}
				));
			});
		},btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  V-Slice to Psych...', function()
		{
			if(!fileDialog.completed) return;
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;

			fileDialog.open('chart.json', 'Open a V-Slice Chart file', function()
			{
				var chart:VSliceChart = cast Json.parse(fileDialog.data);
				if(chart == null || chart.version == null || chart.notes == null || chart.scrollSpeed == null)
				{
					showOutput('Error: File loaded is not a valid FNF V-Slice chart.', true);
					return;
				}

				fileDialog.open('metadata.json', 'Open a V-Slice Metadata file', function()
				{
					var metadata:VSliceMetadata = cast Json.parse(fileDialog.data);
					if(metadata == null || metadata.version == null || metadata.playData == null || metadata.songName == null ||
						metadata.playData.difficulties == null || metadata.timeChanges == null || metadata.timeChanges.length < 1)
					{
						showOutput('Error: File loaded is not a valid FNF V-Slice metadata.', true);
						return;
					}

					try
					{
						var pack:PsychPackage = VSlice.convertToPsych(chart, metadata);
						if(pack.difficulties != null)
						{
							fileDialog.openDirectory('Save Converted Psych JSONs', function()
							{
								var path:String = fileDialog.path.replace('\\', '/');
								if(!path.endsWith('/')) path += '/';

								var diffs:Array<String> = metadata.playData.difficulties.copy();
								var defaultDiff:String = Paths.formatToSongPath(Difficulty.getDefault());
								function nextChart()
								{
									while(diffs.length > 0)
									{
										var diffName:String = diffs[0];
										diffs.remove(diffName);
										if(!pack.difficulties.exists(diffName)) continue;
		
										var diffPostfix:String = (diffName != defaultDiff) ? '-$diffName' : '';
										var chartData:SwagSong = pack.difficulties.get(diffName);
										var chartName:String = Paths.formatToSongPath(chartData.song) + diffPostfix + '.json';
										overwriteCheck(path + chartName, chartName, PsychJsonPrinter.print(chartData, ['sectionNotes', 'events']), nextChart, true);
										return;
									}
	
									if(pack.events != null)
									{
										overwriteCheck(path + 'events/events.json', 'events/events.json', PsychJsonPrinter.print(pack.events, ['events']), function()
										{
											if(overwriteSavedSomething)
												showOutput('Files saved successfully to: ${fileDialog.path}!');
										}, true);
									}
									else if(overwriteSavedSomething)
										showOutput('Files saved successfully to: ${fileDialog.path}!');
								}
								
								overwriteSavedSomething = false;
								nextChart();
							});
						}
						else showOutput('Error: No difficulties found.');
					}
					catch(e:Exception)
					{
						showOutput('Error: ${e.message}', true);
						trace(e.stack);
					}
				});
			});
		},btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);
		
		#if sys
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Update (Legacy)...', function()
		{
			if(!fileDialog.completed) return;
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;

			fileDialog.open(function()
			{
				var oldSong = PlayState.SONG;
				try
				{
					var filePath:String = fileDialog.path.replace('\\', '/');
					filePath = filePath.substring(filePath.lastIndexOf('/')+1, filePath.lastIndexOf('.'));

					var loadedChart:SwagSong = Song.parseJSON(fileDialog.data, filePath, '');
					if(loadedChart == null || !Reflect.hasField(loadedChart, 'song')) //Check if chart is ACTUALLY a chart and valid
					{
						showOutput('Error: File loaded is not a Psych Engine 0.x.x/FNF 0.2.x.x chart.', true);
						return;
					}

					var fmt:String = loadedChart.format;
					if(fmt == null || fmt.length < 1)
						fmt = loadedChart.format = 'unknown';

					if(!Song.isPsychLikeFormat(fmt))
					{
						Song.convert(loadedChart);
						Song.normalizeChart(loadedChart);
						File.saveContent(fileDialog.path, PsychJsonPrinter.print(loadedChart, ['sectionNotes', 'events']));
						showOutput('Updated "$filePath" from format "$fmt" to "${Song.VIRO_FORMAT}" successfully!');
					}
					else if(fmt != Song.VIRO_FORMAT)
					{
						Song.normalizeChart(loadedChart);
						File.saveContent(fileDialog.path, PsychJsonPrinter.print(loadedChart, ['sectionNotes', 'events']));
						showOutput('Updated "$filePath" from format "$fmt" to "${Song.VIRO_FORMAT}" successfully!');
					}
					else showOutput('Chart is already up-to-date! Format: "$fmt"', true);
				}
				catch(e:Exception)
				{
					showOutput('Error: ${e.message}', true);
					trace(e.stack);
				}
			});
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);
		#end
		#end
		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Exit', function()
		{
			PlayState.chartingMode = false;
			MusicBeatState.switchState(new states.MainMenuState(true));
			FlxG.sound.playMusic(Paths.menuMusic('mainMenu'));
			FlxG.mouse.visible = false;
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);
	}

	var lockedEvents:Bool = false;
	function addEditTab()
	{
		var tab = upperBox.getTab('Edit');
		var tab_group = tab.menu;
		var btnX = tab.x - upperBox.x;
		var btnY = 1;
		var btnWid = Std.int(tab.width);

		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Undo', undo, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Redo', redo, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Select All', function()
		{
			var sel = selectedNotes;
			selectedNotes = curRenderedNotes.members.copy();
			addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
			onSelectNote();
			trace('Notes selected: ' + selectedNotes.length);
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		if(SHOW_EVENT_COLUMN)
		{
			btnY++;
			btnY += 20;
			var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Lock Events', btnWid);
			btn.onClick = function()
			{
				lockedEvents = !lockedEvents;
				if(lockedEvents) btn.text.text = '  Unlock Events';
				else btn.text.text = '  Lock Events';
				eventLockOverlay.visible = lockedEvents;
	
				if(selectedNotes.length >= 1)
				{
					var sel = selectedNotes;
					var onlyNotes = selectedNotes.filter((note:MetaNote) -> !note.isEvent);
					resetSelectedNotes();
					selectedNotes = onlyNotes;
					addUndoAction(SELECT_NOTE, {old: sel, current: selectedNotes.copy()});
					if(selectedNotes.length == 1) onSelectNote();
				}
				softReloadNotes();
			};
			btn.text.alignment = LEFT;
			tab_group.add(btn);
		}
		
		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Clear All Notes', function()
		{
			var func:Void->Void = function()
			{
				resetSelectedNotes();
				addUndoAction(DELETE_NOTE, {notes: notes.copy()});
				notes = [];
				loadSection();
				EditorSFX.playChartSound('note_delete', 0.75);
			}

			if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('Delete all Notes in the song?', func));
			else func();
		}, btnWid);
		btn.normalStyle.bgColor = FlxColor.RED;
		btn.normalStyle.textColor = FlxColor.WHITE;
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		if(SHOW_EVENT_COLUMN)
		{
			btnY += 20;
			var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Clear All Events', function()
			{
				var func:Void->Void = function()
				{
					resetSelectedNotes();
					addUndoAction(DELETE_NOTE, {events: events.copy()});
					events = [];
					loadSection();
					EditorSFX.playChartSound('note_delete', 0.75);
				}
	
				if(!ignoreProgressCheckBox.checked) openSubState(new Prompt('Delete all Events in the song?', func));
				else func();
			}, btnWid);
			btn.normalStyle.bgColor = FlxColor.RED;
			btn.normalStyle.textColor = FlxColor.WHITE;
			btn.text.alignment = LEFT;
			tab_group.add(btn);
		}
	}

	function addConvertersTab()
	{
		upperBox.getTab('Converters').menu.visible = false;
	}

	function addSettingsTab()
	{
		upperBox.getTab('Settings').menu.visible = false;
	}

	function addTestingTab()
	{
		var tab = upperBox.getTab('Testing');
		var tab_group = tab.menu;
		var btnX = tab.x - upperBox.x;
		var btnY = 1;
		var btnWid = Std.int(tab.width);

		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Preview (F12)', openEditorPlayState, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Playtest (Enter)', goToPlayState, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);
	}

	function openSettingsWindow(?startTab:String = 'Editor Theme'):Void
	{
		if(!fileDialog.completed) return;

		upperBox.isMinimized = true;
		upperBox.bg.visible = false;
		ClientPrefs.toggleVolumeKeys(false);

		openSubState(new BasePrompt(720, 430, 'Settings',
			function(state:BasePrompt)
			{
				var closeBtn:PsychUIButton = new PsychUIButton(state.bg.x + state.bg.width - 40, state.bg.y, 'X', state.close, 40);
				closeBtn.cameras = state.cameras;
				state.add(closeBtn);

				var sideX:Float = state.bg.x + 18;
				var sideY:Float = state.bg.y + 76;
				var contentX:Float = state.bg.x + 190;
				var contentY:Float = state.bg.y + 76;
				var settingsMembers:Array<FlxBasic> = [];
				var sidebarButtons:Map<String, PsychUIButton> = [];

				function addSetting(member:FlxBasic):FlxBasic
				{
					if(Std.isOfType(member, FlxSprite))
						cast(member, FlxSprite).cameras = state.cameras;
					else if(Std.isOfType(member, FlxSpriteGroup))
					{
						var group:FlxSpriteGroup = cast member;
						group.cameras = state.cameras;
					}
					state.add(member);
					settingsMembers.push(member);
					return member;
				}

				function addLabel(x:Float, y:Float, width:Float, text:String, ?size:Int = 12):FlxText
				{
					return cast addSetting(new FlxText(x, y, width, text, size));
				}

				function clearSettings():Void
				{
					for(member in settingsMembers)
					{
						state.remove(member, true);
						FlxDestroyUtil.destroy(member);
					}
					settingsMembers = [];
				}

				function refreshSidebar(selected:String):Void
				{
					for(name => button in sidebarButtons)
					{
						var isSelected:Bool = name == selected;
						button.normalStyle.bgColor = isSelected ? HaxeUITheme.PURPLE_DARK : HaxeUITheme.PANEL;
						button.normalStyle.textColor = isSelected ? FlxColor.WHITE : HaxeUITheme.TEXT;
						button.forceCheckNext = true;
					}
				}

				function buildTheme():Void
				{
					var y:Float = contentY + 38;
					addLabel(contentX, contentY, 420, 'Editor Theme', 18);

					var themes:Array<{label:String, value:ChartingTheme}> = [
						{label: 'Light', value: LIGHT},
						{label: 'Dark', value: DARK},
						{label: 'Default', value: DEFAULT},
						{label: 'Custom', value: CUSTOM}
					];
					for(i in 0...themes.length)
					{
						var entry = themes[i];
						var btn:PsychUIButton = cast addSetting(new PsychUIButton(contentX + i * 96, y, entry.label, function() changeTheme(entry.value), 88));
					}

					y += 48;
					addLabel(contentX, y, 240, 'Custom Gradient');
					var gradientInputs:Array<PsychUIInputText> = [];
					for(i in 0...coresLegaisManeiras.length)
					{
						var input:PsychUIInputText = cast addSetting(new PsychUIInputText(contentX + i * 88, y + 18, 74, coresLegaisManeiras[i], 8));
						input.maxLength = 6;
						input.filterMode = ONLY_HEXADECIMAL;
						input.forceCase = UPPER_CASE;
						var colorIndex:Int = i;
						input.onChange = function(old:String, cur:String) serManeiro(colorIndex, cur);
						gradientInputs.push(input);
					}

					y += 62;
					addLabel(contentX, y, 240, 'Custom Grid Colors');
					var gridInputs:Array<PsychUIInputText> = [];
					for(i in 0...gridNadaLegalENadaManeira.length)
					{
						var input:PsychUIInputText = cast addSetting(new PsychUIInputText(contentX + i * 88, y + 18, 74, gridNadaLegalENadaManeira[i], 8));
						input.maxLength = 6;
						input.filterMode = ONLY_HEXADECIMAL;
						input.forceCase = UPPER_CASE;
						var colorIndex:Int = i;
						input.onChange = function(old:String, cur:String) changeGridColors(colorIndex, cur);
						gridInputs.push(input);
					}

					y += 64;
					addSetting(new PsychUIButton(contentX, y, 'Save Preset', PresetGradSave, 110));
					addSetting(new PsychUIButton(contentX + 122, y, 'Open Preset', function()
					{
						PresetGradOpen(function()
						{
							for(i in 0...gradientInputs.length)
								gradientInputs[i].text = coresLegaisManeiras[i];
							for(i in 0...gridInputs.length)
								gridInputs[i].text = gridNadaLegalENadaManeira[i];
						});
					}, 110));

					var textured:PsychUICheckBox = cast addSetting(new PsychUICheckBox(contentX, y + 44, 'Textured Hold Notes', 200));
					textured.checked = chartEditorSave.data.texturedSustains ?? true;
					textured.onClick = function()
					{
						chartEditorSave.data.texturedSustains = textured.checked;
						chartEditorSave.flush();
						refreshSustains(textured.checked);
					}
				}

				function buildEditor():Void
				{
					var y:Float = contentY + 38;
					addLabel(contentX, contentY, 420, 'Editor', 18);

					showLastGridButton = cast addSetting(new PsychUIButton(contentX, y, '', function()
					{
						showPreviousSection = !showPreviousSection;
						updateGridVisibility();
					}, 170));
					showLastGridButton.text.alignment = LEFT;

					showNextGridButton = cast addSetting(new PsychUIButton(contentX + 182, y, '', function()
					{
						showNextSection = !showNextSection;
						updateGridVisibility();
					}, 170));
					showNextGridButton.text.alignment = LEFT;

					y += 32;
					noteTypeLabelsButton = cast addSetting(new PsychUIButton(contentX, y, '', function()
					{
						showNoteTypeLabels = !showNoteTypeLabels;
						updateGridVisibility();
					}, 170));
					noteTypeLabelsButton.text.alignment = LEFT;

					downScrollButton = cast addSetting(new PsychUIButton(contentX + 182, y, downScroll ? '  Down-Scroll ON' : '  Down-Scroll OFF', function()
					{
						downScroll = !downScroll;
						chartEditorSave.data.downScroll = downScroll;
						chartEditorSave.flush();
						downScrollButton.text.text = downScroll ? '  Down-Scroll ON' : '  Down-Scroll OFF';
						scrollDirectionUpdated();
					}, 170));
					downScrollButton.text.alignment = LEFT;

					updateGridVisibility();

					#if lime_cffi
					y += 50;
					addLabel(contentX, y, 240, 'Waveform');
					var waveCheck:PsychUICheckBox = cast addSetting(new PsychUICheckBox(contentX, y + 20, 'Enabled', 80));
					waveCheck.checked = waveformEnabled;
					waveCheck.onClick = function()
					{
						chartEditorSave.data.waveformEnabled = waveformEnabled = waveCheck.checked;
						chartEditorSave.flush();
						updateWaveform();
					}

					var waveformC:String = chartEditorSave.data.waveformColor != null ? chartEditorSave.data.waveformColor : '0000FF';
					addLabel(contentX + 112, y + 2, 80, 'Color');
					var input:PsychUIInputText = cast addSetting(new PsychUIInputText(contentX + 112, y + 20, 64, waveformC, 10));
					input.maxLength = 6;
					input.filterMode = ONLY_HEXADECIMAL;
					input.forceCase = UPPER_CASE;
					input.onChange = function(old:String, cur:String)
					{
						chartEditorSave.data.waveformColor = cur;
						chartEditorSave.flush();
						waveformSprite.color = CoolUtil.colorFromString(cur);
					}

					addLabel(contentX + 205, y + 2, 80, 'Opacity');
					var alphaStepper:PsychUINumericStepper = cast addSetting(new PsychUINumericStepper(contentX + 205, y + 20, 0.1, waveformSprite.alpha, 0, 1, 2, true));
					alphaStepper.onValueChange = function()
					{
						chartEditorSave.data.waveformAlpha = waveformSprite.alpha = alphaStepper.value;
						chartEditorSave.flush();
					}

					var options:Array<WaveformTarget> = [INST, PLAYER, OPPONENT, EVERYTHING];
					var radioGrp:PsychUIRadioGroup = cast addSetting(new PsychUIRadioGroup(contentX, y + 58, ['Instrumental', 'Main Vocals', 'Opponent Vocals', 'Every Track'], 22, 0, false, 140));
					radioGrp.onClick = function()
					{
						waveformTarget = chartEditorSave.data.waveformTarget = options[radioGrp.checked];
						chartEditorSave.flush();
						updateWaveform();
					};
					radioGrp.checked = Std.int(Math.max(0, options.indexOf(waveformTarget)));
					#end

					y += 162;
					addSetting(new PsychUIButton(contentX, y, 'Go to...', function()
					{
						state.close();
						openGoToWindow();
					}, 120));
				}

				function buildEditorDetails():Void
				{
					var y:Float = contentY + 44;
					addLabel(contentX, contentY, 420, 'Editor Details', 18);
					addLabel(contentX, y, 360, 'Visual List Picker', 14);

					var blurCheck:PsychUICheckBox = cast addSetting(new PsychUICheckBox(contentX, y + 27, 'Gaussian Blur', 220));
					blurCheck.checked = chartEditorSave.data.visualListBlur ?? true;
					blurCheck.onClick = function()
					{
						chartEditorSave.data.visualListBlur = blurCheck.checked;
						chartEditorSave.flush();
					}

					var detail:FlxText = addLabel(contentX, y + 66, 430,
						'Blurs the editor behind categorized icon selectors.\nThe dark background remains enabled when blur is off.', 11);
					detail.alpha = 0.72;
				}

				function buildAutosave():Void
				{
					addLabel(contentX, contentY, 420, 'AutoSave settings', 18);
					#if sys
					var y:Float = contentY + 48;
					var timeStepper:PsychUINumericStepper = null;
					var enabledCheck:PsychUICheckBox = null;

					addLabel(contentX, y - 16, 130, 'Time (minutes)');
					timeStepper = cast addSetting(new PsychUINumericStepper(contentX, y, 1, autoSaveCap > 0 ? autoSaveCap : 2, 1, 30, 0));
					timeStepper.onValueChange = function()
					{
						autoSaveTime = 0;
						enabledCheck.checked = true;
						autoSaveCap = chartEditorSave.data.autoSave = Std.int(timeStepper.value);
						chartEditorSave.flush();
					}

					enabledCheck = cast addSetting(new PsychUICheckBox(contentX + 88, y + 2, 'Enabled', 80));
					enabledCheck.checked = autoSaveCap > 0;
					enabledCheck.onClick = function()
					{
						autoSaveTime = 0;
						autoSaveCap = chartEditorSave.data.autoSave = enabledCheck.checked ? Std.int(timeStepper.value) : 0;
						chartEditorSave.flush();
					}

					addLabel(contentX + 210, y - 16, 100, 'File Limit');
					var maxFileStepper:PsychUINumericStepper = cast addSetting(new PsychUINumericStepper(contentX + 210, y, 1, backupLimit, 0, 50, 0));
					maxFileStepper.onValueChange = function()
					{
						autoSaveTime = 0;
						chartEditorSave.data.backupLimit = backupLimit = Std.int(maxFileStepper.value);
						chartEditorSave.flush();
					}

					var legacyCheck:PsychUICheckBox = cast addSetting(new PsychUICheckBox(contentX, y + 54, 'Legacy AutoSave System', 220));
					legacyCheck.checked = ClientPrefs.data.chartEditorLegacyAutosave;
					legacyCheck.onClick = function()
					{
						ClientPrefs.data.chartEditorLegacyAutosave = legacyCheck.checked;
						ClientPrefs.saveSettings();
					}
					#else
					addLabel(contentX, contentY + 48, 420, 'Autosave settings need sys file access on this target.');
					#end
				}

				function buildSFX():Void
				{
					var y:Float = contentY + 44;
					addLabel(contentX, contentY, 420, 'SFX', 18);

					var sfxCheck:PsychUICheckBox = cast addSetting(new PsychUICheckBox(contentX, y, 'Editor Sound Effects', 220));
					sfxCheck.checked = ClientPrefs.data.editorSFX;
					sfxCheck.onClick = function()
					{
						ClientPrefs.data.editorSFX = sfxCheck.checked;
						ClientPrefs.saveSettings();
					}

					y += 44;
					var musicCheck:PsychUICheckBox = cast addSetting(new PsychUICheckBox(contentX, y, 'Charting Music', 220));
					musicCheck.checked = ClientPrefs.data.chartEditorMusic;
					musicCheck.onClick = function()
					{
						ClientPrefs.data.chartEditorMusic = musicCheck.checked;
						ClientPrefs.saveSettings();
						updateChartEditorMusicVolume();
					}

					var slider:PsychUISlider = cast addSetting(new PsychUISlider(contentX, y + 58, function(v:Float)
					{
						ClientPrefs.data.chartEditorMusicVolume = FlxMath.roundDecimal(v, 2);
						ClientPrefs.saveSettings();
						updateChartEditorMusicVolume();
					}, ClientPrefs.data.chartEditorMusicVolume, 0, 1, 260));
					slider.decimals = 2;
					slider.label = 'Charting Music Volume';
				}

				function buildMisc():Void
				{
					var y:Float = contentY + 42;
					addLabel(contentX, contentY, 420, 'Misc.', 18);

					var clearBtn:PsychUIButton = cast addSetting(new PsychUIButton(contentX, y, 'Clear Data', function()
					{
						state.close();
						openSubState(new Prompt('Reset all editor settings to default?', function()
						{
							resetEditorSettingsToDefault();
							openSettingsWindow('Misc.');
						}));
					}, 130));
					clearBtn.normalStyle.bgColor = FlxColor.RED;
					clearBtn.normalStyle.textColor = FlxColor.WHITE;

					y += 62;
					addLabel(contentX, y, 300, 'Default Converter');
					var converterOptions = MoonchartConverters.getExternalFormats();
					var labels:Array<String> = [for(option in converterOptions) option.label];
					if(labels.length < 1) labels = [''];
					var converterDropDown:PsychUIDropDownMenu = cast addSetting(new PsychUIDropDownMenu(contentX, y + 20, labels, function(id:Int, label:String)
					{
						ClientPrefs.data.chartEditorDefaultConverter = label;
						ClientPrefs.saveSettings();
					}, 300));
					var selectedIndex:Int = labels.indexOf(ClientPrefs.data.chartEditorDefaultConverter);
					converterDropDown.selectedIndex = selectedIndex >= 0 ? selectedIndex : 0;

					addLabel(contentX + 322, y, 140, 'Difficulty');
					var difficultyInput:PsychUIInputText = cast addSetting(new PsychUIInputText(contentX + 322, y + 20, 120, ClientPrefs.data.chartEditorDefaultConverterDifficulty, 8));
					difficultyInput.forceCase = LOWER_CASE;
					difficultyInput.onChange = function(old:String, cur:String)
					{
						ClientPrefs.data.chartEditorDefaultConverterDifficulty = Paths.formatToSongPath(cur);
						ClientPrefs.saveSettings();
					}
				}

				function selectSettingsTab(name:String):Void
				{
					clearSettings();
					refreshSidebar(name);
					switch(name)
					{
						case 'Editor Theme':
							buildTheme();
						case 'Editor':
							buildEditor();
						case 'Editor Details':
							buildEditorDetails();
						case 'AutoSave settings':
							buildAutosave();
						case 'SFX':
							buildSFX();
						case 'Misc.':
							buildMisc();
					}
				}

				var tabNames:Array<String> = ['Editor Theme', 'Editor', 'Editor Details', 'AutoSave settings', 'SFX', 'Misc.'];
				for(i in 0...tabNames.length)
				{
					var tabName:String = tabNames[i];
					var btn:PsychUIButton = new PsychUIButton(sideX, sideY + i * 32, tabName, function() selectSettingsTab(tabName), 150, 28);
					btn.text.alignment = LEFT;
					btn.cameras = state.cameras;
					sidebarButtons.set(tabName, btn);
					state.add(btn);
				}

				selectSettingsTab(startTab);
			}
		));
	}

	function resetEditorSettingsToDefault():Void
	{
		autoSaveTime = 0;
		autoSaveCap = 2;
		backupLimit = 10;
		autoLoadEvents = true;
		downScroll = false;
		vortexEnabled = false;
		waveformEnabled = false;
		waveformTarget = INST;
		showPreviousSection = true;
		showNextSection = true;
		showNoteTypeLabels = true;
		coresLegaisManeiras = ['6E1896', '57C785', 'EDDD53'];
		gridNadaLegalENadaManeira = ['DFDFDF', 'BFBFBF'];

		chartEditorSave.data.autoSave = autoSaveCap;
		chartEditorSave.data.backupLimit = backupLimit;
		chartEditorSave.data.autoLoadEvents = autoLoadEvents;
		chartEditorSave.data.downScroll = downScroll;
		chartEditorSave.data.vortex = vortexEnabled;
		chartEditorSave.data.mouseScrollSnap = false;
		chartEditorSave.data.ignoreProgressWarns = false;
		chartEditorSave.data.waveformEnabled = waveformEnabled;
		chartEditorSave.data.waveformTarget = waveformTarget;
		chartEditorSave.data.waveformColor = '0000FF';
		chartEditorSave.data.waveformAlpha = 1;
		chartEditorSave.data.theme = DEFAULT;
		chartEditorSave.data.coresLegaisManeiras = coresLegaisManeiras.copy();
		chartEditorSave.data.customGridColors = gridNadaLegalENadaManeira.copy();
		chartEditorSave.data.texturedSustains = true;
		chartEditorSave.data.visualListBlur = true;
		chartEditorSave.flush();

		ClientPrefs.data.editorSFX = true;
		ClientPrefs.data.chartEditorMusic = true;
		ClientPrefs.data.chartEditorMusicVolume = 0.35;
		ClientPrefs.data.chartEditorLegacyAutosave = false;
		ClientPrefs.data.chartEditorDefaultConverter = '';
		ClientPrefs.data.chartEditorDefaultConverterDifficulty = 'normal';
		ClientPrefs.saveSettings();

		if(mouseSnapCheckBox != null) mouseSnapCheckBox.checked = false;
		if(ignoreProgressCheckBox != null) ignoreProgressCheckBox.checked = false;
		if(autoloadEventCheckBox != null) autoloadEventCheckBox.checked = autoLoadEvents;
		if(vortexEditorCheckBox != null) vortexEditorCheckBox.checked = vortexEnabled;
		if(waveformSprite != null)
		{
			waveformSprite.color = CoolUtil.colorFromString('0000FF');
			waveformSprite.alpha = 1;
		}

		changeTheme(DEFAULT, false);
		refreshSustains(true);
		updateWaveform();
		updateGridVisibility();
		scrollDirectionUpdated();
		updateChartEditorMusicVolume();
		showOutput('Editor settings reset to default.');
	}

	function openGoToWindow():Void
	{
		if(FlxG.sound.music == null)
		{
			showOutput('Load a valid song to use Go To!', true);
			return;
		}

		upperBox.isMinimized = true;
		upperBox.bg.visible = false;
		openSubState(new BasePrompt(420, 200, 'Go to Time/Section:',
			function(state:BasePrompt)
			{
				var curTime:Float = Conductor.songPosition;
				var currentSec:Int = curSec;

				var timeStepper:PsychUINumericStepper = new PsychUINumericStepper(state.bg.x + 100, state.bg.y + 90, 1, Math.floor(curTime)/1000, 0, FlxG.sound.music.length/1000 - 0.01, 2, 80);
				timeStepper.cameras = state.cameras;
				var sectionStepper:PsychUINumericStepper = new PsychUINumericStepper(timeStepper.x + 160, timeStepper.y, 1, currentSec, 0, PlayState.SONG.notes.length - 1, 0);
				sectionStepper.cameras = state.cameras;

				var txt1:FlxText = new FlxText(timeStepper.x, timeStepper.y - 15, 100, 'Time (in seconds):');
				var txt2:FlxText = new FlxText(sectionStepper.x, sectionStepper.y - 15, 100, 'Section:');
				txt1.cameras = state.cameras;
				txt2.cameras = state.cameras;
				state.add(txt1);
				state.add(txt2);
				state.add(timeStepper);
				state.add(sectionStepper);

				var timeTxt:FlxText = new FlxText(15, state.bg.y + state.bg.height - 75, 230, '', 16);
				timeTxt.alignment = CENTER;
				timeTxt.screenCenter(X);
				timeTxt.cameras = state.cameras;
				state.add(timeTxt);
				function updateTime()
				{
					var tm:String = FlxStringUtil.formatTime(curTime / 1000, true);
					var ln:String = FlxStringUtil.formatTime(FlxG.sound.music.length / 1000, true);
					timeTxt.text = '$tm / $ln';
				}
				updateTime();

				timeStepper.onValueChange = function()
				{
					curTime = timeStepper.value * 1000;
					for (i => time in cachedSectionTimes)
					{
						if(time <= curTime)
							currentSec = i;
						else break;
					}
					updateTime();
				};
				sectionStepper.onValueChange = function()
				{
					currentSec = Std.int(sectionStepper.value);
					curTime = cachedSectionTimes[currentSec] + 0.000001;
					updateTime();
				};

				var btn:PsychUIButton = new PsychUIButton(0, timeTxt.y + 30, 'Go To', function()
				{
					curSec = currentSec;
					Conductor.songPosition = FlxMath.bound(curTime, 0, getEditorSongEndTime());
					setSongPlaying(true);
					loadSection();
					state.close();
				});
				btn.cameras = state.cameras;
				btn.screenCenter(X);
				btn.x -= 60;
				state.add(btn);

				var btn:PsychUIButton = new PsychUIButton(0, btn.y, 'Cancel', state.close);
				btn.cameras = state.cameras;
				btn.screenCenter(X);
				btn.x += 60;
				state.add(btn);
			}
		));
	}

	var downScrollButton:PsychUIButton;
	var showLastGridButton:PsychUIButton;
	var showNextGridButton:PsychUIButton;
	var noteTypeLabelsButton:PsychUIButton;
	function loadEditorViewSettings():Void
	{
		if(chartEditorSave.data.waveformEnabled != null)
			waveformEnabled = chartEditorSave.data.waveformEnabled;
		if(chartEditorSave.data.waveformTarget != null)
			waveformTarget = chartEditorSave.data.waveformTarget;
		if(chartEditorSave.data.waveformColor != null)
			waveformSprite.color = CoolUtil.colorFromString(chartEditorSave.data.waveformColor);
		if(chartEditorSave.data.waveformAlpha != null)
			waveformSprite.alpha = chartEditorSave.data.waveformAlpha;
	}

	function addViewTab()
	{
		var tab = upperBox.getTab('View');
		var tab_group = tab.menu;
		var btnX = tab.x - upperBox.x;
		var btnY = 1;
		var btnWid = Std.int(tab.width);

		if(chartEditorSave.data.waveformEnabled != null)
			waveformEnabled = chartEditorSave.data.waveformEnabled;
		if(chartEditorSave.data.waveformTarget != null)
			waveformTarget = chartEditorSave.data.waveformTarget;
		if(chartEditorSave.data.waveformColor != null)
			waveformSprite.color = CoolUtil.colorFromString(chartEditorSave.data.waveformColor);
		if(chartEditorSave.data.waveformAlpha != null)
			waveformSprite.alpha = chartEditorSave.data.waveformAlpha;

		showLastGridButton = new PsychUIButton(btnX, btnY, '', function()
		{
			showPreviousSection = !showPreviousSection;
			updateGridVisibility();
		}, btnWid);
		showLastGridButton.text.alignment = LEFT;
		tab_group.add(showLastGridButton);

		btnY += 20;
		showNextGridButton = new PsychUIButton(btnX, btnY, '', function()
		{
			showNextSection = !showNextSection;
			updateGridVisibility();
		}, btnWid);
		showNextGridButton.text.alignment = LEFT;
		tab_group.add(showNextGridButton);

		btnY++;
		btnY += 20;
		noteTypeLabelsButton = new PsychUIButton(btnX, btnY, '', function()
		{
			showNoteTypeLabels = !showNoteTypeLabels;
			updateGridVisibility();
		}, btnWid);
		noteTypeLabelsButton.text.alignment = LEFT;
		tab_group.add(noteTypeLabelsButton);

		btnY++;
		btnY += 20;
		downScrollButton = new PsychUIButton(btnX, btnY, downScroll ? '  Down-Scroll ON' : '  Down-Scroll OFF', function()
		{
			downScroll = !downScroll;
			chartEditorSave.data.downScroll = downScroll;
			downScrollButton.text.text = downScroll ? '  Down-Scroll ON' : '  Down-Scroll OFF';
			trace('SWITCH DOWNSCROLL');
			scrollDirectionUpdated();
		}, btnWid);
		downScrollButton.text.alignment = LEFT;
		tab_group.add(downScrollButton);
		
		#if lime_cffi
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Waveform...', function()
		{
			ClientPrefs.toggleVolumeKeys(false);
			openSubState(new BasePrompt(320, 215, 'Waveform Settings',
				function(state:BasePrompt) {
					upperBox.isMinimized = true;
					upperBox.bg.visible = false;

					var btn:PsychUIButton = new PsychUIButton(state.bg.x + state.bg.width - 40, state.bg.y, 'X', state.close, 40);
					btn.cameras = state.cameras;
					state.add(btn);

					var check:PsychUICheckBox = new PsychUICheckBox(state.bg.x + 40, state.bg.y + 80, 'Enabled', 60);
					check.onClick = function()
					{
						chartEditorSave.data.waveformEnabled = waveformEnabled = check.checked;
						updateWaveform();
					};
					check.cameras = state.cameras;
					check.checked = waveformEnabled;
					state.add(check);

					var waveformC:String = '0000FF';
					if(chartEditorSave.data.waveformColor != null)
						waveformC = chartEditorSave.data.waveformColor;

					var input:PsychUIInputText = new PsychUIInputText(check.x, check.y + 42, 60, waveformC, 10);
					input.onChange = function(old:String, cur:String)
					{
						chartEditorSave.data.waveformColor = cur;
						waveformSprite.color = CoolUtil.colorFromString(cur);
					}
					input.maxLength = 6;
					input.filterMode = ONLY_HEXADECIMAL;
					input.cameras = state.cameras;
					input.forceCase = UPPER_CASE;
					
					state.add(new FlxText(check.x, input.y + 25, 80, 'Opacity:'));
					var alphaStepper:PsychUINumericStepper = new PsychUINumericStepper(check.x, input.y + 40, 0.1, 1, 0, 1, 2, true);
					alphaStepper.onValueChange = function() {
						var alpha:Float = alphaStepper.value;
						chartEditorSave.data.waveformAlpha = alpha;
						waveformSprite.alpha = alpha;
					};
					alphaStepper.value = waveformSprite.alpha;
					alphaStepper.cameras = state.cameras;
					state.add(alphaStepper);

					var options:Array<WaveformTarget> = [INST, PLAYER, OPPONENT, EVERYTHING];
					var radioGrp:PsychUIRadioGroup = new PsychUIRadioGroup(check.x + 120, check.y, ['Instrumental', 'Main Vocals', 'Opponent Vocals', 'Every Track']);
					radioGrp.cameras = state.cameras;
					radioGrp.onClick = function()
					{
						waveformTarget = chartEditorSave.data.waveformTarget = options[radioGrp.checked];
						updateWaveform();
					};
					radioGrp.checked = options.indexOf(waveformTarget);
					state.add(radioGrp);

					var txt1:FlxText = new FlxText(input.x, input.y - 15, 80, 'Color (Hex):');
					txt1.cameras = state.cameras;
					state.add(txt1);
					state.add(input);
				}
			));
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);
		#end

		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Go to...', function()
		{
			if(FlxG.sound.music == null)
			{
				showOutput('Load a valid song to use Go To!', true);
				return;
			}

			upperBox.isMinimized = true;
			upperBox.bg.visible = false;
			openSubState(new BasePrompt(420, 200, 'Go to Time/Section:',
				function(state:BasePrompt)
				{
					var curTime:Float = Conductor.songPosition;
					var currentSec:Int = curSec;

					var timeStepper:PsychUINumericStepper = new PsychUINumericStepper(state.bg.x + 100, state.bg.y + 90, 1, Math.floor(curTime)/1000, 0, FlxG.sound.music.length/1000 - 0.01, 2, 80);
					timeStepper.cameras = state.cameras;
					var sectionStepper:PsychUINumericStepper = new PsychUINumericStepper(timeStepper.x + 160, timeStepper.y, 1, currentSec, 0, PlayState.SONG.notes.length - 1, 0);
					sectionStepper.cameras = state.cameras;

					var txt1:FlxText = new FlxText(timeStepper.x, timeStepper.y - 15, 100, 'Time (in seconds):');
					var txt2:FlxText = new FlxText(sectionStepper.x, sectionStepper.y - 15, 100, 'Section:');
					txt1.cameras = state.cameras;
					txt2.cameras = state.cameras;
					state.add(txt1);
					state.add(txt2);
					state.add(timeStepper);
					state.add(sectionStepper);

					var timeTxt:FlxText = new FlxText(15, state.bg.y + state.bg.height - 75, 230, '', 16);
					timeTxt.alignment = CENTER;
					timeTxt.screenCenter(X);
					timeTxt.cameras = state.cameras;
					state.add(timeTxt);
					function updateTime()
					{
						var tm:String = FlxStringUtil.formatTime(curTime / 1000, true);
						var ln:String = FlxStringUtil.formatTime(FlxG.sound.music.length / 1000, true);
						timeTxt.text = '$tm / $ln';
					}
					updateTime();

					timeStepper.onValueChange = function()
					{
						curTime = timeStepper.value * 1000;
						for (i => time in cachedSectionTimes)
						{
							if(time <= curTime)
								currentSec = i;
							else break;
						}
						updateTime();
					};
					sectionStepper.onValueChange = function()
					{
						currentSec = Std.int(sectionStepper.value);
						curTime = cachedSectionTimes[currentSec] + 0.000001;
						updateTime();
					};

					var btn:PsychUIButton = new PsychUIButton(0, timeTxt.y + 30, 'Go To', function()
					{
						curSec = currentSec;
						Conductor.songPosition = FlxMath.bound(curTime, 0, getEditorSongEndTime());
						setSongPlaying(true);
						loadSection();
						state.close();
					});
					btn.cameras = state.cameras;
					btn.screenCenter(X);
					btn.x -= 60;
					state.add(btn);

					var btn:PsychUIButton = new PsychUIButton(0, btn.y, 'Cancel', state.close);
					btn.cameras = state.cameras;
					btn.screenCenter(X);
					btn.x += 60;
					state.add(btn);
				}
			));
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);

		btnY++;
		btnY += 20;
		var btn:PsychUIButton = new PsychUIButton(btnX, btnY, '  Theme...', function()
		{
			if(!fileDialog.completed) return;
			upperBox.isMinimized = true;
			upperBox.bg.visible = false;

			openSubState(new BasePrompt(430, 315, 'Chart Editor Theme',
				function(state:BasePrompt)
				{
					var btn:PsychUIButton = new PsychUIButton(state.bg.x + state.bg.width - 40, state.bg.y, 'X', state.close, 40);
					btn.cameras = state.cameras;
					state.add(btn);

					var btnY = state.bg.y + 78;
					var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Light', changeTheme.bind(LIGHT));
					btn.screenCenter(X);
					btn.x -= 150;
					btn.cameras = state.cameras;
					state.add(btn);
			
					var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Dark', changeTheme.bind(DARK));
					btn.screenCenter(X);
					btn.x -= 50;
					btn.cameras = state.cameras;
					state.add(btn);
					
					var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Default', changeTheme.bind(DEFAULT));
					btn.screenCenter(X);
					btn.cameras = state.cameras;
					btn.x += 50;
					state.add(btn);

					var btn:PsychUIButton = new PsychUIButton(0, btnY, 'Custom', changeTheme.bind(CUSTOM));
					btn.screenCenter(X);
					btn.cameras = state.cameras;
					btn.x += 150;
					state.add(btn);

					var label:FlxText = new FlxText(0, btnY + 46, 260, 'Custom Gradient', 12);
					label.screenCenter(X);
					label.cameras = state.cameras;
					state.add(label);

					var gradientInputs:Array<PsychUIInputText> = [];
					for(i in 0...coresLegaisManeiras.length)
					{
						var input:PsychUIInputText = new PsychUIInputText(0, btnY + 66, 74, coresLegaisManeiras[i], 8);
						input.maxLength = 6;
						input.filterMode = ONLY_HEXADECIMAL;
						input.forceCase = UPPER_CASE;
						input.screenCenter(X);
						input.x += (i - 1) * 88;
						input.cameras = state.cameras;
						var colorIndex:Int = i;
						input.onChange = function(old:String, cur:String)
						{
							serManeiro(colorIndex, cur);
						}
						gradientInputs.push(input);
						state.add(input);
					}

					var label:FlxText = new FlxText(0, btnY + 96, 260, 'Custom Grid Colors', 12);
					label.screenCenter(X);
					label.cameras = state.cameras;
					state.add(label);

					var gridInputs:Array<PsychUIInputText> = [];
					for(i in 0...gridNadaLegalENadaManeira.length)
					{
						var input:PsychUIInputText = new PsychUIInputText(0, btnY + 115, 74, gridNadaLegalENadaManeira[i], 8);
						input.maxLength = 6;
						input.filterMode = ONLY_HEXADECIMAL;
						input.forceCase = UPPER_CASE;
						input.screenCenter(X);
						input.x += (i - 1) * 88;
						input.cameras = state.cameras;
						var colorIndex:Int = i; // eu tô só copiando a mily -Shiho
						input.onChange = function(old:String, cur:String)
						{
							changeGridColors(colorIndex, cur);
						}
						gridInputs.push(input);
						state.add(input);
					}

					var savePreset:PsychUIButton = new PsychUIButton(0, btnY + 155, 'Save Preset', PresetGradSave, 110);
					savePreset.screenCenter(X);
					savePreset.x -= 62;
					savePreset.cameras = state.cameras;
					state.add(savePreset);

					var openPreset:PsychUIButton = new PsychUIButton(0, btnY + 155, 'Open Preset', function()
					{
						PresetGradOpen(function()
						{
							for(i in 0...gradientInputs.length)
								gradientInputs[i].text = coresLegaisManeiras[i];
							for(i in 0...gridInputs.length)
								gridInputs[i].text = gridNadaLegalENadaManeira[i];
						});
					}, 110);
					openPreset.screenCenter(X);
					openPreset.x += 62;
					openPreset.cameras = state.cameras;
					state.add(openPreset);

					var checkbox:PsychUICheckBox = new PsychUICheckBox(0, btnY + 200, 'Textured Hold Notes', 200);
					checkbox.screenCenter(X);
					checkbox.onClick = function() {
						chartEditorSave.data.texturedSustains = checkbox.checked;
						refreshSustains(checkbox.checked);
					}
					checkbox.checked = chartEditorSave.data.texturedSustains ?? true;
					checkbox.cameras = state.cameras;
					state.add(checkbox);
				}
			));
		}, btnWid);
		btn.text.alignment = LEFT;
		tab_group.add(btn);
		
	}

	function updateChartData()
	{
		for (secNum => section in PlayState.SONG.notes)
			PlayState.SONG.notes[secNum].sectionNotes = [];

		notes.sort(PlayState.sortByTime);
		for (note in notes)
		{
			if(note == null) continue;

			var noteSec:Int = sectionAtStep(Conductor.getStep(note.strumTime));
			note.section = noteSec;
			var arr:Array<Dynamic> = PlayState.SONG.notes[noteSec].sectionNotes;
			//trace('Added note with time ${note.songData[0]} at section $noteSec');
			arr.push(note.songData);
		}

		events.sort(PlayState.sortByTime);
		PlayState.SONG.events = [];
		for (event in events)
			PlayState.SONG.events.push(event.songData);
	}

	function saveChart(canQuickSave:Bool = true)
	{
		updateChartData();
		Song.normalizeChart(PlayState.SONG);
		var chartData:String = PsychJsonPrinter.print(PlayState.SONG, ['sectionNotes', 'events']);
		#if sys if(canQuickSave && Song.chartPath != null)
		{
			File.saveContent(Song.chartPath, chartData);
			rememberLastChartPath(Song.chartPath);
			showOutput('Chart saved successfully to: ${Song.chartPath}');
		}
		else
		#end {
			var chartName:String = Paths.formatToSongPath(PlayState.SONG.song) + '.json';
			if(Song.chartPath != null) chartName = Song.chartPath.substr(Song.chartPath.lastIndexOf('/')).trim();
			fileDialog.save(chartName, chartData,
				function()
				{
					#if sys
					var newPath:String = fileDialog.path;
					Song.chartPath = newPath.replace('\\', '/');
					rememberLastChartPath(Song.chartPath);
					reloadNotesDropdowns();
					
					showOutput('Chart saved successfully to: $newPath');
					#else
					showOutput('Chart downloaded successfully');
					#end

				}, null, function() showOutput('Error on saving chart!', true));
		}
	}
	
	inline function getCurChartSection()
	{
		return PlayState.SONG.notes != null ? PlayState.SONG.notes[curSec] : null;
	}

	function updateNotesRGB()
	{
		PlayState.SONG.disableNoteRGB = noRGBCheckBox.checked;

		for (note in notes)
		{
			if(note == null) continue;

			note.rgbShader.enabled = !noRGBCheckBox.checked;
			if(note.rgbShader.enabled)
			{
				var data = backend.NoteTypesConfig.loadNoteTypeData(note.noteType);
				if(data == null || data.length < 1) continue;

				for (line in data)
				{
					var prop:String = line.property.join('.');
					if(prop == 'rgbShader.enabled')
						note.rgbShader.enabled = line.value;
				}
			}
		}

		for (note in strumLineNotes)
			note.rgbShader.enabled = !noRGBCheckBox.checked;
	}

	function updateGridVisibility()
	{
		if(showLastGridButton != null && showLastGridButton.exists && showLastGridButton.text != null)
			showLastGridButton.text.text = '  Continuous Grid';
		if(showNextGridButton != null && showNextGridButton.exists && showNextGridButton.text != null)
			showNextGridButton.text.text = '  Section Lines On';

		prevGridBg.visible = nextGridBg.visible = false;
		
		if(noteTypeLabelsButton != null && noteTypeLabelsButton.exists && noteTypeLabelsButton.text != null)
			noteTypeLabelsButton.text.text = showNoteTypeLabels ? '  Hide Note Labels' : '  Show Note Labels';
		for (num => text in MetaNote.noteTypeTexts)
			text.visible = showNoteTypeLabels;
		softReloadNotes();
	}
	
	function adaptNotes(oldBPMMap:Array<BPMChangeEvent>, clearUndoHistory:Bool = true)
	{
		if(oldBPMMap == null || oldBPMMap.length < 1) return;
		if(clearUndoHistory) undoActions = [];
		setSongPlaying(false);
		notes.sort(PlayState.sortByTime);

		var songStep:Float = Conductor.getStep(Conductor.songPosition, oldBPMMap);
		var noteSteps:Array<{note:MetaNote, start:Float, end:Float}> = [];
		var eventSteps:Array<{note:EventMetaNote, step:Float}> = [];
		for(note in notes)
		{
			if(note == null) continue;
			noteSteps.push({
				note: note,
				start: Conductor.getStep(note.strumTime, oldBPMMap),
				end: Conductor.getStep(note.strumTime + note.sustainLength, oldBPMMap)
			});
		}
		for(event in events)
			if(event != null)
				eventSteps.push({note: event, step: Conductor.getStep(event.strumTime, oldBPMMap)});

		function syncEvents():Void
		{
			PlayState.SONG.events = [for(event in events) if(event != null) event.songData];
		}
		function retimeChart():Void
		{
			for(data in noteSteps)
			{
				var startTime:Float = Conductor.stepToSeconds(data.start);
				data.note.setStrumTime(startTime);
				data.note.setSustainLength(Conductor.stepToSeconds(data.end) - startTime, curZoom);
				positionNoteYOnTime(data.note);
			}
			for(data in eventSteps)
			{
				data.note.setStrumTime(Conductor.stepToSeconds(data.step));
				positionNoteYOnTime(data.note);
				data.note.updateEventInfo();
			}
			syncEvents();
		}

		syncEvents();
		_cacheSections();
		retimeChart();
		_cacheSections();
		retimeChart();

		var time:Float = Math.min(Math.max(0, getEditorSongLength() - 1), Conductor.stepToSeconds(songStep));
		
		Conductor.songPosition = time;
		if(FlxG.sound.music != null)
			FlxG.sound.music.time = time;
		forceDataUpdate = true;
		loadSection();
	}

	public function UIEvent(id:String, sender:Dynamic)
	{
		//trace(id, sender);
		switch(id)
		{
			case PsychUIButton.CLICK_EVENT | PsychUICheckBox.CLICK_EVENT | PsychUIInputText.CHANGE_EVENT | PsychUINumericStepper.CHANGE_EVENT | PsychUIDropDownMenu.CLICK_EVENT | PsychUIDropDownMenu.REVEAL_EVENT:
				ignoreClickForThisFrame = true;

			case PsychUIBox.CLICK_EVENT:
				ignoreClickForThisFrame = true;
				if(sender == upperBox)
				{
					if(handleUpperActionTab())
						return;
					updateUpperBoxBg();
				}

			case PsychUIBox.MINIMIZE_EVENT:
				if(sender == upperBox)
				{
					upperBox.bg.visible = !upperBox.isMinimized;
					updateUpperBoxBg();
				}

			case PsychUIBox.DROP_EVENT:
				chartEditorSave.data.mainBoxPosition = [mainBox.x, mainBox.y];
				chartEditorSave.data.infoBoxPosition = [infoBox.x, infoBox.y];
		}
	}

	function handleUpperActionTab():Bool
	{
		if(upperBox == null)
			return false;

		switch(upperBox.selectedName)
		{
			case 'Converters':
				upperBox.isMinimized = true;
				upperBox.bg.visible = false;
				abrirConversor();
				return true;

			case 'Settings':
				upperBox.isMinimized = true;
				upperBox.bg.visible = false;
				openSettingsWindow();
				return true;
		}
		return false;
	}

	function updateUpperBoxBg()
	{
		if(upperBox.selectedTab != null)
		{
			var menu = upperBox.selectedTab.menu;
			upperBox.bg.x = upperBox.x + upperBox.selectedIndex * (upperBox.width/upperBox.tabs.length);
			upperBox.bg.setGraphicSize(menu.width, menu.height + 21);
			upperBox.bg.updateHitbox();
		}
	}

	function openEditorPlayState()
	{
		if(FlxG.sound.music == null)
		{
			showOutput('Load a valid song to preview!', true);
			return;
		}
		setSongPlaying(false);
		chartEditorSave.flush(); //just in case a random crash happens before loading

		openSubState(new EditorPlayState(cast notes, [vocals, opponentVocals], downScroll));
		upperBox.isMinimized = true;
		upperBox.visible = mainBox.visible = infoBox.visible = false;
	}

	function goToPlayState()
	{
		ChartingState.startOnTime = Conductor.songPosition;
		
		if (FlxG.keys.pressed.SHIFT)
			PlayState.startOnTime = Conductor.songPosition;
		
		setSongPlaying(false);
		persistentUpdate = false;
		FlxG.mouse.visible = false;
		#if sys
		if(ClientPrefs.data.chartEditorLegacyAutosave)
			createAutosaveBackup(false);
		#end
		chartEditorSave.flush();
		
		updateChartData();
		Song.normalizeChart(PlayState.SONG);
		StageData.loadDirectory(PlayState.SONG);
		LoadingState.prepareToSong();
		LoadingState.loadAndSwitchState(new PlayState());
		ClientPrefs.toggleVolumeKeys(true);
	}
	
	override function openSubState(SubState:FlxSubState)
	{
		if(!persistentUpdate) setSongPlaying(false);
		super.openSubState(SubState);
	}

	override function closeSubState()
	{
		ClientPrefs.toggleVolumeKeys(true);
		super.closeSubState();
		upperBox.isMinimized = true;
		upperBox.visible = mainBox.visible = infoBox.visible = true;
		upperBox.bg.visible = false;
		updateAudioVolume();
	}

	override function destroy()
	{
		instance = null;
		
		Note.globalRgbShaders = [];
		backend.NoteTypesConfig.clearNoteTypesData();

		for (num => text in MetaNote.noteTypeTexts)
			text.destroy();

		MetaNote.noteTypeTexts = [];
		fileDialog.destroy();
		if(chartEditorMusicDelayTimer != null)
		{
			chartEditorMusicDelayTimer.cancel();
			chartEditorMusicDelayTimer.destroy();
			chartEditorMusicDelayTimer = null;
		}
		if(chartEditorMusicTween != null)
			chartEditorMusicTween.cancel();
		chartEditorMusic = FlxDestroyUtil.destroy(chartEditorMusic);
		super.destroy();
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, keyDown);
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, keyUp);
	}
	
	function keyDown(event:KeyboardEvent) {
		if (!focusedOnEditor()) return;
		
		var eventKey:FlxKey = event.keyCode;
		
		var num:Int = keysArray.indexOf(eventKey);
		if (vortexInput && num != -1 && FlxG.keys.checkStatus(eventKey, JUST_PRESSED)) { // note placement
			_keysPressedBuffer[num] = true;
			
			var typeSelected:String = noteTypes[noteTypeDropDown.selectedIndex];
			if(typeSelected != null)
			{
				typeSelected = typeSelected.trim();
				if(typeSelected.length < 1) typeSelected = null;
			}
			
			var noteStep:Float = snapChartStep(Conductor.getStep(Conductor.songPosition));
			var strumTime:Float = Conductor.stepToSeconds(noteStep);
			
			var deletedNotes:Array<MetaNote> = [];
			var addedNotes:Array<MetaNote> = [];
			
			trace('Vortex editor press at time: $strumTime');

			// Try to find a note to delete first
			var didDelete:Bool = false;
			for (note in curRenderedNotes) {
				if(note == null || note.isEvent) continue;
				
				var roundStep:Float = snapChartStep(Conductor.getStep(note.strumTime));
				if (note.songData[1] == num && Math.abs(noteStep - roundStep) < 0.0001) {
					deletedNotes.push(note);
					didDelete = true;
					break;
				}
			}

			// If no notes were found, add a new in its place
			if (!didDelete) {
				var didAdd:Bool = false;
				var noteSetupData:Array<Dynamic> = [strumTime, num, 0];
				var typeSelected:String = noteTypes[noteTypeDropDown.selectedIndex];
				if (typeSelected != null) noteSetupData.push(typeSelected.trim());

				var noteAdded:MetaNote = createNote(noteSetupData);
				for (num in sectionFirstNoteID...notes.length)
				{
					var note = notes[num];
					if(note.strumTime >= strumTime)
					{
						notes.insert(num, noteAdded);
						didAdd = true;
						break;
					}
				}
				if(!didAdd) notes.push(noteAdded);
				addedNotes.push(noteAdded);
				_heldNotes[num] = noteAdded;
				
				if (Conductor.songPosition > noteAdded.strumTime + .001 && FlxG.sound.music != null && FlxG.sound.music.playing)
					hitNote(noteAdded);
			}

			if (deletedNotes.length > 0) {
				for (note in deletedNotes)
				{
					if(selectedNotes.contains(note))
						selectedNotes.remove(note);
					notes.remove(note);
				}
				addUndoAction(DELETE_NOTE, {notes: deletedNotes});
				EditorSFX.playChartSound('note_delete', 0.75);
			}
			if (addedNotes.length > 0)
			{
				addUndoAction(ADD_NOTE, {notes: addedNotes});
				EditorSFX.playChartSound('note_place', 0.75);
			}
			
			if (vortexMoved)
				resetSelectedNotes();
			for (note in addedNotes)
				selectedNotes.push(note);

			softReloadNotes(true);
			forceDataUpdate = true;
			vortexMoved = false;
		}
		
		function noteShift(strumTime:Float) {
			var addedNotes:Array<MetaNote> = [];
			for (num => held in _keysPressedBuffer) {
				if (held && _heldNotes[num] == null) {
					var noteSetupData:Array<Dynamic> = [strumTime, num, 0];
					var typeSelected:String = noteTypes[noteTypeDropDown.selectedIndex];
					if (typeSelected != null) noteSetupData.push(typeSelected.trim());
					
					var didAdd:Bool = false;
					var noteAdded:MetaNote = createNote(noteSetupData);
					for (num in sectionFirstNoteID...notes.length) {
						var note = notes[num];
						if (note.strumTime >= strumTime) {
							notes.insert(num, noteAdded);
							didAdd = true;
							break;
						}
					}
					if (!didAdd) notes.push(noteAdded);
					_heldNotes[num] = noteAdded;
					addedNotes.push(noteAdded);
					softReloadNotes(true);
				}
			}
			if (addedNotes.length > 0) {
				if (vortexMoved)
					resetSelectedNotes();
				for (note in addedNotes)
					selectedNotes.push(note);
				addUndoAction(ADD_NOTE, {notes: addedNotes});
				EditorSFX.playChartSound('note_place', 0.75);
			}
		}
		
		var vortexShifted:Bool = false;
		
		if (!FlxG.keys.pressed.CONTROL) {
			switch (eventKey) {
				case FlxKey.LEFT | FlxKey.RIGHT: // quant shift
					if (!vortexInput) return;
					var quantIndex:Int = quantizations.indexOf(baseQuant);
					if (eventKey == FlxKey.LEFT) {
						baseQuant = quantizations[Std.int(Math.max(quantIndex - 1, 0))];
					} else {
						baseQuant = quantizations[Std.int(Math.min(quantIndex + 1, quantizations.length - 1))];
					}
					updateQuantForZoom();
					
				case FlxKey.Z | FlxKey.X: // zooming
					if (eventKey == FlxKey.Z) {
						curZoom = zoomList[Std.int(Math.max(zoomList.indexOf(curZoom) - 1, 0))];
					} else {
						curZoom = zoomList[Std.int(Math.min(zoomList.indexOf(curZoom) + 1, zoomList.length - 1))];
					}
					updateQuantForZoom();

					notes.sort(PlayState.sortByTime);
					forEachRenderedNote((note:MetaNote) -> {
						positionNoteYOnTime(note);
						note.updateSustainToZoom(curZoom);
					});
					
					loadSection();
					showOutput('Zoom: ${Math.round(curZoom * 100)}%');
					updateScrollY();
					
				case FlxKey.A | FlxKey.D:
					var shiftAdd:Int = (FlxG.keys.pressed.SHIFT ? 4 : 1);
					
					if(FlxG.sound.music != null && FlxG.sound.music.playing)
						setSongPlaying(false);
					
					noteShift(Conductor.stepToSeconds(snapChartStep(Conductor.getStep(Conductor.songPosition))));
					
					if (eventKey == FlxKey.A) {
						if (curSec - shiftAdd < 0) shiftAdd = curSec;

						if (shiftAdd > 0)
							loadSection(curSec - shiftAdd);
						
						Conductor.songPosition = (cachedSectionTimes[curSec] + 0.0001);
					} else {
						if (curSec + shiftAdd >= PlayState.SONG.notes.length) shiftAdd = PlayState.SONG.notes.length - curSec - 1;
						
						if (shiftAdd > 0)
							loadSection(curSec + shiftAdd);
						
						Conductor.songPosition = Math.min(Math.max(0, getEditorSongLength() - 1), cachedSectionTimes[curSec] + 0.0001);
					}
					
					vortexShifted = true;
					
				case FlxKey.UP | FlxKey.PAGEUP | FlxKey.DOWN | FlxKey.PAGEDOWN: // quant scrolling
					if (!vortexInput) return;
					var page:Bool = (eventKey == FlxKey.PAGEUP || eventKey == FlxKey.PAGEDOWN);
					var up:Bool = ((eventKey == FlxKey.UP || eventKey == FlxKey.PAGEUP) == !downScroll);
					
					if (FlxG.sound.music != null && FlxG.sound.music.playing) setSongPlaying(false);
					
					var currentStep:Float = snapChartStep(Conductor.getStep(Conductor.songPosition));
					noteShift(Conductor.stepToSeconds(currentStep));
					var interval:Float = page ? 4 : getSnapStep();
					var nextStep:Float = Math.max(0, currentStep + (up ? -interval : interval));
					Conductor.songPosition = Math.min(getEditorSongLength(), Conductor.stepToSeconds(nextStep)) + 0.0001;
					loadSection(sectionAtTime(Conductor.songPosition));
					
					vortexShifted = true;
				
				default:
			}
		}
		
		if (vortexShifted) {
			updateScrollY();
			updateVortexHolds();
			vortexMoved = true;
			forceDataUpdate = true;
		}
	}
	
	function keyUp(event:KeyboardEvent) {
		if (!focusedOnEditor()) return;
		
		var eventKey:FlxKey = event.keyCode;
		
		var num:Int = keysArray.indexOf(eventKey);
		if (num != -1) {
			_keysPressedBuffer[num] = false;
			_heldNotes[num] = null;
		}
	}
	
	function focusedOnEditor(?allowMouseFocusRelease:Bool = false):Bool {
		sanitizeInputFocus();
		return (PsychUIInputText.focusOn == null && (lastFocus == null || (allowMouseFocusRelease && FlxG.mouse.justPressed)) && (persistentUpdate || subState == null));
	}

	function sanitizeInputFocus():Void
	{
		PsychUIInputText.clearInvalidFocus();
		if(lastFocus != null && (!lastFocus.exists || !lastFocus.active || !lastFocus.visible))
			lastFocus = null;
	}
	
	function updateVortexHolds() {
		var snap:Float = (curQuant / 4);
		
		for (num => key in keysArray) {
			if (_heldNotes[num] != null) {
				var noteSec:Int = 0;
				var note:MetaNote = _heldNotes[num];
				while (cachedSectionTimes.length > noteSec + 1 && cachedSectionTimes[noteSec + 1] <= note.strumTime)
					noteSec++;
				
				var targetTime:Float = Conductor.getStep(Conductor.songPosition + Conductor.offset + delay);
				targetTime = Math.floor(targetTime * snap) / snap;
				
				note.setSustainLength(Conductor.stepToSeconds(targetTime) - note.strumTime, curZoom);
			}
		}
	}

	function loadFileList(mainFolder:String, ?optionalList:String = null, ?fileTypes:Array<String> = null)
	{
		if(fileTypes == null) fileTypes = ['.json'];

		var fileList:Array<String> = [];
		if(optionalList != null)
		{
			for (file in Mods.mergeAllTextsNamed(optionalList))
			{
				file = file.trim();
				if(file.length > 0 && !fileList.contains(file))
					fileList.push(file);
			}
		}

		for (directory in Mods.directoriesWithFile(Paths.getSharedPath(), mainFolder))
		{
			for (file in FileSystem.readDirectory(directory))
			{
				var path = haxe.io.Path.join([directory, file.trim()]);
				if (!FileSystem.isDirectory(path) && !file.startsWith('readme.'))
				{
					for (fileType in fileTypes)
					{
						var fileToCheck:String = file.substr(0, file.length - fileType.length);
						if(fileToCheck.length > 0 && path.endsWith(fileType) && !fileList.contains(fileToCheck))
						{
							fileList.push(fileToCheck);
							break;
						}
					}
				}
			}
		}
		return fileList;
	}
	
	function loadCharacterFile(char:String):CharacterFile
	{
		if(char != null)
		{
			try
			{
				var path:String = Character.getCharacterPath(char);
				if(path != null)
					return cast Character.getCharacterData(path);
			}
			catch (e:Dynamic) {}
		}
		return null;
	}
	
	var overwriteSavedSomething:Bool = false;
	function overwriteCheck(savePath:String, overwriteName:String, saveData:String, continueFunc:Void->Void = null, ?continueOnCancel:Bool = false)
	{
		#if sys
		
		if(FileSystem.exists(savePath))
		{
			openSubState(new Prompt('Overwrite: "$overwriteName"?', function()
			{
				overwriteSavedSomething = true;
				File.saveContent(savePath, saveData);
				if(continueFunc != null) continueFunc();
			},
			continueOnCancel ? (function() if(continueFunc != null) continueFunc()) : null));
		}
		else
		{
			overwriteSavedSomething = true;
			File.saveContent(savePath, saveData);
			if(continueFunc != null) continueFunc();
		}
		
		#else
		
		overwriteSavedSomething = true;
		if (continueFunc != null) continueFunc();
		
		#end
	}

	// Undo/Redo stuff
	var undoActions:Array<UndoStruct> = [];
	var currentUndo:Int = 0;
	function addUndoAction(action:UndoAction, data:Dynamic)
	{
		function destroyFromArr(arr:Array<MetaNote>)
		{
			if(arr == null || arr.length < 1) return;

			for (note in arr)
				if(note != null)
					note.destroy();
		}

		//trace('pushed action: $action');
		if(currentUndo > 0) undoActions = undoActions.slice(currentUndo);
		currentUndo = 0;
		undoActions.insert(0, {action: action, data: data});
		while(undoActions.length > 15)
		{
			var lastAction:UndoStruct = undoActions.pop();
			if(lastAction != null)
			{
				switch(lastAction.action)
				{
					case DELETE_NOTE:
						destroyFromArr(lastAction.data.notes);
						destroyFromArr(lastAction.data.events);
					case MOVE_NOTE:
						destroyFromArr(lastAction.data.originalNotes);
						destroyFromArr(lastAction.data.originalEvents);
					default:
				}
			}
		}
	}

	function undo()
	{
		if(isMovingNotes || currentUndo >= undoActions.length)
		{
			if(ClientPrefs.data.editorSFX)
				FlxG.sound.play(Paths.uiSound('cancelMenu'), 0.4);
			return;
		}
		var oldBPMMap:Array<BPMChangeEvent> = Conductor.copyBPMChanges();

		var action:UndoStruct = undoActions[currentUndo];
		switch(action.action)
		{
			case ADD_NOTE:
				actionRemoveNotes(action.data.notes, action.data.events);
			
			case DELETE_NOTE:
				actionPushNotes(action.data.notes, action.data.events);
			
			case ADD_EVENT:
				actionRemoveEvents(action.data.events);
			
			case DELETE_EVENT:
				actionPushEvents(action.data.events);
			
			case UPDATE_EVENT:
			
			case MOVE_NOTE:
				actionRemoveNotes(action.data.movedNotes, action.data.movedEvents);
				actionPushNotes(action.data.originalNotes, action.data.originalEvents);
				onSelectNote();
			
			case SELECT_NOTE:
				resetSelectedNotes();
				selectedNotes = action.data.old;
				if(lockedEvents) selectedNotes = selectedNotes.filter((note:MetaNote) -> !note.isEvent);
				onSelectNote();
		}
		showOutput('Undo #${currentUndo+1}: ${action.action}', false, false);
		EditorSFX.playChartSound('undo', 0.75);
		currentUndo++;
		adaptNotes(oldBPMMap, false);
	}
	function redo()
	{
		if(isMovingNotes || currentUndo < 1)
		{
			if(ClientPrefs.data.editorSFX)
				FlxG.sound.play(Paths.uiSound('cancelMenu'), 0.4);
			return;
		}
		var oldBPMMap:Array<BPMChangeEvent> = Conductor.copyBPMChanges();

		currentUndo--;
		var action:UndoStruct = undoActions[currentUndo];
		switch(action.action)
		{
			case ADD_NOTE:
				actionPushNotes(action.data.notes, action.data.events);

			case DELETE_NOTE:
				actionRemoveNotes(action.data.notes, action.data.events);
			
			case ADD_EVENT:
				actionPushEvents(action.data.events);
			
			case DELETE_EVENT:
				actionRemoveEvents(action.data.events);
			
			case UPDATE_EVENT:

			case MOVE_NOTE:
				actionRemoveNotes(action.data.originalNotes, action.data.originalEvents);
				actionPushNotes(action.data.movedNotes, action.data.movedEvents);
				onSelectNote();

			case SELECT_NOTE:
				resetSelectedNotes();
				selectedNotes = action.data.current;
				if(lockedEvents) selectedNotes = selectedNotes.filter((note:MetaNote) -> !note.isEvent);
				onSelectNote();
		}
		showOutput('Redo #${currentUndo+1}: ${action.action}', false, false);
		EditorSFX.playChartSound('redo', 0.75);
		adaptNotes(oldBPMMap, false);
	}
	
	function actionPushEvents(data:Array<SelectedEventData>):Void {
		var reload:Bool = false;
		
		for (event in data) {
			var note:EventMetaNote = event.note;
			
			if (!events.contains(note)) {
				reload = true;
				events.push(note);
				selectedNotes.push(note);
				note.songData[0] = note.strumTime;
			}
			
			if (!note.events.contains(event.event)) {
				note.events.push(event.event);
				
				note.updateEventInfo();
			}
			
			if (!selectedEvents.contains(event))
				selectedEvents.push(event);
		}
		
		if (reload) {
			events.sort(PlayState.sortByTime);
			softReloadNotes();
		}
	}
	
	function actionRemoveEvents(data:Array<SelectedEventData>):Void {
		var updateEvents:Array<EventMetaNote> = [];
		
		for (event in data) {
			var note:EventMetaNote = event.note;
			
			if (!updateEvents.contains(note)) updateEvents.push(note);
			
			note.events.remove(event.event);
		}
		
		for (event in updateEvents)
			event.updateEventInfo();
	}

	function actionPushNotes(dataNotes:Array<MetaNote>, dataEvents:Array<EventMetaNote>)
	{
		resetSelectedNotes();
		if(dataNotes != null && dataNotes.length > 0)
		{
			for (note in dataNotes)
			{
				if(note != null)
				{
					notes.push(note);
					selectedNotes.push(note);
					note.songData[0] = note.strumTime;
					note.songData[1] = note.chartNoteData;
				}
			}
			notes.sort(PlayState.sortByTime);
		}
		if(dataEvents != null && dataEvents.length > 0)
		{
			for (event in dataEvents)
			{
				if(event != null)
				{
					events.push(event);
					selectedNotes.push(event);
					event.songData[0] = event.strumTime;
				}
			}
			events.sort(PlayState.sortByTime);
		}
		softReloadNotes();
	}

	function actionRemoveNotes(dataNotes:Array<MetaNote>, dataEvents:Array<EventMetaNote>)
	{
		if(dataNotes != null && dataNotes.length > 0)
		{
			for (note in dataNotes)
			{
				if(note != null)
				{
					notes.remove(note);
					selectedNotes.remove(note);

					if(note.exists)
					{
						note.setColorTransform();
						if(note.animation.curAnim != null) note.animation.curAnim.curFrame = 0;
					}
				}

			}
		}
		if(dataEvents != null && dataEvents.length > 0)
		{
			for (event in dataEvents)
			{
				if(event != null)
				{
					trace(events.remove(event));
					selectedNotes.remove(event);

					if(event.exists)
					{
						event.setColorTransform();
						if(event.animation.curAnim != null) event.animation.curAnim.curFrame = 0;
					}
				}
			}
		}
		softReloadNotes();
	}

	function actionReplaceNotes(oldNote:MetaNote, newNote:MetaNote)
	{
		for (act in undoActions)
		{
			for (field in Reflect.fields(act.data))
			{
				var fld:Array<MetaNote> = cast Reflect.field(act.data, field);
				if(fld != null && fld.length > 0)
					for (num => actNote in fld)
						if(actNote == oldNote)
							fld[num] = newNote;
			}
		}
	}

	// Ported from the old chart editor
	var wavData:Array<Array<Array<Float>>> = [[[0], [0]], [[0], [0]]];
	var waveformStartStep:Float = Math.NaN;
	var waveformEndStep:Float = Math.NaN;
	var waveformCacheZoom:Float = -1;
	var waveformCacheTarget:WaveformTarget;
	var waveformCacheOffset:Float = Math.NaN;
	var waveformCacheMap:String = '';
	function updateWaveform() {
		#if (lime_cffi && !macro)
		if(cachedSectionTimes == null || !waveformEnabled)
		{
			waveformSprite.visible = false;
			return;
		}

		var centerStep:Float = Conductor.getStep(Conductor.songPosition);
		var totalSteps:Float = cachedSectionRow[cachedSectionRow.length - 1];
		var targetHeight:Int = Std.int(Math.max(512, FlxG.height * 2));
		var radius:Float = targetHeight / Math.max(1, GRID_SIZE * curZoom) * 0.5;
		var startStep:Float = Math.max(0, centerStep - radius);
		var endStep:Float = Math.min(totalSteps, centerStep + radius);
		var height:Int = Std.int(Math.max(1, Math.ceil((endStep - startStep) * GRID_SIZE * curZoom)));
		var mapSignature:String = [for(change in Conductor.bpmChangeMap) '${change.stepTime}:${change.bpm}'].join('|');
		var visibleRadius:Float = FlxG.height / Math.max(1, GRID_SIZE * curZoom) * 0.5;
		var cacheValid:Bool = waveformSprite.visible && waveformCacheZoom == curZoom && waveformCacheTarget == waveformTarget &&
			waveformCacheOffset == Conductor.offset && waveformCacheMap == mapSignature &&
			Math.max(0, centerStep - visibleRadius) >= waveformStartStep - 0.001 &&
			Math.min(totalSteps, centerStep + visibleRadius) <= waveformEndStep + 0.001;
		if(cacheValid) return;

		waveformStartStep = startStep;
		waveformEndStep = endStep;
		waveformCacheZoom = curZoom;
		waveformCacheTarget = waveformTarget;
		waveformCacheOffset = Conductor.offset;
		waveformCacheMap = mapSignature;
		waveformSprite.visible = true;
		waveformSprite.y = downScroll ? chartStepToGridY(endStep) : chartStepToGridY(startStep);
		var width:Int = Std.int(GRID_SIZE * GRID_COLUMNS_PER_PLAYER * GRID_PLAYERS);
		if(Std.int(waveformSprite.height) != height || Std.int(waveformSprite.width) != width || waveformSprite.pixels == null)
			waveformSprite.makeGraphic(width, height, 0x00FFFFFF);
		waveformSprite.pixels.fillRect(new Rectangle(0, 0, width, height), 0x00FFFFFF);

		drawOnWaveform(switch(waveformTarget) {
			case INST:
				FlxG.sound.music;
			case PLAYER:
				vocals;
			case OPPONENT:
				opponentVocals;
			default:
				null;
		}, width, height, startStep, endStep);
		
		if (waveformTarget == EVERYTHING) {
			drawOnWaveform(vocals, width, height, startStep, endStep, -.25, .5);
			if (opponentVocals.length <= 0) {
				drawOnWaveform(vocals, width, height, startStep, endStep, .25, .5);
			} else {
				drawOnWaveform(opponentVocals, width, height, startStep, endStep, .25, .5);
			}
			drawOnWaveform(FlxG.sound.music, width, height, startStep, endStep, 0, .5);
		}
		
		#else
		waveformSprite.visible = false;
		#end
	}
	
	#if (lime_cffi && !macro)
	function drawOnWaveform(sound:FlxSound, width:Int, height:Int, startStep:Float, endStep:Float, offset:Float = 0, amp:Float = 1) {
		@:privateAccess
		if (sound == null || sound._sound == null || sound._sound.__buffer == null) return;

		wavData[0][0].resize(0);
		wavData[0][1].resize(0);
		wavData[1][0].resize(0);
		wavData[1][1].resize(0);
		
		@:privateAccess {
		var bytes:Bytes = sound._sound.__buffer.data.toBytes();
		wavData = waveformDataByStep(sound._sound.__buffer, bytes, startStep, endStep, 1, wavData, height);
		}
		
		// Draws
		var gSize:Int = Std.int(GRID_SIZE * 8);
		var hSize:Int = Std.int(gSize / 2);
		var size:Float = 1;
		
		var leftLength:Int = (wavData[0][0].length > wavData[0][1].length ? wavData[0][0].length : wavData[0][1].length);
		var rightLength:Int = (wavData[1][0].length > wavData[1][1].length ? wavData[1][0].length : wavData[1][1].length);
		
		var length:Int = leftLength > rightLength ? leftLength : rightLength;
		
		for (index in 0...length)
		{
			var lmin:Float = FlxMath.bound(((index < wavData[0][0].length && index >= 0) ? wavData[0][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			var lmax:Float = FlxMath.bound(((index < wavData[0][1].length && index >= 0) ? wavData[0][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			
			var rmin:Float = FlxMath.bound(((index < wavData[1][0].length && index >= 0) ? wavData[1][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			var rmax:Float = FlxMath.bound(((index < wavData[1][1].length && index >= 0) ? wavData[1][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			
			var ww:Float = ((lmin + rmin + lmax + rmax) * amp);
			var xx:Float = (hSize - ww * .5 + gSize * offset);
			waveformSprite.pixels.fillRect(new Rectangle(xx, index * size, ww, size), FlxColor.WHITE);
		}
	}
	#end

	function waveformDataByStep(buffer:AudioBuffer, bytes:Bytes, startStep:Float, endStep:Float, multiply:Float,
		array:Array<Array<Array<Float>>>, rows:Int):Array<Array<Array<Float>>>
	{
		#if (lime_cffi && !macro)
		if(buffer == null || buffer.data == null || bytes == null || rows <= 0) return [[[0], [0]], [[0], [0]]];
		var channels:Int = Std.int(Math.max(1, buffer.channels));
		var frameSize:Int = channels * 2;
		var frameCount:Int = Std.int(bytes.length / frameSize);
		var framesPerMs:Float = buffer.sampleRate / 1000;

		for(row in 0...rows)
		{
			var rowStartStep:Float = FlxMath.lerp(startStep, endStep, row / rows);
			var rowEndStep:Float = FlxMath.lerp(startStep, endStep, (row + 1) / rows);
			var startFrame:Int = Std.int(Math.floor((Conductor.stepToSeconds(rowStartStep) - Conductor.offset) * framesPerMs));
			var endFrame:Int = Std.int(Math.ceil((Conductor.stepToSeconds(rowEndStep) - Conductor.offset) * framesPerMs));
			startFrame = Std.int(FlxMath.bound(startFrame, 0, frameCount));
			endFrame = Std.int(FlxMath.bound(Math.max(startFrame + 1, endFrame), 0, frameCount));

			var lmin:Float = 0;
			var lmax:Float = 0;
			var rmin:Float = 0;
			var rmax:Float = 0;
			for(frame in startFrame...endFrame)
			{
				var byteOffset:Int = frame * frameSize;
				if(byteOffset + 1 >= bytes.length) break;
				var left:Int = bytes.getUInt16(byteOffset);
				if(left >= 32768) left -= 65536;
				var leftSample:Float = left / 32768;
				if(leftSample < lmin) lmin = leftSample;
				if(leftSample > lmax) lmax = leftSample;

				var rightSample:Float = leftSample;
				if(channels > 1 && byteOffset + 3 < bytes.length)
				{
					var right:Int = bytes.getUInt16(byteOffset + 2);
					if(right >= 32768) right -= 65536;
					rightSample = right / 32768;
				}
				if(rightSample < rmin) rmin = rightSample;
				if(rightSample > rmax) rmax = rightSample;
			}

			array[0][0].push(Math.abs(lmin) * multiply);
			array[0][1].push(lmax * multiply);
			array[1][0].push(Math.abs(rmin) * multiply);
			array[1][1].push(rmax * multiply);
		}
		return array;
		#else
		return [[[0], [0]], [[0], [0]]];
		#end
	}

	function waveformData(buffer:AudioBuffer, bytes:Bytes, time:Float, endTime:Float, multiply:Float = 1, ?array:Array<Array<Array<Float>>>, ?steps:Float):Array<Array<Array<Float>>>
	{
		#if (lime_cffi && !macro)
		if (buffer == null || buffer.data == null) return [[[0], [0]], [[0], [0]]];

		var khz:Float = (buffer.sampleRate / 1000);
		var channels:Int = buffer.channels;

		var index:Int = Std.int(time * khz);

		var samples:Float = ((endTime - time) * khz);

		if (steps == null) steps = 1280;

		var samplesPerRow:Float = samples / steps;
		var samplesPerRowI:Int = Std.int(samplesPerRow);

		var gotIndex:Int = 0;

		var lmin:Float = 0;
		var lmax:Float = 0;

		var rmin:Float = 0;
		var rmax:Float = 0;

		var rows:Float = 0;

		var simpleSample:Bool = true;//samples > 17200;
		var v1:Bool = false;

		if (array == null) array = [[[0], [0]], [[0], [0]]];

		while (index < (bytes.length - 1)) {
			if (index >= 0) {
				var byte:Int = bytes.getUInt16(index * channels * 2);

				if (byte > 65535 / 2) byte -= 65535;

				var sample:Float = (byte / 65535);

				if (sample > 0)
					if (sample > lmax) lmax = sample;
				else if (sample < 0)
					if (sample < lmin) lmin = sample;

				if (channels >= 2) {
					byte = bytes.getUInt16((index * channels * 2) + 2);

					if (byte > 65535 / 2) byte -= 65535;

					sample = (byte / 65535);

					if (sample > 0) {
						if (sample > rmax) rmax = sample;
					} else if (sample < 0) {
						if (sample < rmin) rmin = sample;
					}
				}
			}

			v1 = samplesPerRowI > 0 ? (index % samplesPerRowI == 0) : false;
			while (simpleSample ? v1 : rows >= samplesPerRow) {
				v1 = false;
				rows -= samplesPerRow;

				gotIndex++;

				var lRMin:Float = Math.abs(lmin) * multiply;
				var lRMax:Float = lmax * multiply;

				var rRMin:Float = Math.abs(rmin) * multiply;
				var rRMax:Float = rmax * multiply;

				if (gotIndex > array[0][0].length) array[0][0].push(lRMin);
					else array[0][0][gotIndex - 1] = array[0][0][gotIndex - 1] + lRMin;

				if (gotIndex > array[0][1].length) array[0][1].push(lRMax);
					else array[0][1][gotIndex - 1] = array[0][1][gotIndex - 1] + lRMax;

				if (channels >= 2)
				{
					if (gotIndex > array[1][0].length) array[1][0].push(rRMin);
						else array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + rRMin;

					if (gotIndex > array[1][1].length) array[1][1].push(rRMax);
						else array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + rRMax;
				}
				else
				{
					if (gotIndex > array[1][0].length) array[1][0].push(lRMin);
						else array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + lRMin;

					if (gotIndex > array[1][1].length) array[1][1].push(lRMax);
						else array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + lRMax;
				}

				lmin = 0;
				lmax = 0;

				rmin = 0;
				rmax = 0;
			}

			index++;
			rows++;
			if(gotIndex > steps) break;
		}

		return array;
		#else
		return [[[0], [0]], [[0], [0]]];
		#end
	}
}
