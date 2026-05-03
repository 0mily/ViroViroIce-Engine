package backend;

import flixel.FlxState;
import backend.PsychCamera;
import psychlua.CustomState;

#if GLOBAL_SCRIPTS
import psychlua.GlobalScriptHandler;
#end

class MusicBeatState extends MusicBeatSubstate {
	public var camOther:FlxCamera = null;
	public static var timePassedOnState:Float = 0;
	@:dox(hide) var _psychCameraInitialized:Bool = false;
	
	public function new() {
		super();
	}
	
	/**
	 * Gets the current state.
	 * 
	 * @return 	The current `MusicBeatState`.
	*/
	public static inline function getState():MusicBeatSubstate {
		return cast (FlxG.state, MusicBeatSubstate);
	}
	/**
	 * Retrieves the current state's custom variables map.
	 * 
	 * @return 	The custom variables map.
	*/
	public static function getVariables():Map<String, Dynamic> {
		return FlxG.state.extraData;
	}

	public static function canseiOverride(?nextState:FlxState, allowStateAlias:Bool = true):FlxState {
		if (!allowStateAlias || nextState == null || nextState is CustomState)
			return nextState;

		var stateName:String = ScriptedSubState.getStateName(nextState);
		var alias:String = Mods.getStateScriptName(stateName);
		if (alias != null && alias.length > 0)
			return new CustomState(alias);
		return nextState;
	}

	public static function buildState(name:String, ?args:Array<Dynamic>, ?data:Dynamic, ignoreStateAlias:Bool = false):FlxState {
		if (name == null)
			return null;

		name = name.trim();
		if (name.length < 1)
			return null;

		var cls:Class<Dynamic> = Type.resolveClass(name);
		if (cls == null && name.indexOf('.') < 0)
			cls = Type.resolveClass('states.$name');
		if (cls == null && name.indexOf('.') < 0)
			cls = Type.resolveClass('options.$name');

		if (cls != null) {
			var state:FlxState = Type.createInstance(cls, args ?? []);
			return canseiOverride(state, !ignoreStateAlias);
		}

		return new CustomState(Mods.getStateName(name) ?? name, data);
	}

	public static function loadState(?nextState:FlxState, allowStateAlias:Bool = true):Void { // eu esqueci como eu fiz isso
		nextState = canseiOverride(nextState, allowStateAlias);
		if (nextState == null)
			return resetState();

		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;

		if (nextState is CustomState) {
			var customState:CustomState = cast nextState;
			FlxG.switchState(() -> new CustomState(customState.stateName, customState.data));
		} else {
			FlxG.switchState(nextState);
		}

		FlxTransitionableState.skipNextTransIn = false;
		FlxTransitionableState.skipNextTransOut = false;
	}
	
	public override function create() {
		#if MODS_ALLOWED Mods.updatedOnState = false; #end
		
		super.create();
		
		if (!FlxTransitionableState.skipNextTransOut && _requestedSubState == null)
			openSubState(new CustomFadeTransition(.5, true));
		FlxTransitionableState.skipNextTransOut = false;
		
		timePassedOnState = 0;
	}
	override function preCreate():Void {
		#if GLOBAL_SCRIPTS GlobalScriptHandler.refreshScripts(); #end
		
		if (camOther == null) {
			camOther = new FlxCamera();
			camOther.bgColor.alpha = 0;
			FlxG.cameras.add(camOther, false);
		}
		setVar('camOther', camOther);
		setVar('camHUD', camOther);
		
		if (!_psychCameraInitialized)
			initPsychCamera();
		
		super.preCreate();
	}
	@:dox(hide) override function _preCreate():Void {
		MusicBeatSubstate.callGlobal('onCreateState', [this, Type.getClass(this)]);
	}
	@:dox(hide) override function _postCreate():Void {
		MusicBeatSubstate.callGlobal('onCreateStatePost', [this, Type.getClass(this)]);
	}
	
	/**
	 * Initializes a PsychCamera and makes it the default camera.
	 * 
	 * @return 	A new `PsychCamera`.
	*/
	public function initPsychCamera():PsychCamera {
		var camera = new PsychCamera();
		FlxG.cameras.reset(camera);
		FlxG.cameras.setDefaultDrawTarget(camera, true);
		setVar('camMain', camera);
		setVar('camGame', camera);
		setVar('camHUD', camOther);
		_psychCameraInitialized = true;
		return camera;
	}

	/**
	 * Switches to a new state, playing a transition. Calls `onSwitchState` on global scripts.
	 * 
	 * @param 	nextState 	The next state to switch to.
	*/
	public static function switchState(?nextState:FlxState):Void {
		nextState = canseiOverride(nextState);
		if (MusicBeatSubstate.callGlobal('onSwitchState', [nextState, Type.getClass(nextState)]) != psychlua.LuaUtils.Function_Stop) {
			if (nextState == null)
				return resetState();
			
			if (FlxTransitionableState.skipNextTransIn) {
				FlxG.switchState(nextState); // actually just cant rid of this deprecated implementation or everything dies
			} else {
				startTransition(nextState);
			}
			
			FlxTransitionableState.skipNextTransIn = false;
		}
	}

	/**
	 * Resets the current state, playing a transition.
	*/
	public static function resetState():Void {
		if (FlxTransitionableState.skipNextTransIn) {
			FlxG.resetState();
		} else {
			startTransition();
		}
		
		FlxTransitionableState.skipNextTransIn = false;
	}

	// Custom made Trans in
	/**
	 * Starts a transition to a new state.
	 * 
	 * @param 	nextState 	The next state to switch to.
	*/
	public static function startTransition(?nextState:FlxState):Void {
		nextState = canseiOverride(nextState);
		FlxG.state.openSubState(new CustomFadeTransition(.5, false));
		
		nextState ??= FlxG.state;
		
		if (nextState is CustomState) {
			var customState:CustomState = cast nextState;
			CustomFadeTransition.finishCallback = () -> FlxG.switchState(() -> new CustomState(customState.stateName, customState.data));
		} else {
			if (nextState == FlxG.state) {
				CustomFadeTransition.finishCallback = () -> FlxG.resetState();
			} else {
				CustomFadeTransition.finishCallback = () -> FlxG.switchState(nextState);
			}
		}
	}
}
