package backend;

import flixel.input.gamepad.FlxGamepadButton;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.gamepad.mappings.FlxGamepadMapping;
import flixel.input.keyboard.FlxKey;
#if mobile
import mobile.backend.flixel.input.TouchInputID;
import mobile.backend.MobileUtil;

private enum abstract InputMode(Int) {
	var PRESSED = 0;
	var JUST_PRESSED = 1;
	var JUST_RELEASED = 2;
}
#end

/**
 * Used to retrieve keybinds and inputs.
 * This class is designed to be a singleton, use `Controls.instance`!
*/
class Controls
{
	//Keeping same use cases on stuff for it to be easier to understand/use
	//I'd have removed it but this makes it a lot less annoying to use in my opinion

	//You do NOT have to create these variables/getters for adding new keys,
	//but you will instead have to use:
	//   controls.justPressed("ui_up")   instead of   controls.UI_UP

	//Dumb but easily usable code, or Smart but complicated? Your choice.
	//Also idk how to use macros they're weird as fuck lol

	// Pressed buttons (directions)
	public var UI_UP_P(get, never):Bool;
	public var UI_DOWN_P(get, never):Bool;
	public var UI_LEFT_P(get, never):Bool;
	public var UI_RIGHT_P(get, never):Bool;
	public var NOTE_UP_P(get, never):Bool;
	public var NOTE_DOWN_P(get, never):Bool;
	public var NOTE_LEFT_P(get, never):Bool;
	public var NOTE_RIGHT_P(get, never):Bool;
	private function get_UI_UP_P() return justPressed('ui_up');
	private function get_UI_DOWN_P() return justPressed('ui_down');
	private function get_UI_LEFT_P() return justPressed('ui_left');
	private function get_UI_RIGHT_P() return justPressed('ui_right');
	private function get_NOTE_UP_P() return justPressed('note_up');
	private function get_NOTE_DOWN_P() return justPressed('note_down');
	private function get_NOTE_LEFT_P() return justPressed('note_left');
	private function get_NOTE_RIGHT_P() return justPressed('note_right');

	// Held buttons (directions)
	public var UI_UP(get, never):Bool;
	public var UI_DOWN(get, never):Bool;
	public var UI_LEFT(get, never):Bool;
	public var UI_RIGHT(get, never):Bool;
	public var NOTE_UP(get, never):Bool;
	public var NOTE_DOWN(get, never):Bool;
	public var NOTE_LEFT(get, never):Bool;
	public var NOTE_RIGHT(get, never):Bool;
	private function get_UI_UP() return pressed('ui_up');
	private function get_UI_DOWN() return pressed('ui_down');
	private function get_UI_LEFT() return pressed('ui_left');
	private function get_UI_RIGHT() return pressed('ui_right');
	private function get_NOTE_UP() return pressed('note_up');
	private function get_NOTE_DOWN() return pressed('note_down');
	private function get_NOTE_LEFT() return pressed('note_left');
	private function get_NOTE_RIGHT() return pressed('note_right');

	// Released buttons (directions)
	public var UI_UP_R(get, never):Bool;
	public var UI_DOWN_R(get, never):Bool;
	public var UI_LEFT_R(get, never):Bool;
	public var UI_RIGHT_R(get, never):Bool;
	public var NOTE_UP_R(get, never):Bool;
	public var NOTE_DOWN_R(get, never):Bool;
	public var NOTE_LEFT_R(get, never):Bool;
	public var NOTE_RIGHT_R(get, never):Bool;
	private function get_UI_UP_R() return justReleased('ui_up');
	private function get_UI_DOWN_R() return justReleased('ui_down');
	private function get_UI_LEFT_R() return justReleased('ui_left');
	private function get_UI_RIGHT_R() return justReleased('ui_right');
	private function get_NOTE_UP_R() return justReleased('note_up');
	private function get_NOTE_DOWN_R() return justReleased('note_down');
	private function get_NOTE_LEFT_R() return justReleased('note_left');
	private function get_NOTE_RIGHT_R() return justReleased('note_right');


	// Pressed buttons (others)
	public var ACCEPT(get, never):Bool;
	public var BACK(get, never):Bool;
	public var PAUSE(get, never):Bool;
	public var RESET(get, never):Bool;
	private function get_ACCEPT() return justPressed('accept');
	private function get_BACK() return justPressed('back');
	private function get_PAUSE() return justPressed('pause');
	private function get_RESET() return justPressed('reset');

	//Gamepad, Keyboard stuff
	public var keyboardBinds:Map<String, Array<FlxKey>>;
	public var gamepadBinds:Map<String, Array<FlxGamepadInputID>>;
	#if mobile public var mobileBinds:Map<String, Array<TouchInputID>>; #end
	public function justPressed(key:String)
	{
		var result:Bool = (FlxG.keys.anyJustPressed(keyboardBinds[key]) == true);
		if(result) controllerMode = false;

		if(key == 'accept' && DeveloperMode.isMobileLike() && TouchUtil.pressAction())
			return true;

		return result || _myGamepadJustPressed(gamepadBinds[key]) == true #if mobile || hitboxJustPressed(mobileBinds[key]) == true || mobilePadJustPressed(mobileBinds[key]) == true #end;
	}

	public function pressed(key:String)
	{
		var result:Bool = (FlxG.keys.anyPressed(keyboardBinds[key]) == true);
		if(result) controllerMode = false; 

		return result || _myGamepadPressed(gamepadBinds[key]) == true #if mobile || hitboxPressed(mobileBinds[key]) == true || mobilePadPressed(mobileBinds[key]) == true #end;
	}

	public function justReleased(key:String)
	{
		var result:Bool = (FlxG.keys.anyJustReleased(keyboardBinds[key]) == true);
		if(result) controllerMode = false;

		return result || _myGamepadJustReleased(gamepadBinds[key]) == true #if mobile || hitboxJustReleased(mobileBinds[key]) == true || mobilePadJustReleased(mobileBinds[key]) == true #end;
	}

	public var controllerMode:Bool = false;
	private function _myGamepadJustPressed(keys:Array<FlxGamepadInputID>):Bool
	{
		if(keys != null)
		{
			for (key in keys)
			{
				if (FlxG.gamepads.anyJustPressed(key) == true)
				{
					controllerMode = true;
					return true;
				}
			}
		}
		return false;
	}
	private function _myGamepadPressed(keys:Array<FlxGamepadInputID>):Bool
	{
		if(keys != null)
		{
			for (key in keys)
			{
				if (FlxG.gamepads.anyPressed(key) == true)
				{
					controllerMode = true;
					return true;
				}
			}
		}
		return false;
	}
	private function _myGamepadJustReleased(keys:Array<FlxGamepadInputID>):Bool
	{
		if(keys != null)
		{
			for (key in keys)
			{
				if (FlxG.gamepads.anyJustReleased(key) == true)
				{
					controllerMode = true;
					return true;
				}
			}
		}
		return false;
	}
	
	#if mobile
	private var _wasInSubstate:Bool = false;
	private var _substateCloseTime:Float = 0;

	private var activePad(get, never):Dynamic;
	@:noCompletion private function get_activePad():Dynamic {
		var sub = FlxG.state.subState;
		
		if (sub != null && Std.isOfType(sub, ScriptedSubState)) {
			var mbs:ScriptedSubState = cast sub;
			if (mbs.virtualPad != null) return mbs.virtualPad;
		}
		
		return (ScriptedState.instance != null) ? ScriptedState.instance.virtualPad : null;
	}

	private var activeHitbox(get, never):Dynamic;
	@:noCompletion private function get_activeHitbox():Dynamic {
		var sub = FlxG.state.subState;
		
		if (sub != null && Std.isOfType(sub, ScriptedSubState)) {
			var mbs:ScriptedSubState = cast sub;
			if (mbs.hitbox != null) return mbs.hitbox;
		}
		
		return (ScriptedState.instance != null) ? ScriptedState.instance.hitbox : null;
	}

	private function processMobileInput(source:Dynamic, keys:Array<TouchInputID>, mode:InputMode):Bool {
		if (keys == null || source == null) return false;

		var sub = FlxG.state.subState;
		var hasSubControls = false;
		
		if (sub != null && Std.isOfType(sub, ScriptedSubState)) {
			var mbs:ScriptedSubState = cast sub;
			hasSubControls = (mbs.virtualPad != null || mbs.hitbox != null);
		}

		if (hasSubControls) {
			_wasInSubstate = true;
		} else if (_wasInSubstate) {
			_wasInSubstate = false;
			_substateCloseTime = haxe.Timer.stamp();
		}

		if (haxe.Timer.stamp() - _substateCloseTime < 0.1) return false;

		var isTriggered:Bool = switch (mode) {
			case PRESSED: source.isAnyPressed(keys);
			case JUST_PRESSED: source.isAnyJustPressed(keys);
			case JUST_RELEASED: source.isAnyJustReleased(keys);
		};

		if (isTriggered) {
			controllerMode = true; // !!DO NOT DISABLE IF YOU DO NOT WANT TO KILL INPUT MOBILE!!
			return true;
		}
		
		return false;
	}
	
	private function mobilePadPressed(keys:Array<TouchInputID>):Bool {
		return processMobileInput(activePad, keys, PRESSED);
	}
	
	private function mobilePadJustPressed(keys:Array<TouchInputID>):Bool {
		return processMobileInput(activePad, keys, JUST_PRESSED);
	}
	
	private function mobilePadJustReleased(keys:Array<TouchInputID>):Bool {
		return processMobileInput(activePad, keys, JUST_RELEASED);
	}
	
	private function hitboxPressed(keys:Array<TouchInputID>):Bool {
		return processMobileInput(activeHitbox, keys, PRESSED);
	}
	
	private function hitboxJustPressed(keys:Array<TouchInputID>):Bool {
		return processMobileInput(activeHitbox, keys, JUST_PRESSED);
	}
	
	private function hitboxJustReleased(keys:Array<TouchInputID>):Bool {
		return processMobileInput(activeHitbox, keys, JUST_RELEASED);
	}
	#end

	// IGNORE THESE
	public static var instance:Controls;
	public function new()
	{
		keyboardBinds = ClientPrefs.keyBinds;
		gamepadBinds = ClientPrefs.gamepadBinds;
		#if mobile mobileBinds = MobileUtil.mobileIDs; #end
	}
}
