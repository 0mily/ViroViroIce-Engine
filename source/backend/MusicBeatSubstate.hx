package backend;

import shaders.ErrorHandledShader;

#if GLOBAL_SCRIPTS
import psychlua.GlobalScriptHandler;
#end

using StringTools;

/**
 * MusicBeatSubstate is the base for most states and sub-states in the game.
 * It automatically handles rhythm events (step/beat/measure hits) and some scripting features.
*/
class MusicBeatSubstate extends flixel.FlxSubState {
	public static var instance:MusicBeatSubstate;
	static var editorFpsHideDepth:Int = 0;
	var stepsToDo:Int = 0;
	var _hidingFpsForEditor:Bool = false;
	var _lastUpdateElapsed:Float = 0;
	
	/**
	 * The current measure in the music.
	*/
	public var curSection:Int = 0;
	/**
	 * The current step (1/16th) in the music.
	*/
	public var curStep:Int = 0;
	/**
	 * The current beat in the music.
	*/
	public var curBeat:Int = 0;
	
	/**
	 * `curSection`, but as a decimal.
	*/
	public var curDecSection:Float = 0;
	/**
	 * `curStep`, but as a decimal.
	*/
	public var curDecStep:Float = 0;
	/**
	 * `curBeat`, but as a decimal.
	*/
	public var curDecBeat:Float = 0;

	/**
	 * Local BPM used when this state/substate drives its own rhythm clock.
	*/
	public var bpm(default, set):Float = 100;
	/**
	 * Whether this state/substate should use its own rhythm clock instead of `Conductor.songPosition`.
	*/
	public var useStateConductor:Bool = false;
	/**
	 * Local rhythm clock position, in milliseconds.
	*/
	public var stateConductorPosition:Float = 0;
	/**
	 * The active BPM for this state/substate.
	*/
	public var curBpm(get, never):Float;
	/**
	 * The active beat length, in milliseconds.
	*/
	public var crochet(get, never):Float;
	/**
	 * The active step length, in milliseconds.
	*/
	public var stepCrochet(get, never):Float;
	
	/**
	 * The time (in milliseconds) in delay for rhythm events.
	*/
	public var delay:Float = ClientPrefs.data.noteOffset;
	
	/**
	 * Whether the game should discard really late rhythm events or call them at once.
	*/
	public var keepUp:Bool = false;
	
	@:dox(hide) var _pre:Bool = false;
	
	/**
	 * Details for the Discord Rich Presence.
	*/
	public var rpcDetails:Null<String> = null;
	/**
	 * State for the Discord Rich Presence.
	*/
	public var rpcState:Null<String> = null;
	/**
	 * Whether the Discord Rich Presence should update automatically or not.
	*/
	public var autoUpdateRPC:Bool = true; //performance setting for custom RPC things
	
	public var parent:flixel.FlxState = null;
	
	public function new() {
		instance = this;
		super();
	}
	
	public override function create() {
		parent = _parentState;
		ResolutionManager.syncForState(this);
		subStateClosed.add((_) -> updatePresence());

		ResolutionManager.beginStateCreateResizeLock();
		if (!_pre) preCreate();
		ResolutionManager.endStateCreateResizeLock();
		super.create();

		verFPSsla(true);
		
		updatePresence();
		postCreate();
	}

	public override function close():Void
	{
		var parentState:flixel.FlxState = parent != null ? parent : _parentState;
		super.close();
		if(parentState != null)
			ResolutionManager.syncForState(parentState);
	}

	public override function onResize(Width:Int, Height:Int):Void
	{
		super.onResize(Width, Height);
		if(subState != null)
			subState.onResize(Width, Height);

		#if GLOBAL_SCRIPTS
		if(_pre)
			GlobalScriptHandler.callStateCallback('onResize', this, [Width, Height], parent != null || _parentState != null);
		#end
	}

	function verFPSsla(created:Bool):Void
	{
		var stateClass = Type.getClass(this);
		var className:String = stateClass == null ? '' : Type.getClassName(stateClass);
		var isEditor:Bool = className != null && className.startsWith('states.editors.');

		if(created)
		{
			if(isEditor && !_hidingFpsForEditor)
			{
				_hidingFpsForEditor = true;
				editorFpsHideDepth++;
			}
		}
		else if(_hidingFpsForEditor)
		{
			_hidingFpsForEditor = false;
			editorFpsHideDepth = Std.int(Math.max(0, editorFpsHideDepth - 1));
		}

		if(Main.fpsVar != null)
			Main.fpsVar.visible = editorFpsHideDepth <= 0 && ClientPrefs.data.showFPS;
	}
	/**
	 * Called in a state before finishing creation.
	*/
	public function preCreate():Void {
		_pre = true;
		
		_preCreate();
	}
	/**
	 * Called in a state after finishing creation.
	*/
	public function postCreate():Void {
		_postCreate();
	}
	function _preCreate():Void {
		callGlobal('onCreateSubState', [this, Type.getClass(this)]);
	}
	function _postCreate():Void {
		callGlobal('onCreateSubStatePost', [this, Type.getClass(this)]);
	}
	
	/**
	 * Updates the Discord Rich Presence.
	*/
	public function updatePresence():Void {
		#if DISCORD_ALLOWED
		if (autoUpdateRPC && (rpcDetails != null || rpcState != null))
			DiscordClient.changePresence(rpcDetails, rpcState);
		#end
	}
	
	/**
	 * Gets the `Controls` instance.
	*/
	public var controls(get, never):Controls;
	function get_controls():Controls {
		return Controls.instance;
	}

	#if (TOUCH_CONTROLS_ALLOWED && mobile)
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
	#end

	override function destroy():Void
	{
		#if GLOBAL_SCRIPTS
		if (parent == null)
			MusicBeatSubstate.callGlobal('onDestroyState', [this, Type.getClass(this)]);
		else
			MusicBeatSubstate.callGlobal('onDestroySubState', [this, Type.getClass(this)]);
		#end

		#if (TOUCH_CONTROLS_ALLOWED && mobile)
		removeTouchPad();
		removeHitbox();
		#end
		
		verFPSsla(false);
		super.destroy();
	}
	
	/**
	 * Gets this instance's custom variables map. Alias for `extraData`.
	*/
	public var variables(get, never):Map<String, Dynamic>;
	function get_variables():Map<String, Dynamic> {
		return extraData;
	}
	
	public override function update(elapsed:Float) {
		_lastUpdateElapsed = elapsed;
		EditorSFX.update();
		ScreenshotUtil.updateInput();
		DeveloperMode.update();

		if(FlxG.keys.justPressed.F9 && DeveloperMode.openPickerAllowed())
		{
			openSubState(new substates.DeveloperModeSubState());
			return;
		}

		if(FlxG.keys.justPressed.F12 && FlxG.keys.pressed.CONTROL)
		{
			FlxG.resetGame();
			return;
		}

		if (subState == null) {
			MusicBeatState.timePassedOnState += elapsed;
			
			if (FlxG.keys.justPressed.F5 #if GLOBAL_SCRIPTS && !GlobalScriptHandler.resetting #end) { // add keybind?
				reset();
			} #if GLOBAL_SCRIPTS else {
				GlobalScriptHandler.resetting = false;
			} #end
		}
		
		var oldStep:Int = curStep;
		updateStep();
		updateBeat();
		updateSection();
		
		if (oldStep != curStep) {
			if (keepUp) {
				while (++ oldStep < curStep)
					stepHit(oldStep);
			}
			stepHit(curStep);

			if (oldStep < curStep) {
				forwardSection();
			} else {
				rollbackSection();
			}
		}
		
		if (FlxG.save.data != null)
			FlxG.save.data.fullscreen = FlxG.fullscreen;
			
		stagesFunc((stage:BaseStage) -> stage.update(elapsed));
		super.update(elapsed);
	}
	/**
	 * Resets the current state.
	*/
	public function reset():Void {
		#if GLOBAL_SCRIPTS GlobalScriptHandler.refreshScripts(FlxG.keys.pressed.SHIFT); #end
		MusicBeatState.switchState(FlxG.state);
	}

	function set_bpm(newBPM:Float):Float {
		if (Math.isNaN(newBPM) || newBPM <= 0)
			newBPM = Conductor.bpm;

		useStateConductor = true;
		return bpm = newBPM;
	}

	function get_curBpm():Float {
		return useStateConductor ? bpm : Conductor.bpm;
	}

	function get_crochet():Float {
		return Conductor.calculateCrochet(curBpm);
	}

	function get_stepCrochet():Float {
		return crochet / 4;
	}

	public function setBPM(newBPM:Float, resetClock:Bool = false):Float {
		bpm = newBPM;
		if (resetClock)
			resetStateConductor();
		return bpm;
	}

	public inline function changeBPM(newBPM:Float, resetClock:Bool = false):Float {
		return setBPM(newBPM, resetClock);
	}

	public function resetStateConductor(position:Float = 0):Void {
		stateConductorPosition = position;
		curSection = 0;
		curStep = 0;
		curBeat = 0;
		curDecSection = 0;
		curDecStep = 0;
		curDecBeat = 0;
		stepsToDo = 0;
	}

	public function setStateConductorPosition(position:Float):Float {
		if (Math.isNaN(position))
			position = 0;
		stateConductorPosition = position;
		return stateConductorPosition;
	}

	public function useStateConductorClock(enabled:Bool = true, resetClock:Bool = false):Bool {
		useStateConductor = enabled;
		if (resetClock)
			resetStateConductor();
		return useStateConductor;
	}

	function usesSongSections():Bool {
		return Std.isOfType(this, states.PlayState);
	}
	
	function forwardSection():Void {
		if (stepsToDo < 1) stepsToDo = Math.round(getBeatsOnSection() * 4);
		
		if (curStep == 0) sectionHit(0); // idgaf

		if (!keepUp && !usesSongSections() && curStep - stepsToDo > 64)
		{
			var sectionSteps:Int = Math.round(getBeatsOnSection() * 4);
			if (sectionSteps < 1) sectionSteps = 16;
			curSection = Math.floor(curStep / sectionSteps);
			stepsToDo = (curSection + 1) * sectionSteps;
			updateSection();
			sectionHit(curSection);
			return;
		}
		
		while (curStep >= stepsToDo) {
			curSection ++;
			updateSection();
			sectionHit(curSection);
			
			stepsToDo += Math.round(getBeatsOnSection() * 4);
		}
	}
	function rollbackSection():Void {
		if (curStep < 0) return;

		var lastSection:Int = curSection;
		curSection = 0;
		stepsToDo = 0;

		if (PlayState.SONG == null || !usesSongSections()) {
			var sectionSteps:Int = Math.round(getBeatsOnSection() * 4);
			if (sectionSteps < 1) sectionSteps = 16;

			curSection = Math.floor(curStep / sectionSteps);
			stepsToDo = (curSection + 1) * sectionSteps;
			updateSection();

			if (curSection != lastSection)
				sectionHit(curSection);
			return;
		}

		for (section in PlayState.SONG.notes) {
			if (section != null) {
				stepsToDo += Math.round(getBeatsOnSection() * 4);
				if (stepsToDo > curStep)
					break;
				
				curSection ++;
			}
		}
		
		if (curSection > lastSection) {
			updateSection();
			sectionHit(curSection);
		}
	}
	/**
	 * Gets the amount of beats in a measure.
	 * 
	 * @param 	section 	The measure to get the amount of beats on. If unspecified, uses the current measure.
	 * 
	 * @return 	Amount of beats in the measure.
	*/
	public function getBeatsOnSection(?section:Int):Null<Float> {
		var val:Null<Float> = 4;
		section ??= curSection;
		
		if (PlayState.SONG != null && usesSongSections() && PlayState.SONG.notes[section] != null)
			val = PlayState.SONG.notes[section].sectionBeats;
		
		return (val == null ? 4 : val);
	}
	
	function updateStep():Void {
		if (useStateConductor) {
			stateConductorPosition += _lastUpdateElapsed * 1000;
			curDecStep = (stateConductorPosition - delay) / stepCrochet;
			curStep = Math.floor(curDecStep);
			return;
		}

		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);
		if (lastChange == null)
			lastChange = Conductor.defaultBPMChangeMap(Conductor.bpm)[0];

		var shit = ((Conductor.songPosition - delay) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = Math.floor(curDecStep);
	}
	function updateBeat():Void {
		curDecBeat = curDecStep / 4;
		curBeat = Math.floor(curDecBeat);
	}
	function updateSection():Void {
		if (PlayState.SONG == null || !usesSongSections()) {
			curDecSection = curDecBeat / getBeatsOnSection();
			return;
		}
		
		var lastSectionTime:Float = 0;
		var curCrochet:Float = Conductor.crochet;
		
		for (i => section in PlayState.SONG.notes) {
			curCrochet = Conductor.getBPMFromSeconds(lastSectionTime).stepCrochet * 4;
			var nextSectionTime = lastSectionTime + getBeatsOnSection(i) * curCrochet;
			
			if (nextSectionTime >= Conductor.songPosition - delay)
				break;
			
			lastSectionTime = nextSectionTime;
		}
		
		curDecSection = curSection + (Conductor.songPosition - delay - lastSectionTime) / curCrochet / getBeatsOnSection(curSection);
	}

	/**
	 * Called on a step hit.
	 * 
	 * @param 	step 	The current step.
	*/
	public function stepHit(step:Int):Void {
		stagesFunc(function(stage:BaseStage) {
			stage.curDecStep = curDecStep;
			stage.curStep = step;
			stage.stepHit();
		});

		if (step % 4 == 0)
			beatHit(curBeat);
		
		callGlobal('onStepHit', [step]);
	}
	/**
	 * Called on a beat hit.
	 * 
	 * @param 	beat 	The current beat.
	*/
	public function beatHit(beat:Int):Void {
		stagesFunc(function(stage:BaseStage) {
			stage.curDecBeat = curDecBeat;
			stage.curBeat = beat;
			stage.beatHit();
		});
		
		callGlobal('onBeatHit', [beat]);
	}
	/**
	 * Called on a measure hit.
	 * 
	 * @param 	section 	The current measure.
	*/
	public function sectionHit(section:Int):Void {
		stagesFunc(function(stage:BaseStage) {
			stage.curSection = section;
			stage.sectionHit();
		});
		
		callGlobal('onSectionHit', [section]);
	}
	
	/**
	 * Calls a function in all global scripts.
	 * 
	 * @param 	fun 	The name of the function to call.
	 * @param 	params 	An `Array` with the parameters to use in the function call.
	 * 
	 * @return 	Return value in last called global script.
	*/
	public static inline function callGlobal(fun:String, ?params:Array<Dynamic>):Dynamic {
		#if GLOBAL_SCRIPTS return GlobalScriptHandler.call(fun, params);
		#else return null; #end
	}
	
	/**
	 * Array containing stage instances.
	*/
	public var stages:Array<BaseStage> = [];
	/**
	 * Calls a function for every stage in the `stages` array.
	 * 
	 * @param 	func 	The function to call for each stage.
	*/
	public function stagesFunc(func:BaseStage->Void) {
		for (stage in stages)
			if(stage != null && stage.exists && stage.active)
				func(stage);
	}
	
	/**
	 * Shows a text string at the top-left of the game screen. Useful for debugging.
	 * 
	 * @param 	text 	The text to add.
	 * @param 	color 	The color of the text to add.
	 * @param 	size 	Optional parameter for the size of the text to add.
	*/
	public function addTextToDebug(text:String, ?color:FlxColor, ?size:Int) {
		ScriptedState.debugPrint(text, color, size);
	}
	
	/**
	 * Opens a sub-state. Calls `onOpenSubState` on global scripts.
	 * 
	 * @param 	subState 	The sub-state to open.
	*/
	public override function openSubState(subState:flixel.FlxSubState):Void {
		if (callGlobal('onOpenSubState', [subState, Type.getClass(subState)]) != psychlua.LuaUtils.Function_Stop)
			super.openSubState(subState);
	}
	
	// shaders
	#if sys
	/**
	 * Array containing cached runtime shaders.
	*/
	public var runtimeShaders:Map<String, Array<String>> = [];
	
	/**
	 * Creates a runtime shader.
	 * 
	 * @param 	shaderName 	The name of the shader to create.
	 * 
	 * @return 	A new `ErrorHandledRuntimeShader`.
	*/
	public function createRuntimeShader(shaderName:String):ErrorHandledRuntimeShader {
		if (!ClientPrefs.data.shaders)
			return new shaders.CodenameRuntimeShader(shaderName);
		
		if (!runtimeShaders.exists(shaderName) && !initRuntimeShader(shaderName)) {
			FlxG.log.warn('Shader $shaderName is missing!');
			return new shaders.CodenameRuntimeShader(shaderName);
		}
		
		var arr:Array<String> = runtimeShaders.get(shaderName);
		return new shaders.CodenameRuntimeShader(shaderName, arr[0], arr[1]);
	}
	
	/**
	 * Initializes the data of a runtime shader.
	 * 
	 * @param 	shaderName 	The name of the shader to initialize.
	 * @param 	glslVersion Unused...
	 * 
	 * @return 	Whether or not the shader data could be initialized.
	*/
	public function initRuntimeShader(name:String, glslVersion:Int = 120):Bool {
		if (!ClientPrefs.data.shaders)
			return false;
		
		if (runtimeShaders.exists(name)) {
			FlxG.log.warn('Shader $name is already initialized!');
			return true;
		}
		
		for (folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'shaders')) {
			var frag:String = '$folder/$name.frag';
			var vert:String = '$folder/$name.vert';
			
			if (FileSystem.exists(frag)) {
				frag = Paths.getTextFromFile(frag);
			} else {
				frag = null;
			}
			if (FileSystem.exists(vert)) {
				vert = Paths.getTextFromFile(vert);
			} else {
				vert = null;
			}

			if (frag != null || vert != null) {
				runtimeShaders.set(name, [frag, vert]);
				return true;
			}
		}
		#if (SCRIPTS_ALLOWED)
		Log.print('No .frag or .vert code found for shader "$name"!', ERROR);
		#else
		FlxG.log.warn('No .frag or .vert code found for shader "$name"!');
		#end
		
		return false;
	}
	
	/**
	 * Creates a runtime shader. Alias for `initRuntimeShader`.
	 * 
	 * @param 	shaderName 	The name of the shader to create.
	 * 
	 * @return 	A new `ErrorHandledRuntimeShader`.
	*/
	public function initLuaShader(name:String, ?glslVersion:Int):Bool { return initRuntimeShader(name, glslVersion); }
	#end
}
