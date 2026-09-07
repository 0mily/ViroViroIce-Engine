package mobile.backend;

import flixel.FlxG;
import flixel.FlxBasic;
import mobile.backend.flixel.input.TouchInputID;
import mobile.backend.flixel.TouchButton;

class MobileUtil {
	public static var isTouchActive(default, null):Bool = true;
	
	public static var mobileIDs:Map<String, Array<TouchInputID>> = [
		'note_up'		=> [NOTE_UP],
		'note_left'		=> [NOTE_LEFT],
		'note_down'		=> [NOTE_DOWN],
		'note_right'	=> [NOTE_RIGHT],

		'ui_up'			=> [UP],
		'ui_left'		=> [LEFT],
		'ui_down'		=> [DOWN],
		'ui_right'		=> [RIGHT],

		'accept'		=> [A],
		'back'			=> [B],
		'pause'			=> [NONE],
		'reset'			=> [NONE]
	];

	/**
	 * Check what the last input used by the player was.
	 * Call this in `main` or in the controller itself.
	 */
	public static function updateInputMethod():Void 
	{
		if (FlxG.touches.justStarted().length > 0) 
		{
			isTouchActive = true;
			return; 
		}

		if (FlxG.keys.justPressed.ANY) 
		{
			isTouchActive = false;
			return;
		}

		if (FlxG.gamepads.numActiveGamepads > 0) 
		{
			for (gamepad in FlxG.gamepads.getActiveGamepads()) 
			{
				if (gamepad.justPressed.ANY) 
				{
					isTouchActive = false;
					return;
				}
			}
		}
	}

	/**
	 * Updates the visibility and activation of an element and its internal buttons.
	 * @param container The main class that contains the buttons (e.g., this)
	 * @param buttons The array of buttons
	 */
	public static function setControlsState(container:FlxBasic, buttons:Array<TouchButton>):Void 
	{
		if (container.visible != isTouchActive) 
		{
			container.visible = isTouchActive;
			
			if (buttons != null) 
			{
				for (btn in buttons) 
				{
					btn.active = isTouchActive;
					btn.visible = isTouchActive;
				}
			}
		}
	}

	/**
	 * Formats the button name. If the user enters "a", it changes to "buttonA".
	 */
	private static function formatButtonName(name:String):String 
	{
		if (!StringTools.startsWith(name, "button")) {
			return "button" + name.charAt(0).toUpperCase() + name.substr(1);
		}
		return name;
	}

	/**
	 * Check if the button actually exists on the current VirtualPad.
	 */
	public static function hasButton(pad:Dynamic, buttonName:String):Bool 
	{
		if (pad == null || pad.getButton == null) return false;
		return pad.getButton(formatButtonName(buttonName)) != null;
	}

	/**
	 * Securely checks if the button was just pressed.
	 * Usage: MobileUtil.justPressed(virtualPad, 'a');
	 */
	public static function justPressed(pad:Dynamic, buttonName:String):Bool 
	{
		if (pad == null || pad.getButton == null) return false;
		var btn = pad.getButton(formatButtonName(buttonName));
		return (btn != null) ? btn.justPressed : false;
	}

	/**
	 * It securely checks if the button is being held down (Pressed).
	 * Usage: MobileUtil.pressed(virtualPad, 'up');
	 */
	public static function pressed(pad:Dynamic, buttonName:String):Bool 
	{
		if (pad == null || pad.getButton == null) return false;
		var btn = pad.getButton(formatButtonName(buttonName));
		return (btn != null) ? btn.pressed : false;
	}

	/**
	 * Check securely if the button has just been released.
	 * Usage: MobileUtil.justReleased(virtualPad, 'b');
	 */
	public static function justReleased(pad:Dynamic, buttonName:String):Bool 
	{
		if (pad == null || pad.getButton == null) return false;
		var btn = pad.getButton(formatButtonName(buttonName));
		return (btn != null) ? btn.justReleased : false;
	}
}