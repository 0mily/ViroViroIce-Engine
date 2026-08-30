package backend;

#if LUA_ALLOWED
import psychlua.*;
#else
import psychlua.LuaUtils;
#end

#if HSCRIPT_ALLOWED
import psychlua.HScript;
import crowplexus.iris.Iris;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;
#end

#if SCRIPTS_ALLOWED
import psychlua.GlobalScriptHandler;
#end

/**
 * ScriptedSubState is the base for scripted states and sub-states in the game.
 * It automatically handles script initialization and most generic script calls.
 * 
 * ## Generic script calls
 * ```haxe
 * function onCreate() {}
 * function onCreatePost() {}
 * 
 * function onUpdate(elapsed:Float) {}
 * function onUpdatePost(elapsed:Float) {}
 * 
 * function onDraw() {}
 * function onDrawPost() {}
 * 
 * function onStepHit(step:Int) {}
 * function onBeatHit(beat:Int) {}
 * function onSectionHit(measure:Int) {}
 * 
 * function onClose() {}
 * ```
*/
class ScriptedSubState extends MusicBeatSubstate {
	#if LUA_ALLOWED public var luaArray:Array<FunkinLua> = []; #end
	#if HSCRIPT_ALLOWED public var hscriptArray:Array<HScript> = []; #end
	static var overrideDnvSla:Map<String, Array<String>> = [];
	
	var multiScript:Bool = true;
	var loadedScripts:Bool = false;
	var _resolvedScriptStateName:String = null;
	
	public var data:Dynamic = null;
	public var scriptFolder:String = 'data';
	
	public function new(?data:Dynamic) {
		super();
		this.data = data;
	}
	public override function create():Void {
		super.create();
	}
	override function _preCreate():Void {
		#if SCRIPTS_ALLOWED startStateScripts(); #end
		
		#if GLOBAL_SCRIPTS GlobalScriptHandler.call('onCreateSubState', [this]); #end
	}
	override function _postCreate():Void {
		callOnScripts('onCreatePost');
		callOnScripts('onLoadPost');
		
		#if GLOBAL_SCRIPTS GlobalScriptHandler.call('onCreateSubStatePost', [this]); #end
	}
	
	var _shouldUpdate:Bool = true;
	public function preUpdate(elapsed:Float):Bool {
		refreshScreenVar();
		_shouldUpdate = (callOnScripts('onUpdate', [elapsed], true) != LuaUtils.Function_Stop);
		return _shouldUpdate;
	}
	public override function update(elapsed:Float):Void {
		if (_shouldUpdate)
			super.update(elapsed);
		_shouldUpdate = true;
	}
	public function postUpdate(elapsed:Float):Void {
		callOnScripts('onUpdatePost', [elapsed]);
	}
	
	public override function updatePresence():Void {
		if (callOnScripts('onUpdatePresence', [rpcDetails, rpcState], true) != LuaUtils.Function_Stop)
			super.updatePresence();
	}

	public override function onResize(Width:Int, Height:Int):Void {
		super.onResize(Width, Height);
		refreshScreenVar();
		if (_pre)
			callOnScripts('onResize', [Width, Height]);
	}

	public function refreshScreenVar():Void {
		setOnScripts('screenWidth', ResolutionManager.scriptScreenWidth());
		setOnScripts('screenHeight', ResolutionManager.scriptScreenHeight());
	}
	
	public override function draw():Void {
		if (callOnScripts('onDraw', true) == LuaUtils.Function_Stop) return;
		prepareMembersDraw();
		super.draw();
		callOnScripts('onDrawPost');
	}

	/**
	 *Called after onDraw scripts and immediately before state members are rendered
	*/
	public function prepareMembersDraw():Void {}
	
	public override function openSubState(subState:flixel.FlxSubState):Void {
		var stopped:Bool = (callOnHScript('onOpenSubState', [subState], true) == LuaUtils.Function_Stop);
		stopped = (stopped || callOnLuas('onOpenSubState', [getStateName(subState)], true) == LuaUtils.Function_Stop);
		
		if (!stopped)
			super.openSubState(subState);
	}
	
	public override function close():Void {
		if (callOnScripts('onClose', true) != LuaUtils.Function_Stop #if GLOBAL_SCRIPTS && GlobalScriptHandler.call('onCloseSubState', [this]) != LuaUtils.Function_Stop #end)
			super.close();
	}
	
	public override function sectionHit(section:Int):Void {
		super.sectionHit(section);
		
		callOnScripts('onSectionHit', [section]);
	}
	public override function beatHit(beat:Int):Void {
		super.beatHit(beat);
		
		callOnScripts('onBeatHit', [beat]);
	}
	public override function stepHit(step:Int):Void {
		super.stepHit(step);
		
		callOnScripts('onStepHit', [step]);
	}
	
	override function updateSection():Void {
		super.updateSection();
		
		setOnScripts('curSection', curSection);
		setOnScripts('curDecSection', curDecSection);
	}
	override function updateBeat():Void {
		super.updateBeat();
		
		setOnScripts('curBeat', curBeat);
		setOnScripts('curDecBeat', curDecBeat);
	}
	override function updateStep():Void {
		super.updateStep();
		
		setOnScripts('curStep', curStep);
		setOnScripts('curDecStep', curDecStep);
		refreshConductorScriptVariables();
	}

	function refreshConductorScriptVariables():Void {
		setOnScripts('curBpm', curBpm);
		setOnScripts('crochet', crochet);
		setOnScripts('stepCrochet', stepCrochet);
		setOnScripts('stateConductorPosition', stateConductorPosition);
		setOnScripts('usesStateConductor', useStateConductor);
	}
	
	public override function destroy():Void {
		#if SCRIPTS_ALLOWED destroyScripts(); #end
		super.destroy();
	}
	
	/**
	 * Gets the name used in a [scripted] state to find and load scripts.
	 * 
	 * @return 	Custom state name.
	*/
	public static function getStateName(state:flixel.FlxState):String { // Used to load the appropriate substate script
		if (state is ScriptedSubState) {
			return cast(state, ScriptedSubState).customStateName();
		} else {
			var clsName:String = Type.getClassName(Type.getClass(state));
			return clsName.substr(clsName.lastIndexOf('.') + 1);
		}
	}
	/**
	 * Used to find and load state scripts.
	*/
	public function customStateName():String { 
		var clsName:String = Type.getClassName(Type.getClass(this));
		return clsName.substr(clsName.lastIndexOf('.') + 1);
	}
	public static function scriptOverrideShit(stateName:String, scriptName:String):Void {
		stateName = Mods.getStateName(stateName);
		if (stateName == null || scriptName == null)
			return;

		scriptName = scriptName.trim();
		if (scriptName.length < 1)
			return;

		if (!overrideDnvSla.exists(stateName))
			overrideDnvSla.set(stateName, []);
		overrideDnvSla.get(stateName).push(scriptName);
	}
	static function consumeScriptOverride(stateName:String):String {
		stateName = Mods.getStateName(stateName);
		if (stateName == null || !overrideDnvSla.exists(stateName))
			return null;

		var queued = overrideDnvSla.get(stateName);
		if (queued == null || queued.length < 1) {
			overrideDnvSla.remove(stateName);
			return null;
		}

		var scriptName:String = queued.shift();
		if (queued.length < 1)
			overrideDnvSla.remove(stateName);
		return scriptName;
	}
	public function scriptStateName():String {
		if (_resolvedScriptStateName == null)
			_resolvedScriptStateName = consumeScriptOverride(customStateName()) ?? customStateName();
		return _resolvedScriptStateName;
	}
	function getFolderName():String {
		return 'substates';
	}
	function getScriptFolders():Array<String> {
		var folders:Array<String> = [];
		var addFolder = function(path:String) {
			if (path == null) return;
			path = path.trim();
			if (path.length > 0 && !folders.contains(path))
				folders.push(path);
		};

		addFolder(scriptFolder);
		addFolder('data/scripts');
		return folders;
	}
	public function getSingleStateScriptPath(scriptName:String, extension:String):String {
		var prefix:String = getFolderName();
		if (prefix.length > 0) prefix += '/';
		var extensions:Array<String> = [extension];
		#if HSCRIPT_ALLOWED
		if(extension == '.hx')
			extensions = HScript.SCRIPT_EXTENSIONS;
		#end

		for (scriptRoot in getScriptFolders()) {
			for(ext in extensions)
			{
				var file:String = '$scriptRoot/$prefix$scriptName$ext';
				var path:String = getModOnlyScriptPath(file);
				if (path != null)
					return path;
			}
		}
		return null;
	}

	function getModOnlyScriptPath(file:String):String
	{
		#if ADDONS_ALLOWED
		for (mod in Mods.getActiveModDirectories())
		{
			var modPath:String = Paths.mods(mod + '/' + file);
			if (FileSystem.exists(modPath))
				return modPath;
		}

		if (Mods.rootAddonsAllowed())
		{
			var rootPath:String = Paths.mods(file);
			if (FileSystem.exists(rootPath))
				return rootPath;
		}
		#end

		var sharedPath:String = Paths.getSharedPath(file);
		return FileSystem.exists(sharedPath) ? sharedPath : null;
	}
	
	#if SCRIPTS_ALLOWED
	@:dox(hide) function startStateScripts():Bool {
		loadedScripts = false;
		
		#if HSCRIPT_ALLOWED
		loadedScripts = startHScripts();
		#end
		#if LUA_ALLOWED
		if (multiScript || !loadedScripts)
			loadedScripts = (startLuas() || loadedScripts);
		#end
		
		return loadedScripts;
	}
	
	@:dox(hide) function destroyScripts():Void {
		#if LUA_ALLOWED
		for (lua in luaArray) {
			lua.call('onDestroy');
			lua.stop();
		}
		luaArray = null;
		//FunkinLua.customFunctions.clear();
		#end

		#if HSCRIPT_ALLOWED
		for (script in hscriptArray) {
			if (script.exists('onDestroy'))
				script.call('onDestroy');
			script.destroy();
		}
		hscriptArray = null;
		#end

		clearScriptRuntimeCallbacks();
	}

	function clearScriptRuntimeCallbacks():Void {
		var keysToRemove:Array<String> = [];
		for (key in variables.keys())
		{
			var value:Dynamic = variables.get(key);
			if (key.startsWith('timer_') && Std.isOfType(value, FlxTimer))
			{
				var timer:FlxTimer = cast value;
				timer.cancel();
				timer.destroy();
				keysToRemove.push(key);
			}
			else if (key.startsWith('tween_') && Std.isOfType(value, FlxTween))
			{
				var tween:FlxTween = cast value;
				tween.cancel();
				tween.destroy();
				keysToRemove.push(key);
			}
			else if (key.startsWith('sound_') && Std.isOfType(value, FlxSound))
			{
				var sound:FlxSound = cast value;
				sound.stop();
				sound.destroy();
				keysToRemove.push(key);
			}
		}

		for (key in keysToRemove)
			variables.remove(key);
	}
	#end
	
	#if LUA_ALLOWED
	@:dox(hide) function startLuas():Bool {
		var loaded:Bool = false;
		var prefix:String = getFolderName();
		if (prefix.length > 0) prefix += '/';
		
		if (multiScript) {
			for (scriptRoot in getScriptFolders()) {
				for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), scriptRoot)) {
					var path:String = '$folder/$prefix${scriptStateName()}.lua';
					if (FileSystem.exists(path))
						loaded = (initLuaScript(path) != null || loaded);
				}
			}
		} else {
			for (scriptRoot in getScriptFolders()) {
				var file:String = '$scriptRoot/$prefix${scriptStateName()}.lua';
				var path:String = getModOnlyScriptPath(file);
				if (path != null)
					loaded = (initLuaScript(path) != null || loaded);
			}
		}
		
		return loaded;
	}
	/**
	 * Initializes Lua scripts with a matching name and adds them to the state.
	 * 
	 * @param 	file 	The mod folder path to the Lua scripts.
	 * 
	 * @return 	Whether or not any scripts of that name were found and initialized.
	*/
	public function startLuasNamed(luaFile:String) {
		#if ADDONS_ALLOWED
		var luaToLoad:String = Paths.modFolders(luaFile);
		if(!FileSystem.exists(luaToLoad))
			luaToLoad = Paths.getSharedPath(luaFile);

		if(FileSystem.exists(luaToLoad))
		#elseif sys
		var luaToLoad:String = Paths.getSharedPath(luaFile);
		if(OpenFlAssets.exists(luaToLoad))
		#end
		{
			for (script in luaArray)
				if(script.scriptName == luaToLoad) return false;

			initLuaScript(luaToLoad);
			return true;
		}
		return false;
	}
	/**
	 * Initializes a Lua script and adds it to the state.
	 * 
	 * @param 	file 	The relative path to the Lua script.
	 * 
	 * @return 	A new `FunkinLua` instance if successful, otherwise `null`.
	*/
	public function initLuaScript(file:String, autoCallCreate:Bool = true):FunkinLua {
		var lua:FunkinLua = FunkinLua.initFromFile(file, this, null, autoCallCreate);
		if (lua != null) luaArray.push(lua);
		
		return lua;
	}
	
	/**
	 * Called when a Lua script is initialized in this state.
	 * You can use this function to implement custom API functions or set custom variables per state.
	 * 
	 * ```haxe
	 * public override function implementLua(lua:FunkinLua):Void {
	 * 	lua.set("customVariable", 1234);
	 * 	lua.addLocalCallback("customFunction", function() {
	 * 		return "Hi!!";
	 * 	});
	 * }
	 * ```
	*/
	public function implementLua(lua:FunkinLua):Void {
		implementConductorLua(lua);
	}
	public function implementConductorLua(lua:FunkinLua):Void {
		lua.addLocalCallback('setBPM', function(newBPM:Float, resetClock:Bool = false) {
			var value:Float = setBPM(newBPM, resetClock);
			refreshConductorScriptVariables();
			return value;
		});
		lua.addLocalCallback('changeBPM', function(newBPM:Float, resetClock:Bool = false) {
			var value:Float = changeBPM(newBPM, resetClock);
			refreshConductorScriptVariables();
			return value;
		});
		lua.addLocalCallback('setStateBPM', function(newBPM:Float, resetClock:Bool = false) {
			var value:Float = setBPM(newBPM, resetClock);
			refreshConductorScriptVariables();
			return value;
		});
		lua.addLocalCallback('setStateConductorEnabled', function(enabled:Bool = true, resetClock:Bool = false) {
			var value:Bool = useStateConductorClock(enabled, resetClock);
			refreshConductorScriptVariables();
			return value;
		});
		lua.addLocalCallback('resetStateConductor', function(position:Float = 0) {
			resetStateConductor(position);
			refreshConductorScriptVariables();
		});
		lua.addLocalCallback('setStateConductorPosition', function(position:Float) {
			var value:Float = setStateConductorPosition(position);
			refreshConductorScriptVariables();
			return value;
		});
	}
	#end
	
	#if HSCRIPT_ALLOWED
	function startHScripts():Bool {
		var loaded:Bool = false;
		var prefix:String = getFolderName();
		if (prefix.length > 0) prefix += '/';
		
		if (multiScript) {
			for (scriptRoot in getScriptFolders()) {
				for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), scriptRoot)) {
					for(ext in HScript.SCRIPT_EXTENSIONS)
					{
						var path:String = '$folder/$prefix${scriptStateName()}$ext';
						if (FileSystem.exists(path))
							loaded = (initHScript(path) != null || loaded);
					}
				}
			}
		} else {
			for (scriptRoot in getScriptFolders()) {
				for(ext in HScript.SCRIPT_EXTENSIONS)
				{
					var file:String = '$scriptRoot/$prefix${scriptStateName()}$ext';
					var path:String = getModOnlyScriptPath(file);
					if (path != null)
						loaded = (initHScript(path) != null || loaded);
				}
			}
		}
		
		return loaded;
	}
	public function startHScriptsNamed(scriptFile:String) {
		var scriptToLoad:String = null;
		for(candidate in HScript.withScriptExtensions(scriptFile))
		{
			#if ADDONS_ALLOWED
			var modPath:String = Paths.modFolders(candidate);
			if(FileSystem.exists(modPath))
			{
				scriptToLoad = modPath;
				break;
			}
			#end

			var sharedPath:String = Paths.getSharedPath(candidate);
			if(FileSystem.exists(sharedPath))
			{
				scriptToLoad = sharedPath;
				break;
			}
		}

		if(scriptToLoad != null && FileSystem.exists(scriptToLoad)) {
			if (Iris.instances.exists(scriptToLoad)) return false;

			initHScript(scriptToLoad);
			return true;
		}
		return false;
	}
	public function initHScript(file:String, autoCallInitialCallbacks:Bool = true):HScript {
		var hs:HScript = HScript.initFromFile(file, this, null, autoCallInitialCallbacks);
		if (hs != null) hscriptArray.push(hs);
		
		return hs;
	}
	#end
	
	public function loadScriptFolderLayers(folders:Array<String>, autoCallbacks:Bool = true):Bool {
		#if sys
		if(folders == null || folders.length < 1)
			return false;

		var orderedKeys:Array<String> = [];
		var resolvedFiles:Map<String, String> = [];

		for(logicalFolder in folders)
		{
			if(logicalFolder == null || logicalFolder.trim().length < 1)
				continue;

			var physicalFolders:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), logicalFolder, true);
			for(folder in physicalFolders)
			{
				if(folder == null || !FileSystem.exists(folder) || !FileSystem.isDirectory(folder))
					continue;

				var files:Array<String> = FileSystem.readDirectory(folder);
				files.sort(function(a:String, b:String) return Reflect.compare(a.toLowerCase(), b.toLowerCase()));
				for(file in files)
				{
					var path:String = '$folder/$file';
					if(FileSystem.isDirectory(path))
						continue;

					var lower:String = file.toLowerCase();
					var kind:String = null;
					var basename:String = file;
					#if LUA_ALLOWED
					if(lower.endsWith('.lua'))
					{
						kind = 'lua';
						basename = file.substr(0, file.length - 4);
					}
					#end
					#if HSCRIPT_ALLOWED
					if(kind == null && HScript.hasScriptExtension(lower))
					{
						kind = 'hscript';
						for(extension in HScript.SCRIPT_EXTENSIONS)
							if(lower.endsWith(extension.toLowerCase()))
							{
								basename = file.substr(0, file.length - extension.length);
								break;
							}
					}
					#end
					if(kind == null)
						continue;

					var key:String = kind + ':' + basename.toLowerCase();
					if(!resolvedFiles.exists(key))
						orderedKeys.push(key);
					resolvedFiles.set(key, path);
				}
			}
		}

		var loaded:Bool = false;
		for(key in orderedKeys)
		{
			var path:String = resolvedFiles.get(key);
			if(key.startsWith('lua:'))
			{
				#if LUA_ALLOWED
				loaded = (initLuaScript(path, autoCallbacks) != null || loaded);
				#end
			}
			else
			{
				#if HSCRIPT_ALLOWED
				loaded = (initHScript(path, autoCallbacks) != null || loaded);
				#end
			}
		}
		return loaded;
		#else
		return false;
		#end
	}

	/**
	 * Calls a function on all scripts.
	 * 
	 * @param 	func 			The name of the function to call.
	 * @param 	args 			An `Array` with the parameters to use in the function call.
	 * @param 	ignoreStops		Whether or not a `Function_Stop` should halt propagation in the remaining scripts.
	 * @param 	exclusions 		An `Array` of scripts to exclude in the call.
	 * @param 	excludeValues 	Values to exclude if the scripts have any return value.
	 * 
	 * @return 	Return value in last called script.
	*/
	public function callOnScripts(func:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>, ?excludeValues:Array<Dynamic>):Dynamic {
		excludeValues ??= [];
		excludeValues.push(LuaUtils.Function_Continue);
		
		var result:Dynamic = callOnLuas(func, args, ignoreStops, exclusions, excludeValues);
		if (result == null || excludeValues.contains(result))
			result = callOnHScript(func, args, ignoreStops, exclusions, excludeValues);
		
		return result;
	}
	/**
	 * Calls a function on all scripts. Separates Lua and HScript arguments.
	 * 
	 * @param 	func 			The name of the function to call.
	 * @param 	argsLua 		An `Array` with the parameters to use in the function call in Lua scripts.
	 * @param 	argsHScript 	An `Array` with the parameters to use in the function call in HScript scripts.
	 * @param 	ignoreStops		Whether or not a `Function_Stop` should halt propagation in the remaining scripts.
	 * @param 	exclusions 		An `Array` of scripts to exclude in the call.
	 * @param 	excludeValues 	Values to exclude if the scripts have any return value.
	 * 
	 * @return 	Return value in last called script.
	*/
	public function callOnScriptsExt(func:String, ?argsLua:Array<Dynamic>, ?argsHScript:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>, ?excludeValues:Array<Dynamic>):Dynamic {
		excludeValues ??= [];
		excludeValues.push(LuaUtils.Function_Continue);
		
		var result:Dynamic = callOnLuas(func, argsLua, ignoreStops, exclusions, excludeValues);
		if (result == null || excludeValues.contains(result))
			result = callOnHScript(func, argsHScript, ignoreStops, exclusions, excludeValues);
		
		return result;
	}
	/**
	 * Calls a function on all Lua scripts.
	 * 
	 * @param 	func 			The name of the function to call.
	 * @param 	args 			An `Array` with the parameters to use in the function call.
	 * @param 	ignoreStops		Whether or not a `Function_Stop` should halt propagation in the remaining scripts.
	 * @param 	exclusions 		An `Array` of scripts to exclude in the call.
	 * @param 	excludeValues 	Values to exclude if the scripts have any return value.
	 * 
	 * @return 	Return value in last called script.
	*/
	public function callOnLuas(func:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ?exclusions:Array<String>, ?excludeValues:Array<Dynamic>):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;
		#if LUA_ALLOWED
		if (luaArray == null) return returnVal;
		
		exclusions ??= [];
		excludeValues ??= [];
		excludeValues.push(LuaUtils.Function_Continue);

		var arr:Array<FunkinLua> = [];
		for (script in luaArray) 	{
			if (script.closed) {
				arr.push(script);
				continue;
			}

			if (exclusions.contains(script.scriptName))
				continue;

			var myValue:Dynamic = script.call(func, args);
			if ((myValue == LuaUtils.Function_StopLua || myValue == LuaUtils.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops) {
				returnVal = myValue;
				break;
			}

			if (myValue != null && !excludeValues.contains(myValue))
				returnVal = myValue;

			if (script.closed) arr.push(script);
		}

		if (arr.length > 0)
			for (script in arr)
				luaArray.remove(script);
		#end
		return returnVal;
	}
	/**
	 * Calls a function on all HScript scripts.
	 * 
	 * @param 	func 			The name of the function to call.
	 * @param 	args 			An `Array` with the parameters to use in the function call.
	 * @param 	ignoreStops		Whether or not a `Function_Stop` should halt propagation in the remaining scripts.
	 * @param 	exclusions 		An `Array` of scripts to exclude in the call.
	 * @param 	excludeValues 	Values to exclude if the scripts have any return value.
	 * 
	 * @return 	Return value in last called script.
	*/
	public function callOnHScript(funcToCall:String, ?args:Array<Dynamic>, ?ignoreStops:Bool = false, ?exclusions:Array<String>, ?excludeValues:Array<Dynamic>):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;

		#if HSCRIPT_ALLOWED
		if (hscriptArray == null) return returnVal;
		
		exclusions ??= [];
		excludeValues ??= [];
		excludeValues.push(LuaUtils.Function_Continue);
		
		for (script in hscriptArray) {
			if (script.closed || !script.exists(funcToCall) || exclusions.contains(script.origin))
				continue;

			var callValue = script.call(funcToCall, args);
			if (callValue != null) {
				var myValue:Dynamic = callValue.returnValue;

				if((myValue == LuaUtils.Function_StopHScript || myValue == LuaUtils.Function_StopAll) && !excludeValues.contains(myValue) && !ignoreStops) {
					returnVal = myValue;
					break;
				}

				if (myValue != null && !excludeValues.contains(myValue))
					returnVal = myValue;
			}
		}
		#end

		return returnVal;
	}
	
	/**
	 * Sets a variable on all scripts.
	 * 
	 * @param 	variable 		The name of the variable to set.
	 * @param 	value 			The value of the variable.
	 * @param 	exclusions 		An `Array` of scripts to exclude when setting.
	*/
	public function setOnScripts(variable:String, value:Dynamic, ?exclusions:Array<String>):Void {
		setOnLuas(variable, value, exclusions);
		setOnHScript(variable, value, exclusions);
	}
	/**
	 * Sets a variable on all Lua scripts.
	 * 
	 * @param 	variable 		The name of the variable to set.
	 * @param 	value 			The value of the variable.
	 * @param 	exclusions 		An `Array` of scripts to exclude when setting.
	*/
	public function setOnLuas(variable:String, value:Dynamic, ?exclusions:Array<String>):Void {
		#if LUA_ALLOWED
		if (luaArray == null) return;
		
		exclusions ??= [];
		for (script in luaArray) {
			if (script.closed || exclusions.contains(script.scriptName))
				continue;

			script.set(variable, value);
		}
		#end
	}
	/**
	 * Sets a variable on all HScript scripts.
	 * 
	 * @param 	variable 		The name of the variable to set.
	 * @param 	value 			The value of the variable.
	 * @param 	exclusions 		An `Array` of scripts to exclude when setting.
	*/
	public function setOnHScript(variable:String, value:Dynamic, ?exclusions:Array<String>):Void {
		#if HSCRIPT_ALLOWED
		if (hscriptArray == null) return;
		
		exclusions ??= [];
		for (script in hscriptArray) {
			if (script.closed || exclusions.contains(script.origin))
				continue;

			script.set(variable, value);
		}
		#end
	}
}
