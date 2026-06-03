package objects;

import backend.animation.PsychAnimationController;
import backend.NoteTypesConfig;
import backend.PsychCamera;

import shaders.RGBPalette;
import shaders.RGBPalette.RGBShaderReference;

import objects.StrumNote;
import objects.NoteSkinData.NoteSkinConfig;
import objects.NoteSkinData.NoteSkinOffset;

import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxRect;

using StringTools;

typedef EventNote = {
	strumTime:Float,
	event:String,
	value1:String,
	value2:String,
	?values:Array<String>
}

typedef NoteSplashData = {
	disabled:Bool,
	texture:String,
	useGlobalShader:Bool, //breaks r/g/b but makes it copy default colors for your custom note
	useRGBShader:Bool,
	antialiasing:Bool,
	r:FlxColor,
	g:FlxColor,
	b:FlxColor,
	a:Float
}

/**
 * The note object used as a data structure to spawn and manage notes during gameplay.
 * 
 * If you want to make a custom note type, you should search for: "function set_noteType"
**/
class Note extends FlxSprite
{
	//This is needed for the hardcoded note types to appear on the Chart Editor,
	//It's also used for backwards compatibility with 0.1 - 0.3.2 charts.
	public static final defaultNoteTypes:Array<String> = [
		'', //Always leave this one empty pls
		'Alt Animation',
		'Hey!',
		'Hurt Note',
		'GF Sing',
		'No Animation'
	];

	public var strumTime:Float = 0;
	public var noteData:Int = 0;

	public var mustPress(default, set):Bool = false;
	public var canBeHit:Bool = false;
	public var tooLate:Bool = false;

	public var wasGoodHit:Bool = false;
	public var missed:Bool = false;

	public var ignoreNote:Bool = false;
	public var hitByOpponent:Bool = false;
	public var noteWasHit:Bool = false;
	public var prevNote:Note;
	public var nextNote:Note;

	public var spawned:Bool = false;

	public var tail:Array<Note> = []; // for sustains
	public var parent:Note;
	
	public var blockHit:Bool = false; // only works for player

	public var sustainLength:Float = 0;
	public var isSustainEnd:Bool = false;
	public var isSustainNote:Bool = false;
	public var noteType(default, set):String = null;

	public var eventName:String = '';
	public var eventLength:Int = 0;
	public var eventVal1:String = '';
	public var eventVal2:String = '';

	public var rgbShader:RGBShaderReference;
	public var useRGBShader(default, set):Bool = true;
	public static var globalRgbShaders:Array<RGBPalette> = [];
	public var inEditor:Bool = false;
	
	public var character:Character = null;
	public var animSuffix:String = '';
	public var gfNote:Bool = false;
	public var earlyHitMult:Float = 1;
	public var lateHitMult:Float = 1;
	public var hitPriority:Float = 1;
	public var lowPriority(get, set):Bool;

	public static var SUSTAIN_SIZE:Int = 44;
	public static var swagWidth:Float = 160 * 0.7;
	public static var dirArray:Array<String> = ['left', 'down', 'up', 'right'];
	public static var colArray:Array<String> = ['purple', 'blue', 'green', 'red'];
	public static var defaultNoteSkin(default, never):String = 'noteskins/notes/NOTE_assets';

	public var noteSplashData:NoteSplashData = {
		disabled: false,
		texture: null,
		antialiasing: !PlayState.isPixelStage,
		useGlobalShader: false,
		useRGBShader: (PlayState.SONG != null) ? !(PlayState.SONG.disableNoteRGB == true) : true,
		r: -1,
		g: -1,
		b: -1,
		a: ClientPrefs.data.splashAlpha
	};
	public var noteHoldSplash:SustainSplash;

	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var offsetAngle:Float = 0;
	public var offsetDirection:Float = 0;
	public var multAlpha:Float = 1;
	public var multSpeed:Float = 1;

	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var copyAngle:Bool = true;
	public var copyAlpha:Bool = true;

	public var hitHealth:Float = 0.02;
	public var missHealth:Float = 0.1;
	public var rating:String = 'unknown';
	public var ratingMod:Float = 0; //9 = unknown, 0.25 = shit, 0.5 = bad, 0.75 = good, 1 = sick
	public var ratingDisabled:Bool = false;
	public var noteSplash:NoteSplash = null;
	public var playField(get, never):FlxTypedGroup<StrumNote>;
	
	public var loadedTexture:String = null;
	public var texture(default, set):String = null;
	public var skinConfig:NoteSkinConfig = null;
	var skinOffsetX:Float = 0;
	var skinOffsetY:Float = 0;
	var skinOffsetAngle:Float = 0;
	public var rgbOverride:Null<FlxColor> = null;

	public var noAnimation:Bool = false;
	public var noMissAnimation:Bool = false;
	public var hitCausesMiss:Bool = false;
	public var distance:Float = 2000; //plan on doing scroll directions soon -bb
	
	public var playMissSound:Bool = false;
	public var hitsoundDisabled:Bool = false;
	public var hitsoundChartEditor:Bool = true;
	/**
	 * Forces the hitsound to be played even if the user's hitsound volume is set to 0
	**/
	public var hitsoundForce:Bool = false;
	public var hitsoundVolume(get, default):Float = 1.0;
	function get_hitsoundVolume():Float {
		if(ClientPrefs.data.hitsoundVolume > 0)
			return ClientPrefs.data.hitsoundVolume;
		return hitsoundForce ? hitsoundVolume : 0.0;
	}

	function get_playField():FlxTypedGroup<StrumNote>
	{
		if(PlayState.instance == null)
			return null;
		return mustPress ? PlayState.instance.playerStrums : PlayState.instance.opponentStrums;
	}
	public var hitsound:String = 'hitsound';
	
	public var section:Int = 0;

	static var nmvNoteSkinCache:Map<String, Dynamic> = new Map();

	public static function resolveNoteSkinPath(skin:String, player:Int = 1):String
	{
		return NoteSkinData.resolveNoteSkinPath(skin, player);
	}

	static function getNMVNoteSkinData(skin:String):Dynamic
	{
		var key:String = skin.replace('\\', '/').trim();
		if(key.startsWith('noteskins/'))
			key = key.substr('noteskins/'.length);
		if(key.endsWith('.json'))
			key = key.substr(0, key.length - '.json'.length);
		if(key.length < 1)
			return null;

		if(nmvNoteSkinCache.exists(key))
			return nmvNoteSkinCache.get(key);

		var data:Dynamic = null;
		try
		{
			var raw:String = Paths.getTextFromFile('noteskins/$key.json');
			if(raw != null && raw.trim().length > 0)
				data = tjson.TJSON.parse(raw);
		}
		catch(e:Dynamic) {}

		nmvNoteSkinCache.set(key, data);
		return data;
	}

	static function readNoteSkinString(data:Dynamic, field:String):String
	{
		if(data == null || field == null || !Reflect.hasField(data, field))
			return null;

		var value:Dynamic = Reflect.field(data, field);
		return value != null ? Std.string(value) : null;
	}

	function set_mustPress(value:Bool):Bool
	{
		var changed:Bool = mustPress != value;
		mustPress = value;
		if(changed && noteData > -1 && texture != null && animation != null)
			reloadNote(texture);
		return value;
	}

	private function set_texture(value:String):String {
		if(texture != value) {
			texture = value;
			reloadNote(value);
		}
		return value;
	}
	
	function set_lowPriority(value:Bool):Bool {
		hitPriority = (value ? Math.NEGATIVE_INFINITY : 1);
		return value;
	}
	function get_lowPriority():Bool {
		return (hitPriority == Math.NEGATIVE_INFINITY);
	}

	public function defaultRGB()
	{
		if (!useRGBShader)
		{
			if (rgbShader != null)
				rgbShader.enabled = false;
			return;
		}

		var arr:Array<FlxColor> = ClientPrefs.data.arrowRGB[noteData];
		if(PlayState.isPixelStage) arr = ClientPrefs.data.arrowRGBPixel[noteData];

		if (arr != null && noteData > -1 && noteData <= arr.length)
		{
			rgbShader.r = arr[0];
			rgbShader.g = arr[1];
			rgbShader.b = arr[2];
		}
		else
		{
			rgbShader.r = 0xFFFF0000;
			rgbShader.g = 0xFF00FF00;
			rgbShader.b = 0xFF0000FF;
		}
		rgbShader.enabled = true;
		applyRGBOverride();
	}

	public function setRGBOverride(color:Null<FlxColor>):Void
	{
		rgbOverride = color;
		if (rgbOverride == null)
			defaultRGB();
		else
		{
			useRGBShader = true;
			applyRGBOverride();
		}
	}

	public function applyRGBOverride():Void
	{
		if (rgbShader == null)
			return;

		if (!useRGBShader)
		{
			rgbShader.enabled = false;
			return;
		}

		if (rgbOverride == null)
			return;

		rgbShader.enabled = true;
		rgbShader.r = rgbOverride;
		rgbShader.g = rgbOverride;
		rgbShader.b = rgbOverride;
	}

	function set_useRGBShader(value:Bool):Bool
	{
		useRGBShader = value;
		if (noteSplashData != null)
			noteSplashData.useRGBShader = value;

		if (rgbShader == null)
			return value;

		if (!value)
		{
			rgbOverride = null;
			rgbShader.enabled = false;
		}
		else if (rgbOverride != null)
			applyRGBOverride();
		else
			defaultRGB();

		return value;
	}

	private function set_noteType(value:String):String {
		if(noteData > -1 && noteType != value) {
			noteSplashData.texture = PlayState.SONG != null ? PlayState.SONG.splashSkin : NoteSplash.defaultNoteSplash;
			defaultRGB();
			
			switch(value) {
				case 'Hurt Note':
					ignoreNote = mustPress;
					//reloadNote('HURTNOTE_assets');
					//this used to change the note texture to HURTNOTE_assets.png,
					//but i've changed it to something more optimized with the implementation of RGBPalette:

					// note colors
					rgbShader.r = 0xFF101010;
					rgbShader.g = 0xFFFF0000;
					rgbShader.b = 0xFF990022;

					// splash data and colors
					noteSplashData.r = 0xFFFF0000;
					noteSplashData.g = 0xFF101010;
					noteSplashData.texture = NoteSplash.resolveSplashPath('Electric');

					// gameplay data
					lowPriority = true;
					missHealth = isSustainNote ? 0.25 : 0.1;
					hitCausesMiss = true;
					hitsound = 'cancelMenu';
					hitsoundChartEditor = false;
				case 'Alt Animation':
					animSuffix = '-alt';
				case 'No Animation':
					noAnimation = true;
					noMissAnimation = true;
				case 'GF Sing':
					gfNote = true;
			}
			if (value != null && value.length > 1) NoteTypesConfig.applyNoteTypeData(this, value);
			applyNoteSkinProperties();
			if (hitsound != 'hitsound' && hitsoundVolume > 0) Paths.sound(hitsound); //precache new sound for being idiot-proof
		}
		return noteType = value;
	}

	public function new(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false, ?inEditor:Bool = false, ?createdFrom:Dynamic = null)
	{
		super();

		animation = new PsychAnimationController(this);

		antialiasing = ClientPrefs.data.antialiasing;
		if(createdFrom == null) createdFrom = PlayState.instance;

		if (prevNote == null)
			prevNote = this;

		this.prevNote = prevNote;
		isSustainNote = sustainNote;
		this.inEditor = inEditor;
		this.moves = false;

		x += (ClientPrefs.data.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X) + 50;
		// MAKE SURE ITS DEFINITELY OFF SCREEN?
		y -= 2000;
		this.strumTime = strumTime;
		if(!inEditor) this.strumTime += ClientPrefs.data.noteOffset;

		this.noteData = noteData;

		if(noteData > -1)
		{
			rgbShader = new RGBShaderReference(this, initializeGlobalRGBShader(noteData));
			if(PlayState.SONG != null && PlayState.SONG.disableNoteRGB) useRGBShader = false;
			texture = '';
			
			x += swagWidth * (noteData);
			if(!isSustainNote && noteData < colArray.length) { //Doing this 'if' check to fix the warnings on Senpai songs
				var animToPlay:String = '';
				animToPlay = colArray[noteData % colArray.length];
				animation.play(animToPlay + 'Scroll');
				updateHitbox();
			}
		}

		if(prevNote != null)
			prevNote.nextNote = this;

		if (isSustainNote && prevNote != null)
		{
			alpha = ClientPrefs.data.sustainAlpha;
			multAlpha = ClientPrefs.data.sustainAlpha;
			hitsoundDisabled = true;

			animation.play(colArray[noteData % colArray.length] + 'holdend');
			updateHitbox();

			if (prevNote.isSustainNote) {
				prevNote.isSustainEnd = false;
				prevNote.animation.play(colArray[prevNote.noteData % colArray.length] + 'hold');
				prevNote.applyNoteSkinOffsets();
			}
			
			isSustainEnd = true;
			applyNoteSkinOffsets();
			earlyHitMult = 0;
		}
		else if(!isSustainNote)
		{
			centerOffsets();
			centerOrigin();
		}
		x += offsetX;
	}

	public static function initializeGlobalRGBShader(noteData:Int)
	{
		if(globalRgbShaders[noteData] == null)
		{
			var newRGB:RGBPalette = new RGBPalette();
			var arr:Array<FlxColor> = (!PlayState.isPixelStage) ? ClientPrefs.data.arrowRGB[noteData] : ClientPrefs.data.arrowRGBPixel[noteData];
			
			if (arr != null && noteData > -1 && noteData <= arr.length)
			{
				newRGB.r = arr[0];
				newRGB.g = arr[1];
				newRGB.b = arr[2];
			}
			else
			{
				newRGB.r = 0xFFFF0000;
				newRGB.g = 0xFF00FF00;
				newRGB.b = 0xFF0000FF;
			}
			
			globalRgbShaders[noteData] = newRGB;
		}
		return globalRgbShaders[noteData];
	}

	var _lastNoteOffX:Float = 0;
	var _lastSustainScaleY:Float = Math.NaN;
	var _lastSustainFrameHeight:Int = -1;
	
	public function reloadNote(texture:String = '', postfix:String = '') {
		var skin:String = texture + postfix;
		
		if (texture.length < 1) {
			skin = PlayState.SONG != null ? PlayState.SONG.arrowSkin : null;
			if (skin == null || skin.length < 1)
				skin = defaultNoteSkin + postfix;
		}
		skin = resolveNoteSkinPath(skin, mustPress ? 1 : 0);

		var animName:String = animation.curAnim?.name;
		
		var skinPostfix:String = '';
		var checkSkin:String = '';
		var validSkin:String = null;
		
		for (path in [PlayState.uiPrefix + skin, skin]) {
			skinPostfix = getNoteSkinPostfix();
			checkSkin = path + skinPostfix;
			
			if (!Paths.fileExists('images/$checkSkin.png', IMAGE)) {
				skinPostfix = '';
				checkSkin = path;
			}
			
			if (Paths.fileExists('images/$checkSkin.png', IMAGE)) {
				validSkin = path;
				break;
			}
		}
		
		if (validSkin != null) {
			var actualSkin:String = '$validSkin$skinPostfix';
			loadedTexture = actualSkin;
			skinConfig = NoteSkinData.getNoteConfigForImage(actualSkin);
			
			if (PlayState.isPixelStage) {
				if(isSustainNote) {
					loadGraphic(Paths.image(getPixelSustainSkinPath(validSkin, skinPostfix)));
					width = width / 4;
					height = height / 2;
					loadGraphic(graphic, true, Math.floor(width), Math.floor(height));
				} else {
					loadGraphic(Paths.image(actualSkin));
					width = width / 4;
					height = height / 5;
					loadGraphic(graphic, true, Math.floor(width), Math.floor(height));
				}
				loadPixelNoteAnims();
				antialiasing = false;
				
				scale.set(PlayState.daPixelZoom, PlayState.daPixelZoom);
			} else {
				frames = Paths.getSparrowAtlas(actualSkin);
				loadNoteAnims();
				if(!isSustainNote)
				{
					centerOffsets();
					centerOrigin();
				}
			}
			
			updateHitbox();
			applyNoteSkinOffsets();
			applyNoteSkinProperties();

			if (animName != null)
				animation.play(animName, true);
			applyRGBOverride();
		}
	}

	static function getPixelSustainSkinPath(validSkin:String, skinPostfix:String):String
	{
		var candidates:Array<String> = [];
		candidates.push('${validSkin}ENDS$skinPostfix');

		var slash:Int = validSkin.lastIndexOf('/');
		var folder:String = slash >= 0 ? validSkin.substr(0, slash + 1) : '';
		var file:String = slash >= 0 ? validSkin.substr(slash + 1) : validSkin;
		if (file.startsWith('NOTE_assets-'))
			candidates.push(folder + 'NOTE_assetsENDS-' + file.substr('NOTE_assets-'.length));
		candidates.push('${validSkin}ENDS');

		for (candidate in candidates)
			if (Paths.fileExists('images/$candidate.png', IMAGE))
				return candidate;
		return candidates[0];
	}

	public static function getNoteSkinPostfix()
	{
		var skin:String = '';
		if(ClientPrefs.data.noteSkin != ClientPrefs.defaultData.noteSkin)
			skin = '-' + ClientPrefs.data.noteSkin.trim().toLowerCase().replace(' ', '_');
		return skin;
	}

	function loadNoteAnims() {
		if (colArray[noteData] == null)
			return;

		if (isSustainNote)
		{
			var endFPS:Int = NoteSkinData.getFPS(skinConfig, 'sustain_end', 24);
			var sustainFPS:Int = NoteSkinData.getFPS(skinConfig, 'sustain', 24);
			attemptToAddAnimationByPrefix('purpleholdend', 'pruple end hold', endFPS, true); // this fixes some retarded typo from the original note .FLA
			animation.addByPrefix(colArray[noteData] + 'holdend', colArray[noteData] + ' hold end', endFPS, true);
			animation.addByPrefix(colArray[noteData] + 'hold', colArray[noteData] + ' hold piece', sustainFPS, true);
		}
		else animation.addByPrefix(colArray[noteData] + 'Scroll', colArray[noteData] + '0', NoteSkinData.getFPS(skinConfig, 'notes', 24));

		setGraphicSize(Std.int(width * 0.7));
		updateHitbox();
	}

	function loadPixelNoteAnims() {
		if (colArray[noteData] == null)
			return;

		if(isSustainNote)
		{
			animation.add(colArray[noteData] + 'holdend', [noteData + 4], NoteSkinData.getFPS(skinConfig, 'sustain_end', 24), true);
			animation.add(colArray[noteData] + 'hold', [noteData], NoteSkinData.getFPS(skinConfig, 'sustain', 24), true);
		} else animation.add(colArray[noteData] + 'Scroll', [noteData + 4], NoteSkinData.getFPS(skinConfig, 'notes', 24), true);
	}

	function attemptToAddAnimationByPrefix(name:String, prefix:String, framerate:Float = 24, doLoop:Bool = true)
	{
		var animFrames = [];
		@:privateAccess
		animation.findByPrefix(animFrames, prefix); // adds valid frames to animFrames
		if(animFrames.length < 1) return;

		animation.addByPrefix(name, prefix, framerate, doLoop);
	}

	public function applyNoteSkinOffsets():Void
	{
		if (noteData < 0)
			return;

		offsetX -= skinOffsetX;
		offsetY -= skinOffsetY;
		offsetAngle -= skinOffsetAngle;

		var type:String = isSustainNote ? (isSustainEnd ? 'sustain_end' : 'sustain') : 'notes';
		var skinOffset:NoteSkinOffset = NoteSkinData.getOffset(skinConfig, type, noteData);
		skinOffsetX = skinOffset.x;
		skinOffsetY = skinOffset.y;
		skinOffsetAngle = skinOffset.angle;

		offsetX += skinOffsetX;
		offsetY += skinOffsetY;
		offsetAngle += skinOffsetAngle;
	}

	function applyNoteSkinProperties():Void
	{
		NoteSkinData.applyPropertiesToNote(this, skinConfig);
		applyRGBOverride();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (mustPress)
		{
			canBeHit = (strumTime > Conductor.songPosition - (Conductor.safeZoneOffset * lateHitMult) &&
						strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult));
		}
		else
		{
			canBeHit = false;

			if (!wasGoodHit && strumTime <= Conductor.songPosition)
			{
				if(!isSustainNote || (prevNote.wasGoodHit && !ignoreNote))
					wasGoodHit = true;
			}
		}

		if (tooLate && !inEditor)
		{
			if (alpha > 0.3)
				alpha = 0.3;
		}
	}

	public function followStrumNote(myStrum:StrumNote, songSpeed:Float = 1)
	{
		var noteSpeed:Float = songSpeed * multSpeed;
		var strumDir:Float = myStrum.direction;
		
		distance = getDistance(strumTime - Conductor.songPosition, noteSpeed);
		var scrollMult:Int = (myStrum.downScroll ? -1 : 1);
		
		if(copyAlpha)
			alpha = myStrum.alpha * multAlpha;
		
		var angleDir:Float = strumDir * Math.PI / 180;
		if(copyX)
			x = myStrum.x + offsetX + Math.cos(angleDir) * distance;
		if(copyY)
			y = myStrum.y + offsetY + Math.sin(angleDir) * distance * scrollMult;
		if (copyAngle)
			angle = (isSustainNote ? strumDir - 90 : myStrum.angle) + offsetAngle;
		
		if (isSustainNote)
			updateSustain(myStrum, noteSpeed);
	}
	public function updateSustain(myStrum:StrumNote, noteSpeed:Float = 1) {
		if (!isSustainEnd) {
			var sustainScaleY:Float = Note.getDistance(sustainLength, noteSpeed) / frameHeight; // PROVAVELMENTE otimiza principalmente no mily mc 
			scale.y = sustainScaleY;

			if (_lastSustainScaleY != sustainScaleY || _lastSustainFrameHeight != frameHeight) {
				_lastSustainScaleY = sustainScaleY;
				_lastSustainFrameHeight = frameHeight;
				updateHitbox();
			}
		}
		origin.set(frameWidth * .5, 0);
		offset.set();
		
		flipX = myStrum.downScroll;
		x += (myStrum.width - frameWidth) * .5;
		y += myStrum.height * .5;
		if (myStrum.downScroll)
			angle = 180 - angle;
	}
	public static function getDistance(time:Float, speed:Float) {
		return (0.45 * time * speed);
	}

	public function clipToStrumNote(myStrum:StrumNote)
	{
		if ((mustPress || !ignoreNote) && wasGoodHit) {
			var clipDistance:Float = Math.max(-distance, 0);
			clipRect ??= new FlxRect(0, 0, frameWidth);
			
			clipRect.y = clipDistance / scale.y;
			clipRect.height = frameHeight - clipRect.y;
			
			clipRect = clipRect;
		}
	}

	override public function isOnScreen(?camera:FlxCamera):Bool
	{
		if(camera == null)
			camera = getDefaultCamera();

		var playState:PlayState = PlayState.instance;
		if(ClientPrefs.data.downScroll && !inEditor && playState != null && camera == playState.camHUD)
			return PsychCamera.containsRectWithPadding(camera, getScreenBounds(_rect, camera), playState.getDownscrollNoteCullPadding(this));

		return super.isOnScreen(camera);
	}

	@:noCompletion
	override function set_clipRect(rect:FlxRect):FlxRect
	{
		clipRect = rect;

		if (frames != null)
			frame = frames.frames[animation.frameIndex];

		return rect;
	}
}
