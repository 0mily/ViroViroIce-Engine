package backend;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxColor;
import openfl.display.BitmapData;

/*
    Probably a Util to make vignette without a image, directly with coding shit (works better in CamOther, but later on i'll add a better compatibility with camGame and HUD thingie)
*/

class VignetteUtil
{
	public static inline var DEFAULT_RADIUS:Float = 0.55;
	public static inline var DEFAULT_SOFTNESS:Float = 0.45;
	public static inline var DEFAULT_STRENGTH:Float = 1.0;

	public static inline function windowWidth(?fallback:Int = 0):Int
		return ResolutionManager.windowWidth(fallback);

	public static inline function windowHeight(?fallback:Int = 0):Int
		return ResolutionManager.windowHeight(fallback);

	public static inline function windowPixelWidth(?fallback:Int = 0):Int
		return ResolutionManager.windowPixelWidth(fallback);

	public static inline function windowPixelHeight(?fallback:Int = 0):Int
		return ResolutionManager.windowPixelHeight(fallback);

	public static function makeBitmap(width:Int = 0, height:Int = 0, color:FlxColor = FlxColor.BLACK, strength:Float = DEFAULT_STRENGTH,
			radius:Float = DEFAULT_RADIUS, softness:Float = DEFAULT_SOFTNESS):BitmapData
	{
		width = width > 0 ? width : windowWidth();
		height = height > 0 ? height : windowHeight();
		width = Std.int(Math.max(1, width));
		height = Std.int(Math.max(1, height));

		strength = clamp01(strength);
		radius = clamp01(radius);
		softness = Math.max(0.0001, clamp01(softness));

		var colorInt:Int = color;
		var rgb:Int = colorInt & 0x00FFFFFF;
		var sourceAlpha:Int = (colorInt >>> 24) & 0xFF;
		var bitmap = new BitmapData(width, height, true, 0x00000000);
		var halfWidth:Float = width * 0.5;
		var halfHeight:Float = height * 0.5;
		var edge:Float = radius + softness;

		bitmap.lock();
		for(y in 0...height)
		{
			var normalizedY:Float = (y + 0.5 - halfHeight) / halfHeight;
			for(x in 0...width)
			{
				var normalizedX:Float = (x + 0.5 - halfWidth) / halfWidth;
				var distance:Float = Math.sqrt(normalizedX * normalizedX + normalizedY * normalizedY);
				var amount:Float = smoothStep(radius, edge, distance) * strength;
				var alpha:Int = Std.int(Math.round(sourceAlpha * amount));
				if(alpha > 0)
					bitmap.setPixel32(x, y, (alpha << 24) | rgb);
			}
		}
		bitmap.unlock();
		return bitmap;
	}

	public static function makeGraphic(width:Int = 0, height:Int = 0, color:FlxColor = FlxColor.BLACK, strength:Float = DEFAULT_STRENGTH,
			radius:Float = DEFAULT_RADIUS, softness:Float = DEFAULT_SOFTNESS):FlxGraphic
	{
		width = width > 0 ? width : windowWidth();
		height = height > 0 ? height : windowHeight();
		var key:String = cacheKey(width, height, cast color, strength, radius, softness);
		var cached = FlxG.bitmap.get(key);
		if(cached != null)
			return cached;
		return FlxG.bitmap.add(makeBitmap(width, height, color, strength, radius, softness), false, key);
	}

	static inline function clamp01(value:Float):Float
		return value < 0 ? 0 : (value > 1 ? 1 : value);

	static inline function smoothStep(edge0:Float, edge1:Float, value:Float):Float
	{
		var t:Float = clamp01((value - edge0) / (edge1 - edge0));
		return t * t * (3 - 2 * t);
	}

	static function cacheKey(width:Int, height:Int, color:Int, strength:Float, radius:Float, softness:Float):String
	{
		return 'vignette-${width}x${height}-${StringTools.hex(color, 8)}-${floatKey(strength)}-${floatKey(radius)}-${floatKey(softness)}';
	}

	static inline function floatKey(value:Float):Int
		return Std.int(Math.round(value * 1000));
}
