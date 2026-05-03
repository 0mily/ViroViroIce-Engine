package psychlua;

import backend.Mods;
import backend.MusicBeatState;
import backend.ScriptedState;
import backend.ScriptedSubState;
import flixel.addons.transition.FlxTransitionableState;

#if LUA_ALLOWED
import psychlua.FunkinLua;
#end

#if HSCRIPT_ALLOWED
import psychlua.HScript;
#end

class CustomState extends ScriptedState {
	public var stateName:String;
	
	#if LUA_ALLOWED
	public static function implement() {
		FunkinLua.registerFunction('openCustomState', function(name:String, ?data:Dynamic) MusicBeatState.switchState(new CustomState(name, data)));
	}
	#end
	
	public function new(name:String, ?data:Dynamic) {
		super(data);
		stateName = name;
		multiScript = false;
	}

	function normalizarPorra(value:Dynamic):String {
		if (!Std.isOfType(value, String))
			return null;

		var state:String = cast value;
		state = state.trim();
		return state.length > 0 ? state : null;
	}

	#if LUA_ALLOWED
	function slaBuceta():String {
		var path:String = getSingleStateScriptPath(stateName, '.lua');
		if (path == null)
			return null;

		var probe:FunkinLua = null;
		try {
			probe = new FunkinLua(path, this);

			var forkState:String = normalizarPorra(probe.get('forkState'));
			if (forkState == null)
				forkState = normalizarPorra(probe.get('baseState'));
			if (forkState == null && probe.exists('getState'))
				forkState = normalizarPorra(probe.call('getState'));
			if (forkState == null && probe.exists('getBaseState'))
				forkState = normalizarPorra(probe.call('getBaseState'));

			probe.stop();
			return forkState;
		} catch (e:Dynamic) {
			probe?.stop();
		}
		return null;
	}
	#end

	#if HSCRIPT_ALLOWED
	function esuquecidoHaxe():String {
		var path:String = getSingleStateScriptPath(stateName, '.hx');
		if (path == null)
			return null;

		var probe:HScript = null;
		try {
			probe = new HScript(null, path, null, true, this);
			probe.execute();

			var forkState:String = normalizarPorra(probe.get('forkState'));
			if (forkState == null)
				forkState = normalizarPorra(probe.get('baseState'));
			if (forkState == null && probe.exists('getState'))
			{
				var ret = probe.call('getState');
				forkState = normalizarPorra(ret?.returnValue);
			}
			if (forkState == null && probe.exists('getBaseState'))
			{
				var ret = probe.call('getBaseState');
				forkState = normalizarPorra(ret?.returnValue);
			}

			probe.destroy();
			return forkState;
		} catch (e:Dynamic) {
			probe?.destroy();
		}
		return null;
	}
	#end

	function resolverState():String {
		var forkState:String = null;
		#if LUA_ALLOWED
		forkState = slaBuceta();
		#end
		#if HSCRIPT_ALLOWED
		if (forkState == null)
			forkState = esuquecidoHaxe();
		#end
		return forkState;
	}
	
	public override function create():Void {
		rpcDetails = 'Custom State ($stateName)';
		
		preCreate();
		super.create();
	}
	override function _preCreate():Void {
		var forkState:String = resolverState();
		if (forkState != null && Mods.getStateName(forkState) != Mods.getStateName(stateName))
		{
			var nextState = MusicBeatState.buildState(forkState, null, null, true);
			if (nextState != null && !(nextState is CustomState))
			{
				ScriptedSubState.scriptOverrideShit(ScriptedSubState.getStateName(nextState), stateName);
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
				MusicBeatState.loadState(nextState, false);
				return;
			}
		}

		var loaded:Bool = #if SCRIPTS_ALLOWED startStateScripts() #else false #end;
		
		if (!loaded) {
			FlxTransitionableState.skipNextTransIn = true;
			
			#if SCRIPTS_ALLOWED
			var e:String = 'Custom state script was not found / had errors, for "$stateName"';
			MusicBeatState.switchState(new states.ErrorState('$e\n\nPress ACCEPT to attempt to reload the state.\nPress BACK to return to Main Menu.',
				() -> MusicBeatState.switchState(new CustomState(stateName)),
				() -> MusicBeatState.switchState(new states.MainMenuState())
			));
			#else
			var e:String = 'Scripts are unsupported in this build';
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
