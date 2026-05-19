package objects;

import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.geom.Matrix;

class HealthIcon extends FlxSprite
{
	public static inline final ICON_SIZE:Float = 150;
	static inline final PIXEL_ICON_SOURCE_WIDTH:Int = 64;
	static inline final PIXEL_ICON_SOURCE_HEIGHT:Int = 32;

	public var sprTracker:FlxSprite;
	private var isPlayer:Bool = false;
	private var char:String = '';

	public function new(char:String = 'face', isPlayer:Bool = false, ?allowGPU:Bool = true)
	{
		super();
		this.isPlayer = isPlayer;
		changeIcon(char, allowGPU);
		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);
	}

	private var iconOffsets:Array<Float> = [0, 0];
	static function upscalePixelIconGraphic(key:String, graphic:FlxGraphic, allowGPU:Bool):FlxGraphic
	{
		if(graphic == null || graphic.width != PIXEL_ICON_SOURCE_WIDTH || graphic.height != PIXEL_ICON_SOURCE_HEIGHT || graphic.bitmap == null)
			return graphic;

		var scaledKey:String = 'pixel-health-icon:$key';
		if(Paths.currentTrackedAssets.exists(scaledKey))
			return Paths.currentTrackedAssets.get(scaledKey);

		var bitmap:BitmapData = new BitmapData(Std.int(ICON_SIZE * 2), Std.int(ICON_SIZE), true, 0x00000000);
		var matrix:Matrix = new Matrix(bitmap.width / graphic.bitmap.width, 0, 0, bitmap.height / graphic.bitmap.height);
		bitmap.draw(graphic.bitmap, matrix, null, null, null, false);
		return Paths.cacheBitmap(scaledKey, null, bitmap, allowGPU);
	}

	public function changeIcon(char:String, ?allowGPU:Bool = true) {
		if(char == null || char.length < 1) char = 'face';
		if(this.char != char) {
			if(Character.isNoneCharacter(char))
			{
				makeGraphic(1, 1, 0x00000000);
				iconOffsets[0] = 0;
				iconOffsets[1] = 0;
				updateHitbox();
				animation.add(char, [0], 0, false, isPlayer);
				animation.play(char);
				this.char = char;
				antialiasing = false;
				return;
			}

			var name:String = 'icons/' + char;
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-' + char; //Older versions of psych engine's support
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-face'; //Prevents crash from missing icon
			
			var graphic = Paths.image(name, allowGPU);
			var isSmallPixelIcon:Bool = graphic != null && graphic.width == PIXEL_ICON_SOURCE_WIDTH && graphic.height == PIXEL_ICON_SOURCE_HEIGHT;
			if(isSmallPixelIcon)
				graphic = upscalePixelIconGraphic(name, graphic, allowGPU);
			var iSize:Float = Math.round(graphic.width / graphic.height);
			loadGraphic(graphic, true, Math.floor(graphic.width / iSize), Math.floor(graphic.height));
			iconOffsets[0] = (width - 150) / iSize;
			iconOffsets[1] = (height - 150) / iSize;
			updateHitbox();

			animation.add(char, [for(i in 0...frames.frames.length) i], 0, false, isPlayer);
			animation.play(char);
			this.char = char;

			if(isSmallPixelIcon || char.endsWith('-pixel'))
				antialiasing = false;
			else
				antialiasing = ClientPrefs.data.antialiasing;
		}
	}

	public var autoAdjustOffset:Bool = true;
	override function updateHitbox()
	{
		super.updateHitbox();
		if(autoAdjustOffset)
		{
			offset.x = iconOffsets[0];
			offset.y = iconOffsets[1];
		}
	}

	public function centerIconOrigin():Void
	{
		origin.set(ICON_SIZE * 0.5, ICON_SIZE * 0.5);
	}

	public function getIconDisplayWidth():Float
	{
		return ICON_SIZE * Math.abs(scale.x);
	}

	public function getIconDisplayHeight():Float
	{
		return ICON_SIZE * Math.abs(scale.y);
	}

	public function centerIconOn(x:Float, y:Float):Void
	{
		updateHitbox();
		centerIconOrigin();
		setPosition(x - getIconDisplayWidth() * 0.5, y - getIconDisplayHeight() * 0.5);
	}

	public function getIconFrameCount():Int
	{
		return (animation.curAnim != null) ? animation.curAnim.numFrames : 0;
	}

	public function setIconFrame(frame:Int):Void
	{
		var total:Int = getIconFrameCount();
		if(total < 1)
			return;

		animation.curAnim.curFrame = Std.int(FlxMath.wrap(frame, 0, total - 1));
	}

	public function getCharacter():String {
		return char;
	}
}
