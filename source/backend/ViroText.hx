package backend;

import openfl.text.AntiAliasType;

/**
 * Makin this to be easier then ScriptedText shit
 */
class ViroText extends flixel.text.FlxText
{
	public var pixelText(default, set):Bool = false;
	var requestedAntialiasing:Bool = true;

	public function new(X:Float = 0, Y:Float = 0, FieldWidth:Float = 0, ?Text:String, Size:Int = 8, EmbeddedFont:Bool = true)
	{
		super(X, Y, FieldWidth, Text, Size, EmbeddedFont);
		applyTextRasterization();
	}

	override function set_antialiasing(value:Bool):Bool
	{
		requestedAntialiasing = value;
		var result:Bool = super.set_antialiasing(pixelText ? false : value);
		applyTextRasterization();
		return result;
	}

	function set_pixelText(value:Bool):Bool
	{
		if(pixelText == value)
			return value;

		pixelText = value;
		var result:Bool = super.set_antialiasing(value ? false : requestedAntialiasing);
		applyTextRasterization();
		return value;
	}

	inline function applyTextRasterization():Void
	{
		if(textField == null)
			return;

		textField.antiAliasType = pixelText ? AntiAliasType.ADVANCED : AntiAliasType.NORMAL;
		textField.sharpness = pixelText ? 400 : 100;
	}
}
