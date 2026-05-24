package psychlua;

#if GLOBAL_SCRIPTS
import flixel.FlxState;

class GlobalScriptHandler {
	public static var game(get, never):FlxState;
	public static var subState(get, never):FlxState;
	
	public static var resetting:Bool = false;
	
	static function get_game():FlxState {
		return FlxG.state;
	}
	static function get_subState():FlxState {
		var subState:FlxState = FlxG.state;
		
		while (subState.subState != null)
			subState = subState.subState;
		
		return subState;
	}
	
	#if HSCRIPT_ALLOWED
	public static var hscriptArray:Array<HScript> = []; // TODO: lua... also...
	public static function initHScript(file:String):HScript {
		var hs:HScript = HScript.initFromFile(file, null, HScriptGlobal);
		if (hs != null) hscriptArray.push(hs);
		
		return hs;
	}
	#end

	#if LUA_ALLOWED
	public static var luaArray:Array<FunkinLua> = [];
	public static function initLuaScript(file:String):FunkinLua {
		var lua:FunkinLua = FunkinLua.initFromFile(file, null);
		if (lua != null) luaArray.push(lua);

		return lua;
	}
	#end
	
	public static function init():Void {
		FlxG.signals.preUpdate.add(() -> call('onUpdate', [FlxG.elapsed]));
		FlxG.signals.postUpdate.add(() -> call('onUpdatePost', [FlxG.elapsed]));
	}
	public static function refreshScripts(complete:Bool = false):Void {
		if(!canRunOnCurrentState())
		{
			destroyScripts();
			return;
		}

		var tracked:Array<String> = [];
		var trackedLua:Array<String> = [];
		resetting = true;
		
		if (complete)
			destroyScripts();

		#if LUA_ALLOWED
		FunkinLua.registerFunctions();
		for (path in Mods.directoriesWithFile(Paths.getSharedPath(), 'data/global.lua')) {
			if (findLuaScript(path) != null || initLuaScript(path) != null)
				trackedLua.push(path);
		}
		#end
		
		#if HSCRIPT_ALLOWED
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'scripts/global')) {
			for (file in FileSystem.readDirectory(folder)) {
				var path:String = '$folder/$file';
				
				if (FileSystem.exists(path)) {
					if (findScript(path) != null || initHScript(path) != null)
						tracked.push(path);
				}
			}
		}
		
		var cleanup:Array<HScript> = [];
		for (hs in hscriptArray) {
			if (!tracked.contains(hs.filePath)) {
				destroyScript(hs);
				cleanup.push(hs);
			}
		}
		while (cleanup.length > 0)
			hscriptArray.remove(cleanup.shift());
		#end

		#if LUA_ALLOWED
		var cleanupLua:Array<FunkinLua> = [];
		for (lua in luaArray) {
			if (!trackedLua.contains(lua.scriptName)) {
				destroyLuaScript(lua);
				cleanupLua.push(lua);
			}
		}
		while (cleanupLua.length > 0)
			luaArray.remove(cleanupLua.shift());
		#end
	}
	public static function destroyScripts():Void {
		#if HSCRIPT_ALLOWED
		for (hs in hscriptArray)
			destroyScript(hs);
		hscriptArray.resize(0);
		#end

		#if LUA_ALLOWED
		for (lua in luaArray)
			destroyLuaScript(lua);
		luaArray.resize(0);
		#end
	}
	
	#if HSCRIPT_ALLOWED
	static function findScript(path:String):HScript {
		return Lambda.find(hscriptArray, (hs:HScript) -> (hs.filePath == path));
	}
	static function destroyScript(hs:HScript):Void {
		if (hs.exists('onDestroy'))
			hs.call('onDestroy');
		hs.destroy();
	}
	#end

	#if LUA_ALLOWED
	static function findLuaScript(path:String):FunkinLua {
		return Lambda.find(luaArray, (lua:FunkinLua) -> (lua.scriptName == path));
	}
	static function destroyLuaScript(lua:FunkinLua):Void {
		if(lua == null)
			return;
		lua.call('onDestroy');
		lua.stop();
	}
	#end
	
	public static function call(func:String, ?args:Array<Dynamic>, ?excludeValues:Array<Dynamic>):Dynamic {
		if(!canRunOnCurrentState() || isEditorCallbackTarget(func, args))
			return LuaUtils.Function_Continue;

		var returnVal:Dynamic = callOnHScript(func, args, excludeValues);
		#if LUA_ALLOWED
		if(returnVal == LuaUtils.Function_Continue)
			returnVal = callOnLuas(func, args, excludeValues);
		#end
		return returnVal;
	}
	public static function callOnHScript(func:String, ?args:Array<Dynamic>, ?excludeValues:Array<Dynamic>):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;
		
		#if HSCRIPT_ALLOWED
		if (hscriptArray == null) return returnVal;
		
		excludeValues ??= [];
		excludeValues.push(LuaUtils.Function_Continue);
		
		for (script in hscriptArray) {
			if (script == null || !script.exists(func))
				continue;
			
			var callValue:Dynamic = script.call(func, args);
			if (callValue != null) {
				var myValue:Dynamic = callValue.returnValue;
				
				if (myValue == LuaUtils.Function_StopHScript || myValue == LuaUtils.Function_StopAll) {
					return LuaUtils.Function_Stop;
				} else if (myValue != null && !excludeValues.contains(myValue)) {
					return myValue;
				}
			}
		}
		#end
		
		return returnVal;
	}

	#if LUA_ALLOWED
	public static function callOnLuas(func:String, ?args:Array<Dynamic>, ?excludeValues:Array<Dynamic>):Dynamic {
		var returnVal:Dynamic = LuaUtils.Function_Continue;

		if (luaArray == null) return returnVal;

		excludeValues ??= [];
		excludeValues.push(LuaUtils.Function_Continue);

		var luaArgs:Array<Dynamic> = makeLuaSafeArgs(args);
		updateLuaStateNames();

		var cleanup:Array<FunkinLua> = [];
		for (script in luaArray) {
			if (script == null || script.closed) {
				cleanup.push(script);
				continue;
			}

			var myValue:Dynamic = script.call(func, luaArgs);
			if ((myValue == LuaUtils.Function_StopLua || myValue == LuaUtils.Function_StopAll) && !excludeValues.contains(myValue))
			{
				returnVal = LuaUtils.Function_Stop;
				break;
			}

			if (myValue != null && !excludeValues.contains(myValue))
				returnVal = myValue;

			if (script.closed)
				cleanup.push(script);
		}

		for (script in cleanup)
			if(script != null)
				luaArray.remove(script);

		return returnVal;
	}
	#end
	
	public static function set(variable:String, args:Dynamic):Void {
		if(!canRunOnCurrentState())
			return;
		setOnHScript(variable, args);
		setOnLuas(variable, args);
	}
	public static function setOnHScript(variable:String, args:Dynamic):Void {
		#if HSCRIPT_ALLOWED
		if (hscriptArray == null) return;
		
		for (script in hscriptArray)
			script.set(variable, args);
		#end
	}
	public static function setOnLuas(variable:String, args:Dynamic):Void {
		#if LUA_ALLOWED
		if (luaArray == null) return;

		var value:Dynamic = makeLuaSafeValue(args);
		for (script in luaArray)
			if(script != null && !script.closed)
				script.set(variable, value);
		#end
	}

	public static function canRunOnCurrentState():Bool {
		var state:FlxState = FlxG.state;
		while(state != null)
		{
			if(isEditorState(state))
				return false;
			state = state.subState;
		}
		return true;
	}

	static function isEditorCallbackTarget(func:String, ?args:Array<Dynamic>):Bool {
		if(func != 'onSwitchState' || args == null || args.length < 1)
			return false;
		return isEditorStateValue(args[0]);
	}

	static function isEditorStateValue(value:Dynamic):Bool {
		if(value == null)
			return false;

		if(Std.isOfType(value, FlxState))
			return isEditorState(cast value);

		var cls:Class<Dynamic> = null;
		if(Std.isOfType(value, Class))
			cls = cast value;
		else
			cls = Type.getClass(value);

		var className:String = cls == null ? null : Type.getClassName(cls);
		return className != null && className.startsWith('states.editors.');
	}

	static function isEditorState(state:FlxState):Bool {
		if(state == null)
			return false;

		var cls = Type.getClass(state);
		var className:String = cls == null ? null : Type.getClassName(cls);
		return className != null && className.startsWith('states.editors.');
	}

	#if LUA_ALLOWED
	static function updateLuaStateNames():Void {
		var stateName:String = getStateName(game);
		var subStateName:String = getStateName(subState);
		for (script in luaArray)
		{
			if(script != null && !script.closed)
			{
				script.set('curStateName', stateName);
				script.set('curSubStateName', subStateName);
			}
		}
	}

	static function getStateName(state:FlxState):String {
		if(state == null)
			return '';

		var cls = Type.getClass(state);
		return cls == null ? '' : Type.getClassName(cls);
	}

	static function makeLuaSafeArgs(args:Array<Dynamic>):Array<Dynamic> {
		var safe:Array<Dynamic> = [];
		if(args != null)
			for(arg in args)
				safe.push(makeLuaSafeValue(arg));
		return safe;
	}

	static function makeLuaSafeValue(value:Dynamic):Dynamic {
		if(value == null)
			return null;

		return switch(Type.typeof(value)) {
			case TNull | TBool | TInt | TFloat:
				value;
			case TClass(String):
				value;
			case TClass(Array):
				[for(item in (cast value : Array<Dynamic>)) makeLuaSafeValue(item)];
			case TObject:
				value;
			default:
				var cls = Type.getClass(value);
				cls != null ? Type.getClassName(cls) : Std.string(value);
		}
	}
	#end
}

class HScriptGlobal extends HScript {
	public override function preset():Void {
		parentState = null;
		super.preset();
	}
	
	public override function getParent():Dynamic {
		return GlobalScriptHandler;
	}
	public override function getVariables():Map<String, Dynamic> {
		return HScript.globalStatic;
	}
}
#end
