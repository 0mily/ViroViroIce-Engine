package milyMC;

#if LUA_ALLOWED
import backend.Mods;
import backend.Paths;
import psychlua.FunkinLua;
import states.PlayState;
import sys.FileSystem;
import sys.io.File;
import backend.ClientPrefs;
#end

// LLM ASSISTED BECAUSE I'M TOO STUPID TO MAKE THIS SHIT LOOKS "OKAY"

class MilyMC
{
	public static inline var CORE_SCRIPT_NAME:String = 'source:milyMC/runtime';
	static var pendingCalls:Array<{name:String, args:Array<Dynamic>}> = [];

	public static function shouldSkipRegularLua(path:String, ?songName:String = ''):Bool
	{
		#if LUA_ALLOWED
		var normalized:String = normalizePath(path);
		var slash:Int = normalized.lastIndexOf('/');
		var fileName:String = (slash >= 0 ? normalized.substr(slash + 1) : normalized).toLowerCase();

		if (fileName == 'backendmily.lua')
			return true;
		if (fileName == 'modchart.lua' && normalized.indexOf('/songs/') >= 0)
			return true;
		if (fileName == 'modchart.lua' && normalized.indexOf('/data/scripts/') >= 0) // i forgor
			return true;
		#end

		return false;
	}

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

		MilyMCOptimizations.registerLuaCallbacks();

		var modchartFiles:Array<String> = findSongModcharts(state.songName);
		var source:String = buildSource(modchartFiles);

		try
		{
			var lua:FunkinLua = new FunkinLua(source, state);
			lua.scriptName = CORE_SCRIPT_NAME;
			lua.modFolder = Mods.currentModDirectory;
			state.luaArray.push(lua);
			flushPendingCalls(lua);
			lua.call('onCreate');
		}
		catch(e:Dynamic)
		{
			trace('[MilyMC] Failed to start runtime: $e');
		}
	}

	static function buildSource(modchartFiles:Array<String>):String
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

		var source:String = modules.join('\n\n');
		source += '\n\n_milyMCSourceMode = true\n';
		source += '\n\nlocal function _milyMCLoadSongModchart(path, code)\n';
		source += '\tlocal loader = loadstring or load\n';
		source += '\tlocal chunk, err = loader(code, path)\n';
		source += '\tif not chunk then\n';
		source += "\t\tif debugPrint then debugPrint('[MilyMC] Modchart syntax error in ' .. tostring(path) .. ': ' .. tostring(err)) end\n";
		source += '\t\treturn\n';
		source += '\tend\n';
		source += '\tlocal ok, runErr = pcall(chunk)\n';
		source += '\tif not ok and debugPrint then\n';
		source += "\t\tdebugPrint('[MilyMC] Modchart load error in ' .. tostring(path) .. ': ' .. tostring(runErr))\n";
		source += '\tend\n';
		source += 'end\n';

		for (file in modchartFiles)
		{
			try
			{
				source += '\n\n-- MilyMC song modchart: $file\n';
				var modchartSource:String = MilyMCSyntax.process(File.getContent(file));
				source += '_milyMCLoadSongModchart(' + luaStringLiteral(file) + ', ' + luaStringLiteral(modchartSource) + ')\n';
			}
			catch(e:Dynamic)
			{
				trace('[MilyMC] Could not read modchart file "$file": $e');
			}
		}

		return source;
	}

	static function addCoreModule(modules:Array<String>, name:String, source:String):Void
		modules.push('-- MilyMC module: ' + name + '\n' + source);

	static function luaStringLiteral(value:String):String
	{
		if (value == null)
			value = '';

		var delimiter:String = '';
		while (value.indexOf(']' + delimiter + ']') >= 0)
			delimiter += '=';

		return '[' + delimiter + '[' + value + ']' + delimiter + ']';
	}

	static function findSongModcharts(songName:String):Array<String>
	{
		var files:Array<String> = [];
		addModchartFilesFromFolders(files, Mods.directoriesWithFile(Paths.getSharedPath(), 'data/scripts/'));

		if (songName == null || songName.trim().length < 1)
			return files;

		addModchartFilesFromFolders(files, Mods.directoriesWithFile(Paths.getSharedPath(), 'songs/$songName/'));
		return files;
	}

	static function addModchartFilesFromFolders(files:Array<String>, folders:Array<String>):Void
	{
		for (folder in folders)
		{
			var path:String = normalizePath(folder);
			if (!path.endsWith('/'))
				path += '/';

			var file:String = path + 'modchart.lua';
			if (FileSystem.exists(file) && !files.contains(file))
				files.push(file);
		}
	}

	static function hasScript(state:PlayState, scriptName:String):Bool
	{
		for (script in state.luaArray)
			if (script != null && script.scriptName == scriptName)
				return true;
		return false;
	}

	static function normalizePath(path:String):String
	{
		return path == null ? '' : path.replace('\\', '/');
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

	static function callRuntime(name:String, args:Array<Dynamic>):Dynamic
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
