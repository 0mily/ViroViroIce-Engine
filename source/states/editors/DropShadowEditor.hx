package states.editors;

import backend.DropShadowData;
import backend.DropShadowData.CharacterSpecificData;
import backend.StageData;

import flixel.addons.display.shapes.FlxShapeCircle;
import flixel.util.FlxGradient;
import lime.system.Clipboard;

import objects.Character;
import states.MainMenuState;
import states.editors.content.FileDialogHandler;

typedef DropShadowColorPicker = {
	var tabName:String;
	var character:Character;
	var data:CharacterSpecificData;
	var gradient:FlxSprite;
	var gradientSelector:FlxSprite;
	var wheel:FlxSprite;
	var wheelSelector:FlxShapeCircle;
	var preview:FlxSprite;
	var hexText:FlxText;
}

class DropShadowEditor extends ScriptedState implements PsychUIEventHandler.PsychUIEvent
{
	var camGame:FlxCamera;
	var camUI:FlxCamera;
	var mainBox:PsychUIBox;
	var upperBox:PsychUIBox;

	var curStage:String = 'stage';
	var stageData:StageFile;
	var dropShadowData:DropShadowData;

	public var boyfriendGroup:FlxSpriteGroup;
	public var dadGroup:FlxSpriteGroup;
	public var gfGroup:FlxSpriteGroup;

	public var boyfriend:Character;
	public var dad:Character;
	public var gf:Character;

	var BF_X:Float = 770;
	var BF_Y:Float = 100;
	var DAD_X:Float = 100;
	var DAD_Y:Float = 100;
	var GF_X:Float = 400;
	var GF_Y:Float = 130;

	var outputTxt:FlxText;
	var outputAlpha:Float = 0;

	var stageDropDown:PsychUIDropDownMenu;
	var dadDropDown:PsychUIDropDownMenu;
	var gfDropDown:PsychUIDropDownMenu;
	var boyfriendDropDown:PsychUIDropDownMenu;
	var characterList:Array<String> = [];
	var fileDialog:FileDialogHandler = new FileDialogHandler();
	var colorPickers:Array<DropShadowColorPicker> = [];
	var holdingColorPicker:DropShadowColorPicker;
	var holdingColorPickerSprite:FlxSprite;
	var holdingPickerRawPosition:Bool = false;
	var storedPickerColor:FlxColor = FlxColor.WHITE;

	public function new(?stageToLoad:String = null)
	{
		curStage = DropShadowData.stageName(stageToLoad);
		super();
	}

	override function create()
	{
        /**
            quick check
            erm please if there's a better way to do this please do change it!!!
        **/

		// ok - Mily

		FlxG.mouse.visible = true;
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		camGame = initPsychCamera();
		camUI = new FlxCamera();
		camUI.bgColor.alpha = 0;
		FlxG.cameras.add(camUI, false);

		stageData = StageData.getStageFile(curStage);
		loadJsonAssetDirectory();
		readStagePositions();

		boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
		gfGroup = new FlxSpriteGroup(GF_X, GF_Y);

		gf = new Character(0, 0, editorMetaCharacter('gf', 'gf'));
		gf.visible = !stageData.hide_girlfriend;
		startCharacterPos(gf, 'gf');
		gfGroup.add(gf);

		dad = new Character(0, 0, editorMetaCharacter('dad', 'dad'));
		startCharacterPos(dad, 'dad');
		dadGroup.add(dad);

		boyfriend = new Character(0, 0, editorMetaCharacter('boyfriend', 'bf'), true);
		startCharacterPos(boyfriend, 'boyfriend');
		boyfriendGroup.add(boyfriend);

		var previewObjects:Array<Dynamic> = filterPreviewStageObjects(stageData.objects);
		if(previewObjects.length > 0)
			StageData.addObjectsToState(previewObjects, null, null, null, this, true);
		else
		{
			if(!stageData.hide_girlfriend)
				add(gfGroup);
			add(dadGroup);
			add(boyfriendGroup);
		}
		addPreviewGroupIfMissing(gfGroup, !stageData.hide_girlfriend);
		addPreviewGroupIfMissing(dadGroup);
		addPreviewGroupIfMissing(boyfriendGroup);

		dropShadowData = new DropShadowData(curStage);
		applyAllDropShadows();
		playCharactersAnimation('idle');

		FlxG.camera.zoom = stageData.defaultZoom;
		focusCameraOnBoyfriend();

		buildUI();
		super.create();
	}

	function buildUI():Void
	{
		mainBox = new PsychUIBox(FlxG.width - 430, 40, 410, 500, ['Stage', 'Dad', 'Boyfriend', 'Girlfriend']);
		mainBox.selectedName = 'Dad';
		mainBox.scrollFactor.set();
		mainBox.cameras = [camUI];
		add(mainBox);

		upperBox = new PsychUIBox(0, 0, 465, 300, ['File']);
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

		reloadCharacterList();
		addFileTab();
		addStageTab();
		addCharacterTab('Dad', dad, dropShadowData.dad);
		addCharacterTab('Boyfriend', boyfriend, dropShadowData.boyfriend);
		addCharacterTab('Girlfriend', gf, dropShadowData.girlfriend);
	}

	function addFileTab():Void
	{
		var tab = upperBox.getTab('File');
		var tab_group = tab.menu;
		var btnX = tab.x - upperBox.x;
		var btnWid = Std.int(tab.width);

		var saveButton:PsychUIButton = new PsychUIButton(btnX, 20, #if sys '  Save XML as...' #else '  Download XML' #end, saveDropshadow, btnWid);
		saveButton.text.alignment = LEFT;
		tab_group.add(saveButton);
	}

	function addStageTab():Void
	{
		var tab_group = mainBox.getTab('Stage').menu;

		stageDropDown = new PsychUIDropDownMenu(10, 30, getStageList(), function(sel:Int, selected:String)
		{
			if(selected != null && selected.length > 0 && selected != curStage)
				MusicBeatState.switchState(new DropShadowEditor(selected));
		}, 150);
		stageDropDown.selectedLabel = curStage;
		tab_group.add(new FlxText(stageDropDown.x, stageDropDown.y - 18, 100, 'Stage:'));
		tab_group.add(stageDropDown);

		var reloadButton:PsychUIButton = new PsychUIButton(180, 30, 'Reload Stage', function()
		{
			MusicBeatState.switchState(new DropShadowEditor(curStage));
		}, 120);
		tab_group.add(reloadButton);

		var objY:Int = 95;
		dadDropDown = characterDropdown(10, objY, dad.curCharacter, function(character:String)
		{
			changePreviewCharacter(dad, character, dropShadowData.dad, 'dad');
			dadDropDown.selectedLabel = dad.curCharacter;
		});
		tab_group.add(new FlxText(dadDropDown.x, dadDropDown.y - 18, 100, 'Dad:'));
		tab_group.add(dadDropDown);

		objY += 55;
		gfDropDown = characterDropdown(10, objY, gf.curCharacter, function(character:String)
		{
			changePreviewCharacter(gf, character, dropShadowData.girlfriend, 'gf');
			gfDropDown.selectedLabel = gf.curCharacter;
		});
		tab_group.add(new FlxText(gfDropDown.x, gfDropDown.y - 18, 100, 'Girlfriend:'));
		tab_group.add(gfDropDown);

		objY += 55;
		boyfriendDropDown = characterDropdown(10, objY, boyfriend.curCharacter, function(character:String)
		{
			changePreviewCharacter(boyfriend, character, dropShadowData.boyfriend, 'boyfriend');
			boyfriendDropDown.selectedLabel = boyfriend.curCharacter;
		});
		tab_group.add(new FlxText(boyfriendDropDown.x, boyfriendDropDown.y - 18, 100, 'Boyfriend:'));
		tab_group.add(boyfriendDropDown);
	}

	function addCharacterTab(tabName:String, character:Character, data:CharacterSpecificData):Void
	{
		var tab_group = mainBox.getTab(tabName).menu;
		var leftX:Int = 10;
		var rightX:Int = 240;
		var objY:Int = 18;
		var row:Int = 48;
		var picker:DropShadowColorPicker = null;
		var distanceSlider:PsychUISlider = null;
		var angleSlider:PsychUISlider = null;
		var strengthSlider:PsychUISlider = null;
		var thresholdSlider:PsychUISlider = null;
		var antialiasSlider:PsychUISlider = null;
		var brightnessStepper:PsychUINumericStepper = null;
		var hueStepper:PsychUINumericStepper = null;
		var saturationStepper:PsychUINumericStepper = null;
		var contrastStepper:PsychUINumericStepper = null;
		var maskThresholdSlider:PsychUISlider = null;
		var useAltMaskCheckbox:PsychUICheckBox = null;
		var altMaskInput:PsychUIInputText = null;
		var enabledCheckbox:PsychUICheckBox = null;

		function syncControlsToData():Void
		{
			if(enabledCheckbox != null) enabledCheckbox.checked = data.enabled;
			if(distanceSlider != null) distanceSlider.value = data.distance;
			if(angleSlider != null) angleSlider.value = data.angle;
			if(strengthSlider != null) strengthSlider.value = data.strength;
			if(thresholdSlider != null) thresholdSlider.value = data.threshold;
			if(antialiasSlider != null) antialiasSlider.value = data.antialiasAmt;
			if(brightnessStepper != null) brightnessStepper.value = data.brightness;
			if(hueStepper != null) hueStepper.value = data.hue;
			if(saturationStepper != null) saturationStepper.value = data.saturation;
			if(contrastStepper != null) contrastStepper.value = data.contrast;
			if(useAltMaskCheckbox != null) useAltMaskCheckbox.checked = data.useAltMask;
			if(maskThresholdSlider != null) maskThresholdSlider.value = data.maskThreshold;
			if(altMaskInput != null) altMaskInput.text = data.altMaskPath ?? '';
			updateColorPicker(picker);
		}

		function addCopyButton(label:String, source:CharacterSpecificData, x:Float):Void
		{
			tab_group.add(new PsychUIButton(x, objY, label, function()
			{
				copyCharacterPreset(source, data);
				refreshCharacterShadow(character, data);
				syncControlsToData();
				showOutput('Copied $label preset to $tabName.');
			}, 50));
		}

		enabledCheckbox = new PsychUICheckBox(leftX, objY, 'Enabled', 100, function()
		{
			data.enabled = enabledCheckbox.checked;
			refreshCharacterShadow(character, data);
		});
		enabledCheckbox.checked = data.enabled;
		tab_group.add(enabledCheckbox);
		tab_group.add(new FlxText(122, objY + 2, 70, 'Copy from:'));
		addCopyButton('Dad', dropShadowData.dad, 190);
		addCopyButton('BF', dropShadowData.boyfriend, 243);
		addCopyButton('GF', dropShadowData.girlfriend, 296);

		tab_group.add(new FlxText(leftX, 43, 120, 'Color:'));
		picker = addColorPicker(tabName, tab_group, leftX, 62, character, data);

		distanceSlider = addSlider(tab_group, rightX, 58, 'Distance', data.distance, 0, 100, 0, function(value:Float)
		{
			data.distance = value;
			refreshCharacterShadow(character, data);
		});
		angleSlider = addSlider(tab_group, rightX, 58 + row, 'Angle', data.angle, -360, 360, 0, function(value:Float)
		{
			data.angle = value;
			refreshCharacterShadow(character, data);
		});
		strengthSlider = addSlider(tab_group, rightX, 58 + row * 2, 'Strength', data.strength, 0, 5, 2, function(value:Float)
		{
			data.strength = value;
			refreshCharacterShadow(character, data);
		});
		thresholdSlider = addSlider(tab_group, rightX, 58 + row * 3, 'Threshold', data.threshold, 0, 1, 2, function(value:Float)
		{
			data.threshold = value;
			refreshCharacterShadow(character, data);
		});
		antialiasSlider = addSlider(tab_group, rightX, 58 + row * 4, 'Antialiasing', data.antialiasAmt, 0, 8, 0, function(value:Float)
		{
			data.antialiasAmt = value;
			refreshCharacterShadow(character, data);
		});

		objY = 300;
		brightnessStepper = addStepper(tab_group, leftX, objY, 'Brightness:', 5, data.brightness, -9999, 9999, 0, function(value:Float)
		{
			data.brightness = value;
			refreshCharacterShadow(character, data);
		}, 80);
		hueStepper = addStepper(tab_group, leftX + 95, objY, 'Hue:', 5, data.hue, -9999, 9999, 0, function(value:Float)
		{
			data.hue = value;
			refreshCharacterShadow(character, data);
		}, 80);
		saturationStepper = addStepper(tab_group, leftX + 190, objY, 'Saturation:', 5, data.saturation, -9999, 9999, 0, function(value:Float)
		{
			data.saturation = value;
			refreshCharacterShadow(character, data);
		}, 80);
		contrastStepper = addStepper(tab_group, leftX + 285, objY, 'Contrast:', 5, data.contrast, -9999, 9999, 0, function(value:Float)
		{
			data.contrast = value;
			refreshCharacterShadow(character, data);
		}, 80);

		objY += row + 4;
		useAltMaskCheckbox = new PsychUICheckBox(leftX, objY, 'Use Alt Mask', 100, function()
		{
			data.useAltMask = useAltMaskCheckbox.checked;
			refreshCharacterShadow(character, data);
		});
		useAltMaskCheckbox.checked = data.useAltMask;
		tab_group.add(useAltMaskCheckbox);
		maskThresholdSlider = addSlider(tab_group, leftX + 155, objY - 5, 'Mask Threshold', data.maskThreshold, 0, 1, 2, function(value:Float)
		{
			data.maskThreshold = value;
			refreshCharacterShadow(character, data);
		}, 155);

		objY += row;
		tab_group.add(new FlxText(leftX, objY - 15, 120, 'Alt Mask Image:'));
		altMaskInput = new PsychUIInputText(leftX, objY, 210, data.altMaskPath ?? '', 8);
		altMaskInput.onChange = function(old:String, cur:String)
		{
			data.altMaskPath = cur;
		};
		var reloadMaskButton = new PsychUIButton(leftX + 225, objY, 'Reload Mask', function()
		{
			data.altMaskPath = altMaskInput.text;
			refreshCharacterShadow(character, data);
		}, 115);
		tab_group.add(altMaskInput);
		tab_group.add(reloadMaskButton);
	}

	function addColorPicker(tabName:String, tab_group:FlxSpriteGroup, x:Float, y:Float, character:Character, data:CharacterSpecificData):DropShadowColorPicker
	{
		var colorGradient = FlxGradient.createGradientFlxSprite(18, 118, [FlxColor.WHITE, FlxColor.BLACK]);
		colorGradient.setPosition(x, y);

		var colorGradientSelector = new FlxSprite(colorGradient.x - 4, colorGradient.y).makeGraphic(26, 6, FlxColor.WHITE);
		colorGradientSelector.offset.y = 3;

		var colorWheel = new FlxSprite(x + 30, y).loadGraphic(Paths.image('noteColorMenu/colorWheel'));
		colorWheel.setGraphicSize(118, 118);
		colorWheel.updateHitbox();

		var colorWheelSelector = new FlxShapeCircle(0, 0, 5, {thickness: 0}, FlxColor.WHITE);
		colorWheelSelector.offset.set(5, 5);
		colorWheelSelector.alpha = 0.72;

		var colorPreview = new FlxSprite(x + 166, y).makeGraphic(44, 44, FlxColor.WHITE);
		var colorHexText = new FlxText(x + 150, y + 50, 76, colorHex(data.color), 12);
		colorHexText.alignment = CENTER;

		var picker:DropShadowColorPicker = {
			tabName: tabName,
			character: character,
			data: data,
			gradient: colorGradient,
			gradientSelector: colorGradientSelector,
			wheel: colorWheel,
			wheelSelector: colorWheelSelector,
			preview: colorPreview,
			hexText: colorHexText
		};

		var copyColor:PsychUIButton = new PsychUIButton(x + 150, y + 76, 'Copy', function()
		{
			Clipboard.text = colorHex(data.color);
			showOutput('Copied ${colorHex(data.color)}');
		}, 76);

		var pasteColor:PsychUIButton = new PsychUIButton(x + 150, y + 100, 'Paste', function()
		{
			var parsed:Null<FlxColor> = parseColor(Clipboard.text);
			if(parsed == null)
			{
				showOutput('Clipboard does not contain a color.', true);
				return;
			}
			setPickerColor(picker, parsed);
		}, 76);

		tab_group.add(colorGradient);
		tab_group.add(colorWheel);
		tab_group.add(colorGradientSelector);
		tab_group.add(colorWheelSelector);
		tab_group.add(colorPreview);
		tab_group.add(colorHexText);
		tab_group.add(copyColor);
		tab_group.add(pasteColor);

		colorPickers.push(picker);
		updateColorPicker(picker);
		return picker;
	}

	function addStepper(tab_group:FlxSpriteGroup, x:Float, y:Float, label:String, step:Float, value:Float, min:Float, max:Float, decimals:Int, onChange:Float->Void, ?width:Int = 76):PsychUINumericStepper
	{
		var text = new FlxText(x, y - 15, 110, label);
		var stepper = new PsychUINumericStepper(x, y, step, value, min, max, decimals, width);
		stepper.onValueChange = function()
		{
			if(onChange != null)
				onChange(stepper.value);
		};
		tab_group.add(text);
		tab_group.add(stepper);
		return stepper;
	}

	function addSlider(tab_group:FlxSpriteGroup, x:Float, y:Float, label:String, value:Float, min:Float, max:Float, decimals:Int, onChange:Float->Void, ?width:Int = 150):PsychUISlider
	{
		var slider:PsychUISlider = new PsychUISlider(x, y, function(raw:Float)
		{
			var rounded:Float = FlxMath.roundDecimal(raw, decimals);
			if(onChange != null)
				onChange(rounded);
		}, value, min, max, width);
		slider.decimals = decimals;
		slider.label = label;
		tab_group.add(slider);
		return slider;
	}

	function characterDropdown(x:Float, y:Float, selected:String, onPick:String->Void):PsychUIDropDownMenu
	{
		var dropdown = new PsychUIDropDownMenu(x, y, characterList, function(id:Int, character:String)
		{
			if(character != null && character.length > 0 && onPick != null)
				onPick(character);
		}, 155);
		dropdown.selectedLabel = selected;
		return dropdown;
	}

	function saveDropshadow():Void
	{
		if(!fileDialog.completed)
			return;

		upperBox.isMinimized = true;
		upperBox.bg.visible = false;

		fileDialog.save('$curStage.xml', dropShadowData.buildXml(curStage), function()
		{
			#if sys
			showOutput('Dropshadow XML saved to: ${fileDialog.path}. Put it in data/stages/$curStage.xml to load with the stage.');
			#else
			showOutput('Dropshadow XML downloaded.');
			#end
		}, null, function() showOutput('Error saving dropshadow XML.', true));
	}

	function showOutput(message:String, isError:Bool = false):Void
	{
		trace(message);
		outputTxt.text = message;
		outputTxt.y = FlxG.height - outputTxt.height - 30;
		outputTxt.color = isError ? FlxColor.RED : FlxColor.WHITE;
		outputAlpha = 4;

		if(ClientPrefs.data.editorSFX)
			FlxG.sound.play(Paths.uiSound(isError ? 'cancelMenu' : 'scrollMenu'), 0.6);
	}

	function readStagePositions():Void
	{
		BF_X = readStagePoint(stageData.boyfriend, 0, 770);
		BF_Y = readStagePoint(stageData.boyfriend, 1, 100);
		GF_X = readStagePoint(stageData.girlfriend, 0, 400);
		GF_Y = readStagePoint(stageData.girlfriend, 1, 130);
		DAD_X = readStagePoint(stageData.opponent, 0, 100);
		DAD_Y = readStagePoint(stageData.opponent, 1, 100);
	}

	function readStagePoint(values:Array<Dynamic>, index:Int, fallback:Float):Float
	{
		if(values == null || values.length <= index)
			return fallback;
		var parsed:Float = Std.parseFloat(Std.string(values[index]));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	function loadJsonAssetDirectory():Void
	{
		var directory:String = 'shared';
		if(stageData != null && stageData.directory != null && stageData.directory.trim().length > 0)
			directory = stageData.directory;

		Paths.setCurrentLevel(directory);
	}

	function filterPreviewStageObjects(objects:Array<Dynamic>):Array<Dynamic>
	{
		var filtered:Array<Dynamic> = [];
		if(objects == null)
			return filtered;

		for(data in objects)
		{
			var type:String = Std.string(Reflect.field(data, 'type'));
			var name:String = Std.string(Reflect.field(data, 'name'));
			if(StageData.reservedNames.contains(type) || StageData.reservedNames.contains(name))
				continue;
			filtered.push(data);
		}
		return filtered;
	}

	function addPreviewGroupIfMissing(group:FlxSpriteGroup, addGroup:Bool = true):Void
	{
		if(addGroup && group != null && !members.contains(group))
			add(group);
	}

	function editorMetaCharacter(field:String, fallback:String):String
	{
		if(stageData != null && stageData._editorMeta != null && Reflect.hasField(stageData._editorMeta, field))
		{
			var value:String = Std.string(Reflect.field(stageData._editorMeta, field));
			if(value != null && value.trim().length > 0)
				return value;
		}
		return fallback;
	}

	function reloadCharacterList():Void
	{
		characterList = Mods.mergeAllTextsNamed('data/characterList.txt');
		Character.appendCharacterFileList(characterList);
		if(characterList.length < 1)
			characterList.push('');
	}

	function getStageList():Array<String>
	{
		var stageList:Array<String> = ['stage', 'spooky', 'philly', 'limo', 'mall', 'mallEvil', 'school', 'schoolEvil', 'tank', 'phillyStreets', 'phillyBlazin', 'mallErect', 'phillyStreetsErect']; // i will probably remove this
		#if sys
		function pushStageFromFile(file:String, extension:String):Void
		{
			if(!file.toLowerCase().endsWith(extension))
				return;

			var stageToCheck:String = file.substr(0, file.length - extension.length);
			if(!stageList.contains(stageToCheck))
				stageList.push(stageToCheck);
		}

		for(folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'data/stages/'))
			for(file in FileSystem.readDirectory(folder))
			{
				pushStageFromFile(file, '.json');
				pushStageFromFile(file, '.xml');
			}
		#end
		return stageList;
	}

	function startCharacterPos(char:Character, ?role:String = ''):Void
	{
		if(char == null)
			return;

		resetPreviewGroupPosition(role, char);
		char.setPosition(0, 0);
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

	function resetPreviewGroupPosition(role:String, char:Character):Void
	{
		switch(role)
		{
			case 'gf':
				if(gfGroup != null)
				{
					gfGroup.setPosition(GF_X, GF_Y);
					gfGroup.scrollFactor.set(0.95, 0.95);
				}

			case 'dad':
				if(dadGroup != null)
				{
					if(char != null && char.curCharacter.startsWith('gf'))
					{
						dadGroup.setPosition(GF_X, GF_Y);
						dadGroup.scrollFactor.set(0.95, 0.95);
						char.danceEveryNumBeats = 2;
					}
					else
					{
						dadGroup.setPosition(DAD_X, DAD_Y);
						dadGroup.scrollFactor.set(1, 1);
					}
				}

			case 'boyfriend':
				if(boyfriendGroup != null)
				{
					boyfriendGroup.setPosition(BF_X, BF_Y);
					boyfriendGroup.scrollFactor.set(1, 1);
				}
		}
	}

	function changePreviewCharacter(character:Character, next:String, data:CharacterSpecificData, metaField:String):Void
	{
		if(character == null || next == null || next.length < 1)
			return;

		character.changeCharacter(next);
		startCharacterPos(character, metaField);
		character.dance();
		if(stageData._editorMeta == null)
			stageData._editorMeta = {dad: 'dad', gf: 'gf', boyfriend: 'bf'};
		Reflect.setField(stageData._editorMeta, metaField, next);
		refreshCharacterShadow(character, data);
		focusCameraOnBoyfriend();
	}

	function applyAllDropShadows():Void
	{
		refreshCharacterShadow(dad, dropShadowData.dad);
		refreshCharacterShadow(gf, dropShadowData.girlfriend);
		refreshCharacterShadow(boyfriend, dropShadowData.boyfriend);
	}

	function refreshCharacterShadow(character:Character, data:CharacterSpecificData):Void
	{
		DropShadowData.applyToCharacter(character, data, true);
	}

	function copyCharacterPreset(source:CharacterSpecificData, target:CharacterSpecificData):Void
	{
		if(source == null || target == null)
			return;

		target.enabled = source.enabled;
		target.color = source.color;
		target.distance = source.distance;
		target.strength = source.strength;
		target.threshold = source.threshold;
		target.antialiasAmt = source.antialiasAmt;
		target.hue = source.hue;
		target.saturation = source.saturation;
		target.brightness = source.brightness;
		target.contrast = source.contrast;
		target.angle = source.angle;
		target.altMaskImage = source.altMaskImage;
		target.altMaskPath = source.altMaskPath;
		target.useAltMask = source.useAltMask;
		target.maskThreshold = source.maskThreshold;
	}

	function playCharactersAnimation(name:String):Void
	{
		for(character in [gf, dad, boyfriend])
			if(character != null && character.hasAnimation(name))
				character.playAnim(name, true);
	}

	function focusCameraOnBoyfriend():Void
	{
		if(boyfriend == null)
			return;

		var point:FlxPoint = boyfriend.getMidpoint();
		FlxG.camera.scroll.set(point.x - FlxG.width / 2, point.y - FlxG.height / 2);
		point.put();
	}

	function setPickerColor(picker:DropShadowColorPicker, color:FlxColor, ?wheelColor:Null<FlxColor>):Void
	{
		if(picker == null)
			return;

		picker.data.color = color;
		refreshCharacterShadow(picker.character, picker.data);
		updateColorPicker(picker, wheelColor);
	}

	function updateColorPicker(picker:DropShadowColorPicker, ?specific:Null<FlxColor>):Void
	{
		if(picker == null || picker.wheel == null)
			return;

		var color:FlxColor = picker.data.color;
		var wheelColor:FlxColor = specific == null ? color : specific;
		picker.preview.color = color;
		picker.hexText.text = colorHex(color);
		picker.wheel.color = FlxColor.fromHSB(0, 0, color.brightness);

		picker.wheelSelector.setPosition(picker.wheel.x + picker.wheel.width / 2, picker.wheel.y + picker.wheel.height / 2);
		if(wheelColor.brightness != 0)
		{
			var hueWrap:Float = wheelColor.hue * Math.PI / 180;
			picker.wheelSelector.x += Math.sin(hueWrap) * picker.wheel.width / 2 * wheelColor.saturation;
			picker.wheelSelector.y -= Math.cos(hueWrap) * picker.wheel.height / 2 * wheelColor.saturation;
		}
		picker.gradientSelector.y = picker.gradient.y + picker.gradient.height * (1 - color.brightness);
	}

	function updateColorPickerInput():Void
	{
		if(holdingColorPicker == null || holdingColorPickerSprite == null)
			return;

		if(holdingColorPickerSprite == holdingColorPicker.gradient)
		{
			var mouse:FlxPoint = getPickerMouse();
			var newBrightness:Float = 1 - FlxMath.bound((mouse.y - pickerScreenY(holdingColorPicker.gradient)) / holdingColorPicker.gradient.height, 0, 1);
			mouse.put();
			if(storedPickerColor.brightness == 0)
				setPickerColor(holdingColorPicker, FlxColor.fromRGBFloat(newBrightness, newBrightness, newBrightness), storedPickerColor);
			else
				setPickerColor(holdingColorPicker, FlxColor.fromHSB(storedPickerColor.hue, storedPickerColor.saturation, newBrightness), storedPickerColor);
		}
		else if(holdingColorPickerSprite == holdingColorPicker.wheel)
		{
			var center:FlxPoint = FlxPoint.get(pickerScreenX(holdingColorPicker.wheel) + holdingColorPicker.wheel.width / 2, pickerScreenY(holdingColorPicker.wheel) + holdingColorPicker.wheel.height / 2);
			var mouse:FlxPoint = getPickerMouse();
			var cX:Float = (center.x - mouse.x) / holdingColorPicker.wheel.width * 2;
			var cY:Float = (center.y - mouse.y) / holdingColorPicker.wheel.height * 2;
			var hue:Float = FlxMath.wrap(FlxMath.wrap(Std.int(mouse.degreesTo(center)), 0, 360) - 90, 0, 360);
			var saturation:Float = FlxMath.bound(Math.sqrt(cX * cX + cY * cY), 0, 1);
			if(saturation != 0)
				setPickerColor(holdingColorPicker, FlxColor.fromHSB(hue, saturation, storedPickerColor.brightness));
			else
				setPickerColor(holdingColorPicker, FlxColor.fromRGBFloat(storedPickerColor.brightness, storedPickerColor.brightness, storedPickerColor.brightness));
			center.put();
			mouse.put();
		}
	}

	function updateColorPickerHold():Void
	{
		if(mainBox == null || mainBox.isMinimized)
			return;

		var activePicker:DropShadowColorPicker = holdingColorPicker != null ? holdingColorPicker : getColorPickerForTab(mainBox.selectedName);
		if(activePicker == null)
			return;

		if(FlxG.mouse.justPressed)
		{
			if(mouseOverPickerSprite(activePicker.wheel))
			{
				holdingColorPicker = activePicker;
				holdingColorPickerSprite = activePicker.wheel;
			}
			else if(mouseOverPickerSprite(activePicker.gradient))
			{
				holdingColorPicker = activePicker;
				holdingColorPickerSprite = activePicker.gradient;
			}
			else
			{
				holdingColorPicker = null;
				holdingColorPickerSprite = null;
			}

			if(holdingColorPicker != null)
			{
				storedPickerColor = holdingColorPicker.data.color;
				updateColorPickerInput();
			}
		}
		else if(holdingColorPicker != null)
		{
			if(FlxG.mouse.justReleased)
			{
				holdingColorPickerSprite = null;
				storedPickerColor = holdingColorPicker.data.color;
				updateColorPicker(holdingColorPicker);
				holdingColorPicker = null;
				if(ClientPrefs.data.editorSFX)
					FlxG.sound.play(Paths.uiSound('scrollMenu'), 0.45);
			}
			else if(FlxG.mouse.pressed && (FlxG.mouse.justMoved || FlxG.mouse.deltaViewX != 0 || FlxG.mouse.deltaViewY != 0))
				updateColorPickerInput();
		}
	}

	function getColorPickerForTab(tabName:String):DropShadowColorPicker
	{
		for(picker in colorPickers)
			if(picker.tabName == tabName)
				return picker;
		return null;
	}

	function mouseOverPickerSprite(sprite:FlxSprite):Bool
	{
		if(sprite == null)
			return false;

		var mouse:FlxPoint = getPickerMouse();
		if(FlxG.mouse.overlaps(sprite, sprite.camera))
		{
			holdingPickerRawPosition = mouseOverBounds(mouse.x, mouse.y, sprite.x, sprite.y, sprite.width, sprite.height);
			mouse.put();
			return true;
		}

		if(mouseOverBounds(mouse.x, mouse.y, sprite.x, sprite.y, sprite.width, sprite.height))
		{
			holdingPickerRawPosition = true;
			mouse.put();
			return true;
		}

		var result:Bool = mouseOverBounds(mouse.x, mouse.y, menuScreenX(sprite), menuScreenY(sprite), sprite.width, sprite.height);
		if(result)
			holdingPickerRawPosition = false;
		mouse.put();
		return result;
	}

	function mouseOverBounds(mouseX:Float, mouseY:Float, x:Float, y:Float, width:Float, height:Float):Bool
		return mouseX >= x && mouseX <= x + width && mouseY >= y && mouseY <= y + height;

	function getPickerMouse():FlxPoint
		return FlxG.mouse.getViewPosition(camUI != null ? camUI : FlxG.camera);

	function pickerScreenX(sprite:FlxSprite):Float
		return holdingPickerRawPosition ? sprite.x : menuScreenX(sprite);

	function pickerScreenY(sprite:FlxSprite):Float
		return holdingPickerRawPosition ? sprite.y : menuScreenY(sprite);

	function menuScreenX(sprite:FlxSprite):Float
		return mainBox.x + sprite.x;

	function menuScreenY(sprite:FlxSprite):Float
		return mainBox.y + mainBox.tabHeight + sprite.y;

	function colorHex(color:FlxColor):String
		return '#' + color.toHexString(false, false);

	function parseColor(raw:String):Null<FlxColor>
	{
		if(raw == null)
			return null;
		raw = raw.trim();
		if(raw.length < 1)
			return null;

		if(raw.indexOf(',') > -1)
		{
			var split:Array<String> = raw.split(',');
			if(split.length >= 3)
			{
				var rgb:Array<Int> = [];
				for(i in 0...3)
				{
					var parsed:Null<Int> = Std.parseInt(split[i].trim());
					if(parsed == null)
						return null;
					rgb.push(Std.int(FlxMath.bound(parsed, 0, 255)));
				}
				return FlxColor.fromRGB(rgb[0], rgb[1], rgb[2]);
			}
		}

		if(!raw.startsWith('#') && !raw.startsWith('0x') && !raw.startsWith('0X'))
			raw = '#' + raw;
		return FlxColor.fromString(raw);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		outputAlpha = Math.max(0, outputAlpha - elapsed);
		if(outputTxt != null)
			outputTxt.alpha = Math.min(1, outputAlpha);

		updateColorPickerHold();

		if(FlxG.keys.justPressed.ESCAPE)
		{
			if(ClientPrefs.data.editorSFX)
				FlxG.sound.play(Paths.uiSound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
			return;
		}

		if(FlxG.keys.justPressed.SPACE)
			playCharactersAnimation('idle');

		var shiftMult:Float = FlxG.keys.pressed.SHIFT ? 4 : 1;
		var ctrlMult:Float = FlxG.keys.pressed.CONTROL ? 0.25 : 1;

		if(FlxG.keys.pressed.J) FlxG.camera.scroll.x -= elapsed * 500 * shiftMult * ctrlMult;
		if(FlxG.keys.pressed.K) FlxG.camera.scroll.y += elapsed * 500 * shiftMult * ctrlMult;
		if(FlxG.keys.pressed.L) FlxG.camera.scroll.x += elapsed * 500 * shiftMult * ctrlMult;
		if(FlxG.keys.pressed.I) FlxG.camera.scroll.y -= elapsed * 500 * shiftMult * ctrlMult;

		if(FlxG.keys.justPressed.R && !FlxG.keys.pressed.CONTROL)
			FlxG.camera.zoom = stageData.defaultZoom;
		else if(FlxG.keys.pressed.E && FlxG.camera.zoom < 3)
			FlxG.camera.zoom = Math.min(3, FlxG.camera.zoom + elapsed * FlxG.camera.zoom * shiftMult * ctrlMult);
		else if(FlxG.keys.pressed.Q && FlxG.camera.zoom > 0.1)
			FlxG.camera.zoom = Math.max(0.1, FlxG.camera.zoom - elapsed * FlxG.camera.zoom * shiftMult * ctrlMult);
	}

	public function UIEvent(id:String, sender:Dynamic) {}
}
