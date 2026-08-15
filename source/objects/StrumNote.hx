package objects;

import backend.animation.PsychAnimationController;

import shaders.RGBPalette;
import shaders.RGBPalette.RGBShaderReference;
import objects.NoteSkinData.NoteSkinConfig;

class StrumNote extends FlxSprite
{
	public var rgbShader:RGBShaderReference;
	public var resetAnim:Float = 0;
	public var noteData(default, null):Int = 0;
	public var direction:Float = 90;
	public var downScroll:Bool = false;
	public var sustainReduce:Bool = true;
	private var player:Int;
	
	public var loadedTexture:String = null;
	public var texture(default, set):String = null;
	public var skinConfig:NoteSkinConfig = null;
	public var skinOffsetAngle:Float = 0;
	public var rgbOverrideR:Null<FlxColor> = null;
	public var rgbOverrideG:Null<FlxColor> = null;
	public var rgbOverrideB:Null<FlxColor> = null;
	public var pressedRGBR:Null<FlxColor> = null;
	public var pressedRGBG:Null<FlxColor> = null;
	public var pressedRGBB:Null<FlxColor> = null;
	private function set_texture(value:String):String {
		if(texture != value) {
			texture = value;
			reloadNote(value);
		}
		return value;
	}

	public var useRGBShader(default, set):Bool = true;
	public function new(x:Float, y:Float, leData:Int, player:Int) {
		animation = new PsychAnimationController(this);

		rgbShader = new RGBShaderReference(this, Note.initializeGlobalRGBShader(leData));
		rgbShader.enabled = false;
		if(PlayState.SONG != null && PlayState.SONG.disableNoteRGB) setRGBAllowed(false);
		
		var arr:Array<FlxColor> = ClientPrefs.data.arrowRGB[leData];
		if(PlayState.isPixelStage) arr = ClientPrefs.data.arrowRGBPixel[leData];
		
		if(leData <= arr.length)
		{
			@:bypassAccessor
			{
				rgbShader.r = arr[0];
				rgbShader.g = arr[1];
				rgbShader.b = arr[2];
			}
		}

		noteData = leData;
		this.player = player;
		this.noteData = leData;
		this.ID = noteData;
		super(x, y);
		
		var skin:String = null;
		if (PlayState.SONG != null && PlayState.SONG.arrowSkin != null && PlayState.SONG.arrowSkin.length > 1) skin = PlayState.SONG.arrowSkin;
		else skin = Note.defaultNoteSkin;
		skin = Note.resolveNoteSkinPath(skin, player);

		var customSkin:String = skin + Note.getNoteSkinPostfix();
		if (Paths.fileExists('images/$customSkin.png', IMAGE)) {
			skin = customSkin;
		} else {
			skin = '';
		}
		
		texture = skin;
		scrollFactor.set();
		playAnim('static');
	}

	public function setRGBOverride(color:Null<FlxColor>):Void
	{
		setRGBPalette(color, color, color);
	}

	public function setRGBPalette(r:Null<FlxColor>, g:Null<FlxColor>, b:Null<FlxColor>):Void
	{
		rgbOverrideR = r;
		rgbOverrideG = g;
		rgbOverrideB = b;
		if (!hasRGBOverride())
			applyDefaultRGB();
		else
		{
			setRGBAllowed(true, false);
			applyRGBOverride();
		}
	}

	public function setRGBAllowed(value:Bool, clearOverride:Bool = true):Void
	{
		useRGBShader = value;
		if (!value && clearOverride)
			clearRGBOverride();

		if (value)
		{
			if (animation?.curAnim != null)
				rgbShader.enabled = true;
			if (hasRGBOverride())
				applyRGBOverride();
			else
				applyDefaultRGB();
		}
		else
			rgbShader.enabled = false;
	}

	function set_useRGBShader(value:Bool):Bool
	{
		useRGBShader = value;
		if (!value && rgbShader != null)
			rgbShader.enabled = false;
		return value;
	}

	public function applyRGBOverride():Bool
	{
		if (!hasRGBOverride())
			return false;

		rgbShader.enabled = true;
		if (rgbOverrideR != null) rgbShader.r = rgbOverrideR;
		if (rgbOverrideG != null) rgbShader.g = rgbOverrideG;
		if (rgbOverrideB != null) rgbShader.b = rgbOverrideB;
		return true;
	}

	public inline function hasRGBOverride():Bool
		return rgbOverrideR != null || rgbOverrideG != null || rgbOverrideB != null;

	public function clearRGBOverride():Void
	{
		rgbOverrideR = null;
		rgbOverrideG = null;
		rgbOverrideB = null;
	}

	public function setPressedRGBPalette(r:Null<FlxColor>, g:Null<FlxColor>, b:Null<FlxColor>):Void
	{
		pressedRGBR = r;
		pressedRGBG = g;
		pressedRGBB = b;
		if (useRGBShader && !hasRGBOverride() && animation?.curAnim != null && animation.curAnim.name != 'static')
			applyStateRGB();
	}

	function applyDefaultRGB():Void
	{
		var arr:Array<FlxColor> = ClientPrefs.data.arrowRGB[noteData];
		if(PlayState.isPixelStage) arr = ClientPrefs.data.arrowRGBPixel[noteData];

		if(arr != null && noteData <= arr.length)
		{
			rgbShader.r = arr[0];
			rgbShader.g = arr[1];
			rgbShader.b = arr[2];
		}
	}

	function applyStateRGB():Void
	{
		if (animation?.curAnim != null && animation.curAnim.name != 'static')
		{
			if (pressedRGBR != null && pressedRGBG != null && pressedRGBB != null)
			{
				rgbShader.r = pressedRGBR;
				rgbShader.g = pressedRGBG;
				rgbShader.b = pressedRGBB;
			}
			else
				applyDefaultRGB();
		}
		else if (!PlayState.isPixelStage)
		{
			rgbShader.r = 0x87A3AD;
			rgbShader.g = 0xFFFFFFFF;
			rgbShader.b = 0x00000000;
		}
		else
		{
			rgbShader.r = 0xA2BAC8;
			rgbShader.g = 0xFFFFFFFF;
			rgbShader.b = 0x404047;
		}
	}

	public function reloadNote(texture:String = '', postfix:String = '') {
		var skin:String = texture + postfix;
		
		if (texture.length < 1) {
			skin = PlayState.SONG != null ? PlayState.SONG.arrowSkin : null;
			if (skin == null || skin.length < 1)
				skin = Note.defaultNoteSkin + postfix;
		}
		skin = Note.resolveNoteSkinPath(skin, player);
		
		var lastAnim:String = animation.curAnim?.name;
		
		var skinPostfix:String = '';
		var checkSkin:String = '';
		var validSkin:String = null;
		
		for (path in [PlayState.uiPrefix + skin, skin]) {
			skinPostfix = Note.getNoteSkinPostfix();
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
			if (loadedTexture == actualSkin && frames != null)
			{
				skinConfig = NoteSkinData.getNoteConfigForImage(actualSkin);
				NoteSkinData.applyPropertiesToStrum(this, skinConfig);
				if (lastAnim != null)
					playAnim(lastAnim, true);
				return;
			}
			loadedTexture = actualSkin;
			skinConfig = NoteSkinData.getNoteConfigForImage(actualSkin);
			
			var data:Int = Std.int(Math.abs(noteData) % 4);

			if (PlayState.isPixelStage) {
				loadGraphic(Paths.image(actualSkin));
				width = (width / 4);
				height = (height / 5);
				loadGraphic(graphic, true, Math.floor(width), Math.floor(height));
				
				antialiasing = false;
				setGraphicSize(Std.int(width * PlayState.daPixelZoom));
				
				animation.add('static', [data]);
				animation.add('green', [6]);
				animation.add('red', [7]);
				animation.add('blue', [5]);
				animation.add('purple', [4]);
				animation.add('pressed', [data + 4, data + 8], NoteSkinData.getFPS(skinConfig, 'press', 12), false);
				animation.add('confirm', [data + 12, data + 16], NoteSkinData.getFPS(skinConfig, 'confirm', 12), false);
			} else {
				frames = Paths.getSparrowAtlas(actualSkin);
				animation.addByPrefix('green', 'arrowUP');
				animation.addByPrefix('blue', 'arrowDOWN');
				animation.addByPrefix('purple', 'arrowLEFT');
				animation.addByPrefix('red', 'arrowRIGHT');

				antialiasing = ClientPrefs.data.antialiasing;
				setGraphicSize(Std.int(width * 0.7));
				
				var name:String = (Note.dirArray[data] ?? 'down');
				animation.addByPrefix('static', 'arrow${name.toUpperCase()}');
				animation.addByPrefix('pressed', '$name press', NoteSkinData.getFPS(skinConfig, 'press', 24), false);
				animation.addByPrefix('confirm', '$name confirm', NoteSkinData.getFPS(skinConfig, 'confirm', 24), false);
			}
			NoteSkinData.applyBitmapSize(this, skinConfig, 'static');
			updateHitbox();
			NoteSkinData.applyPropertiesToStrum(this, skinConfig);
			if (PlayState.isPixelStage)
				antialiasing = false;

			if (lastAnim != null)
				playAnim(lastAnim, true);
			applyRGBOverride();
		}
	}

	public function playerPosition()
	{
		x += Note.swagWidth * noteData;
		x += 50;
		x += ((FlxG.width / 2) * player);
	}

	override function update(elapsed:Float) {

        if(!ClientPrefs.data.opaqueSustains) 
		{
			if(animation.curAnim != null && animation.curAnim.name != 'static' && animation.curAnim.name != 'pressed')
			{
				alpha = 1;
			}
			else
			{
				alpha = 0.8;
			}
        }
		else
		{
			if(animation.curAnim != null && animation.curAnim.name != 'static' && animation.curAnim.name != 'pressed')
			{
				alpha = 1;
			}
			else
			{
				alpha = 1;
			}
		}

        if(resetAnim > 0) {
            resetAnim -= elapsed;
            if(resetAnim <= 0) {
                playAnim('static');
                resetAnim = 0;
            }
        }
		if(useRGBShader){
			if (!applyRGBOverride())
				applyStateRGB();
		}
		else if (rgbShader != null)
			rgbShader.enabled = false;
        super.update(elapsed);
    }

	public function playAnim(anim:String, ?force:Bool = false) {
		animation.play(anim, force);
		if(animation.curAnim != null)
		{
			centerOffsets();
			var pivotType:String = switch (animation.curAnim.name)
			{
				case 'pressed': 'press';
				case 'confirm': 'confirm';
				default: 'static';
			};
			if (!NoteSkinData.applyPivot(this, skinConfig, pivotType))
				centerOrigin();
			NoteSkinData.applyStrumOffset(this, animation.curAnim.name, skinConfig);
		}
		if (useRGBShader) {
			rgbShader.enabled = (animation.curAnim != null);
			if (!applyRGBOverride())
				applyStateRGB();
		}
		else
			rgbShader.enabled = false;
	}
}
