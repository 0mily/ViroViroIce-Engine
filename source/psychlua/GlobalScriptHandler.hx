package psychlua;

//recoded almost everything ashley hiiii


#if GLOBAL_SCRIPTS
import flixel.FlxState;
import sys.FileSystem;

class GlobalScriptHandler {
	public static var game(get, never):FlxState;
	public static var subState(get, never):FlxState;
	public static var resetting:Bool = false;

	#if HSCRIPT_ALLOWED
	public static var hscriptArray:Array<HScript> = [];
	#end
	#if LUA_ALLOWED
	public static var luaArray:Array<FunkinLua> = [];
	static var luaExistsCache:Map<FunkinLua, Map<String, Bool>> = [];
	#end

	static var initialized:Bool = false;
	static final STATE_CALLBACKS:Array<String> = [
		'onCreate',
		'onCreatePost',
		'onUpdate',
		'onUpdatePost',
		'onClose',
		'onClosePost',
		'onSwitch',
		'onSwitchPost',
		'onStepHit',
		'onBeatHit',
		'onSectionHit',
		'onResize'
	];

	static function get_game():FlxState {
		return FlxG.state;
	}

	static function get_subState():FlxState {
		var state:FlxState = FlxG.state;
		while (state != null && state.subState != null)
			state = state.subState;
		return state;
	}

	public static function init():Void {
		if (initialized)
			return;
		initialized = true;

		FlxG.signals.preUpdate.add(() -> updateCallbacks(false));
		FlxG.signals.postUpdate.add(() -> updateCallbacks(true));
	}

	static function updateCallbacks(post:Bool):Void {
		if (resetting || FlxG.state == null)
			return;

		var elapsed:Float = FlxG.elapsed;
		var suffix:String = post ? 'Post' : '';
		var updateFunc:String = 'onUpdate$suffix';
		var updateStateFunc:String = 'onUpdateState$suffix';
		var updateSubStateFunc:String = 'onUpdateSubState$suffix';
		var updateSubstateFunc:String = 'onUpdateSubstate$suffix';
		var state:FlxState = game;
		var currentSubState:FlxState = subState;

		if(!hasCallable(updateFunc)
			&& (state == null || !hasFilteredStateCallable(updateStateFunc, state))
			&& (currentSubState == null || currentSubState == state || (!hasFilteredStateCallable(updateSubStateFunc, currentSubState) && !hasFilteredStateCallable(updateSubstateFunc, currentSubState))))
			return;

		updateSharedVariables(false, game);
		call(updateFunc, [elapsed], null, false, false);

		if (state != null)
			call(updateStateFunc, [state, Type.getClass(state), elapsed], null, false, false);

		if (currentSubState != null && currentSubState != state)
			call(updateSubStateFunc, [currentSubState, Type.getClass(currentSubState), elapsed], null, false, false);
	}

	public static function refreshScripts(complete:Bool = false, allowEditor:Bool = false):Void {
		resetting = true;

		if (complete)
			destroyScripts();

		var files:Array<String> = collectScriptFiles();
		var tracked:Array<String> = [];

		#if LUA_ALLOWED
		FunkinLua.registerFunctions();
		#end

		for (path in files) {
			tracked.push(path);
			#if LUA_ALLOWED
			if (path.toLowerCase().endsWith('.lua')) {
				if (findLuaScript(path) == null)
					initLuaScript(path);
				continue;
			}
			#end

			#if HSCRIPT_ALLOWED
			if (HScript.hasScriptExtension(path) && findScript(path) == null)
				initHScript(path);
			#end
		}

		cleanupMissing(tracked);
		updateSharedVariables(allowEditor, game);
		resetting = false;
		backend.ResolutionManager.flushPendingResolution();
	}

	static function collectScriptFiles():Array<String> {
		var files:Array<String> = [];

		#if LUA_ALLOWED
		addGlobalFolderFiles(files, '.lua');
		addContentGlobalFolderFiles(files, '.lua');
		addDataGlobalFiles(files, '.lua');
		addContentDataGlobalFiles(files, '.lua');
		#end

		#if HSCRIPT_ALLOWED
		for (ext in HScript.SCRIPT_EXTENSIONS) {
			addGlobalFolderFiles(files, ext);
			addContentGlobalFolderFiles(files, ext);
			addDataGlobalFiles(files, ext);
			addContentDataGlobalFiles(files, ext);
		}
		#end

		return files;
	}

	static function addGlobalFolderFiles(files:Array<String>, extension:String):Void {
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'data/scripts/global')) {
			if (!FileSystem.exists(folder) || !FileSystem.isDirectory(folder))
				continue;

			for (file in FileSystem.readDirectory(folder)) {
				var path:String = '$folder/$file';
				if (FileSystem.exists(path) && !FileSystem.isDirectory(path) && path.toLowerCase().endsWith(extension))
					addUnique(files, path);
			}
		}
	}

	static function addContentGlobalFolderFiles(files:Array<String>, extension:String):Void {
		for (folder in contentGlobalRoots('data/scripts/global'))
			addFolderFiles(files, folder, extension);
	}

	static function addDataGlobalFiles(files:Array<String>, extension:String):Void {
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'data')) {
			if (!FileSystem.exists(folder) || !FileSystem.isDirectory(folder))
				continue;

			for (file in FileSystem.readDirectory(folder)) {
				var lower:String = file.toLowerCase();
				var path:String = '$folder/$file';
				if (lower.startsWith('global.') && lower.endsWith(extension) && FileSystem.exists(path) && !FileSystem.isDirectory(path))
					addUnique(files, path);
			}
		}
	}

	static function addContentDataGlobalFiles(files:Array<String>, extension:String):Void {
		for (folder in contentGlobalRoots('data'))
		{
			if (!FileSystem.exists(folder) || !FileSystem.isDirectory(folder))
				continue;

			for (file in FileSystem.readDirectory(folder)) {
				var lower:String = file.toLowerCase();
				var path:String = '$folder/$file';
				if (lower.startsWith('global.') && lower.endsWith(extension) && FileSystem.exists(path) && !FileSystem.isDirectory(path))
					addUnique(files, path);
			}
		}
	}

	static function contentGlobalRoots(path:String):Array<String> {
		var roots:Array<String> = [];
		#if ADDONS_ALLOWED
		var content:String = Mods.getSelectedContentDirectory();
		if (content != null && content.length > 0)
		{
			var root:String = Paths.contents('$content/global/$path');
			if (FileSystem.exists(root) && FileSystem.isDirectory(root))
				roots.push(root);
		}
		#end
		return roots;
	}

	static function addFolderFiles(files:Array<String>, folder:String, extension:String):Void {
		if (!FileSystem.exists(folder) || !FileSystem.isDirectory(folder))
			return;

		for (file in FileSystem.readDirectory(folder)) {
			var path:String = '$folder/$file';
			if (FileSystem.exists(path) && !FileSystem.isDirectory(path) && path.toLowerCase().endsWith(extension))
				addUnique(files, path);
		}
	}

	static function addUnique(files:Array<String>, path:String):Void {
		if (!files.contains(path))
			files.push(path);
	}

	static function cleanupMissing(tracked:Array<String>):Void {
		#if HSCRIPT_ALLOWED
		var deadHScript:Array<HScript> = [];
		for (script in hscriptArray)
			if (script == null || !tracked.contains(script.filePath))
				deadHScript.push(script);
		for (script in deadHScript) {
			destroyScript(script);
			hscriptArray.remove(script);
		}
		#end

		#if LUA_ALLOWED
		var deadLua:Array<FunkinLua> = [];
		for (script in luaArray)
			if (script == null || script.closed || !tracked.contains(script.scriptName))
				deadLua.push(script);
		for (script in deadLua) {
			destroyLuaScript(script);
			luaArray.remove(script);
		}
		#end
	}

	public static function destroyScripts():Void {
		#if HSCRIPT_ALLOWED
		for (script in hscriptArray)
			destroyScript(script);
		hscriptArray.resize(0);
		#end

		#if LUA_ALLOWED
		for (script in luaArray)
			destroyLuaScript(script);
		luaArray.resize(0);
		#end
	}

	#if HSCRIPT_ALLOWED
	public static function initHScript(file:String):HScript {
		var script:HScript = HScript.initFromFileWithVars(file, null, null, HScriptGlobal, (hs:HScript) -> {
			hs.set('editorBlock', true);
			hs.set('isGlobalScript', true);
		}, false);
		if (script != null) {
			hscriptArray.push(script);
			callHScriptLifecycle(script, 'onGlobalStartup');
			callHScriptLifecycle(script, 'onGlobalInit');
			callHScriptLifecycle(script, 'onCreateGlobal');
			callHScriptLifecycle(script, 'onGlobalStartupPost');
		}
		return script;
	}

	static function callHScriptLifecycle(script:HScript, func:String):Void {
		if (script != null && !script.closed && script.exists(func))
			script.call(func);
	}

	static function findScript(path:String):HScript {
		return Lambda.find(hscriptArray, (script:HScript) -> script != null && script.filePath == path);
	}

	static function destroyScript(script:HScript):Void {
		if (script == null)
			return;
		if (script.exists('onGlobalEnd'))
			script.call('onGlobalEnd');
		if (script.exists('onDestroy'))
			script.call('onDestroy');
		if (script.exists('onDestroyGlobal'))
			script.call('onDestroyGlobal');
		script.destroy();
	}
	#end

	#if LUA_ALLOWED
	public static function initLuaScript(file:String):FunkinLua {
		var script:FunkinLua = FunkinLua.initFromFile(file, game, (lua:FunkinLua) -> {
			lua.set('editorBlock', true);
			lua.set('isGlobalScript', true);
		}, false);
		if (script != null) {
			luaArray.push(script);
			luaExistsCache.set(script, []);
			callLuaLifecycle(script, 'onGlobalStartup');
			callLuaLifecycle(script, 'onGlobalInit');
			callLuaLifecycle(script, 'onCreateGlobal');
			callLuaLifecycle(script, 'onGlobalStartupPost');
		}
		return script;
	}

	static function callLuaLifecycle(script:FunkinLua, func:String):Void {
		if (script != null && !script.closed && luaHasFunction(script, func))
			script.call(func);
	}

	static function findLuaScript(path:String):FunkinLua {
		return Lambda.find(luaArray, (script:FunkinLua) -> script != null && script.scriptName == path);
	}

	static function destroyLuaScript(script:FunkinLua):Void {
		if (script == null)
			return;
		callLuaLifecycle(script, 'onGlobalEnd');
		callLuaLifecycle(script, 'onDestroy');
		callLuaLifecycle(script, 'onDestroyGlobal');
		luaExistsCache.remove(script);
		script.stop();
	}
	#end

	public static function call(func:String, ?args:Array<Dynamic>, ?excludeValues:Array<Dynamic>, allowEditor:Bool = false, syncVariables:Bool = true):Dynamic {
		if (syncVariables)
			updateSharedVariables(allowEditor, func == 'onSwitchState' ? FlxG.state : resolveTargetState(args));
		var returnVal:Dynamic = callOnHScript(func, args, excludeValues, allowEditor);
		#if LUA_ALLOWED
		if (returnVal == LuaUtils.Function_Continue)
			returnVal = callOnLuas(func, args, excludeValues, allowEditor);
		#end
		return returnVal;
	}

	public static function callStateCallback(baseName:String, state:Dynamic, ?extra:Array<Dynamic>, isSubState:Bool = false, syncVariables:Bool = true):Dynamic {
		var fullName:String = getStateName(cast state);
		var stateName:String = getShortStateName(fullName, state);
		var hscriptArgs:Array<Dynamic> = [stateName, state, Type.getClass(state), fullName];
		var luaArgs:Array<Dynamic> = [stateName, fullName];
		if (extra != null)
		{
			hscriptArgs = hscriptArgs.concat(extra);
			luaArgs = luaArgs.concat(extra);
		}

		var ret:Dynamic = call(baseName, extra, null, false, syncVariables);
		if (ret != LuaUtils.Function_Continue)
			return ret;

		var suffix:String = isSubState ? 'SubState' : 'State';
		ret = callFilteredStateCallback(baseName + suffix, stateName, fullName, hscriptArgs, luaArgs, syncVariables);
		if (ret != LuaUtils.Function_Continue)
			return ret;

		if (isSubState)
			return callFilteredStateCallback(baseName + 'Substate', stateName, fullName, hscriptArgs, luaArgs, syncVariables);
		return ret;
	}

	static function callFilteredStateCallback(func:String, stateName:String, fullName:String, hscriptArgs:Array<Dynamic>, luaArgs:Array<Dynamic>, syncVariables:Bool = true):Dynamic {
		var ret:Dynamic = callStateFunction(func, hscriptArgs, luaArgs, syncVariables);
		if (ret != LuaUtils.Function_Continue)
			return ret;

		var cleanBase:String = normalizeCallbackBase(func);
		if (cleanBase == null)
			return ret;

		var specific:String = cleanBase + stateName;
		if (specific != func)
		{
			ret = callStateFunction(specific, hscriptArgs, luaArgs, syncVariables);
			if (ret != LuaUtils.Function_Continue)
				return ret;
		}

		if (fullName != null && fullName.length > 0)
		{
			var fullSpecific:String = cleanBase + normalizeStateFilter(fullName, false);
			if (fullSpecific != specific && fullSpecific != func)
				ret = callStateFunction(fullSpecific, hscriptArgs, luaArgs, syncVariables);
		}
		return ret;
	}

	static function callStateFunction(func:String, hscriptArgs:Array<Dynamic>, luaArgs:Array<Dynamic>, syncVariables:Bool = true):Dynamic {
		if (syncVariables)
			updateSharedVariables(false, resolveTargetState(hscriptArgs));
		var returnVal:Dynamic = callOnHScript(func, hscriptArgs);
		#if LUA_ALLOWED
		if (returnVal == LuaUtils.Function_Continue)
			returnVal = callOnLuas(func, luaArgs);
		#end
		return returnVal;
	}

	public static function callOnHScript(func:String, ?args:Array<Dynamic>, ?excludeValues:Array<Dynamic>, allowEditor:Bool = false):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;

		#if HSCRIPT_ALLOWED
		if (hscriptArray == null)
			return returnVal;

		excludeValues ??= [];
		excludeValues.push(LuaUtils.Function_Continue);

		for (script in hscriptArray) {
			if (script == null || script.closed || !script.exists(func) || shouldBlockForEditor(scriptValue(script, 'editorBlock'), allowEditor))
				continue;

			var callValue = script.call(func, args);
			if (callValue == null)
				continue;

			var value:Dynamic = callValue.returnValue;
			if ((value == LuaUtils.Function_StopHScript || value == LuaUtils.Function_StopAll) && !excludeValues.contains(value))
				return LuaUtils.Function_Stop;
			if (value != null && !excludeValues.contains(value))
				return value;
		}
		#end

		return returnVal;
	}

	#if LUA_ALLOWED
	public static function callOnLuas(func:String, ?args:Array<Dynamic>, ?excludeValues:Array<Dynamic>, allowEditor:Bool = false):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;
		if (luaArray == null)
			return returnVal;

		excludeValues ??= [];
		excludeValues.push(LuaUtils.Function_Continue);

		var luaArgs:Array<Dynamic> = makeLuaSafeArgs(args);
		var cleanup:Array<FunkinLua> = [];
		for (script in luaArray) {
			if (script == null || script.closed) {
				cleanup.push(script);
				continue;
			}
			if (!luaHasFunction(script, func) || shouldBlockForEditor(script.get('editorBlock'), allowEditor))
				continue;

			var value:Dynamic = script.call(func, luaArgs);
			if ((value == LuaUtils.Function_StopLua || value == LuaUtils.Function_StopAll) && !excludeValues.contains(value)) {
				returnVal = LuaUtils.Function_Stop;
				break;
			}
			if (value != null && !excludeValues.contains(value))
				returnVal = value;
			if (script.closed)
				cleanup.push(script);
		}

		for (script in cleanup)
			if (script != null)
			{
				luaArray.remove(script);
				luaExistsCache.remove(script);
			}

		return returnVal;
	}

	// i'm not paid enough for this
	static function luaHasFunction(script:FunkinLua, func:String):Bool {
		if(script == null || script.closed)
			return false;

		var cache:Map<String, Bool> = luaExistsCache.get(script);
		if(cache == null)
		{
			cache = [];
			luaExistsCache.set(script, cache);
		}

		if(!cache.exists(func))
			cache.set(func, script.exists(func));
		return cache.get(func);
	}
	#end

	static function hasCallable(func:String, allowEditor:Bool = false):Bool {
		#if HSCRIPT_ALLOWED
		if (hscriptArray != null)
			for (script in hscriptArray)
				if (script != null && !script.closed && script.exists(func) && !shouldBlockForEditor(scriptValue(script, 'editorBlock'), allowEditor))
					return true;
		#end

		#if LUA_ALLOWED
		if (luaArray != null)
			for (script in luaArray)
				if (script != null && !script.closed && luaHasFunction(script, func) && !shouldBlockForEditor(script.get('editorBlock'), allowEditor))
					return true;
		#end

		return false;
	}

	static function hasFilteredStateCallable(func:String, state:Dynamic, allowEditor:Bool = false):Bool {
		if(hasCallable(func, allowEditor))
			return true;

		var fullName:String = getStateName(cast state);
		var stateName:String = getShortStateName(fullName, state);
		var cleanBase:String = normalizeCallbackBase(func);
		if(cleanBase == null)
			return false;

		if(stateName != null && stateName.length > 0 && hasCallable(cleanBase + stateName, allowEditor))
			return true;
		if(fullName != null && fullName.length > 0 && hasCallable(cleanBase + normalizeStateFilter(fullName, false), allowEditor))
			return true;
		return false;
	}

	public static function set(variable:String, value:Dynamic):Void {
		setOnHScript(variable, value);
		setOnLuas(variable, value);
	}

	public static function setOnHScript(variable:String, value:Dynamic):Void {
		#if HSCRIPT_ALLOWED
		if (hscriptArray == null)
			return;
		for (script in hscriptArray)
			if (script != null && !script.closed)
				script.set(variable, value);
		#end
	}

	public static function setOnLuas(variable:String, value:Dynamic):Void {
		#if LUA_ALLOWED
		if (luaArray == null)
			return;
		value = makeLuaSafeValue(value);
		for (script in luaArray)
			if (script != null && !script.closed)
				script.set(variable, value);
		#end
	}

	public static function canRunOnCurrentState():Bool {
		return !isEditorStateTree();
	}

	static function shouldBlockForEditor(editorBlock:Dynamic, allowEditor:Bool):Bool {
		return !allowEditor && isEditorStateTree() && editorBlock != false;
	}

	static function isEditorStateTree():Bool {
		var state:FlxState = FlxG.state;
		while (state != null) {
			if (isEditorState(state))
				return true;
			state = state.subState;
		}
		return false;
	}

	static function isEditorState(state:FlxState):Bool {
		if (state == null)
			return false;

		var cls = Type.getClass(state);
		var className:String = cls == null ? null : Type.getClassName(cls);
		return className != null && className.startsWith('states.editors.');
	}

	static function resolveTargetState(?args:Array<Dynamic>):FlxState {
		if (args != null && args.length > 0 && Std.isOfType(args[0], FlxState))
			return cast args[0];
		if (args != null && args.length > 1 && Std.isOfType(args[1], FlxState))
			return cast args[1];

		var currentSubState:FlxState = subState;
		if (currentSubState != null)
			return currentSubState;
		return game;
	}

	static function updateSharedVariables(allowEditor:Bool = false, ?targetState:FlxState):Void {
		var stateName:String = getStateName(game);
		var subStateName:String = getStateName(subState);
		var inEditor:Bool = isEditorStateTree();
		targetState ??= resolveTargetState();

		syncParentState(game);

		set('game', game);
		set('state', game);
		set('scriptState', targetState);
		set('subState', subState);
		set('curStateName', stateName);
		set('curSubStateName', subStateName);
		set('inEditor', inEditor);
		set('globalScriptsAllowEditor', allowEditor);
	}

	static function syncParentState(targetState:FlxState):Void {
		if (targetState == null)
			return;

		#if LUA_ALLOWED
		if (luaArray != null)
		{
			for (script in luaArray)
			{
				if (script == null || script.closed)
					continue;

				if (script.parentState != targetState)
				{
					script.parentState = targetState;
					if (Std.isOfType(targetState, backend.ScriptedSubState))
						cast(targetState, backend.ScriptedSubState).implementLua(script);
				}
			}
		}
		#end

		#if HSCRIPT_ALLOWED
		if (hscriptArray != null)
		{
			for (script in hscriptArray)
				if (script != null && !script.closed)
					script.parentState = targetState;
		}
		#end
	}

	static function getStateName(state:FlxState):String {
		if (state == null)
			return '';
		var cls = Type.getClass(state);
		return cls == null ? '' : Type.getClassName(cls);
	}

	static function getShortStateName(fullName:String, state:Dynamic):String {
		if (Std.isOfType(state, CustomState))
		{
			var customState:CustomState = cast state;
			if (customState.stateName != null && customState.stateName.trim().length > 0)
				return normalizeStateFilter(customState.stateName, true);
		}

		return normalizeStateFilter(fullName, true);
	}

	static function normalizeStateFilter(name:String, shortOnly:Bool):String {
		if (name == null)
			return '';
		name = name.replace('\\', '/').trim();
		if (name.length < 1)
			return '';
		if (name.endsWith('.lua'))
			name = name.substr(0, name.length - 4);
		else if (HScript.hasScriptExtension(name))
			for(ext in HScript.SCRIPT_EXTENSIONS)
				if (name.endsWith(ext))
					name = name.substr(0, name.length - ext.length);
		if (shortOnly)
		{
			var slash:Int = name.lastIndexOf('/');
			if (slash >= 0)
				name = name.substr(slash + 1);
			var dot:Int = name.lastIndexOf('.');
			if (dot >= 0)
				name = name.substr(dot + 1);
		}
		return name;
	}

	static function normalizeCallbackBase(func:String):String {
		for (base in STATE_CALLBACKS)
		{
			if (func == base + 'State' || func == base + 'SubState' || func == base + 'Substate')
				return func;
		}
		return null;
	}

	#if HSCRIPT_ALLOWED
	static function scriptValue(script:HScript, variable:String):Dynamic {
		try return script.get(variable) catch (e:Dynamic) return null;
	}
	#end

	#if LUA_ALLOWED
	static function makeLuaSafeArgs(args:Array<Dynamic>):Array<Dynamic> {
		var safe:Array<Dynamic> = [];
		if (args != null)
			for (arg in args)
				safe.push(makeLuaSafeValue(arg));
		return safe;
	}

	static function makeLuaSafeValue(value:Dynamic):Dynamic {
		if (value == null)
			return null;

		return switch (Type.typeof(value)) {
			case TNull | TBool | TInt | TFloat:
				value;
			case TClass(String):
				value;
			case TClass(Array):
				[for (item in (cast value : Array<Dynamic>)) makeLuaSafeValue(item)];
			case TObject:
				value;
			default:
				var cls = Type.getClass(value);
				cls != null ? Type.getClassName(cls) : Std.string(value);
		}
	}
	#end
}

#if HSCRIPT_ALLOWED
class HScriptGlobal extends HScript {
	public override function preset():Void {
		parentState = null;
		super.preset();
		set('editorBlock', true);
		set('isGlobalScript', true);
		set('GlobalScriptHandler', GlobalScriptHandler);
	}

	public override function getParent():Dynamic {
		return GlobalScriptHandler;
	}

	public override function getVariables():Map<String, Dynamic> {
		return HScript.globalStatic;
	}
}
#end
#end
