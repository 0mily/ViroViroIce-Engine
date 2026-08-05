package backend;

import flixel.FlxBasic;
import flixel.FlxSprite;
import objects.Character;
import psychlua.LuaUtils;

private typedef StageDataEntry =
{
	var object:FlxSprite;

	var baseActive:Bool;
	var baseAlpha:Float;
	var baseX:Float;
	var baseY:Float;
	var baseScaleX:Float;
	var baseScaleY:Float;

	var appliedActive:Bool;
	var appliedX:Float;
	var appliedY:Float;
	var appliedScaleX:Float;
	var appliedScaleY:Float;
}

/**
 * basically created this for my own business (Come One Come All port)
 * but ended up being pretty useful tbh
 */
class StageDataController
{
	public var state(default, null):PlayState;
	public var objects(default, null):Array<FlxBasic> = [];
	public var members(get, never):Array<FlxBasic>;
	public var length(get, never):Int;
	public var visibilityWasSet(default, null):Bool = false;

	public var visible(get, set):Bool;
	public var active(get, set):Bool;
	public var alpha(get, set):Float;
	public var x(get, set):Float;
	public var y(get, set):Float;
	public var scale(get, set):Float;
	public var scaleX(get, set):Float;
	public var scaleY(get, set):Float;

	var _visible:Bool = true;
	var _active:Bool = true;
	var _alpha:Float = 1;
	var _x:Float = 0;
	var _y:Float = 0;
	var _scale:Float = 1;
	var _scaleX:Float = 1;
	var _scaleY:Float = 1;

	var entries:Array<StageDataEntry> = [];
	var roots:Array<FlxBasic> = [];

	public function new(state:PlayState)
	{
		this.state = state;
	}

	public static function registerFromScript(member:Dynamic, ?target:Dynamic):Bool
		return registerFromCurrentStageScript(member, target);

	// only data/stage 
	public static function registerFromCurrentStageScript(member:Dynamic, ?target:Dynamic):Bool
	{
		var game:PlayState = PlayState.instance;
		if(game == null || game.stageData == null || !Std.isOfType(member, FlxBasic))
			return false;
		if(target != null && target != game)
			return false;

		var scriptPath:String = null;
		#if LUA_ALLOWED
		var luaScript:psychlua.FunkinLua = psychlua.FunkinLua.lastCalledScript;
		if(luaScript != null && luaScript.parentState == game)
			scriptPath = luaScript.scriptName;
		#end
		#if HSCRIPT_ALLOWED
		if(scriptPath == null)
		{
			var hscript:psychlua.HScript = LuaUtils.lastCalledHScript;
			if(hscript != null && hscript.parentState == game)
				scriptPath = hscript.origin != null ? hscript.origin : hscript.filePath;
		}
		#end

		if(!isCurrentStageScript(scriptPath))
			return false;
		return game.stageData.register(cast member);
	}

	public static function unregisterFromScript(member:Dynamic):Bool
	{
		var game:PlayState = PlayState.instance;
		if(game == null || game.stageData == null || !Std.isOfType(member, FlxBasic))
			return false;
		return game.stageData.unregister(cast member);
	}

	static function isCurrentStageScript(scriptPath:String):Bool
	{
		if(scriptPath == null || PlayState.curStage == null)
			return false;

		var normalized:String = scriptPath.replace('\\', '/').toLowerCase();
		if(!normalized.startsWith('/'))
			normalized = '/' + normalized;
		var stagePath:String = '/data/stages/' + PlayState.curStage.toLowerCase();
		for(extension in ['.lua', '.hx', '.hxc', '.hscript'])
			if(normalized.endsWith(stagePath + extension))
				return true;
		return false;
	}

	public function refresh():Void
	{
		prepareEntries();
		applyAll();
	}

	public function register(member:FlxBasic):Bool
	{
		if(member == null || isGameplayCharacter(member))
			return false;
		if(!roots.contains(member))
			roots.push(member);
		var previousLength:Int = objects.length;
		captureMember(member);
		return objects.length > previousLength;
	}

	public function unregister(member:FlxBasic):Bool
	{
		if(member == null)
			return false;

		roots.remove(member);
		return removeMember(member);
	}

	public inline function get(index:Int):FlxBasic
		return index >= 0 && index < objects.length ? objects[index] : null;

	public function show():Void
	{
		visible = true;
		active = true;
	}

	public function hide():Void
	{
		visible = false;
		active = false;
	}

	// basically just resets the stageData to default values, but doesn't change the individual sprite values
	public function restore():Void
	{
		prepareEntries();
		_visible = true;
		_active = true;
		_alpha = 1;
		_x = 0;
		_y = 0;
		_scale = 1;
		_scaleX = 1;
		_scaleY = 1;
		visibilityWasSet = false;
		applyAll();
	}

	inline function get_members():Array<FlxBasic> return objects;
	inline function get_length():Int return objects.length;
	inline function get_visible():Bool return _visible;
	inline function get_active():Bool return _active;
	inline function get_alpha():Float return _alpha;
	inline function get_x():Float return _x;
	inline function get_y():Float return _y;
	inline function get_scale():Float return _scale;
	inline function get_scaleX():Float return _scaleX;
	inline function get_scaleY():Float return _scaleY;

	function set_visible(value:Bool):Bool
	{
		prepareEntries();
		visibilityWasSet = true;
		_visible = value;
		applyAll();
		return value;
	}

	function set_active(value:Bool):Bool
	{
		prepareEntries();
		_active = value;
		applyAll();
		return value;
	}

	function set_alpha(value:Float):Float
	{
		if(Math.isNaN(value)) value = 1;
		prepareEntries();
		_alpha = value;
		applyAll();
		return value;
	}

	function set_x(value:Float):Float
	{
		if(Math.isNaN(value)) value = 0;
		prepareEntries();
		_x = value;
		applyAll();
		return value;
	}

	function set_y(value:Float):Float
	{
		if(Math.isNaN(value)) value = 0;
		prepareEntries();
		_y = value;
		applyAll();
		return value;
	}

	function set_scale(value:Float):Float
	{
		if(Math.isNaN(value)) value = 1;
		prepareEntries();
		_scale = value;
		_scaleX = value;
		_scaleY = value;
		applyAll();
		return value;
	}

	function set_scaleX(value:Float):Float
	{
		if(Math.isNaN(value)) value = 1;
		prepareEntries();
		_scaleX = value;
		applyAll();
		return value;
	}

	function set_scaleY(value:Float):Float
	{
		if(Math.isNaN(value)) value = 1;
		prepareEntries();
		_scaleY = value;
		applyAll();
		return value;
	}

	function captureMember(member:FlxBasic):Void
	{
		if(member == null || isGameplayCharacter(member))
			return;

		// A sprite group is a sprite too, but tracking the group itself would also
		// transform Character children (pregnancy on VVIE!). Track only its visual leaves instead
		var children:Dynamic = Reflect.getProperty(member, 'members');
		if(Std.isOfType(children, Array))
		{
			for(child in (cast children:Array<Dynamic>))
				if(Std.isOfType(child, FlxBasic))
					captureMember(cast child);
			return;
		}

		if(!Std.isOfType(member, FlxSprite) || objects.contains(member))
			return;

		var sprite:FlxSprite = cast member;
		var entry:StageDataEntry = {
			object: sprite,
			baseActive: sprite.active,
			baseAlpha: sprite.alpha,
			baseX: sprite.x,
			baseY: sprite.y,
			baseScaleX: sprite.scale.x,
			baseScaleY: sprite.scale.y,
			appliedActive: sprite.active,
			appliedX: sprite.x,
			appliedY: sprite.y,
			appliedScaleX: sprite.scale.x,
			appliedScaleY: sprite.scale.y
		};
		objects.push(sprite);
		entries.push(entry);
		applyEntry(entry);
	}

	function removeMember(member:FlxBasic):Bool
	{
		var removed:Bool = false;
		var children:Dynamic = Reflect.getProperty(member, 'members');
		if(Std.isOfType(children, Array))
			for(child in (cast children:Array<Dynamic>))
				if(Std.isOfType(child, FlxBasic) && removeMember(cast child))
					removed = true;

		var index:Int = entries.length;
		while(index-- > 0)
			if(entries[index].object == member)
			{
				restoreVisualAlpha(entries[index]);
				entries.splice(index, 1);
				objects.remove(member);
				removed = true;
			}
		return removed;
	}

	function discoverMembers():Void
	{
		var rootIndex:Int = roots.length;
		while(rootIndex-- > 0)
			if(roots[rootIndex] == null)
				roots.splice(rootIndex, 1);

		var entryIndex:Int = entries.length;
		while(entryIndex-- > 0)
		{
			var sprite:FlxSprite = entries[entryIndex].object;
			if(sprite == null || isGameplayCharacter(sprite))
			{
				objects.remove(sprite);
				entries.splice(entryIndex, 1);
			}
		}

		for(root in roots)
			captureMember(root);
	}

	function isGameplayCharacter(member:FlxBasic):Bool
	{
		if(member == null || Std.isOfType(member, Character))
			return true;
		if(state == null)
			return false;
		return member == state.boyfriendGroup
			|| member == state.dadGroup
			|| member == state.gfGroup
			|| member == state.boyfriend
			|| member == state.dad
			|| member == state.gf;
	}

	function prepareEntries():Void
	{
		discoverMembers();
		for(entry in entries)
			syncEntry(entry);
	}

	// sycn everything in the entry to the sprite, but only if it has changed since the last time we applied it
	function syncEntry(entry:StageDataEntry):Void
	{
		var sprite:FlxSprite = entry.object;
		if(sprite == null)
			return;

		if(sprite.active != entry.appliedActive)
		{
			if(_active || sprite.active)
				entry.baseActive = sprite.active;
		}

		// Alpha and visibility remain properties of the sprite itself. The stage
		// multiplier is applied only to its render ColorTransform in applyEntry()
		entry.baseAlpha = sprite.alpha;
		if(different(sprite.x, entry.appliedX))
			entry.baseX = sprite.x - _x;
		if(different(sprite.y, entry.appliedY))
			entry.baseY = sprite.y - _y;
		if(different(sprite.scale.x, entry.appliedScaleX))
			entry.baseScaleX = _scaleX != 0 ? sprite.scale.x / _scaleX : sprite.scale.x;
		if(different(sprite.scale.y, entry.appliedScaleY))
			entry.baseScaleY = _scaleY != 0 ? sprite.scale.y / _scaleY : sprite.scale.y;
	}

	function applyAll():Void
	{
		for(entry in entries)
			applyEntry(entry);
	}

	function applyEntry(entry:StageDataEntry):Void
	{
		var sprite:FlxSprite = entry.object;
		if(sprite == null)
			return;

		entry.appliedActive = _active && entry.baseActive;
		entry.appliedX = entry.baseX + _x;
		entry.appliedY = entry.baseY + _y;
		entry.appliedScaleX = entry.baseScaleX * _scaleX;
		entry.appliedScaleY = entry.baseScaleY * _scaleY;

		sprite.active = entry.appliedActive;
		sprite.x = entry.appliedX;
		sprite.y = entry.appliedY;
		sprite.scale.set(entry.appliedScaleX, entry.appliedScaleY);
		applyVisualAlpha(sprite, (_visible ? _alpha : 0) * entry.baseAlpha);
	}
	
	// applies the final rendered opacity to the sprite, but does not change sprite.alpha itself
	static function applyVisualAlpha(sprite:FlxSprite, value:Float):Void
	{
		if(sprite == null)
			return;
		value = Math.max(0, Math.min(1, value));
		if(different(sprite.colorTransform.alphaMultiplier, value))
		{
			sprite.colorTransform.alphaMultiplier = value;
			sprite.dirty = true;
		}
		@:privateAccess sprite.useColorTransform = value != 1
			|| sprite.color.rgb != 0xffffff
			|| sprite.colorTransform.redOffset != 0
			|| sprite.colorTransform.greenOffset != 0
			|| sprite.colorTransform.blueOffset != 0
			|| sprite.colorTransform.alphaOffset != 0;
	}

	static function restoreVisualAlpha(entry:StageDataEntry):Void
	{
		if(entry != null && entry.object != null)
			applyVisualAlpha(entry.object, entry.object.alpha);
	}

	static inline function different(a:Float, b:Float):Bool
		return Math.abs(a - b) > 0.000001;
}
