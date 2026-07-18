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
	static var previousState:Void->FlxState = null;
	
	public function new() {
		super();
	}

	/*#if TOUCH_CONTROLS_ALLOWED // cara nem sei doido -Shiho
	public var touchPad:TouchPad;
	public var hitbox:Hitbox;
	public var camControls:FlxCamera;
	public var tpadCam:FlxCamera;

	public function addTouchPad(DPad:String, Action:String)
	{
		touchPad = new TouchPad(DPad, Action);
		add(touchPad);
	}

	public function removeTouchPad()
	{
		if (touchPad != null)
		{
			remove(touchPad);
			touchPad = FlxDestroyUtil.destroy(touchPad);
		}

		if(tpadCam != null)
		{
			FlxG.cameras.remove(tpadCam);
			tpadCam = FlxDestroyUtil.destroy(tpadCam);
		}
	}

	public function addHitbox(defaultDrawTarget:Bool = false):Void
	{
		var extraMode = MobileData.extraActions.get(ClientPrefs.data.extraHints);

		hitbox = new Hitbox(extraMode,MobileData.getButtonsColors());

		camControls = new FlxCamera();
		camControls.bgColor.alpha = 0;
		FlxG.cameras.add(camControls, defaultDrawTarget);

		hitbox.cameras = [camControls];
		hitbox.visible = false;
		add(hitbox);
	}

	public function removeHitbox()
	{
		if (hitbox != null)
		{
			remove(hitbox);
			hitbox = FlxDestroyUtil.destroy(hitbox);
			hitbox = null;
		}

		if(camControls != null)
		{
			FlxG.cameras.remove(camControls);
			camControls = FlxDestroyUtil.destroy(camControls);
		}
	}

	public function addTouchPadCamera(defaultDrawTarget:Bool = false):Void
	{
		if (touchPad != null)
		{
			tpadCam = new FlxCamera();
			tpadCam.bgColor.alpha = 0;
			FlxG.cameras.add(tpadCam, defaultDrawTarget);
			touchPad.cameras = [tpadCam];
		}
	}

	override function destroy()
	{
		removeTouchPad();
		removeHitbox();
		
		super.destroy();
	}
	#end*/
	
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
			return new CustomState(alias, {aliasedState: stateName});
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
		clearTransientStateManagers();
		ResolutionManager.syncForState(nextState);

		if (nextState is CustomState) {
			var customState:CustomState = cast nextState;
			FlxG.switchState(() -> new CustomState(customState.stateName, customState.data));
		} else {
			FlxG.switchState(nextState);
		}

		FlxTransitionableState.skipNextTransIn = false;
		FlxTransitionableState.skipNextTransOut = false;
	}

	static function stateFactoryFrom(state:FlxState):Void->FlxState {
		if (state == null)
			return null;

		if (state is CustomState) {
			var customState:CustomState = cast state;
			var name:String = customState.stateName;
			var data:Dynamic = customState.data;
			return () -> new CustomState(name, data);
		}

		var cls:Class<Dynamic> = Type.getClass(state);
		if (cls == null)
			return null;

		return function() {
			try return cast Type.createInstance(cls, []) catch (e:Dynamic) return null;
		}
	}

	static function rememberCurrentState():Void {
		var factory:Void->FlxState = stateFactoryFrom(FlxG.state);
		if (factory != null)
			previousState = factory;
	}

	public static function switchLastState():Bool {
		if (previousState == null)
			return false;

		var state:FlxState = previousState();
		if (state == null)
			return false;

		switchState(state);
		return true;
	}
	
	public override function create() {
		#if ADDONS_ALLOWED Mods.updatedOnState = false; #end
		
		super.create();
		
		if (!FlxTransitionableState.skipNextTransOut && _requestedSubState == null)
			openSubState(new CustomFadeTransition(.5, true));
		FlxTransitionableState.skipNextTransOut = false;
		
		timePassedOnState = 0;
	}
	override function preCreate():Void {
		ResolutionManager.syncForState(this);
		#if GLOBAL_SCRIPTS GlobalScriptHandler.refreshScripts(); #end
		
		if (camOther == null) {
			camOther = new PsychCamera();
			camOther.bgColor.alpha = 0;
			FlxG.cameras.add(camOther, false);
		}
		setVar('camOther', camOther);
		setVar('camHUD', camOther);
		
		if (!_psychCameraInitialized)
			initPsychCamera();
		
		super.preCreate();
	}

	public override function update(elapsed:Float):Void {
		#if ADDONS_ALLOWED
		if (FlxG.keys.justPressed.TAB && subState == null && isMainMenuContext(this))
		{
			FlxG.sound.play(Paths.uiSound('scrollMenu'), 0.6);
			switchState(new states.ContentMenuState());
			return;
		}
		#end
		super.update(elapsed);
	}

	public static function isMainMenuContext(state:Dynamic):Bool
	{
		if (state is states.MainMenuState)
			return true;

		if (state is CustomState)
		{
			var customState:CustomState = cast state;
			if (Mods.getStateName(customState.stateName) == 'MainMenuState')
				return true;

			var aliasedState:Dynamic = customState.data != null ? Reflect.field(customState.data, 'aliasedState') : null;
			if (aliasedState != null && Mods.getStateName(Std.string(aliasedState)) == 'MainMenuState')
				return true;
		}
		return false;
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

			rememberCurrentState();
			
			if (FlxTransitionableState.skipNextTransIn) {
				clearTransientStateManagers();
				ResolutionManager.syncForState(nextState);
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
			clearTransientStateManagers();
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
		clearTransientStateManagers();
		if(nextState != null)
			ResolutionManager.syncForState(nextState);
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

	static function clearTransientStateManagers():Void {
		flixel.util.FlxTimer.globalManager.clear();
		flixel.tweens.FlxTween.globalManager.clear();
	}
}
