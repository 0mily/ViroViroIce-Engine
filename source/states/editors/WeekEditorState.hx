package states.editors;

import backend.WeekData;

import openfl.utils.Assets;
import openfl.net.FileReference;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import flash.net.FileFilter;
import lime.system.Clipboard;
import haxe.Json;
import flixel.addons.display.shapes.FlxShapeCircle;
import flixel.util.FlxGradient;

import objects.HealthIcon;
import objects.MenuCharacter;
import objects.MenuItem;

import states.editors.content.Prompt;

class WeekEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	var txtWeekTitle:FlxText;
	var bgSprite:FlxSprite;
	var lock:FlxSprite;
	var txtTracklist:FlxText;
	var grpWeekCharacters:FlxTypedGroup<MenuCharacter>;
	var weekThing:MenuItem;
	var missingFileText:FlxText;

	public static var unsavedProgress:Bool = false;

	var weekFile:WeekFile = null;
	public function new(weekFile:WeekFile = null)
	{
		super();
		this.weekFile = WeekData.createWeekFile();
		if(weekFile != null) this.weekFile = weekFile;
		else weekFileName = 'week1';
	}

	override function create() {
		txtWeekTitle = new FlxText(FlxG.width * 0.7, 10, 0, "", 32);
		txtWeekTitle.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		txtWeekTitle.alpha = 0.7;
		
		var ui_tex = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		var bgYellow:FlxSprite = new FlxSprite(0, 56).makeGraphic(FlxG.width, 386, 0xFFF9CF51);
		bgSprite = new FlxSprite(0, 56);
		bgSprite.antialiasing = ClientPrefs.data.antialiasing;

		weekThing = new MenuItem(0, bgSprite.y + 396, weekFileName);
		weekThing.y += weekThing.height + 20;
		weekThing.antialiasing = ClientPrefs.data.antialiasing;
		add(weekThing);

		var blackBarThingie:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 56, FlxColor.BLACK);
		add(blackBarThingie);
		
		grpWeekCharacters = new FlxTypedGroup<MenuCharacter>();
		
		lock = new FlxSprite();
		lock.frames = ui_tex;
		lock.animation.addByPrefix('lock', 'lock');
		lock.animation.play('lock');
		lock.antialiasing = ClientPrefs.data.antialiasing;
		add(lock);
		
		missingFileText = new FlxText(0, 0, FlxG.width, "");
		missingFileText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingFileText.borderSize = 2;
		missingFileText.visible = false;
		add(missingFileText); 
		
		var charArray:Array<String> = weekFile.weekCharacters;
		for (char in 0...3)
		{
			var weekCharacterThing:MenuCharacter = new MenuCharacter((FlxG.width * 0.25) * (1 + char) - 150, charArray[char]);
			weekCharacterThing.y += 70;
			grpWeekCharacters.add(weekCharacterThing);
		}

		add(bgYellow);
		add(bgSprite);
		add(grpWeekCharacters);

		var tracksSprite:FlxSprite = new FlxSprite(FlxG.width * 0.07, bgSprite.y + 435).loadGraphic(Paths.image('Menu_Tracks'));
		tracksSprite.antialiasing = ClientPrefs.data.antialiasing;
		add(tracksSprite);

		txtTracklist = new FlxText(FlxG.width * 0.05, tracksSprite.y + 60, 0, "", 32);
		txtTracklist.alignment = CENTER;
		txtTracklist.font = Paths.font("vcr.ttf");
		txtTracklist.color = 0xFFe55777;
		add(txtTracklist);
		add(txtWeekTitle);

		addEditorBox();
		reloadAllShit();

		FlxG.mouse.visible = true;

		super.create();
	}

	var UI_box:PsychUIBox;
	function addEditorBox() {
		UI_box = new PsychUIBox(FlxG.width, FlxG.height, 250, 375, ['Other', 'Week']);
		UI_box.x -= UI_box.width;
		UI_box.y -= UI_box.height;
		UI_box.scrollFactor.set();
		add(UI_box);
		addOtherUI();
		addWeekUI();
		
		UI_box.selectedName = 'Week';
		add(UI_box);

		var loadWeekButton:PsychUIButton = new PsychUIButton(0, 650, "Load Week", function() loadWeek());
		loadWeekButton.screenCenter(X);
		loadWeekButton.x -= 120;
		add(loadWeekButton);
		
		var freeplayButton:PsychUIButton = new PsychUIButton(0, 650, "Freeplay", function() MusicBeatState.switchState(new WeekEditorFreeplayState(weekFile)));
		freeplayButton.screenCenter(X);
		add(freeplayButton);
	
		var saveWeekButton:PsychUIButton = new PsychUIButton(0, 650, "Save Week", function() saveWeek(weekFile));
		saveWeekButton.screenCenter(X);
		saveWeekButton.x += 120;
		add(saveWeekButton);
	}

	var songsInputText:PsychUIInputText;
	var backgroundInputText:PsychUIInputText;
	var displayNameInputText:PsychUIInputText;
	var weekNameInputText:PsychUIInputText;
	var weekFileInputText:PsychUIInputText;
	
	var opponentInputText:PsychUIInputText;
	var boyfriendInputText:PsychUIInputText;
	var girlfriendInputText:PsychUIInputText;

	var hideCheckbox:PsychUICheckBox;

	public static var weekFileName:String = 'week1';
	
	function addWeekUI() {
		var tab_group = UI_box.getTab('Week').menu;

		songsInputText = new PsychUIInputText(10, 30, 200, '', 8);

		opponentInputText = new PsychUIInputText(10, songsInputText.y + 40, 70, '', 8);
		boyfriendInputText = new PsychUIInputText(opponentInputText.x + 75, opponentInputText.y, 70, '', 8);
		girlfriendInputText = new PsychUIInputText(boyfriendInputText.x + 75, opponentInputText.y, 70, '', 8);

		backgroundInputText = new PsychUIInputText(10, opponentInputText.y + 40, 120, '', 8);
		displayNameInputText = new PsychUIInputText(10, backgroundInputText.y + 60, 200, '', 8);
		weekNameInputText = new PsychUIInputText(10, displayNameInputText.y + 60, 150, '', 8);
		weekFileInputText = new PsychUIInputText(10, weekNameInputText.y + 40, 100, '', 8);
		reloadWeekThing();

		hideCheckbox = new PsychUICheckBox(10, weekFileInputText.y + 40, "Hide Week from Story Mode?", 100);
		hideCheckbox.onClick = function()
		{
			weekFile.hideStoryMode = hideCheckbox.checked;
			unsavedProgress = true;
		};

		tab_group.add(new FlxText(songsInputText.x, songsInputText.y - 18, 0, 'Songs:'));
		tab_group.add(new FlxText(opponentInputText.x, opponentInputText.y - 18, 0, 'Characters:'));
		tab_group.add(new FlxText(backgroundInputText.x, backgroundInputText.y - 18, 0, 'Background Asset:'));
		tab_group.add(new FlxText(displayNameInputText.x, displayNameInputText.y - 18, 0, 'Display Name:'));
		tab_group.add(new FlxText(weekNameInputText.x, weekNameInputText.y - 18, 0, 'Week Name (for Reset Score Menu):'));
		tab_group.add(new FlxText(weekFileInputText.x, weekFileInputText.y - 18, 0, 'Week File:'));

		tab_group.add(songsInputText);
		tab_group.add(opponentInputText);
		tab_group.add(boyfriendInputText);
		tab_group.add(girlfriendInputText);
		tab_group.add(backgroundInputText);

		tab_group.add(displayNameInputText);
		tab_group.add(weekNameInputText);
		tab_group.add(weekFileInputText);
		tab_group.add(hideCheckbox);
	}

	var weekBeforeInputText:PsychUIInputText;
	var difficultiesInputText:PsychUIInputText;
	var lockedCheckbox:PsychUICheckBox;
	var hiddenUntilUnlockCheckbox:PsychUICheckBox;

	function addOtherUI() {
		var tab_group = UI_box.getTab('Other').menu;

		lockedCheckbox = new PsychUICheckBox(10, 30, "Week starts Locked", 100);
		lockedCheckbox.onClick = function()
		{
			weekFile.startUnlocked = !lockedCheckbox.checked;
			lock.visible = lockedCheckbox.checked;
			hiddenUntilUnlockCheckbox.alpha = 0.4 + 0.6 * (lockedCheckbox.checked ? 1 : 0);
			unsavedProgress = true;
		};

		hiddenUntilUnlockCheckbox = new PsychUICheckBox(10, lockedCheckbox.y + 25, "Hidden until Unlocked", 110);
		hiddenUntilUnlockCheckbox.onClick = function()
		{
			weekFile.hiddenUntilUnlocked = hiddenUntilUnlockCheckbox.checked;
			unsavedProgress = true;
		};
		hiddenUntilUnlockCheckbox.alpha = 0.4;

		weekBeforeInputText = new PsychUIInputText(10, hiddenUntilUnlockCheckbox.y + 55, 100, '', 8);
		difficultiesInputText = new PsychUIInputText(10, weekBeforeInputText.y + 60, 200, '', 8);
		
		tab_group.add(new FlxText(weekBeforeInputText.x, weekBeforeInputText.y - 28, 0, 'Week File name of the Week you have\nto finish for Unlocking:'));
		tab_group.add(new FlxText(difficultiesInputText.x, difficultiesInputText.y - 20, 0, 'Difficulties:'));
		tab_group.add(new FlxText(difficultiesInputText.x, difficultiesInputText.y + 20, 0, 'Default difficulties are "Easy, Normal, Hard"\nwithout quotes.'));
		tab_group.add(weekBeforeInputText);
		tab_group.add(difficultiesInputText);
		tab_group.add(hiddenUntilUnlockCheckbox);
		tab_group.add(lockedCheckbox);
	}

	//Used on onCreate and when you load a week
	function reloadAllShit() {
		var weekString:String = weekFile.songs[0][0];
		for (i in 1...weekFile.songs.length) {
			weekString += ', ' + weekFile.songs[i][0];
		}
		songsInputText.text = weekString;
		backgroundInputText.text = weekFile.weekBackground;
		displayNameInputText.text = weekFile.storyName;
		weekNameInputText.text = weekFile.weekName;
		weekFileInputText.text = weekFileName;
		
		opponentInputText.text = weekFile.weekCharacters[0];
		boyfriendInputText.text = weekFile.weekCharacters[1];
		girlfriendInputText.text = weekFile.weekCharacters[2];

		hideCheckbox.checked = weekFile.hideStoryMode;

		weekBeforeInputText.text = weekFile.weekBefore;

		difficultiesInputText.text = '';
		if(weekFile.difficulties != null) difficultiesInputText.text = weekFile.difficulties;

		lockedCheckbox.checked = !weekFile.startUnlocked;
		lock.visible = lockedCheckbox.checked;
		
		hiddenUntilUnlockCheckbox.checked = weekFile.hiddenUntilUnlocked;
		hiddenUntilUnlockCheckbox.alpha = 0.4 + 0.6 * (lockedCheckbox.checked ? 1 : 0);

		reloadBG();
		reloadWeekThing();
		updateText();
	}

	function updateText()
	{
		for (i in 0...grpWeekCharacters.length) {
			grpWeekCharacters.members[i].changeCharacter(weekFile.weekCharacters[i]);
		}

		var stringThing:Array<String> = [];
		for (i in 0...weekFile.songs.length) {
			stringThing.push(weekFile.songs[i][0]);
		}

		txtTracklist.text = '';
		for (i in 0...stringThing.length)
		{
			txtTracklist.text += stringThing[i] + '\n';
		}

		txtTracklist.screenCenter(X);
		txtTracklist.x -= FlxG.width * 0.35;
		
		txtWeekTitle.text = weekFile.storyName;
		txtWeekTitle.x = FlxG.width - (txtWeekTitle.width + 10);
	}

	function reloadBG() {
		bgSprite.visible = true;
		var assetName:String = weekFile.weekBackground;

		var isMissing:Bool = true;
		if(assetName != null && assetName.length > 0) {
			if( #if MODS_ALLOWED FileSystem.exists(Paths.modsImages('menubackgrounds/menu_' + assetName)) || #end
			Assets.exists(Paths.getPath('images/menubackgrounds/menu_' + assetName + '.png', IMAGE), IMAGE)) {
				bgSprite.loadGraphic(Paths.image('menubackgrounds/menu_' + assetName));
				isMissing = false;
			}
		}

		if(isMissing) {
			bgSprite.visible = false;
		}
	}

	function reloadWeekThing() {
		weekThing.visible = true;
		missingFileText.visible = false;
		var assetName:String = weekFileInputText.text.trim();
		
		var isMissing:Bool = true;
		if(assetName != null && assetName.length > 0) {
			if( #if MODS_ALLOWED FileSystem.exists(Paths.modsImages('storymenu/' + assetName)) || #end
			Assets.exists(Paths.getPath('images/storymenu/' + assetName + '.png', IMAGE), IMAGE)) {
				weekThing.loadGraphic(Paths.image('storymenu/' + assetName));
				isMissing = false;
			}
		}

		if(isMissing) {
			weekThing.visible = false;
			missingFileText.visible = true;
			missingFileText.text = 'MISSING FILE: images/storymenu/' + assetName + '.png';
		}
		recalculateStuffPosition();
		
		rpcDetails = 'Week Editor';
		rpcState = 'Editing $weekFileName';
		updatePresence();
	}
	
	public function UIEvent(id:String, sender:Dynamic) {
		if(id == PsychUICheckBox.CLICK_EVENT)
			unsavedProgress = true;

		if(id == PsychUIInputText.CHANGE_EVENT && (sender is PsychUIInputText)) {
			if(sender == weekFileInputText) {
				weekFileName = weekFileInputText.text.trim();
				unsavedProgress = true;
				reloadWeekThing();
			} else if(sender == opponentInputText || sender == boyfriendInputText || sender == girlfriendInputText) {
				weekFile.weekCharacters[0] = opponentInputText.text.trim();
				weekFile.weekCharacters[1] = boyfriendInputText.text.trim();
				weekFile.weekCharacters[2] = girlfriendInputText.text.trim();
				unsavedProgress = true;
				updateText();
			} else if(sender == backgroundInputText) {
				weekFile.weekBackground = backgroundInputText.text.trim();
				unsavedProgress = true;
				reloadBG();
			} else if(sender == displayNameInputText) {
				weekFile.storyName = displayNameInputText.text.trim();
				unsavedProgress = true;
				updateText();
			} else if(sender == weekNameInputText) {
				weekFile.weekName = weekNameInputText.text.trim();
				unsavedProgress = true;
			} else if(sender == songsInputText) {
				var splittedText:Array<String> = songsInputText.text.trim().split(',');
				for (i in 0...splittedText.length) {
					splittedText[i] = splittedText[i].trim();
				}

				while(splittedText.length < weekFile.songs.length) {
					weekFile.songs.pop();
				}

				for (i in 0...splittedText.length) {
					if(i >= weekFile.songs.length) { //Add new song
						weekFile.songs.push([splittedText[i], 'face', [146, 113, 253]]);
					} else { //Edit song
						weekFile.songs[i][0] = splittedText[i];
						if(weekFile.songs[i][1] == null || weekFile.songs[i][1]) {
							weekFile.songs[i][1] = 'face';
							weekFile.songs[i][2] = [146, 113, 253];
						}
					}
				}
				updateText();
				unsavedProgress = true;
			} else if(sender == weekBeforeInputText) {
				weekFile.weekBefore = weekBeforeInputText.text.trim();
				unsavedProgress = true;
			} else if(sender == difficultiesInputText) {
				weekFile.difficulties = difficultiesInputText.text.trim();
				unsavedProgress = true;
			}
		}
	}
	
	override function update(elapsed:Float)
	{
		if(loadedWeek != null) {
			weekFile = loadedWeek;
			loadedWeek = null;

			reloadAllShit();
		}

		if(PsychUIInputText.focusOn == null)
		{
			ClientPrefs.toggleVolumeKeys(true);
			if(FlxG.keys.justPressed.ESCAPE)
			{
				if(!unsavedProgress)
				{
					MusicBeatState.switchState(new states.MainMenuState(true));
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
				}
				else openSubState(new ExitConfirmationPrompt(function() unsavedProgress = false));
			}
		}
		else ClientPrefs.toggleVolumeKeys(false);

		super.update(elapsed);

		lock.y = weekThing.y;
		missingFileText.y = weekThing.y + 36;
	}

	function recalculateStuffPosition() {
		weekThing.screenCenter(X);
		lock.x = weekThing.width + 10 + weekThing.x;
	}

	private static var _file:FileReference;
	public static function loadWeek() {
		var jsonFilter:FileFilter = new FileFilter('JSON', 'json');
		_file = new FileReference();
		_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.addEventListener(Event.CANCEL, onLoadCancel);
		_file.addEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file.browse([#if !mac jsonFilter #end]);
	}
	
	public static var loadedWeek:WeekFile = null;
	public static var loadError:Bool = false;
	private static function onLoadComplete(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);

		#if sys
		var fullPath:String = null;
		@:privateAccess
		if(_file.__path != null) fullPath = _file.__path;

		if(fullPath != null) {
			var rawJson:String = Paths.getTextFromFile(fullPath);
			if(rawJson != null) {
				loadedWeek = cast Json.parse(rawJson);
				if(loadedWeek.weekCharacters != null && loadedWeek.weekName != null) //Make sure it's really a week
				{
					var cutName:String = _file.name.substr(0, _file.name.length - 5);
					trace("Successfully loaded file: " + cutName);
					loadError = false;

					weekFileName = cutName;
					_file = null;
					unsavedProgress = false;
					return;
				}
			}
		}
		loadError = true;
		loadedWeek = null;
		_file = null;
		#else
		trace("File couldn't be loaded! You aren't on Desktop, are you?");
		#end
	}

	/**
		* Called when the save file dialog is cancelled.
		*/
		private static function onLoadCancel(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;
		trace("Cancelled file loading.");
	}

	/**
		* Called if there is an error while saving the gameplay recording.
		*/
	private static function onLoadError(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onLoadComplete);
		_file.removeEventListener(Event.CANCEL, onLoadCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onLoadError);
		_file = null;
		trace("Problem loading file");
	}

	public static function saveWeek(weekFile:WeekFile) {
		var data:String = haxe.Json.stringify(weekFile, "\t");
		if (data.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data, weekFileName + ".json");
		}
	}
	
	private static function onSaveComplete(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved file.");
		unsavedProgress = false;
	}

	/**
		* Called when the save file dialog is cancelled.
		*/
		private static function onSaveCancel(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		trace("Cancelled file saving.");
	}

	/**
		* Called if there is an error while saving the gameplay recording.
		*/
	private static function onSaveError(_):Void
	{
		_file.removeEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving file");
	}
}

class WeekEditorFreeplayState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	var weekFile:WeekFile = null;
	public function new(weekFile:WeekFile = null)
	{
		super();
		this.weekFile = WeekData.createWeekFile();
		if(weekFile != null) this.weekFile = weekFile;
	}

	var bg:FlxSprite;
	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var iconArray:Array<HealthIcon> = [];

	var curSelected = 0;

	override function create() {
		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = FlxColor.WHITE;
		add(bg);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...weekFile.songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 320, weekFile.songs[i][0], true);
			songText.isMenuItem = true;
			songText.targetY = i;
			grpSongs.add(songText);
			songText.scaleX = Math.min(1, 980 / songText.width);
			songText.snapToPosition();

			var icon:HealthIcon = new HealthIcon(weekFile.songs[i][1]);
			icon.sprTracker = songText;

			// using a FlxGroup is too much fuss!
			iconArray.push(icon);
			add(icon);

			// songText.x += 40;
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
			// songText.screenCenter(X);
		}

		addEditorBox();
		changeSelection();
		super.create();
	}
	
	var UI_box:PsychUIBox;
	function addEditorBox() {
		var tabs = [
			{name: 'Freeplay', label: 'Freeplay'},
		];
		UI_box = new PsychUIBox(FlxG.width, FlxG.height, 250, 320, ['Freeplay']);
		UI_box.x -= UI_box.width + 100;
		UI_box.y -= UI_box.height + 60;
		UI_box.scrollFactor.set();
		addFreeplayUI();
		add(UI_box);

		var blackBlack:FlxSprite = new FlxSprite(0, 670).makeGraphic(FlxG.width, 50, FlxColor.BLACK);
		blackBlack.alpha = 0.6;
		add(blackBlack);

		var loadWeekButton:PsychUIButton = new PsychUIButton(0, 685, "Load Week", function() {
			WeekEditorState.loadWeek();
		});
		loadWeekButton.screenCenter(X);
		loadWeekButton.x -= 120;
		add(loadWeekButton);
		
		var storyModeButton:PsychUIButton = new PsychUIButton(0, 685, "Story Mode", function() {
			MusicBeatState.switchState(new WeekEditorState(weekFile));
			
		});
		storyModeButton.screenCenter(X);
		add(storyModeButton);
	
		var saveWeekButton:PsychUIButton = new PsychUIButton(0, 685, "Save Week", function() {
			WeekEditorState.saveWeek(weekFile);
		});
		saveWeekButton.screenCenter(X);
		saveWeekButton.x += 120;
		add(saveWeekButton);
	}
	
	public function UIEvent(id:String, sender:Dynamic)
	{
		if(id == PsychUICheckBox.CLICK_EVENT)
			WeekEditorState.unsavedProgress = true;

		if(id == PsychUIInputText.CHANGE_EVENT && (sender is PsychUIInputText))
		{
			weekFile.songs[curSelected][1] = iconInputText.text;
			iconArray[curSelected].changeIcon(iconInputText.text);
		}
	}

	var colorWheel:FlxSprite;
	var colorWheelSelector:FlxShapeCircle;
	var colorGradient:FlxSprite;
	var colorGradientSelector:FlxSprite;
	var colorPreview:FlxSprite;
	var colorHexText:FlxText;
	var holdingColorPicker:FlxSprite;
	var holdingPickerRawPosition:Bool = false;
	var storedPickerColor:FlxColor = FlxColor.WHITE;
	var iconInputText:PsychUIInputText;
	function addFreeplayUI() {
		var tab_group = UI_box.getTab('Freeplay').menu;

		colorGradient = FlxGradient.createGradientFlxSprite(18, 118, [FlxColor.WHITE, FlxColor.BLACK]);
		colorGradient.setPosition(12, 48);

		colorGradientSelector = new FlxSprite(colorGradient.x - 4, colorGradient.y).makeGraphic(26, 6, FlxColor.WHITE);
		colorGradientSelector.offset.y = 3;

		colorWheel = new FlxSprite(42, 48).loadGraphic(Paths.image('noteColorMenu/colorWheel'));
		colorWheel.setGraphicSize(118, 118);
		colorWheel.updateHitbox();

		colorWheelSelector = new FlxShapeCircle(0, 0, 5, {thickness: 0}, FlxColor.WHITE);
		colorWheelSelector.offset.set(5, 5);
		colorWheelSelector.alpha = 0.72;

		colorPreview = new FlxSprite(176, 48).makeGraphic(44, 44, FlxColor.WHITE);
		colorHexText = new FlxText(164, 98, 72, '#FFFFFF', 12);
		colorHexText.alignment = CENTER;

		var copyColor:PsychUIButton = new PsychUIButton(160, 124, "Copy", function() Clipboard.text = getSelectedFreeplayColor().toHexString(false, false), 74);

		var pasteColor:PsychUIButton = new PsychUIButton(160, 148, "Paste", function()
		{
			if(Clipboard.text != null)
			{
				var leColor:Array<Int> = [];
				var raw:String = Clipboard.text.trim();
				if(raw.startsWith('#') || raw.startsWith('0x') || raw.startsWith('0X'))
				{
					var parsed:FlxColor = CoolUtil.colorFromString(raw);
					setSelectedFreeplayColor(parsed);
					return;
				}

				var splitted:Array<String> = raw.split(',');
				for (i in 0...splitted.length)
				{
					var toPush:Int = Std.parseInt(splitted[i]);
					if(!Math.isNaN(toPush))
					{
						if(toPush > 255) toPush = 255;
						else if(toPush < 0) toPush *= -1;
						leColor.push(toPush);
					}
				}

				if(leColor.length > 2)
				{
					setSelectedFreeplayColor(FlxColor.fromRGB(leColor[0], leColor[1], leColor[2]));
				}
			}
		}, 74);

		iconInputText = new PsychUIInputText(10, 204, 100, '', 8);

		var hideFreeplayCheckbox:PsychUICheckBox = new PsychUICheckBox(10, iconInputText.y + 30, "Hide Week from Freeplay?", 100);
		hideFreeplayCheckbox.checked = weekFile.hideFreeplay;
		hideFreeplayCheckbox.onClick = function()
		{
			weekFile.hideFreeplay = hideFreeplayCheckbox.checked;
			WeekEditorState.unsavedProgress = true;
		};
		
		tab_group.add(new FlxText(10, 28, 0, 'Selected background Color:'));
		tab_group.add(new FlxText(10, iconInputText.y - 18, 0, 'Selected icon:'));
		tab_group.add(colorGradient);
		tab_group.add(colorWheel);
		tab_group.add(colorGradientSelector);
		tab_group.add(colorWheelSelector);
		tab_group.add(colorPreview);
		tab_group.add(colorHexText);
		tab_group.add(copyColor);
		tab_group.add(pasteColor);
		tab_group.add(iconInputText);
		tab_group.add(hideFreeplayCheckbox);
	}

	function updateBG() {
		bg.color = getSelectedFreeplayColor();
		updateColorPicker();
	}

	function ensureSelectedFreeplayColor():Array<Dynamic>
	{
		if(weekFile.songs[curSelected][2] == null || weekFile.songs[curSelected][2].length < 3)
			weekFile.songs[curSelected][2] = [146, 113, 253];
		return weekFile.songs[curSelected][2];
	}

	function getSelectedFreeplayColor():FlxColor
	{
		var colors:Array<Dynamic> = ensureSelectedFreeplayColor();
		return FlxColor.fromRGB(Std.int(colors[0]), Std.int(colors[1]), Std.int(colors[2]));
	}

	function setSelectedFreeplayColor(color:FlxColor):Void
	{
		var colors:Array<Dynamic> = ensureSelectedFreeplayColor();
		colors[0] = color.red;
		colors[1] = color.green;
		colors[2] = color.blue;
		bg.color = color;
		WeekEditorState.unsavedProgress = true;
		updateColorPicker();
	}

	function updateColorPicker(?specific:Null<FlxColor>):Void
	{
		if(colorWheel == null) return;

		var color:FlxColor = getSelectedFreeplayColor();
		var wheelColor:FlxColor = specific == null ? color : specific;
		colorPreview.color = color;
		colorHexText.text = '#' + color.toHexString(false, false);
		colorWheel.color = FlxColor.fromHSB(0, 0, color.brightness);

		colorWheelSelector.setPosition(colorWheel.x + colorWheel.width / 2, colorWheel.y + colorWheel.height / 2);
		if(wheelColor.brightness != 0)
		{
			var hueWrap:Float = wheelColor.hue * Math.PI / 180;
			colorWheelSelector.x += Math.sin(hueWrap) * colorWheel.width / 2 * wheelColor.saturation;
			colorWheelSelector.y -= Math.cos(hueWrap) * colorWheel.height / 2 * wheelColor.saturation;
		}
		colorGradientSelector.y = colorGradient.y + colorGradient.height * (1 - color.brightness);
	}

	function updateColorPickerInput():Void
	{
		if(holdingColorPicker == null) return;

		if(holdingColorPicker == colorGradient)
		{
			var newBrightness:Float = 1 - FlxMath.bound((FlxG.mouse.y - pickerScreenY(colorGradient)) / colorGradient.height, 0, 1);
			if(storedPickerColor.brightness == 0)
				setSelectedFreeplayColor(FlxColor.fromRGBFloat(newBrightness, newBrightness, newBrightness));
			else
				setSelectedFreeplayColor(FlxColor.fromHSB(storedPickerColor.hue, storedPickerColor.saturation, newBrightness));
			updateColorPicker(storedPickerColor);
		}
		else if(holdingColorPicker == colorWheel)
		{
			var center:FlxPoint = FlxPoint.get(pickerScreenX(colorWheel) + colorWheel.width / 2, pickerScreenY(colorWheel) + colorWheel.height / 2);
			var mouse:FlxPoint = FlxPoint.get(FlxG.mouse.x, FlxG.mouse.y);
			var cX:Float = (center.x - mouse.x) / colorWheel.width * 2;
			var cY:Float = (center.y - mouse.y) / colorWheel.height * 2;
			var hue:Float = FlxMath.wrap(FlxMath.wrap(Std.int(mouse.degreesTo(center)), 0, 360) - 90, 0, 360);
			var sat:Float = FlxMath.bound(Math.sqrt(cX * cX + cY * cY), 0, 1);
			if(sat != 0)
				setSelectedFreeplayColor(FlxColor.fromHSB(hue, sat, storedPickerColor.brightness));
			else
				setSelectedFreeplayColor(FlxColor.fromRGBFloat(storedPickerColor.brightness, storedPickerColor.brightness, storedPickerColor.brightness));
			center.put();
			mouse.put();
		}
	}

	function updateColorPickerHold():Void
	{
		if(UI_box == null || UI_box.selectedName != 'Freeplay' || UI_box.isMinimized)
			return;

		if(FlxG.mouse.justPressed)
		{
			if(mouseOverPickerSprite(colorWheel))
				holdingColorPicker = colorWheel;
			else if(mouseOverPickerSprite(colorGradient))
				holdingColorPicker = colorGradient;
			else
				holdingColorPicker = null;

			if(holdingColorPicker != null)
			{
				storedPickerColor = getSelectedFreeplayColor();
				updateColorPickerInput();
			}
		}
		else if(holdingColorPicker != null)
		{
			if(FlxG.mouse.justReleased)
			{
				holdingColorPicker = null;
				storedPickerColor = getSelectedFreeplayColor();
				updateColorPicker();
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.45);
			}
			else if(FlxG.mouse.pressed && (FlxG.mouse.justMoved || FlxG.mouse.deltaViewX != 0 || FlxG.mouse.deltaViewY != 0))
				updateColorPickerInput();
		}
	}

	function mouseOverPickerSprite(sprite:FlxSprite):Bool
	{
		if(sprite == null) return false;

		if(FlxG.mouse.overlaps(sprite, sprite.camera))
		{
			holdingPickerRawPosition = true;
			return true;
		}

		if(mouseOverBounds(sprite.x, sprite.y, sprite.width, sprite.height))
		{
			holdingPickerRawPosition = true;
			return true;
		}

		if(mouseOverBounds(menuScreenX(sprite), menuScreenY(sprite), sprite.width, sprite.height))
		{
			holdingPickerRawPosition = false;
			return true;
		}
		return false;
	}

	function mouseOverBounds(x:Float, y:Float, width:Float, height:Float):Bool
		return FlxG.mouse.x >= x && FlxG.mouse.x <= x + width && FlxG.mouse.y >= y && FlxG.mouse.y <= y + height;

	function pickerScreenX(sprite:FlxSprite):Float
		return holdingPickerRawPosition ? sprite.x : menuScreenX(sprite);

	function pickerScreenY(sprite:FlxSprite):Float
		return holdingPickerRawPosition ? sprite.y : menuScreenY(sprite);

	function menuScreenX(sprite:FlxSprite):Float
		return UI_box.x + sprite.x;

	function menuScreenY(sprite:FlxSprite):Float
		return UI_box.y + UI_box.tabHeight + sprite.y;

	function changeSelection(change:Int = 0) {
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected = FlxMath.wrap(curSelected + change, 0, weekFile.songs.length - 1);
		for (num => item in grpSongs.members)
		{
			var icon:HealthIcon = iconArray[num];
			item.targetY = num - curSelected;
			item.alpha = 0.6;
			icon.alpha = 0.6;
			if (item.targetY == 0)
			{
				item.alpha = 1;
				icon.alpha = 1;
			}
		}
		//trace(weekFile.songs[curSelected]);
		iconInputText.text = weekFile.songs[curSelected][1];
		updateBG();
	}

	override function update(elapsed:Float) {
		if(WeekEditorState.loadedWeek != null) {
			super.update(elapsed);
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new WeekEditorFreeplayState(WeekEditorState.loadedWeek));
			WeekEditorState.loadedWeek = null;
			return;
		}
		
		if(PsychUIInputText.focusOn != null)
			ClientPrefs.toggleVolumeKeys(false);
		else
		{
			ClientPrefs.toggleVolumeKeys(true);
			if(FlxG.keys.justPressed.ESCAPE) {
				if(!WeekEditorState.unsavedProgress)
				{
					MusicBeatState.switchState(new MainMenuState(true));
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
				}
				else openSubState(new ExitConfirmationPrompt());
			}

			if(controls.UI_UP_P) changeSelection(-1);
			if(controls.UI_DOWN_P) changeSelection(1);
		}
		updateColorPickerHold();
		super.update(elapsed);
	}
}
