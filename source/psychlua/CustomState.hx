package psychlua;

import backend.Mods;
import backend.MusicBeatState;
import backend.ScriptedState;
import backend.ScriptedSubState;
import flixel.addons.transition.FlxTransitionableState;

#if sys
import sys.io.File;
#end

#if LUA_ALLOWED
import psychlua.FunkinLua;
#end

#if HSCRIPT_ALLOWED
import psychlua.HScript;
#end

class CustomState extends ScriptedState {
	public var stateName:String;
	public static var fodaseStateName:String; // foda-se https://tenor.com/view/son-loaf-sonloaf-talking-to-wall-talking-to-a-wall-gif-16790865802997911039
	static var tempData:Map<String, Dynamic> = [];
	var cancelCreate:Bool = false;
	
	#if LUA_ALLOWED
	public static function implement() {
		FunkinLua.registerFunction('openCustomState', function(name:String, ?data:Dynamic) MusicBeatState.switchState(new CustomState(name, data)));
		FunkinLua.registerFunction('switchLastState', function() return MusicBeatState.switchLastState());
		FunkinLua.registerFunction('setStateTempData', function(key:String, value:Dynamic, ?state:String) return setTempData(key, value, state));
		FunkinLua.registerFunction('getStateTempData', function(key:String, ?fallback:Dynamic = null, ?state:String) return getTempData(key, fallback, state));
		FunkinLua.registerFunction('stateTempDataExists', function(key:String, ?state:String) return tempDataExists(key, state));
		FunkinLua.registerFunction('clearStateTempData', function(?key:String, ?state:String) return clearTempData(key, state));
	}
	#end

	static function currentStateName():String {
		if (FlxG.state is CustomState)
			return cast(FlxG.state, CustomState).stateName;
		return ScriptedSubState.getStateName(FlxG.state);
	}

	static function tempScope(?state:String):String {
		state = normalizarStatic(state) ?? Mods.getStateName(currentStateName()) ?? currentStateName() ?? 'global';
		var content:String = Mods.getSelectedContentDirectory();
		return '${content ?? ""}::$state';
	}

	static function tempKey(key:String, ?state:String):String {
		if (key == null)
			key = '';
		return tempScope(state) + '::' + key.trim();
	}

	static function normalizarStatic(value:Dynamic):String {
		if (!Std.isOfType(value, String))
			return null;

		var state:String = cast value;
		state = state.trim();
		return state.length > 0 ? state : null;
	}

	public static function setTempData(key:String, value:Dynamic, ?state:String):Dynamic {
		tempData.set(tempKey(key, state), value);
		return value;
	}

	public static function getTempData(key:String, ?fallback:Dynamic = null, ?state:String):Dynamic {
		var fullKey:String = tempKey(key, state);
		return tempData.exists(fullKey) ? tempData.get(fullKey) : fallback;
	}

	public static function tempDataExists(key:String, ?state:String):Bool {
		return tempData.exists(tempKey(key, state));
	}

	public static function clearTempData(?key:String, ?state:String):Bool {
		if (key != null && key.trim().length > 0)
			return tempData.remove(tempKey(key, state));

		var prefix:String = tempScope(state) + '::';
		var removed:Bool = false;
		for (storedKey in tempData.keys())
		{
			if (storedKey.startsWith(prefix))
			{
				tempData.remove(storedKey);
				removed = true;
			}
		}
		return removed;
	}

	public static function clearAllTempData():Void {
		tempData.clear();
	}

	public function new(name:String, ?data:Dynamic) {
		super(data);
		stateName = name;
		fodaseStateName = name; // foda-se
		multiScript = false;
		useStateConductorClock(true, true);
	}

	function readForkStateMetadata():String {
		#if sys
		var paths:Array<String> = [];
		#if LUA_ALLOWED
		var luaPath:String = getSingleStateScriptPath(stateName, '.lua');
		if (luaPath != null)
			paths.push(luaPath);
		#end
		#if HSCRIPT_ALLOWED
		var hscriptPath:String = getSingleStateScriptPath(stateName, '.hx');
		if (hscriptPath != null)
			paths.push(hscriptPath);
		#end

		for (path in paths)
		{
			try {
				var value:String = parseForkStateMetadata(File.getContent(path));
				if (value != null)
					return value;
			} catch (e:Dynamic) {}
		}
		#end
		return null;
	}

	static function parseForkStateMetadata(raw:String):String {
		if (raw == null)
			return null;

		var patterns:Array<EReg> = [
			~/^\s*(?:var\s+)?forkState\s*(?::\s*String)?\s*=\s*["']([^"']+)["']/m,
			~/^\s*(?:var\s+)?baseState\s*(?::\s*String)?\s*=\s*["']([^"']+)["']/m
		];

		for (pattern in patterns)
		{
			if (pattern.match(raw))
			{
				var value:String = normalizarStatic(pattern.matched(1));
				if (value != null)
					return value;
			}
		}
		return null;
	}

	public override function create():Void {
		rpcDetails = '$stateName';
		
		preCreate();
		if (cancelCreate)
			return;
		super.create();
	}
	override function _preCreate():Void {
		var forkState:String = readForkStateMetadata();
		if (forkState != null && Mods.getStateName(forkState) != Mods.getStateName(stateName))
		{
			var nextState = MusicBeatState.buildState(forkState, null, null, true);
			if (nextState != null && !(nextState is CustomState))
			{
				ScriptedSubState.scriptOverrideShit(ScriptedSubState.getStateName(nextState), stateName);
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
				cancelCreate = true;
				MusicBeatState.loadState(nextState, false);
				return;
			}
		}

		var loaded:Bool = #if SCRIPTS_ALLOWED startStateScripts() #else false #end;
		
		if (!loaded) {
			FlxTransitionableState.skipNextTransIn = true;
			
			#if SCRIPTS_ALLOWED
			var e:String = 'Custom state script was not found / had errors, for "$stateName"';
			cancelCreate = true;
			MusicBeatState.switchState(new states.ErrorState('$e\n\nPress ACCEPT to attempt to reload the state.\nPress BACK to return to Main Menu.',
				() -> MusicBeatState.switchState(new CustomState(stateName)),
				() -> MusicBeatState.switchState(new states.MainMenuState())
			));
			#else
			var e:String = 'Scripts are unsupported in this build';
			cancelCreate = true;
			MusicBeatState.switchState(new states.ErrorState('$e\n\nPress ACCEPT or BACK to return to Main Menu.',
				() -> MusicBeatState.switchState(new states.MainMenuState()),
				() -> MusicBeatState.switchState(new states.MainMenuState())
			));
			#end
		}
	}
	
	public override function update(elapsed:Float):Void {
		preUpdate(elapsed);
		super.update(elapsed);
		postUpdate(elapsed);
	}
	
	public override function customStateName():String {
		return stateName;
	}
}
