package states.editors;

import backend.DropShadowData;

import flixel.FlxSubState;
import flixel.util.FlxSave;
import flixel.util.FlxSort;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxStringUtil;
import flixel.util.FlxDestroyUtil;
import flixel.input.keyboard.FlxKey;

import openfl.events.KeyboardEvent;

import lime.utils.Assets;
import lime.media.AudioBuffer;

import flash.media.Sound;
import flash.geom.Rectangle;


import objects.*;
import states.stages.*;
import states.stages.objects.*;

import haxe.Json;
import haxe.Exception;
import haxe.io.Bytes;

import states.editors.content.MetaNote;
import states.editors.content.VSlice;
import states.editors.content.Prompt;
import states.editors.content.*;

import backend.Song;
import backend.StageData;
import backend.Highscore;
import backend.Difficulty;

import objects.Character;
import objects.HealthIcon;
import objects.Note;
import objects.StrumNote;

import shaders.DropShadowShader;


import flixel.math.FlxAngle;

using DateTools;

/**
    Code first, optimize after
**/
class DropShadowEditor extends ScriptedState implements PsychUIEventHandler.PsychUIEvent
{
    var camGame:FlxCamera;
    var camUI:FlxCamera;
    var mainBox:PsychUIBox;
    var curStage:String = 'stage';

    var boyfriendGroup:FlxSpriteGroup;
    var dadGroup:FlxSpriteGroup;
    var gfGroup:FlxSpriteGroup;

    var gf:Character;
    var dad:Character;
    var boyfriend:Character;

    var characters:Array<Character> = [];

    
    var stageData:StageFile;
    var dropShadowData:DropShadowData = new DropShadowData();

    var BF_X:Float = 770;
	var BF_Y:Float = 100;
	var DAD_X:Float = 100;
	var DAD_Y:Float = 100;
	var GF_X:Float = 400;
	var GF_Y:Float = 130;
    override function create()
    {
        /**
            quick check
            erm please if there's a better way to do this please do change it!!!
        **/
        if(PlayState.SONG == null)
            Song.loadFromJson('tutorial');
        FlxG.mouse.visible = true;
        camGame = initPsychCamera();

        stageData = StageData.getStageFile(PlayState.curStage);

        BF_X = stageData.boyfriend[0];
		BF_Y = stageData.boyfriend[1];
		GF_X = stageData.girlfriend[0];
		GF_Y = stageData.girlfriend[1];
		DAD_X = stageData.opponent[0];
		DAD_Y = stageData.opponent[1];

        switch (PlayState.curStage) {
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

        stagesFunc(function(stage:BaseStage) stage.createPost());

        boyfriendGroup = new FlxSpriteGroup(BF_X, BF_Y);
		dadGroup = new FlxSpriteGroup(DAD_X, DAD_Y);
		gfGroup = new FlxSpriteGroup(GF_X, GF_Y);

        if (!stageData.hide_girlfriend) {
			if(PlayState.SONG.gfVersion == null || PlayState.SONG.gfVersion.length < 1) PlayState.SONG.gfVersion = 'gf'; //Fix for the Chart Editor
			gf = new Character(0, 0, PlayState.SONG.gfVersion);
            startCharacterPos(gf);
			gfGroup.scrollFactor.set(0.95, 0.95);
			gfGroup.add(gf);
            characters.push(gf);
		}

        dad = new Character(0, 0, PlayState.SONG.player2);
        startCharacterPos(dad, true);
		dadGroup.add(dad);
        characters.push(dad);

		boyfriend = new Character(0, 0, PlayState.SONG.player1, true);
        startCharacterPos(boyfriend);
		boyfriendGroup.add(boyfriend);
        characters.push(boyfriend);

        add(gfGroup);
        add(dadGroup);
        add(boyfriendGroup);

        for(character in characters)
        {
            var dropShadow:DropShadowShader = new DropShadowShader(character);
            
            character.shader = dropShadow;
            character.dropShadow = dropShadow;
        }

        playCharactersAnimation('idle');

        initPsychCamera();
		camUI = new FlxCamera();
		camUI.bgColor.alpha = 0;
		FlxG.cameras.add(camUI, false);

        var mainBoxWidth:Int = 300;
        var mainBoxHeight:Int = 400;
        var mainBoxPosition:FlxPoint = new FlxPoint(FlxG.width - mainBoxWidth - 50, 50);
        mainBox = new PsychUIBox(mainBoxPosition.x, mainBoxPosition.y, 300, 280, ['Shader', 'Dad', 'Boyfriend', 'Girlfriend']);
		mainBox.selectedName = 'Shader';
		mainBox.scrollFactor.set();
		mainBox.cameras = [camUI];
		add(mainBox);

        //songName = Paths.formatToSongPath(PlayState.SONG.song);
		//if(PlayState.SONG.stage == null || PlayState.SONG.stage.length < 1)
			//PlayState.SONG.stage = StageData.vanillaSongStage(Paths.formatToSongPath(Song.loadedSongName));

		//curStage = PlayState.SONG.stage;

		

        addShaderTab();
        addDadTab();
    }

    function startCharacterPos(char:Character, ?gfCheck:Bool = false)
    {
        if(gfCheck && char.curCharacter.startsWith('gf'))
        { //IF DAD IS GIRLFRIEND, HE GOES TO HER POSITION
			char.setPosition(GF_X, GF_Y);
			char.scrollFactor.set(0.95, 0.95);
			char.danceEveryNumBeats = 2;
		}
		char.x += char.positionArray[0];
		char.y += char.positionArray[1];
	}

    var enabledCheckbox:PsychUICheckBox;
    var colorInput:PsychUIInputText;
    var distanceStepper:PsychUINumericStepper;
    var antialiasingAmountStepper:PsychUINumericStepper;
    var strengthStepper:PsychUINumericStepper;
    var thresholdStepper:PsychUINumericStepper;
    var brightnessStepper:PsychUINumericStepper;
    var hueStepper:PsychUINumericStepper;
    var saturationStepper:PsychUINumericStepper;
    var contrastStepper:PsychUINumericStepper;
    function addShaderTab()
    {

        var tab_group = mainBox.getTab('Shader').menu;
		var objX:Int = 10;
		var objY:Int = 20;
        var addY:Int = 40;

        enabledCheckbox = new PsychUICheckBox(objX, objY, 'Enabled', function()
        {
            /*
            for(character in characters)
            {
                character.dropShadow.enabled = enabledCheckbox.checked;
                
            }
                */
            dropShadowData.enabled = enabledCheckbox.checked;

        });
        tab_group.add(enabledCheckbox);

        objY += addY;
		colorInput = new PsychUIInputText(objX, objY, 120, 'FFFFFF');
        colorInput.onChange = function(old:String, cur:String)
		{
			for(character in characters)
            {
                character.dropShadow.color = FlxColor.fromString('#$cur');
                dropShadowData.color = FlxColor.fromString('#$cur');
            }
		}
        tab_group.add(colorInput);
        tab_group.add(new FlxText(colorInput.x, colorInput.y - 15, 80, 'Color:'));

        

        objY += addY;
        distanceStepper = new PsychUINumericStepper(objX, objY, 1, 0, -9999, 9999, 0);
        distanceStepper.onValueChange = function()
        {
            for(character in characters)
            {
                character.dropShadow.distance = distanceStepper.value;
                dropShadowData.distance = distanceStepper.value;
            }
        }
        tab_group.add(distanceStepper);
        tab_group.add(new FlxText(distanceStepper.x, distanceStepper.y - 15, 80, 'Distance:'));

        objY += addY;
        antialiasingAmountStepper = new PsychUINumericStepper(objX, objY, 0.1, 0, -9999, 9999, 2);
        antialiasingAmountStepper.onValueChange = function()
        {
            for(character in characters)
            {
                character.dropShadow.antialiasAmt = antialiasingAmountStepper.value;
                dropShadowData.antialiasAmt = antialiasingAmountStepper.value;
            }
        }
        tab_group.add(antialiasingAmountStepper);
        tab_group.add(new FlxText(antialiasingAmountStepper.x, antialiasingAmountStepper.y - 15, 80, 'Antialiasing Amount:'));

        objY += addY;
        strengthStepper = new PsychUINumericStepper(objX, objY, 0.1, 0, -9999, 9999, 0);
        strengthStepper.onValueChange = function()
        {
            for(character in characters)
            {
                character.dropShadow.strength = strengthStepper.value;
                dropShadowData.strength = strengthStepper.value;
            }
        }
        tab_group.add(strengthStepper);
        tab_group.add(new FlxText(strengthStepper.x, strengthStepper.y - 15, 80, 'Strength:'));

        objY += addY;
        thresholdStepper = new PsychUINumericStepper(objX, objY, 0.05, 0, -9999, 9999, 2);
        thresholdStepper.onValueChange = function()
        {
            for(character in characters)
            {
                character.dropShadow.threshold = thresholdStepper.value;
                dropShadowData.threshold = thresholdStepper.value;
            }
        }
        tab_group.add(thresholdStepper);
        tab_group.add(new FlxText(thresholdStepper.x, thresholdStepper.y - 15, 80, 'Threshold:'));

        objY += addY;
        var addColorsY:Float = 80;
        brightnessStepper = new PsychUINumericStepper(objX, objY, 1, 0, -9999, 9999, 0);
        brightnessStepper.onValueChange = function()
        {
            for(character in characters)
            {
                character.dropShadow.baseBrightness = brightnessStepper.value;
                dropShadowData.brightness = brightnessStepper.value;
            }
        }
        tab_group.add(brightnessStepper);
        tab_group.add(new FlxText(brightnessStepper.x, brightnessStepper.y - 15, 80, 'Brightness:'));

        hueStepper = new PsychUINumericStepper(objX + addColorsY, objY, 1, 0, -9999, 9999, 0);
        hueStepper.onValueChange = function()
        {
            for(character in characters)
            {
                character.dropShadow.baseHue = hueStepper.value;
                dropShadowData.hue = hueStepper.value;
            }
        }
        tab_group.add(hueStepper);
        tab_group.add(new FlxText(hueStepper.x, hueStepper.y - 15, 80, 'Hue:'));

        saturationStepper = new PsychUINumericStepper(objX + addColorsY * 2, objY, 1, 0, -9999, 9999, 0);
        saturationStepper.onValueChange = function()
        {
            for(character in characters)
            {
                character.dropShadow.baseSaturation = saturationStepper.value;
                dropShadowData.saturation = saturationStepper.value;
            }
        }
        tab_group.add(saturationStepper);
        tab_group.add(new FlxText(saturationStepper.x, saturationStepper.y - 15, 80, 'Saturation:'));

        contrastStepper = new PsychUINumericStepper(objX + addColorsY * 3, objY, 1, 0, -9999, 9999, 0);
        contrastStepper.onValueChange = function()
        {
            for(character in characters)
            {
                character.dropShadow.baseContrast = contrastStepper.value;
                dropShadowData.contrast = contrastStepper.value;
            }
        }
        tab_group.add(contrastStepper);
        tab_group.add(new FlxText(contrastStepper.x, contrastStepper.y - 15, 80, 'Contrast:'));
    }

    var dadEnabledCheckbox:PsychUICheckBox;
    var dadUseAltMaskCheckbox:PsychUICheckBox;
    var dadAngleStepper:PsychUINumericStepper;
    var dadMaskThresholdStepper:PsychUINumericStepper;
    var dadAltMaskImageInput:PsychUIInputText;
    var reloadDadAltMaskButton:PsychUIButton;
    function addDadTab()
    {
        var tab_group = mainBox.getTab('Dad').menu;
		var objX:Int = 10;
		var objY:Int = 20;
        var addY:Int = 40;

        dadEnabledCheckbox = new PsychUICheckBox(objX, objY, 'Enabled', function()
        {
            dad.dropShadow.enabled = dadEnabledCheckbox.checked;
            dropShadowData.dad.enabled = dadEnabledCheckbox.checked;
        });
        tab_group.add(dadEnabledCheckbox);

        objY += addY;
        dadUseAltMaskCheckbox = new PsychUICheckBox(objX + 150, objY, 'Use Alt Mask', function()
        {
            dad.dropShadow.useAltMask = dadUseAltMaskCheckbox.checked;
            dropShadowData.dad.useAltMask = dadUseAltMaskCheckbox.checked;
        });
        tab_group.add(dadUseAltMaskCheckbox);


        objY += addY;
        dadAngleStepper = new PsychUINumericStepper(objX, objY, 1, 0, 0, 270, 0);
        dadAngleStepper.onValueChange = function()
        {
            dad.dropShadow.angle = dadAngleStepper.value;
            dropShadowData.dad.angle = dadAngleStepper.value;
        };
        tab_group.add(dadAngleStepper);
        tab_group.add(new FlxText(dadAngleStepper.x, dadAngleStepper.y - 15, 80, 'Angle:'));

        objY += addY;
        dadMaskThresholdStepper = new PsychUINumericStepper(objX, objY, 0.05, 0, -9999, 9999, 2);
        dadMaskThresholdStepper.onValueChange = function()
        {
            dad.dropShadow.maskThreshold = dadMaskThresholdStepper.value;
            dropShadowData.dad.maskThreshold = dadMaskThresholdStepper.value;
        };
        tab_group.add(dadMaskThresholdStepper);
        tab_group.add(new FlxText(dadMaskThresholdStepper.x, dadMaskThresholdStepper.y - 15, 120, 'Mask Threshold:'));

        objY += addY;
        dadAltMaskImageInput = new PsychUIInputText(objX, objY, 120, '');
        tab_group.add(dadAltMaskImageInput);

        reloadDadAltMaskButton = new PsychUIButton(objX + 140, objY, 'Reload Alt Mask', function()
        {
            var useAltMask:Bool = dad.dropShadow.useAltMask;
            if(useAltMask) dad.dropShadow.loadAltMask(dadAltMaskImageInput.text);
        });
        tab_group.add(reloadDadAltMaskButton);

    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if(FlxG.keys.justPressed.ESCAPE)
        {
            FlxG.sound.play(Paths.sound('cancelMenu'));
            MusicBeatState.switchState(new MainMenuState());
        }

        if(FlxG.keys.justPressed.SPACE)
        {
            playCharactersAnimation('idle');
        }

        var shiftMult:Float = 1;
		var ctrlMult:Float = 1;
		var shiftMultBig:Float = 1;
		if(FlxG.keys.pressed.SHIFT)
		{
			shiftMult = 4;
			shiftMultBig = 10;
		}
		if(FlxG.keys.pressed.CONTROL) ctrlMult = 0.25;

		// CAMERA CONTROLS
		if (FlxG.keys.pressed.J) FlxG.camera.scroll.x -= elapsed * 500 * shiftMult * ctrlMult;
		if (FlxG.keys.pressed.K) FlxG.camera.scroll.y += elapsed * 500 * shiftMult * ctrlMult;
		if (FlxG.keys.pressed.L) FlxG.camera.scroll.x += elapsed * 500 * shiftMult * ctrlMult;
		if (FlxG.keys.pressed.I) FlxG.camera.scroll.y -= elapsed * 500 * shiftMult * ctrlMult;

		var lastZoom = FlxG.camera.zoom;
		if(FlxG.keys.justPressed.R && !FlxG.keys.pressed.CONTROL) FlxG.camera.zoom = 1;
		else if (FlxG.keys.pressed.E && FlxG.camera.zoom < 3) {
			FlxG.camera.zoom += elapsed * FlxG.camera.zoom * shiftMult * ctrlMult;
			if(FlxG.camera.zoom > 3) FlxG.camera.zoom = 3;
		}
		else if (FlxG.keys.pressed.Q && FlxG.camera.zoom > 0.1) {
			FlxG.camera.zoom -= elapsed * FlxG.camera.zoom * shiftMult * ctrlMult;
			if(FlxG.camera.zoom < 0.1) FlxG.camera.zoom = 0.1;
		}
    }

    function playCharactersAnimation(name:String)
    {
        for(character in characters)
                character.playAnim(name);
    }

    public function UIEvent(id:String, sender:Dynamic)
    {
        /*
		//trace(id, sender);
		if(id == PsychUICheckBox.CLICK_EVENT)
			unsavedProgress = true;

		if(id == PsychUIInputText.CHANGE_EVENT)
		{
			if(sender == healthIconInputText) {
				var lastIcon = healthIcon.getCharacter();
				healthIcon.changeIcon(healthIconInputText.text, false);
				character.healthIcon = healthIconInputText.text;
				if(lastIcon != healthIcon.getCharacter()) updatePresence();
				unsavedProgress = true;
			}
			else if(sender == vocalsInputText)
			{
				character.vocalsFile = vocalsInputText.text;
				unsavedProgress = true;
			}
			else if(sender == imageInputText)
			{
				character.imageFile = imageInputText.text;
				unsavedProgress = true;
			}
		}
		else if(id == PsychUINumericStepper.CHANGE_EVENT)
		{
			if (sender == scaleStepper)
			{
				reloadCharacterImage();
				character.jsonScale = sender.value;
				character.scale.set(character.jsonScale, character.jsonScale);
				character.updateHitbox();
				updatePointerPos(false);
				unsavedProgress = true;
			}
			else if(sender == positionXStepper)
			{
				character.positionArray[0] = positionXStepper.value;
				updateCharacterPositions();
				unsavedProgress = true;
			}
			else if(sender == positionYStepper)
			{
				character.positionArray[1] = positionYStepper.value;
				updateCharacterPositions();
				unsavedProgress = true;
			}
			else if(sender == singDurationStepper)
			{
				character.singDuration = singDurationStepper.value;
				unsavedProgress = true;
			}
			else if(sender == positionCameraXStepper)
			{
				character.cameraPosition[0] = positionCameraXStepper.value;
				updatePointerPos();
				unsavedProgress = true;
			}
			else if(sender == positionCameraYStepper)
			{
				character.cameraPosition[1] = positionCameraYStepper.value;
				updatePointerPos();
				unsavedProgress = true;
			}
			else if(sender == healthColorStepperR)
			{
				character.healthColorArray[0] = Math.round(healthColorStepperR.value);
				updateHealthBar();
				unsavedProgress = true;
			}
			else if(sender == healthColorStepperG)
			{
				character.healthColorArray[1] = Math.round(healthColorStepperG.value);
				updateHealthBar();
				unsavedProgress = true;
			}
			else if(sender == healthColorStepperB)
			{
				character.healthColorArray[2] = Math.round(healthColorStepperB.value);
				updateHealthBar();
				unsavedProgress = true;
			}
		}
            */ 

	}

}