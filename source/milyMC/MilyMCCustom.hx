package milyMC;

using StringTools;

#if LUA_ALLOWED
import flixel.FlxState;
import psychlua.FunkinLua;
import llua.Lua;
import llua.LuaL;

#if HSCRIPT_ALLOWED
import psychlua.HScript;
#end

private typedef MilyMCCustomDefinition =
{
	var name:String;
	var owner:Dynamic;
	var luaOwner:Bool;
	var callbacks:Dynamic;
	var defaultValue:Float;
	var order:Float;
	var flags:Int;
	var registration:Int;
}
#end

// Is this the best way to do it? No!!! BUT I CARE??? naaahhh
class MilyMCCustom
{
	#if LUA_ALLOWED
	static inline var APPLY:Int = 1;
	static inline var NOTE:Int = 2;
	static inline var SUSTAIN:Int = 4;
	static inline var STRUM:Int = 8;
	static inline var ENABLED:Int = 16;
	static inline var UPDATE:Int = 32;

	static var definitions:Map<String, MilyMCCustomDefinition> = [];
	static var nextRegistration:Int = 0;

	public static function installLua(owner:FunkinLua):Void
	{
		if (owner == null || owner.lua == null)
			return;

		owner.addLocalCallback('_milyMCRegisterCustom', function(name:String, defaultValue:Dynamic, order:Dynamic, flags:Dynamic) {
			return registerLua(owner, name, defaultValue, order, flags);
		});
		owner.addLocalCallback('_milyMCRemoveCustom', function(name:String, localDestroyCalled:Bool = false) {
			return remove(name, owner, localDestroyCalled);
		});
		owner.addLocalCallback('_milyMCCustomDispatch', dispatch);

		var status:Int = LuaL.dostring(owner.lua, MilyMCMacros.luaFile('api/public'));
		if (status != Lua.LUA_OK)
			trace('[MilyMC] Could not install the public Lua API: ' + owner.getErrorMessage(status));
	}

	#if HSCRIPT_ALLOWED
	public static function installHScript(owner:HScript):Void
	{
		if (owner == null)
			return;

		owner.set('defineMC', function(name:String, callbacks:Dynamic) {
			return registerHScript(owner, name, callbacks);
		});
		owner.set('removeCustomMC', function(name:String) {
			return remove(name, owner, false);
		});
	}
	#end

	static function registerLua(owner:FunkinLua, name:String, defaultValue:Dynamic, order:Dynamic, flags:Dynamic):Dynamic
	{
		name = normalizeName(name);
		if (name.length < 1)
			return null;

		var definition:MilyMCCustomDefinition = {
			name: name,
			owner: owner,
			luaOwner: true,
			callbacks: null,
			defaultValue: number(defaultValue),
			order: number(order),
			flags: Std.int(number(flags)),
			registration: nextRegistration++
		};
		definitions.set(name, definition);
		registerWithRuntime(definition);
		return name;
	}

	#if HSCRIPT_ALLOWED
	static function registerHScript(owner:HScript, name:String, callbacks:Dynamic):Dynamic
	{
		name = normalizeName(name);
		if (name.length < 1)
			throw 'defineMC requires a modifier name.';
		if (Reflect.isFunction(callbacks))
			callbacks = {apply: callbacks};
		if (callbacks == null)
			throw 'defineMC callbacks must be a function or object.';

		var definition:MilyMCCustomDefinition = {
			name: name,
			owner: owner,
			luaOwner: false,
			callbacks: callbacks,
			defaultValue: number(Reflect.field(callbacks, 'default')),
			order: number(Reflect.field(callbacks, 'order')),
			flags: callbackFlags(callbacks),
			registration: nextRegistration++
		};
		definitions.set(name, definition);
		registerWithRuntime(definition);
		callHScript(definition, 'load', [name]);
		return name;
	}
	#end

	static function registerWithRuntime(definition:MilyMCCustomDefinition):Void
	{
		if (definition == null || !MilyMC.runtimeReady())
			return;
		MilyMC.callRuntime('_milyMCDefineExternalCustom', [
			definition.name,
			definition.defaultValue,
			definition.order,
			definition.flags
		]);
	}

	public static function attachRuntime():Void
	{
		var active:Array<MilyMCCustomDefinition> = [for (definition in definitions) definition];
		active.sort(function(first, second) return first.registration - second.registration);
		for (definition in active)
			if (ownerAlive(definition))
				registerWithRuntime(definition);
	}

	public static function pruneForState(state:FlxState):Void
	{
		var stale:Array<String> = [];
		for (name => definition in definitions)
			if (!ownerAlive(definition) || ownerState(definition) != state)
				stale.push(name);

		for (name in stale)
		{
			var definition = definitions.get(name);
			if (definition != null && ownerAlive(definition))
				invokeLifecycle(definition, 'destroy');
			definitions.remove(name);
		}
	}

	public static function releaseLua(owner:FunkinLua):Void
		releaseOwner(owner);

	#if HSCRIPT_ALLOWED
	public static function releaseHScript(owner:HScript):Void
		releaseOwner(owner);
	#end

	static function releaseOwner(owner:Dynamic):Void
	{
		if (owner == null)
			return;

		var names:Array<String> = [];
		for (name => definition in definitions)
			if (definition.owner == owner)
				names.push(name);

		for (name in names)
		{
			var definition = definitions.get(name);
			if (definition == null)
				continue;
			invokeLifecycle(definition, 'destroy');
			definitions.remove(name);
			if (MilyMC.runtimeReady())
				MilyMC.callRuntime('removeCustomMC', [name]);
		}
	}

	static function remove(name:String, requester:Dynamic, localDestroyCalled:Bool):Bool
	{
		name = normalizeName(name);
		var definition = definitions.get(name);
		if (definition != null)
		{
			if (!localDestroyCalled || definition.owner != requester)
				invokeLifecycle(definition, 'destroy');
			definitions.remove(name);
		}

		var runtimeResult:Dynamic = null;
		if (MilyMC.runtimeReady())
			runtimeResult = MilyMC.callRuntime('removeCustomMC', [name]);
		return definition != null || runtimeResult == true;
	}

	static function dispatch(name:String, phase:String, first:Dynamic = null, second:Dynamic = null):Dynamic
	{
		var definition = definitions.get(normalizeName(name));
		if (definition == null || !ownerAlive(definition))
			return phase == 'enabled' ? true : (isContextPhase(phase) ? first : null);

		if (definition.luaOwner)
		{
			var owner:FunkinLua = cast definition.owner;
			return owner.call('_milyMCInvokeCustom', [definition.name, phase, first, second]);
		}

		#if HSCRIPT_ALLOWED
		var callback:Dynamic = selectCallback(definition.callbacks, phase);
		if (!Reflect.isFunction(callback))
			return phase == 'enabled' ? true : (isContextPhase(phase) ? first : null);

		try
		{
			var result:Dynamic = Reflect.callMethod(null, callback, [first, second]);
			return isContextPhase(phase) && result == null ? first : result;
		}
		catch(e:Dynamic)
		{
			trace('[MilyMC] Custom modifier "${definition.name}" failed in $phase: $e');
			return phase == 'enabled' ? true : (isContextPhase(phase) ? first : null);
		}
		#else
		return phase == 'enabled' ? true : (isContextPhase(phase) ? first : null);
		#end
	}

	static function invokeLifecycle(definition:MilyMCCustomDefinition, phase:String):Void
	{
		if (definition == null || !ownerAlive(definition))
			return;
		if (definition.luaOwner)
		{
			(cast definition.owner:FunkinLua).call('_milyMCInvokeCustom', [definition.name, phase]);
			return;
		}
		#if HSCRIPT_ALLOWED
		callHScript(definition, phase, [definition.name]);
		#end
	}

	#if HSCRIPT_ALLOWED
	static function callHScript(definition:MilyMCCustomDefinition, phase:String, args:Array<Dynamic>):Dynamic
	{
		var callback:Dynamic = Reflect.field(definition.callbacks, phase);
		if (!Reflect.isFunction(callback))
			return null;
		try
		{
			return Reflect.callMethod(null, callback, args);
		}
		catch(e:Dynamic)
		{
			trace('[MilyMC] Custom modifier "${definition.name}" failed in $phase: $e');
			return null;
		}
	}
	#end

	static function selectCallback(callbacks:Dynamic, phase:String):Dynamic
	{
		if (callbacks == null)
			return null;
		return switch (phase)
		{
			case 'strum': firstFunction(callbacks, ['strum', 'receptor', 'apply']);
			case 'sustain': firstFunction(callbacks, ['sustain', 'note', 'apply']);
			case 'note': firstFunction(callbacks, ['note', 'apply']);
			default: Reflect.field(callbacks, phase);
		}
	}

	static function firstFunction(callbacks:Dynamic, fields:Array<String>):Dynamic
	{
		for (field in fields)
		{
			var callback:Dynamic = Reflect.field(callbacks, field);
			if (Reflect.isFunction(callback))
				return callback;
		}
		return null;
	}

	static function callbackFlags(callbacks:Dynamic):Int
	{
		var flags:Int = 0;
		if (hasCallback(callbacks, 'apply')) flags |= APPLY;
		if (hasCallback(callbacks, 'note')) flags |= NOTE;
		if (hasCallback(callbacks, 'sustain')) flags |= SUSTAIN;
		if (hasCallback(callbacks, 'strum') || hasCallback(callbacks, 'receptor')) flags |= STRUM;
		if (hasCallback(callbacks, 'enabled')) flags |= ENABLED;
		if (hasCallback(callbacks, 'update')) flags |= UPDATE;
		return flags;
	}

	static inline function hasCallback(callbacks:Dynamic, field:String):Bool
		return callbacks != null && Reflect.isFunction(Reflect.field(callbacks, field));

	static inline function isContextPhase(phase:String):Bool
		return phase == 'note' || phase == 'sustain' || phase == 'strum';

	static function ownerAlive(definition:MilyMCCustomDefinition):Bool
	{
		if (definition == null || definition.owner == null)
			return false;
		if (definition.luaOwner)
		{
			var owner:FunkinLua = cast definition.owner;
			return !owner.closed && owner.lua != null;
		}
		#if HSCRIPT_ALLOWED
		return (cast definition.owner:HScript).isReady();
		#else
		return false;
		#end
	}

	static function ownerState(definition:MilyMCCustomDefinition):FlxState
	{
		if (definition.luaOwner)
			return (cast definition.owner:FunkinLua).parentState;
		#if HSCRIPT_ALLOWED
		return (cast definition.owner:HScript).parentState;
		#else
		return null;
		#end
	}

	static function normalizeName(name:Dynamic):String
		return name == null ? '' : Std.string(name).trim();

	static function number(value:Dynamic):Float
	{
		if (value == null)
			return 0;
		var parsed:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? 0 : parsed;
	}
	#else
	public static function installLua(owner:Dynamic):Void {}
	public static function installHScript(owner:Dynamic):Void {}
	public static function releaseLua(owner:Dynamic):Void {}
	public static function releaseHScript(owner:Dynamic):Void {}
	#end
}
