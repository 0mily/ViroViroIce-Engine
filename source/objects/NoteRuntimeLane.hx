package objects;

import flixel.tweens.FlxTween.TweenOptions;
import haxe.ds.ObjectMap;
import openfl.display.BlendMode;

// basically the scope of the lane object, like if it affects moving notes, the receptor, or both!
enum abstract NoteRuntimeScope(Int) from Int to Int
{
	var MOVING_NOTES = 0;
	var RECEPTOR = 1;
	var ALL = 2;
}

// atchoo?
class NoteRuntimeLane
{
	public var game(default, null):PlayState;
	public var index(default, null):Int;
	public var scope(default, null):NoteRuntimeScope;

	public var x(get, set):Float;
	public var y(get, set):Float;
	public var alpha(get, set):Float;
	public var scale(get, set):Dynamic;
	public var blend(get, set):Dynamic;
	public var angle(get, set):Float;
	public var visible(get, set):Bool;
	public var color(get, set):Dynamic;
	public var r(get, set):Dynamic;
	public var g(get, set):Dynamic;
	public var b(get, set):Dynamic;

	var scaleProxy:NoteRuntimeScale;
	var propertyOverrides:Map<String, Dynamic> = [];

	public function new(game:PlayState, index:Int, scope:NoteRuntimeScope)
	{
		this.game = game;
		this.index = index;
		this.scope = scope;
		scaleProxy = new NoteRuntimeScale(
			() -> getFloatProperty('scale.x', 1),
			value -> setGenericProperty('scale.x', value),
			() -> getFloatProperty('scale.y', 1),
			value -> setGenericProperty('scale.y', value));
	}

	inline function get_x():Float return getFloatProperty('x', 0);
	inline function set_x(value:Float):Float return cast setGenericProperty('x', value);
	inline function get_y():Float return getFloatProperty('y', 0);
	inline function set_y(value:Float):Float return cast setGenericProperty('y', value);
	inline function get_alpha():Float return getFloatProperty('alpha', 1);
	inline function set_alpha(value:Float):Float return cast setGenericProperty('alpha', value);
	inline function get_scale():Dynamic return scaleProxy;
	function set_scale(value:Dynamic):Dynamic
	{
		var values:Array<Float> = scaleValues(value);
		setGenericProperty('scale.x', values[0]);
		setGenericProperty('scale.y', values[1]);
		return value;
	}
	inline function get_blend():Dynamic return getGenericProperty('blend', BlendMode.NORMAL);
	inline function set_blend(value:Dynamic):Dynamic return setGenericProperty('blend', normalizeBlend(value));
	inline function get_angle():Float return getFloatProperty('angle', 0);
	inline function set_angle(value:Float):Float return cast setGenericProperty('angle', value);
	inline function get_visible():Bool return getGenericProperty('visible', true) != false;
	inline function set_visible(value:Bool):Bool return cast setGenericProperty('visible', value);
	inline function get_color():Dynamic return getGenericProperty('color', FlxColor.WHITE);
	inline function set_color(value:Dynamic):Dynamic return setGenericProperty('color', colorFromDynamic(value));

	inline function get_r():Dynamic return game.getRuntimeRGBChannel(index, scope, 0);
	inline function get_g():Dynamic return game.getRuntimeRGBChannel(index, scope, 1);
	inline function get_b():Dynamic return game.getRuntimeRGBChannel(index, scope, 2);

	function set_r(value:Dynamic):Dynamic
	{
		game.setRuntimeRGBChannel(index, scope, 0, colorFromDynamic(value));
		return value;
	}

	function set_g(value:Dynamic):Dynamic
	{
		game.setRuntimeRGBChannel(index, scope, 1, colorFromDynamic(value));
		return value;
	}

	function set_b(value:Dynamic):Dynamic
	{
		game.setRuntimeRGBChannel(index, scope, 2, colorFromDynamic(value));
		return value;
	}

	public function getGenericProperty(field:String, fallback:Dynamic):Dynamic
	{
		if (scope == ALL && game != null)
		{
			var moving:NoteRuntimeLane = game.noteLanes[index];
			if (moving != null)
				return moving.getGenericProperty(field, fallback);
			var receptor:NoteRuntimeLane = game.strumLane[index];
			if (receptor != null)
				return receptor.getGenericProperty(field, fallback);
		}

		if (propertyOverrides.exists(field))
			return propertyOverrides.get(field);

		var found:Dynamic = null;
		forEachTarget(function(target:FlxSprite)
		{
			if (found == null)
				found = readTargetProperty(target, field);
		});
		return found != null ? found : fallback;
	}

	public function setGenericProperty(field:String, value:Dynamic):Dynamic
	{
		if (scope == ALL && game != null)
		{
			var moving:NoteRuntimeLane = game.noteLanes[index];
			var receptor:NoteRuntimeLane = game.strumLane[index];
			if (moving != null) moving.setGenericProperty(field, value);
			if (receptor != null) receptor.setGenericProperty(field, value);
			return value;
		}

		propertyOverrides.set(field, value);
		forEachTarget(function(target:FlxSprite) applyTargetProperty(target, field, value));
		return value;
	}

	public function applyToNote(note:Note):Void
	{
		if (note == null || (scope != MOVING_NOTES && scope != ALL) || !matchesNote(note))
			return;
		applyPropertiesToTarget(note);
	}

	public function applyToStrum(strum:StrumNote):Void
	{
		if (strum == null || (scope != RECEPTOR && scope != ALL))
			return;
		applyPropertiesToTarget(strum);
	}

	function applyPropertiesToTarget(target:FlxSprite):Void
	{
		for (field => value in propertyOverrides)
			applyTargetProperty(target, field, value);
	}

	function forEachTarget(callback:FlxSprite->Void):Void
	{
		if (game == null || callback == null)
			return;

		if (scope == RECEPTOR || scope == ALL)
		{
			var strum:StrumNote = game.strumLineNotes?.members[index];
			if (strum != null)
				callback(strum);
		}

		if ((scope == MOVING_NOTES || scope == ALL) && game.notes != null)
			for (note in game.notes.members)
				if (note != null && matchesNote(note))
					callback(note);
	}

	inline function matchesNote(note:Note):Bool
		return note.noteData + (note.mustPress ? 4 : 0) == index;

	function getFloatProperty(field:String, fallback:Float):Float
	{
		var value:Dynamic = getGenericProperty(field, fallback);
		var parsed:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	static function readTargetProperty(target:FlxSprite, field:String):Dynamic
	{
		return switch (field)
		{
			case 'scale.x': target.scale.x;
			case 'scale.y': target.scale.y;
			default: Reflect.getProperty(target, field);
		}
	}

	static function applyTargetProperty(target:FlxSprite, field:String, value:Dynamic):Void
	{
		switch (field)
		{
			case 'scale.x': target.scale.x = toFloat(value, target.scale.x);
			case 'scale.y': target.scale.y = toFloat(value, target.scale.y);
			case 'x': target.x = toFloat(value, target.x);
			case 'y': target.y = toFloat(value, target.y);
			case 'alpha': target.alpha = toFloat(value, target.alpha);
			case 'angle': target.angle = toFloat(value, target.angle);
			case 'visible': target.visible = toBool(value, target.visible);
			case 'color': target.color = colorFromDynamic(value);
			case 'blend': target.blend = normalizeBlend(value);
			default: Reflect.setProperty(target, field, value);
		}
	}

	public static function colorFromDynamic(value:Dynamic):FlxColor
	{
		if (value == null)
			return FlxColor.WHITE;

		return switch (Type.typeof(value))
		{
			case TInt: FlxColor.fromInt(value);
			case TFloat: FlxColor.fromInt(Std.int(value));
			default: CoolUtil.colorFromString(Std.string(value));
		}
	}

	public static function normalizeBlend(value:Dynamic):BlendMode
	{
		if (value == null)
			return BlendMode.NORMAL;

		return switch (Std.string(value).toLowerCase().trim())
		{
			case 'add': BlendMode.ADD;
			case 'alpha': BlendMode.ALPHA;
			case 'darken': BlendMode.DARKEN;
			case 'difference': BlendMode.DIFFERENCE;
			case 'erase': BlendMode.ERASE;
			case 'hardlight': BlendMode.HARDLIGHT;
			case 'invert': BlendMode.INVERT;
			case 'layer': BlendMode.LAYER;
			case 'lighten': BlendMode.LIGHTEN;
			case 'multiply': BlendMode.MULTIPLY;
			case 'overlay': BlendMode.OVERLAY;
			case 'screen': BlendMode.SCREEN;
			case 'shader': BlendMode.SHADER;
			case 'subtract': BlendMode.SUBTRACT;
			default: BlendMode.NORMAL;
		}
	}

	public static function scaleValues(value:Dynamic):Array<Float>
	{
		if (Std.isOfType(value, Int) || Std.isOfType(value, Float) || Std.isOfType(value, String))
		{
			var size:Float = toFloat(value, 1);
			return [size, size];
		}
		if (Std.isOfType(value, Array))
		{
			var values:Array<Dynamic> = cast value;
			var x:Float = toFloat(values[0], 1);
			return [x, toFloat(values[1], x)];
		}
		var x:Float = toFloat(Reflect.field(value, 'x'), 1);
		return [x, toFloat(Reflect.field(value, 'y'), x)];
	}

	public static function toFloat(value:Dynamic, fallback:Float):Float
	{
		var parsed:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	public static function toBool(value:Dynamic, fallback:Bool):Bool
	{
		if (Std.isOfType(value, Bool))
			return value;
		return switch (Std.string(value).toLowerCase().trim())
		{
			case 'true' | '1' | 'yes' | 'on': true;
			case 'false' | '0' | 'no' | 'off': false;
			default: fallback;
		}
	}
}

// view used when a lane collection is accessed without `[index]`, e.g. `game.noteLanes[0].x` vs `game.noteLanes.x`
class NoteRuntimeCollection
{
	public var game(default, null):PlayState;
	public var lanes(default, null):Array<NoteRuntimeLane>;
	public var scope(default, null):NoteRuntimeScope;
	public var length(get, never):Int;

	public var x(get, set):Float;
	public var y(get, set):Float;
	public var alpha(get, set):Float;
	public var scale(get, set):Dynamic;
	public var blend(get, set):Dynamic;
	public var angle(get, set):Float;
	public var visible(get, set):Bool;
	public var color(get, set):Dynamic;
	public var r(get, set):Dynamic;
	public var g(get, set):Dynamic;
	public var b(get, set):Dynamic;

	var scaleProxy:NoteRuntimeScale;

	public function new(game:PlayState, lanes:Array<NoteRuntimeLane>, scope:NoteRuntimeScope)
	{
		this.game = game;
		this.lanes = lanes;
		this.scope = scope;
		scaleProxy = new NoteRuntimeScale(
			() -> getFloat('scale.x', 1),
			value -> setGenericProperty('scale.x', value),
			() -> getFloat('scale.y', 1),
			value -> setGenericProperty('scale.y', value));
	}

	inline function get_length():Int return lanes.length;
	public inline function get(index:Int):NoteRuntimeLane return index >= 0 && index < lanes.length ? lanes[index] : null;
	public inline function iterator():Iterator<NoteRuntimeLane> return lanes.iterator();

	inline function get_x():Float return getFloat('x', 0);
	inline function set_x(value:Float):Float return cast setGenericProperty('x', value);
	inline function get_y():Float return getFloat('y', 0);
	inline function set_y(value:Float):Float return cast setGenericProperty('y', value);
	inline function get_alpha():Float return getFloat('alpha', 1);
	inline function set_alpha(value:Float):Float return cast setGenericProperty('alpha', value);
	inline function get_scale():Dynamic return scaleProxy;
	function set_scale(value:Dynamic):Dynamic
	{
		var values:Array<Float> = NoteRuntimeLane.scaleValues(value);
		setGenericProperty('scale.x', values[0]);
		setGenericProperty('scale.y', values[1]);
		return value;
	}
	inline function get_blend():Dynamic return first().blend;
	function set_blend(value:Dynamic):Dynamic
	{
		for (lane in lanes) lane.blend = value;
		return value;
	}
	inline function get_angle():Float return getFloat('angle', 0);
	inline function set_angle(value:Float):Float return cast setGenericProperty('angle', value);
	inline function get_visible():Bool return first().visible;
	function set_visible(value:Bool):Bool
	{
		for (lane in lanes) lane.visible = value;
		return value;
	}
	inline function get_color():Dynamic return first().color;
	function set_color(value:Dynamic):Dynamic
	{
		for (lane in lanes) lane.color = value;
		return value;
	}
	inline function get_r():Dynamic return first().r;
	inline function set_r(value:Dynamic):Dynamic return setPaletteChannel('r', value);
	inline function get_g():Dynamic return first().g;
	inline function set_g(value:Dynamic):Dynamic return setPaletteChannel('g', value);
	inline function get_b():Dynamic return first().b;
	inline function set_b(value:Dynamic):Dynamic return setPaletteChannel('b', value);

	public function getGenericProperty(field:String, fallback:Dynamic):Dynamic
		return lanes.length > 0 ? lanes[0].getGenericProperty(field, fallback) : fallback;

	public function setGenericProperty(field:String, value:Dynamic):Dynamic
	{
		for (lane in lanes)
			lane.setGenericProperty(field, value);
		return value;
	}

	public function skin(skinName:String, ?target:Dynamic):Bool
		return game.setStrumSkin(target, skinName);

	inline function first():NoteRuntimeLane return lanes[0];

	function getFloat(field:String, fallback:Float):Float
		return lanes.length > 0 ? NoteRuntimeLane.toFloat(lanes[0].getGenericProperty(field, fallback), fallback) : fallback;

	function setPaletteChannel(field:String, value:Dynamic):Dynamic
	{
		for (lane in lanes)
			Reflect.setProperty(lane, field, value);
		return value;
	}
}

// Adds a scale proxy to allow for `scale.x` and `scale.y` to be set independentlyy
class NoteRuntimeScale
{
	public var x(get, set):Float;
	public var y(get, set):Float;

	var readX:Void->Float;
	var writeX:Float->Void;
	var readY:Void->Float;
	var writeY:Float->Void;

	public function new(readX:Void->Float, writeX:Float->Void, readY:Void->Float, writeY:Float->Void)
	{
		this.readX = readX;
		this.writeX = writeX;
		this.readY = readY;
		this.writeY = writeY;
	}

	inline function get_x():Float return readX();
	function set_x(value:Float):Float { writeX(value); return value; }
	inline function get_y():Float return readY();
	function set_y(value:Float):Float { writeY(value); return value; }

	public function set(x:Float = 0, y:Float = 0):NoteRuntimeScale
	{
		this.x = x;
		this.y = y;
		return this;
	}
}

// dose a natural interpolation to runtime lane objects and their collections
class NoteRuntimeTween
{
	static var runtimeTwens:ObjectMap<Dynamic, Array<FlxTween>> = new ObjectMap();

	public static function tween(object:Dynamic, values:Dynamic, duration:Float = 1, ?options:TweenOptions):FlxTween
	{
		var target:Dynamic = resolveTarget(object);
		if (target == null || values == null)
			return FlxTween.tween(object, values, duration, options);

		var fields:Array<String> = [];
		var starts:Array<Dynamic> = [];
		var targets:Array<Dynamic> = [];
		for (field in Reflect.fields(values))
		{
			var normalized:String = field.toLowerCase();
			if (!isGenericField(normalized))
				continue;

			fields.push(normalized);
			var current:Dynamic = normalized == 'scale' ? Reflect.getProperty(Reflect.getProperty(target, 'scale'), 'x') : Reflect.getProperty(target, normalized);
			starts.push(isColorField(normalized) ? NoteRuntimeLane.colorFromDynamic(current) : current);
			var wanted:Dynamic = Reflect.field(values, field);
			targets.push(isColorField(normalized) ? NoteRuntimeLane.colorFromDynamic(wanted) : wanted);
		}

		if (fields.length < 1)
			return FlxTween.tween(object, values, duration, options);

		cancelTweensOf(target, fields);
		var wrappedOptions:TweenOptions = copyOptions(options);
		var originalComplete:FlxTween->Void = options != null ? options.onComplete : null;
		wrappedOptions.onComplete = function(tween:FlxTween)
		{
			if (tween.type != LOOPING && tween.type != PINGPONG)
				removeTween(target, tween);
			if (originalComplete != null)
				originalComplete(tween);
		};

		var tween:FlxTween = FlxTween.num(0, 1, duration, wrappedOptions, function(progress:Float)
		{
			for (i in 0...fields.length)
			{
				var field:String = fields[i];
				if (isColorField(field))
					Reflect.setProperty(target, field, FlxColor.interpolate(starts[i], targets[i], progress));
				else if (field == 'visible' || field == 'blend')
				{
					if (progress >= 1) Reflect.setProperty(target, field, targets[i]);
				}
				else
				{
					var start:Float = NoteRuntimeLane.toFloat(starts[i], 0);
					var finish:Float = NoteRuntimeLane.toFloat(targets[i], start);
					Reflect.setProperty(target, field, FlxMath.lerp(start, finish, progress));
				}
			}
		});

		if (!runtimeTwens.exists(target))
			runtimeTwens.set(target, []);
		runtimeTwens.get(target).push(tween);
		return tween;
	}

	public static function cancelTweensOf(object:Dynamic, ?fieldPaths:Array<String>):Void
	{
		var target:Dynamic = resolveTarget(object);
		if (target == null)
		{
			FlxTween.cancelTweensOf(object, fieldPaths);
			return;
		}

		var tweens:Array<FlxTween> = runtimeTwens.get(target);
		if (tweens == null)
			return;

		for (tween in tweens.copy())
		{
			tween.cancel();
			tween.destroy();
		}
		runtimeTwens.remove(target);
	}

	static function resolveTarget(object:Dynamic):Dynamic
	{
		if (Std.isOfType(object, NoteRuntimeLane) || Std.isOfType(object, NoteRuntimeCollection))
			return object;
		if (PlayState.instance != null)
			return PlayState.instance.getRuntimeLaneCollection(object);
		return null;
	}

	static inline function isColorField(field:String):Bool
		return field == 'r' || field == 'g' || field == 'b' || field == 'color';

	static inline function isGenericField(field:String):Bool
		return isColorField(field) || field == 'x' || field == 'y' || field == 'alpha' || field == 'scale'
			|| field == 'angle' || field == 'visible' || field == 'blend';

	static function removeTween(target:Dynamic, tween:FlxTween):Void
	{
		var tweens:Array<FlxTween> = runtimeTwens.get(target);
		if (tweens == null)
			return;
		tweens.remove(tween);
		if (tweens.length < 1)
			runtimeTwens.remove(target);
	}

	static function copyOptions(options:TweenOptions):TweenOptions
	{
		var result:TweenOptions = {};
		if (options != null)
			for (field in Reflect.fields(options))
				Reflect.setField(result, field, Reflect.field(options, field));
		return result;
	}
}
