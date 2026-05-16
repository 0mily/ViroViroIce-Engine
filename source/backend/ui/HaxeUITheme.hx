package backend.ui; //aé

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;

class HaxeUITheme
{
	public static inline final PURPLE:FlxColor = 0xFF8A5CFF;
	public static inline final PURPLE_TOP:FlxColor = 0xFFA883FF;
	public static inline final PURPLE_BOTTOM:FlxColor = 0xFF5D3BB8;
	public static inline final PURPLE_DARK:FlxColor = 0xFF6847C7;
	public static inline final PURPLE_DARK_TOP:FlxColor = 0xFF8060E0;
	public static inline final PURPLE_DARK_BOTTOM:FlxColor = 0xFF4B3199;
	public static inline final BG:FlxColor = 0xFF21172B;
	public static inline final BG_BOTTOM:FlxColor = 0xFF181020;
	public static inline final PANEL:FlxColor = 0xFF332346;
	public static inline final PANEL_BOTTOM:FlxColor = 0xFF24182F;
	public static inline final PANEL_LIGHT:FlxColor = 0xFF4B3670;
	public static inline final PANEL_LIGHT_TOP:FlxColor = 0xFF6A5192;
	public static inline final PANEL_LIGHT_BOTTOM:FlxColor = 0xFF382752;
	public static inline final TEXT:FlxColor = 0xFFEDEAF8;
	public static inline final TEXT_MUTED:FlxColor = 0xFFD6C9F4;
	public static inline final OUTLINE:FlxColor = 0xFF6D5799;
	public static inline final BLACK:FlxColor = 0xFF140E1D;
	public static inline final INPUT_FILL:FlxColor = 0xFFEFE6FF;
	public static inline final INPUT_TEXT:FlxColor = 0xFF12091E;
	public static inline final SELECTION:FlxColor = 0xFF8A5CFF;
	public static inline final RADIUS:Int = 6;
	public static inline final BORDER:Int = 2;
	public static function applyText(text:FlxText, ?size:Int = -1):FlxText
	{
		return text;
	}

	public static inline function snap(value:Float):Float
		return Math.floor(value + 0.5);

	public static function drawRoundedBox(sprite:FlxSprite, width:Float, height:Float, fillColor:FlxColor, alpha:Float = 1, radius:Int = RADIUS,
			borderColor:FlxColor = BLACK, borderSize:Int = BORDER, ?gradientBottom:Null<FlxColor>):FlxSprite
	{
		var w:Int = Std.int(Math.max(1, Math.ceil(width)));
		var h:Int = Std.int(Math.max(1, Math.ceil(height)));
		var r:Int = Std.int(Math.min(radius * 2, Math.min(w, h)));
		var topColor:FlxColor = terDegradCima(fillColor);
		var bottomColor:Null<FlxColor> = gradientBottom != null ? gradientBottom : terDegradBaixo(fillColor);

		sprite.makeGraphic(w, h, FlxColor.TRANSPARENT, true);
		sprite.color = FlxColor.WHITE;
		sprite.alpha = alpha;

		if(borderSize > 0)
		{
			FlxSpriteUtil.drawRoundRect(sprite, 0, 0, w, h, r, r, borderColor); // é tipo o local de lua!!!

			var innerW:Float = Math.max(1, w - borderSize * 2);
			var innerH:Float = Math.max(1, h - borderSize * 2);
			var innerR:Int = Std.int(Math.max(0, r - borderSize * 2));
			if(bottomColor != null)
				fazerBctRedondo(sprite, borderSize, borderSize, innerW, innerH, innerR, topColor, bottomColor);
			else
				FlxSpriteUtil.drawRoundRect(sprite, borderSize, borderSize, innerW, innerH, innerR, innerR, fillColor);
		}
		else if(bottomColor != null)
			fazerBctRedondo(sprite, 0, 0, w, h, r, topColor, bottomColor);
		else
			FlxSpriteUtil.drawRoundRect(sprite, 0, 0, w, h, r, r, fillColor);

		sprite.updateHitbox();
		return sprite;
	}

	static function terDegradBaixo(fillColor:FlxColor):Null<FlxColor>
	{
		if(fillColor == BG) return BG_BOTTOM;
		if(fillColor == PANEL) return PANEL_BOTTOM;
		if(fillColor == PANEL_LIGHT) return PANEL_LIGHT_BOTTOM;
		if(fillColor == PURPLE) return PURPLE_BOTTOM;
		if(fillColor == PURPLE_DARK) return PURPLE_DARK_BOTTOM;
		return null;
	}

	static function terDegradCima(fillColor:FlxColor):FlxColor
	{
		if(fillColor == PURPLE) return PURPLE_TOP;
		if(fillColor == PURPLE_DARK) return PURPLE_DARK_TOP;
		if(fillColor == PANEL_LIGHT) return PANEL_LIGHT_TOP;
		return fillColor;
	}

	static function fazerBctRedondo(sprite:FlxSprite, x:Float, y:Float, width:Float, height:Float, radius:Int, topColor:FlxColor,
			bottomColor:FlxColor):Void
	{
		var w:Int = Std.int(Math.max(1, Math.ceil(width)));
		var h:Int = Std.int(Math.max(1, Math.ceil(height)));
		var corner:Float = Math.max(0, radius * 0.5);

		for(row in 0...h)
		{
			var ratio:Float = h <= 1 ? 0 : row / (h - 1);
			var inset:Float = otraBct(row, h, corner);
			var drawX:Float = x + inset;
			var drawW:Float = Math.max(1, w - inset * 2);
			FlxSpriteUtil.drawRect(sprite, drawX, y + row, drawW, 1, FlxColor.interpolate(topColor, bottomColor, ratio));
		}
	}

	static function otraBct(row:Int, height:Int, corner:Float):Float
	{
		if(corner <= 0) return 0;

		var offset:Float = -1;
		if(row < corner)
			offset = corner - row - 0.5;
		else if(row >= height - corner)
			offset = row - (height - corner) + 0.5;

		if(offset < 0) return 0;
		return Math.max(0, corner - Math.sqrt(Math.max(0, corner * corner - offset * offset)));
	}
}
