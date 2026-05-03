package milyMC;

#if LUA_ALLOWED
import backend.Mods;
import backend.Paths;
import psychlua.FunkinLua;
import states.PlayState;
import sys.FileSystem;
import sys.io.File;
#end

// LLM ASSISTED BECAUSE I'M TOO STUPID TO MAKE THIS SHIT LOOKS "OKAY"

class MilyMC
{
	public static inline var CORE_SCRIPT_NAME:String = 'source:milyMC/runtime';

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
		#end

		return false;
	}

	#if LUA_ALLOWED
	public static function load(state:PlayState):Void
	{
		if (state == null || state.luaArray == null || hasScript(state, CORE_SCRIPT_NAME))
			return;

		var modchartFiles:Array<String> = findSongModcharts(state.songName);
		var source:String = buildSource(modchartFiles);

		try
		{
			var lua:FunkinLua = new FunkinLua(source, state);
			lua.scriptName = CORE_SCRIPT_NAME;
			lua.modFolder = Mods.currentModDirectory;
			state.luaArray.push(lua);
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
		addCoreModule(modules, 'logic/tweens', MilyMCMacros.luaFile('logic/tweens'));
		addCoreModule(modules, 'logic/strums', MilyMCMacros.luaFile('logic/strums'));
		addCoreModule(modules, 'core/callbacks', MilyMCMacros.luaFile('core/callbacks'));
		addCoreModule(modules, 'modifiers/lanes', MilyMCMacros.luaFile('modifiers/lanes'));
		addCoreModule(modules, 'modifiers/custom', MilyMCMacros.luaFile('modifiers/custom'));
		addCoreModule(modules, 'modifiers/defaults', MilyMCMacros.luaFile('modifiers/defaults'));
		addCoreModule(modules, 'core/default_callbacks', MilyMCMacros.luaFile('core/default_callbacks'));

		var source:String = modules.join('\n\n');
		source += '\n\n__milyMCSourceMode = true\n';
		source += '\n\nlocal function __milyMCLoadSongModchart(path, code)\n';
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
				source += '__milyMCLoadSongModchart(' + luaStringLiteral(file) + ', ' + luaStringLiteral(File.getContent(file)) + ')\n';
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
		if (songName == null || songName.trim().length < 1)
			return files;

		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'songs/$songName/'))
		{
			var path:String = normalizePath(folder);
			if (!path.endsWith('/'))
				path += '/';

			var file:String = path + 'modchart.lua';
			if (FileSystem.exists(file) && !files.contains(file))
				files.push(file);
		}

		return files;
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
	#else
	public static function load(state:Dynamic):Void {}
	#end
}
