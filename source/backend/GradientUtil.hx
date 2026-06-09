package backend;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxTween.FlxTweenType;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import openfl.display.BitmapData;

/**
yar lost pal?

yeah, me too.

me?

i'm just the coder.

i coded a monster called gradientUtil because i could not port funkinSprite for now soooooooo uuuuuhmmmmmmm sorry for the mess

**/

class GradientUtil
{
	public static var spriteData:Map<FlxSprite, GradientData> = [];

	public static function makeGraphic(width:Int = 256, height:Int = 256, colors:Dynamic = null, ?alphas:Dynamic = null, rotation:Int = 90,
			chunkSize:Int = 1, interpolate:Bool = true):FlxGraphic
	{
		width = Std.int(Math.max(1, width));
		height = Std.int(Math.max(1, height));
		chunkSize = Std.int(Math.max(1, chunkSize));

		var parsedColors:Array<FlxColor> = parseColors(colors, alphas);
		var key:String = cacheKey(width, height, parsedColors, rotation, chunkSize, interpolate);
		var cached = FlxG.bitmap.get(key);
		if(cached != null)
			return cached;

		return FlxG.bitmap.add(makeBitmap(width, height, parsedColors, rotation, chunkSize, interpolate), false, key);
	}

	public static function makeBitmap(width:Int = 256, height:Int = 256, colors:Dynamic = null, ?alphas:Dynamic = null, rotation:Int = 90,
			chunkSize:Int = 1, interpolate:Bool = true):BitmapData
	{
		return FlxGradient.createGradientBitmapData(Std.int(Math.max(1, width)), Std.int(Math.max(1, height)), parseColors(colors, alphas),
			Std.int(Math.max(1, chunkSize)), rotation, interpolate);
	}

	public static function applyToSprite(sprite:FlxSprite, width:Int = 256, height:Int = 256, colors:Dynamic = null, ?alphas:Dynamic = null,
			rotation:Int = 90, chunkSize:Int = 1, interpolate:Bool = true):Bool
	{
		if(sprite == null)
			return false;

		sprite.loadGraphic(makeGraphic(width, height, colors, alphas, rotation, chunkSize, interpolate));
		spriteData.set(sprite, {
			width: Std.int(Math.max(1, width)),
			height: Std.int(Math.max(1, height)),
			colors: parseColors(colors, alphas),
			rotation: rotation,
			chunkSize: Std.int(Math.max(1, chunkSize)),
			interpolate: interpolate
		});
		return true;
	}

	public static function tweenSprite(sprite:FlxSprite, toColors:Dynamic = null, ?toAlphas:Dynamic = null, duration:Float = 1, ease:Dynamic = null,
		?onComplete:FlxTween->Void):FlxTween
	{
		if(sprite == null)
			return null;

		var data:GradientData = spriteData.get(sprite);
		if(data == null)
		{
			var width:Int = Std.int(Math.max(1, sprite.width));
			var height:Int = Std.int(Math.max(1, sprite.height));
			applyToSprite(sprite, width, height, toColors, toAlphas);
			data = spriteData.get(sprite);
			if(data == null)
				return null;
		}

		var fromColors:Array<FlxColor> = data.colors.copy();
		var targetColors:Array<FlxColor> = matchStopCount(parseColors(toColors, toAlphas), fromColors.length);
		FlxTween.cancelTweensOf(data);

		return FlxTween.num(0, 1, duration, {
			ease: ease,
			onComplete: function(twn:FlxTween) {
				data.colors = targetColors.copy();
				if(twn.type == FlxTweenType.ONESHOT || twn.type == FlxTweenType.BACKWARD)
					renderData(sprite, data);
				if(onComplete != null)
					onComplete(twn);
			}
		}, function(value:Float) {
			data.colors = interpolateColors(fromColors, targetColors, value);
			renderData(sprite, data);
		});
	}

	public static function tweenSpriteAlpha(sprite:FlxSprite, toAlphas:Dynamic = null, duration:Float = 1, ease:Dynamic = null,
			?onComplete:FlxTween->Void):FlxTween
	{
		var data:GradientData = spriteData.get(sprite);
		if(data == null || sprite == null)
			return null;

		var targetColors:Array<FlxColor> = data.colors.copy();
		var alphas:Array<Dynamic> = asArray(toAlphas);
		for(i in 0...targetColors.length)
		{
			var alpha:Null<Float> = alphas.length > i ? parseAlpha(alphas[i]) : (alphas.length > 0 ? parseAlpha(alphas[0]) : null);
			if(alpha != null)
				targetColors[i].alphaFloat = alpha;
		}
		return tweenSprite(sprite, targetColors, null, duration, ease, onComplete);
	}

	public static function setStop(sprite:FlxSprite, index:Int, ?color:Dynamic = null, ?alpha:Dynamic = null):Bool
	{
		var data:GradientData = spriteData.get(sprite);
		if(data == null || index < 0 || index >= data.colors.length)
			return false;

		var stop:FlxColor = color == null ? data.colors[index] : parseColorStop(color);
		var alphaValue:Null<Float> = alpha != null ? parseAlpha(alpha) : alphaFromStop(color);
		if(alphaValue != null)
			stop.alphaFloat = alphaValue;
		data.colors[index] = stop;
		renderData(sprite, data);
		return true;
	}

	static function parseColors(colors:Dynamic, ?alphas:Dynamic):Array<FlxColor>
	{
		var rawColors:Array<Dynamic> = asArray(colors);
		var rawAlphas:Array<Dynamic> = asArray(alphas);
		var parsed:Array<FlxColor> = [];

		for(i in 0...rawColors.length)
		{
			var color:FlxColor = parseColorStop(rawColors[i]);
			var alphaValue:Null<Float> = null;

			if(rawAlphas.length > i)
				alphaValue = parseAlpha(rawAlphas[i]);
			else
				alphaValue = alphaFromStop(rawColors[i]);

			if(alphaValue != null)
				color.alphaFloat = alphaValue;

			parsed.push(color);
		}

		if(parsed.length == 0)
			parsed = [FlxColor.WHITE, FlxColor.BLACK];
		else if(parsed.length == 1)
			parsed.push(parsed[0]);

		return parsed;
	}

	static function renderData(sprite:FlxSprite, data:GradientData):Void
	{
		if(sprite != null && data != null)
			sprite.loadGraphic(makeGraphic(data.width, data.height, data.colors, null, data.rotation, data.chunkSize, data.interpolate));
	}

	static function matchStopCount(colors:Array<FlxColor>, count:Int):Array<FlxColor>
	{
		if(count < 1)
			count = 1;
		if(colors.length == 0)
			colors = [FlxColor.WHITE, FlxColor.BLACK];

		var matched:Array<FlxColor> = [];
		for(i in 0...count)
		{
			var colorIndex:Int = colors.length == 1 ? 0 : Std.int(Math.round((i / Math.max(1, count - 1)) * (colors.length - 1)));
			matched.push(colors[colorIndex]);
		}
		return matched;
	}

	static function interpolateColors(fromColors:Array<FlxColor>, toColors:Array<FlxColor>, amount:Float):Array<FlxColor>
	{
		amount = FlxMath.bound(amount, 0, 1);
		var colors:Array<FlxColor> = [];
		for(i in 0...fromColors.length)
		{
			var from:FlxColor = fromColors[i];
			var to:FlxColor = toColors[i];
			colors.push(FlxColor.fromRGBFloat(
				FlxMath.lerp(from.redFloat, to.redFloat, amount),
				FlxMath.lerp(from.greenFloat, to.greenFloat, amount),
				FlxMath.lerp(from.blueFloat, to.blueFloat, amount),
				FlxMath.lerp(from.alphaFloat, to.alphaFloat, amount)
			));
		}
		return colors;
	}

	static function parseColorStop(value:Dynamic):FlxColor
	{
		if(value == null)
			return FlxColor.WHITE;

		if(Std.isOfType(value, Int))
			return cast value;

		if(Std.isOfType(value, Array))
		{
			var array:Array<Dynamic> = cast value;
			if(array.length >= 3)
			{
				var color:FlxColor = FlxColor.fromRGB(clampByte(array[0]), clampByte(array[1]), clampByte(array[2]));
				if(array.length >= 4)
					color.alphaFloat = parseAlpha(array[3]) ?? 1;
				return color;
			}
			if(array.length > 0)
				return parseColorStop(array[0]);
		}

		for(field in ['color', 'hex', 'value'])
		{
			var fieldValue:Dynamic = Reflect.field(value, field);
			if(fieldValue != null)
				return parseColorStop(fieldValue);
		}

		return CoolUtil.colorFromString(Std.string(value));
	}

	static function alphaFromStop(value:Dynamic):Null<Float>
	{
		if(value == null)
			return null;

		if(Std.isOfType(value, Array))
		{
			var array:Array<Dynamic> = cast value;
			if(array.length >= 4)
				return parseAlpha(array[3]);
		}

		for(field in ['alpha', 'a'])
		{
			var fieldValue:Dynamic = Reflect.field(value, field);
			if(fieldValue != null)
				return parseAlpha(fieldValue);
		}

		return null;
	}

	static function asArray(value:Dynamic):Array<Dynamic>
	{
		if(value == null)
			return [];
		if(Std.isOfType(value, Array))
			return cast value;
		return [value];
	}

	static function parseAlpha(value:Dynamic):Null<Float>
	{
		if(value == null)
			return null;

		var alpha:Float = Std.parseFloat(Std.string(value));
		if(Math.isNaN(alpha))
			return null;
		if(alpha > 1)
			alpha /= 255;
		return FlxMath.bound(alpha, 0, 1);
	}

	static inline function clampByte(value:Dynamic):Int
		return Std.int(FlxMath.bound(Std.parseInt(Std.string(value)) ?? 0, 0, 255));

	static function cacheKey(width:Int, height:Int, colors:Array<FlxColor>, rotation:Int, chunkSize:Int, interpolate:Bool):String
	{
		var parts:Array<String> = ['gradient', Std.string(width), Std.string(height), Std.string(rotation), Std.string(chunkSize), Std.string(interpolate)];
		for(color in colors)
			parts.push(StringTools.hex(cast color, 8));
		return parts.join(':');
	}
}

typedef GradientData =
{
	var width:Int;
	var height:Int;
	var colors:Array<FlxColor>;
	var rotation:Int;
	var chunkSize:Int;
	var interpolate:Bool;
}
// IT ENDED