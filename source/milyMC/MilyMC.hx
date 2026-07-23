package milyMC;

#if LUA_ALLOWED
import backend.Mods;
import psychlua.FunkinLua;
import states.PlayState;
import backend.ClientPrefs;
#end

// LLM ASSISTED BECAUSE I'M TOO STUPID TO MAKE THIS SHIT LOOKS "OKAY"

class MilyMC
{
	public static inline var CORE_SCRIPT_NAME:String = 'source:milyMC/runtime';
	static var pendingCalls:Array<{name:String, args:Array<Dynamic>}> = [];

	#if LUA_ALLOWED
	public static function load(state:PlayState):Void
	{
		if (!ClientPrefs.data.modchart) // po esqueci legal da opçãoooo
		{
			pendingCalls = [];
			return;
		}

		if (state == null || state.luaArray == null || hasScript(state, CORE_SCRIPT_NAME))
			return;

		MilyMCCustom.pruneForState(state);
		MilyMCOptimizations.registerLuaCallbacks();
		var source:String = buildSource();

		try
		{
			var lua:FunkinLua = new FunkinLua(source, state);
			lua.scriptName = CORE_SCRIPT_NAME;
			lua.modFolder = Mods.currentModDirectory;
			state.luaArray.push(lua);
			MilyMCCustom.attachRuntime();
			flushPendingCalls(lua);
			lua.call('onCreate');
		}
		catch(e:Dynamic)
		{
			trace('[MilyMC] Failed to start runtime: $e');
		}
	}

	static function buildSource():String
	{
		var modules:Array<String> = [];
		addCoreModule(modules, 'core/state', MilyMCMacros.luaFile('core/state'));
		addCoreModule(modules, 'math/easing', MilyMCMacros.luaFile('math/easing'));
		addCoreModule(modules, 'logic/helpers', MilyMCMacros.luaFile('logic/helpers'));
		addCoreModule(modules, 'logic/strums', MilyMCMacros.luaFile('logic/strums'));
		addCoreModule(modules, 'logic/tweens', MilyMCMacros.luaFile('logic/tweens'));
		addCoreModule(modules, 'core/callbacks', MilyMCMacros.luaFile('core/callbacks'));
		addCoreModule(modules, 'modifiers/lanes', MilyMCMacros.luaFile('modifiers/lanes'));
		addCoreModule(modules, 'modifiers/custom', MilyMCMacros.luaFile('modifiers/custom'));
		addCoreModule(modules, 'modifiers/defaults', MilyMCMacros.luaFile('modifiers/defaults'));

		return modules.join('\n\n');
	}

	static function addCoreModule(modules:Array<String>, name:String, source:String):Void
		modules.push('-- MilyMC module: ' + name + '\n' + source);

	static function hasScript(state:PlayState, scriptName:String):Bool
	{
		for (script in state.luaArray)
			if (script != null && script.scriptName == scriptName)
				return true;
		return false;
	}

	static function getRuntime():FunkinLua
	{
		var state:PlayState = PlayState.instance;
		if (state == null || state.luaArray == null)
			return null;

		for (script in state.luaArray)
			if (script != null && script.scriptName == CORE_SCRIPT_NAME)
				return script;
		return null;
	}

	public static function runtimeReady():Bool
		return getRuntime() != null;

	public static function callRuntime(name:String, args:Array<Dynamic>):Dynamic
	{
		if (!ClientPrefs.data.modchart)
			return null;

		var runtime:FunkinLua = getRuntime();
		if (runtime == null)
		{
			pendingCalls.push({name: name, args: args});
			return null;
		}
		return runtime.call(name, args);
	}

	static function flushPendingCalls(runtime:FunkinLua):Void
	{
		if (runtime == null || pendingCalls.length < 1)
			return;

		var calls = pendingCalls;
		pendingCalls = [];
		for (call in calls)
			runtime.call(call.name, call.args);
	}

	public static function setMC(name:String, value:Dynamic, ?target:Dynamic, ?tag:String):Dynamic
		return callRuntime('setMC', [name, value, target, tag]);

	public static function easeMC(name:String, value:Dynamic, time:Float, ease:String, ?target:Dynamic, ?tag:String):Dynamic
		return callRuntime('easeMC', [name, value, time, ease, target, tag]);

	public static function removeMC(tag:String, ?target:Dynamic):Dynamic
		return callRuntime('removeMC', [tag, target]);

	public static function setQueueMC(step:Float, name:String, value:Dynamic, ?target:Dynamic, ?tag:String):Dynamic
		return callRuntime('setQueueMC', [step, name, value, target, tag]);

	public static function easeQueueMC(stepRange:Dynamic, name:String, value:Dynamic, ease:String, ?target:Dynamic, ?tag:String):Dynamic
		return callRuntime('easeQueueMC', [stepRange, name, value, ease, target, tag]);

	public static function removeQueueMC(step:Float, tag:String, ?target:Dynamic):Dynamic
		return callRuntime('removeQueueMC', [step, tag, target]);

	public static function kickMC(name:String, value:Dynamic, endValue:Dynamic, time:Float, ease:String, ?target:Dynamic, ?tag:String):Dynamic
		return callRuntime('kickMC', [name, value, endValue, time, ease, target, tag]);

	public static function setStrum(option:String, value:Dynamic, ?target:Dynamic, ?tag:String):Dynamic
		return callRuntime('setStrum', [option, value, target, tag]);

	public static function easeStrum(option:String, value:Dynamic, time:Float, ease:String, ?target:Dynamic, ?tag:String):Dynamic
		return callRuntime('easeStrum', [option, value, time, ease, target, tag]);

	public static function setQueueStrum(step:Float, option:String, value:Dynamic, ?target:Dynamic, ?tag:String):Dynamic
		return callRuntime('setQueueStrum', [step, option, value, target, tag]);

	public static function easeQueueStrum(stepRange:Dynamic, option:String, value:Dynamic, ease:String, ?target:Dynamic, ?tag:String):Dynamic
		return callRuntime('easeQueueStrum', [stepRange, option, value, ease, target, tag]);
	#else
	public static function load(state:Dynamic):Void {}
	public static function setMC(name:String, value:Dynamic, ?target:Dynamic, ?tag:String):Dynamic return null;
	public static function easeMC(name:String, value:Dynamic, time:Float, ease:String, ?target:Dynamic, ?tag:String):Dynamic return null;
	public static function removeMC(tag:String, ?target:Dynamic):Dynamic return null;
	public static function setQueueMC(step:Float, name:String, value:Dynamic, ?target:Dynamic, ?tag:String):Dynamic return null;
	public static function easeQueueMC(stepRange:Dynamic, name:String, value:Dynamic, ease:String, ?target:Dynamic, ?tag:String):Dynamic return null;
	public static function removeQueueMC(step:Float, tag:String, ?target:Dynamic):Dynamic return null;
	public static function kickMC(name:String, value:Dynamic, endValue:Dynamic, time:Float, ease:String, ?target:Dynamic, ?tag:String):Dynamic return null;
	public static function setStrum(option:String, value:Dynamic, ?target:Dynamic, ?tag:String):Dynamic return null;
	public static function easeStrum(option:String, value:Dynamic, time:Float, ease:String, ?target:Dynamic, ?tag:String):Dynamic return null;
	public static function setQueueStrum(step:Float, option:String, value:Dynamic, ?target:Dynamic, ?tag:String):Dynamic return null;
	public static function easeQueueStrum(stepRange:Dynamic, option:String, value:Dynamic, ease:String, ?target:Dynamic, ?tag:String):Dynamic return null;
	#end
}
