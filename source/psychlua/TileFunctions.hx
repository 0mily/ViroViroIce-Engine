package psychlua;

import flixel.FlxBasic;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.util.FlxAxes;

using StringTools;

typedef TileMotion = {
	var x:Float;
	var y:Float;
}

class TileFunctions
{
	#if LUA_ALLOWED
	public static function implement():Void
	{
		FunkinLua.registerFunction('setObjectBackdrop', function(tag:String, axes:String = 'xy', direction:Dynamic = null, direction2OrVelocity:Dynamic = null, velocityOrVelocity2:Dynamic = null, velocity2:Dynamic = null) {
			return setTileObject(tag, axes, direction, direction2OrVelocity, velocityOrVelocity2, velocity2);
		});
		FunkinLua.registerFunction('setBackdrop', function(tag:String, axes:String = 'xy', direction:Dynamic = null, direction2OrVelocity:Dynamic = null, velocityOrVelocity2:Dynamic = null, velocity2:Dynamic = null) {
			return setTileObject(tag, axes, direction, direction2OrVelocity, velocityOrVelocity2, velocity2);
		});
		FunkinLua.registerFunction('makeObjectBackdrop', function(tag:String, image:String = null, x:Float = 0, y:Float = 0, axes:String = 'xy', direction:Dynamic = null, direction2OrVelocity:Dynamic = null, velocityOrVelocity2:Dynamic = null, velocity2:Dynamic = null) {
			return makeTileObject(tag, image, x, y, axes, direction, direction2OrVelocity, velocityOrVelocity2, velocity2) != null;
		});
		FunkinLua.registerFunction('makeAnimatedObjectBackdrop', function(tag:String, image:String = null, x:Float = 0, y:Float = 0, spriteType:String = 'auto', axes:String = 'xy', direction:Dynamic = null, direction2OrVelocity:Dynamic = null, velocityOrVelocity2:Dynamic = null, velocity2:Dynamic = null) {
			return makeAnimatedTileObject(tag, image, x, y, spriteType, axes, direction, direction2OrVelocity, velocityOrVelocity2, velocity2) != null;
		});
		FunkinLua.registerFunction('makeAnimatedObjectBackdrop', function(tag:String, image:String = null, x:Float = 0, y:Float = 0, spriteType:String = 'auto', axes:String = 'xy', direction:Dynamic = null, direction2OrVelocity:Dynamic = null, velocityOrVelocity2:Dynamic = null, velocity2:Dynamic = null) {
			return makeAnimatedTileObject(tag, image, x, y, spriteType, axes, direction, direction2OrVelocity, velocityOrVelocity2, velocity2) != null;
		});
		FunkinLua.registerFunction('copyObjectBackdrop', function(tag:String, sourceTag:String, axes:String = 'xy', direction:Dynamic = null, direction2OrVelocity:Dynamic = null, velocityOrVelocity2:Dynamic = null, velocity2:Dynamic = null) {
			return copyTileObject(tag, sourceTag, axes, direction, direction2OrVelocity, velocityOrVelocity2, velocity2) != null;
		});
		FunkinLua.registerFunction('setBackdropVelocity', setTileVelocity);
		FunkinLua.registerFunction('setBackdropMotion', setTileMotion);
		FunkinLua.registerFunction('setBackdropAxes', setTileAxes);
		FunkinLua.registerFunction('removeObjectBackdrop', removeTileObject);
		FunkinLua.registerFunction('addGridBackdrop', addGridBackdrop);
		FunkinLua.registerFunction('removeBackdrop', removeTileObject);
	}
	#end

	public static function parseBackdropAxes(value:String):FlxAxes
	{
		if (value == null)
			return XY;

		switch (value.trim().toLowerCase())
		{
			case 'x', 'horizontal', 'h':
				return X;
			case 'y', 'vertical', 'v':
				return Y;
			case 'none', 'off', 'false':
				return NONE;
			default:
				return XY;
		}
	}

	public static function setTileObject(tag:String, axes:String = 'xy', direction:Dynamic = null, direction2OrVelocity:Dynamic = null, velocityOrVelocity2:Dynamic = null, velocity2:Dynamic = null):Bool
	{
		var source:FlxSprite = getSprite(tag);
		if (source == null)
			return false;

		var backdrop:FlxBackdrop;
		if (Std.isOfType(source, FlxBackdrop))
		{
			backdrop = cast source;
			backdrop.repeatAxes = parseBackdropAxes(axes);
		}
		else
		{
			backdrop = cloneAsBackdrop(source, axes);
			if (!replaceInDisplay(source, backdrop))
				addToTarget(backdrop);

			source.visible = false;
			backdrop.extraData.set('tileSource', source);
			MusicBeatState.getVariables().set(storageTag(tag), backdrop);
		}

		return applyTileMotion(backdrop, axes, direction, direction2OrVelocity, velocityOrVelocity2, velocity2);
	}

	public static function makeTileObject(tag:String, image:String = null, x:Float = 0, y:Float = 0, axes:String = 'xy', direction:Dynamic = null, direction2OrVelocity:Dynamic = null, velocityOrVelocity2:Dynamic = null, velocity2:Dynamic = null):TileBackdrop
	{
		if (tag == null || tag.trim().length < 1)
			return null;

		tag = storageTag(tag);
		LuaUtils.destroyObject(tag);

		var backdrop:TileBackdrop = new TileBackdrop(null, parseBackdropAxes(axes));
		if (image != null && image.length > 0)
			backdrop.loadGraphic(Paths.image(image));
		backdrop.setPosition(x, y);
		backdrop.active = true;
		backdrop.moves = true;
		backdrop.antialiasing = ClientPrefs.data.antialiasing;

		MusicBeatState.getVariables().set(tag, backdrop);
		applyTileMotion(backdrop, axes, direction, direction2OrVelocity, velocityOrVelocity2, velocity2);
		return backdrop;
	}

	public static function makeAnimatedTileObject(tag:String, image:String = null, x:Float = 0, y:Float = 0, spriteType:String = 'auto', axes:String = 'xy', direction:Dynamic = null, direction2OrVelocity:Dynamic = null, velocityOrVelocity2:Dynamic = null, velocity2:Dynamic = null):TileBackdrop
	{
		if (tag == null || tag.trim().length < 1)
			return null;

		tag = storageTag(tag);
		LuaUtils.destroyObject(tag);

		var backdrop:TileBackdrop = new TileBackdrop(null, parseBackdropAxes(axes));
		if (image != null && image.length > 0)
			LuaUtils.loadFrames(backdrop, image, spriteType);
		backdrop.setPosition(x, y);
		backdrop.active = true;
		backdrop.moves = true;
		backdrop.antialiasing = ClientPrefs.data.antialiasing;

		MusicBeatState.getVariables().set(tag, backdrop);
		applyTileMotion(backdrop, axes, direction, direction2OrVelocity, velocityOrVelocity2, velocity2);
		return backdrop;
	}

	public static function copyTileObject(tag:String, sourceTag:String, axes:String = 'xy', direction:Dynamic = null, direction2OrVelocity:Dynamic = null, velocityOrVelocity2:Dynamic = null, velocity2:Dynamic = null):TileBackdrop
	{
		if (tag == null || tag.trim().length < 1)
			return null;

		var source:FlxSprite = getSprite(sourceTag);
		if (source == null)
			return null;

		tag = storageTag(tag);
		LuaUtils.destroyObject(tag);

		var backdrop:TileBackdrop = cloneAsBackdrop(source, axes);
		MusicBeatState.getVariables().set(tag, backdrop);
		applyTileMotion(backdrop, axes, direction, direction2OrVelocity, velocityOrVelocity2, velocity2);
		return backdrop;
	}

	public static function setTileVelocity(tag:String, velocityX:Float = 0, velocityY:Float = 0):Bool
	{
		var backdrop = getBackdrop(tag);
		if (backdrop == null)
			return false;

		backdrop.velocity.set(velocityX, velocityY);
		return true;
	}

	public static function setTileMotion(tag:String, direction:Dynamic = null, direction2OrVelocity:Dynamic = null, velocityOrVelocity2:Dynamic = null, velocity2:Dynamic = null):Bool
	{
		var backdrop = getBackdrop(tag);
		if (backdrop == null)
			return false;

		return applyTileMotion(backdrop, axesToString(backdrop.repeatAxes), direction, direction2OrVelocity, velocityOrVelocity2, velocity2);
	}

	public static function setTileAxes(tag:String, axes:String = 'xy'):Bool
	{
		var backdrop = getBackdrop(tag);
		if (backdrop == null)
			return false;

		backdrop.repeatAxes = parseBackdropAxes(axes);
		return true;
	}

	public static function removeTileObject(tag:String, destroy:Bool = true):Bool
	{
		var backdrop = getBackdrop(tag);
		if (backdrop == null)
			return false;

		removeFromDisplay(backdrop);
		if (destroy)
			backdrop.destroy();
		MusicBeatState.getVariables().remove(storageTag(tag));
		return true;
	}

	public static function addGridBackdrop(tag:String, cellWidth:Int = 80, cellHeight:Int = 80, width:Int = 160, height:Int = 160, velocityX:Float = 0, velocityY:Float = 0, color1:String = '33FFFFFF', color2:String = '000000', alpha:Float = 1, x:Float = 0, y:Float = 0, repeatAxes:String = 'xy'):Bool
	{
		if (tag == null || tag.trim().length < 1)
			return false;

		tag = storageTag(tag);
		if (getObject(tag) != null)
			return false;

		var grid = FlxGridOverlay.createGrid(cellWidth, cellHeight, width, height, true, CoolUtil.colorFromString(color1), CoolUtil.colorFromString(color2));
		var backdrop:TileBackdrop = new TileBackdrop(grid, parseBackdropAxes(repeatAxes));
		backdrop.setPosition(x, y);
		backdrop.velocity.set(velocityX, velocityY);
		backdrop.alpha = alpha;
		backdrop.moves = true;

		MusicBeatState.getVariables().set(tag, backdrop);
		addToTarget(backdrop);
		return true;
	}

	static function applyTileMotion(backdrop:FlxBackdrop, axes:String, direction:Dynamic = null, direction2OrVelocity:Dynamic = null, velocityOrVelocity2:Dynamic = null, velocity2:Dynamic = null):Bool
	{
		if (backdrop == null)
			return false;

		var motion = parseMotion(axes, direction, direction2OrVelocity, velocityOrVelocity2, velocity2);
		backdrop.velocity.set(motion.x, motion.y);
		backdrop.moves = true;
		return true;
	}

	static function parseMotion(axes:String, direction:Dynamic = null, direction2OrVelocity:Dynamic = null, velocityOrVelocity2:Dynamic = null, velocity2:Dynamic = null):TileMotion
	{
		var repeatAxes = parseBackdropAxes(axes);
		var hasX = repeatAxes == X || repeatAxes == XY;
		var hasY = repeatAxes == Y || repeatAxes == XY;
		var motion:TileMotion = {x: 0, y: 0};

		if ((!hasX && !hasY) || direction == null)
			return motion;

		if (isNumber(direction))
		{
			if (hasX && hasY)
			{
				motion.x = toFloat(direction);
				motion.y = toFloat(direction2OrVelocity);
			}
			else if (hasX)
				motion.x = toFloat(direction);
			else if (hasY)
				motion.y = toFloat(direction);

			return motion;
		}

		var firstDirection = normalizeDirection(direction);
		var secondIsDirection = isDirection(direction2OrVelocity);
		var secondDirection = secondIsDirection ? normalizeDirection(direction2OrVelocity) : null;
		var firstSpeed = secondIsDirection ? toFloat(velocityOrVelocity2) : toFloat(direction2OrVelocity);
		var secondSpeed = secondIsDirection ? (velocity2 == null ? firstSpeed : toFloat(velocity2)) : (velocityOrVelocity2 == null ? 0 : toFloat(velocityOrVelocity2));
		var xWasSet = false;
		var yWasSet = false;

		function applyDirection(dir:String, speed:Float):Void
		{
			if (isHorizontalDirection(dir) && hasX)
			{
				motion.x = directionSignX(dir) * speed;
				xWasSet = true;
			}
			else if (isVerticalDirection(dir) && hasY)
			{
				motion.y = directionSignY(dir) * speed;
				yWasSet = true;
			}
		}

		applyDirection(firstDirection, firstSpeed);
		if (secondDirection != null)
			applyDirection(secondDirection, secondSpeed);

		if (!secondIsDirection && velocityOrVelocity2 != null)
		{
			if (hasX && !xWasSet)
				motion.x = secondSpeed;
			if (hasY && !yWasSet)
				motion.y = secondSpeed;
		}

		return motion;
	}

	static function cloneAsBackdrop(source:FlxSprite, axes:String):TileBackdrop
	{
		var backdrop:TileBackdrop = new TileBackdrop(source.graphic, parseBackdropAxes(axes));
		if (source.frames != null)
		{
			backdrop.frames = source.frames;
			if (source.animation != null)
			{
				backdrop.animation.copyFrom(source.animation);
				if (source.animation.curAnim != null)
					backdrop.playAnim(source.animation.curAnim.name, true, source.animation.curAnim.reversed, source.animation.curAnim.curFrame);
			}
		}

		copySpriteProperties(source, backdrop);
		copyAnimationOffsets(source, backdrop);
		return backdrop;
	}

	static function copySpriteProperties(source:FlxSprite, backdrop:TileBackdrop):Void // https://mediamarketing.com.br/products/backdrop-portatil-banner-ajustavel
	{
		backdrop.setPosition(source.x, source.y);
		backdrop.scrollFactor.copyFrom(source.scrollFactor);
		backdrop.scale.copyFrom(source.scale);
		backdrop.origin.copyFrom(source.origin);
		backdrop.offset.copyFrom(source.offset);
		backdrop.alpha = source.alpha;
		backdrop.angle = source.angle;
		backdrop.color = source.color;
		backdrop.visible = source.visible;
		backdrop.active = true;
		backdrop.moves = true;
		backdrop.antialiasing = source.antialiasing;
		backdrop.flipX = source.flipX;
		backdrop.flipY = source.flipY;
		backdrop.blend = source.blend;
		backdrop.shader = source.shader;
		backdrop.ID = source.ID;
		if (source.cameras != null)
			backdrop.cameras = source.cameras.copy();

		for (key => value in source.extraData)
			backdrop.extraData.set(key, value);

		backdrop.updateHitbox();
	}

	static function copyAnimationOffsets(source:FlxSprite, backdrop:TileBackdrop):Void
	{
		var offsets:Dynamic = Reflect.getProperty(source, 'animOffsets');
		if (offsets == null || offsets.keys == null)
			return;

		var keys:Iterator<Dynamic> = cast offsets.keys();
		for (name in keys)
		{
			var value:Array<Float> = cast offsets.get(name);
			if (value != null && value.length > 1)
				backdrop.addOffset(name, value[0], value[1]);
		}
	}

	static function getBackdrop(tag:String):FlxBackdrop
	{
		var object = getObject(tag);
		return Std.isOfType(object, FlxBackdrop) ? cast object : null;
	}

	static function getSprite(tag:String):FlxSprite
	{
		var object = getObject(tag);
		return Std.isOfType(object, FlxSprite) ? cast object : null;
	}

	static function getObject(tag:String):Dynamic
	{
		if (tag == null || tag.trim().length < 1)
			return null;

		var object:Dynamic = null;
		try object = LuaUtils.getObjectDirectly(tag) catch (e:Dynamic) object = null;

		var storedTag = storageTag(tag);
		if (object == null && storedTag != tag)
		{
			 try object = LuaUtils.getObjectDirectly(storedTag) catch (e:Dynamic) object = null; // just in case
		}
		return object;
	}

	static function replaceInDisplay(oldObject:FlxBasic, newObject:FlxBasic):Bool
	{
		var target = targetInstance();
		if (target != null && replaceInContainer(target, oldObject, newObject))
			return true;

		if (FlxG.state != null)
		{
			if (target != FlxG.state && replaceInContainer(FlxG.state, oldObject, newObject))
				return true;

			var subState:Dynamic = FlxG.state.subState;
			while (subState != null)
			{
				if (subState != target && replaceInContainer(subState, oldObject, newObject))
					return true;
				subState = subState.subState;
			}
		}
		return false;
	}

	static function replaceInContainer(container:Dynamic, oldObject:FlxBasic, newObject:FlxBasic):Bool
	{
		var members:Array<Dynamic> = getMembers(container);
		if (members == null)
			return false;

		var index = members.indexOf(oldObject);
		if (index >= 0)
		{
			callMethod(container, 'remove', [oldObject, true]);
			callMethod(container, 'insert', [index, newObject]);
			return true;
		}

		for (member in members)

			if (member != null && member != oldObject && replaceInContainer(member, oldObject, newObject))
				return true;

		return false;
	}

	static function removeFromDisplay(object:FlxBasic):Bool
	{
		var target = targetInstance();
		if (target != null && removeFromContainer(target, object))
			return true;

		if (FlxG.state != null)
		{
			if (target != FlxG.state && removeFromContainer(FlxG.state, object))
				return true;

			var subState:Dynamic = FlxG.state.subState;
			while (subState != null)
			{
				if (subState != target && removeFromContainer(subState, object))
					return true;
				subState = subState.subState;
			}

		}
		return false;
	}

	static function removeFromContainer(container:Dynamic, object:FlxBasic):Bool
	{
		var members:Array<Dynamic> = getMembers(container);
		if (members == null)
			return false;

		if (members.indexOf(object) >= 0)
		{
			callMethod(container, 'remove', [object, true]);
			return true;
		}

		for (member in members)
			if (member != null && member != object && removeFromContainer(member, object))
				return true;

		return false;
	}

	static function getMembers(container:Dynamic):Array<Dynamic>
	{
		if (container == null)
			return null;

		var members:Dynamic = null;
		try members = Reflect.getProperty(container, 'members') catch (e:Dynamic) members = null;
		return Std.isOfType(members, Array) ? cast members : null;
	}

	static function addToTarget(object:FlxBasic):Bool
	{
		var target = targetInstance();
		if (target == null)
			return false;

		callMethod(target, 'add', [object]);
		return true;
	}

	static function callMethod(target:Dynamic, methodName:String, args:Array<Dynamic>):Dynamic
	{
		var method = Reflect.field(target, methodName);
		if (method == null)
			return null;
		return Reflect.callMethod(target, method, args);
	}

	static function targetInstance():Dynamic
	{
		if (CustomSubstate.instance != null)
			return CustomSubstate.instance;
		return LuaUtils.getTargetInstance();
	}

	static function axesToString(axes:FlxAxes):String
	{
		return switch (axes)
		{
			case X: 'x';
			case Y: 'y';
			case NONE: 'none';
			default: 'xy';
		}

	}

	static function normalizeDirection(value:Dynamic):String
		return value == null ? '' : Std.string(value).trim().toLowerCase();

	static function isDirection(value:Dynamic):Bool
	{
		var direction = normalizeDirection(value);
		return isHorizontalDirection(direction) || isVerticalDirection(direction) || direction == 'none' || direction == 'stop' || direction == '0';
	}

	static function isHorizontalDirection(direction:String):Bool // eu tô me assustando cadavez mais com o tamanho dessa buceta
	{
		return switch (direction)
		{
			case 'left', 'l', '-', '-1', 'negative', 'neg', 'right', 'r', '+', '+1', '1', 'positive', 'pos':
				true;
			default:
				false;
		}
	}

	static function isVerticalDirection(direction:String):Bool
	{
		return switch (direction)
		{
			case 'up', 'u', 'top', 't', 'down', 'd', 'bottom', 'b':
				true;
			default:
				false;
		}
	}

	static function directionSignX(direction:String):Float
	{
		return switch (direction)
		{
			case 'left', 'l', '-', '-1', 'negative', 'neg':
				-1;
			case 'none', 'stop', '0':
				0;
			default:
				1;
		}
	}

	static function directionSignY(direction:String):Float
	{
		return switch (direction)
		{
			case 'up', 'u', 'top', 't':
				-1;
			case 'none', 'stop', '0':
				0;
			default:
				1;
		}
	}

	static function isNumber(value:Dynamic):Bool
	{
		return switch (Type.typeof(value))
		{
			case TInt | TFloat:
				true;
			default:
				false;
		}
	}

	static function toFloat(value:Dynamic, fallback:Float = 0):Float
	{
		if (value == null)
			return fallback;

		switch (Type.typeof(value))
		{
			case TInt | TFloat:
				return value;
			default:
				var parsed = Std.parseFloat(Std.string(value));
				return Math.isNaN(parsed) ? fallback : parsed;
		}
	}

	static function storageTag(tag:String):String
		return tag == null ? null : tag.trim().replace('.', '');
}

class TileBackdrop extends FlxBackdrop
{
	public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();

	public function new(?graphic:Dynamic = null, repeatAxes:FlxAxes = XY)
	{
		super(graphic, repeatAxes);
	}

	public function playAnim(name:String, forced:Bool = false, reverse:Bool = false, startFrame:Int = 0):Void
	{
		animation.play(name, forced, reverse, startFrame);

		var offsetData = animOffsets.get(name);
		if (offsetData != null)
			offset.set(offsetData[0], offsetData[1]);
	}

	public function addOffset(name:String, x:Float, y:Float):Void
	{
		animOffsets.set(name, [x, y]);
	}
}
