package psychlua;

class ClipFunctions
{
	static function getSprite(tag:String, func:String):FlxSprite
	{
		var obj:Dynamic = LuaUtils.getObjectDirectly(tag);
		if (obj == null)
		{
			FunkinLua.luaTrace('$func: Object $tag doesn\'t exist!', false, false, ERROR);
			return null;
		}

		if (!Std.isOfType(obj, FlxSprite))
		{
			FunkinLua.luaTrace('$func: Object $tag doesn\'t support clipRect!', false, false, ERROR);
			return null;
		}

		return cast obj;
	}

	static function getBounds(tag:String, func:String):FlxObject
	{
		var obj:Dynamic = LuaUtils.getObjectDirectly(tag);
		if (obj == null)
		{
			FunkinLua.luaTrace('$func: Clip object $tag doesn\'t exist!', false, false, ERROR);
			return null;
		}

		if (!Std.isOfType(obj, FlxObject))
		{
			FunkinLua.luaTrace('$func: Clip object $tag doesn\'t have bounds!', false, false, ERROR);
			return null;
		}

		return cast obj;
	}

	static function setClip(sprite:FlxSprite, x:Float, y:Float, width:Float, height:Float):Void
	{
		width = Math.max(0, width);
		height = Math.max(0, height);

		if (sprite.clipRect == null)
			sprite.clipRect = new flixel.math.FlxRect(); // cliprect legal

		sprite.clipRect.set(x, y, width, height);
		sprite.clipRect = sprite.clipRect;
	}

	static function applyRectClip(sprite:FlxSprite, x:Float, y:Float, width:Float, height:Float):Bool
	{
		if (width <= 0 || height <= 0 || sprite.scale.x == 0 || sprite.scale.y == 0)
		{
			setClip(sprite, 0, 0, 0, 0);
			return false;
		}

		var left:Float = Math.max(x, sprite.x);
		var top:Float = Math.max(y, sprite.y);
		var right:Float = Math.min(x + width, sprite.x + sprite.width);
		var bottom:Float = Math.min(y + height, sprite.y + sprite.height);

		if (right <= left || bottom <= top)
		{
			setClip(sprite, 0, 0, 0, 0);
			return false;
		}

		var scaleX:Float = Math.abs(sprite.scale.x);
		var scaleY:Float = Math.abs(sprite.scale.y);
		setClip(sprite, (left - sprite.x) / scaleX, (top - sprite.y) / scaleY, (right - left)/ scaleX, (bottom - top) / scaleY);
		return true;
	}

	public static function implement()
	{
		FunkinLua.registerFunction('setObjectClip', function(tag:String, x:Float = 0, y:Float = 0, width:Float = 0, height:Float = 0) {
			var sprite:FlxSprite = getSprite(tag, 'setObjectClip');
			if (sprite == null)
				return false;

			setClip(sprite, x, y, width, height);
			return true;
		});

		FunkinLua.registerFunction('clipObjectToRect', function(tag:String, x:Float = 0, y:Float = 0, width:Float = 0, height:Float = 0) {
			var sprite:FlxSprite = getSprite(tag, 'clipObjectToRect');
			return sprite != null && applyRectClip(sprite, x, y, width, height);
		});

		FunkinLua.registerFunction('clipObjectToObject', function(tag:String, clipTag:String, padding:Float = 0) {
			var sprite:FlxSprite = getSprite(tag, 'clipObjectToObject');
			var bounds:FlxObject = getBounds(clipTag, 'clipObjectToObject');
			if (sprite == null || bounds == null)
				return false;

			return applyRectClip(sprite, bounds.x + padding, bounds.y + padding, bounds.width - padding * 2, bounds.height - padding * 2);
		});

		FunkinLua.registerFunction('clearObjectClip', function(tag:String) {
			var sprite:FlxSprite = getSprite(tag, 'clearObjectClip');
			if (sprite == null)
				return false;

			sprite.clipRect = null;
			return true;
		});
	}
}
