package mobile.backend.flixel.input;

import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import mobile.backend.flixel.input.TouchInputID;
import mobile.backend.flixel.TouchButton;
import haxe.ds.Map;

/**
 * Virtual button manager for mobile devices
 * @Authors: StarNova (Cream.BR)
 */
class TouchInputManager extends FlxTypedSpriteGroup<TouchButton>
{
	/**
	 * A dictionary that maps unique IDs to the actual instances of the buttons
	 */
	public var activeButtons:Map<TouchInputID, TouchButton> = new Map<TouchInputID, TouchButton>();

	public function new()
	{
		super();
		refreshMappedButtons();
	}

	public inline function isPressed(id:TouchInputID):Bool
	{
		return checkButtonState(id, PRESSED);
	}

	public inline function isJustPressed(id:TouchInputID):Bool
	{
		return checkButtonState(id, JUST_PRESSED);
	}

	public inline function isJustReleased(id:TouchInputID):Bool
	{
		return checkButtonState(id, JUST_RELEASED);
	}

	public inline function isAnyPressed(ids:Array<TouchInputID>):Bool
	{
		return checkArrayState(ids, PRESSED);
	}

	public inline function isAnyJustPressed(ids:Array<TouchInputID>):Bool
	{
		return checkArrayState(ids, JUST_PRESSED);
	}

	public inline function isAnyJustReleased(ids:Array<TouchInputID>):Bool
	{
		return checkArrayState(ids, JUST_RELEASED);
	}


	/**
	 * Checks the status of a specific button, or handles special cases such as ANY and NONE
	 */
	public function checkButtonState(id:TouchInputID, state:InputState = JUST_PRESSED):Bool
	{
		switch (id)
		{
			case TouchInputID.ANY:
				for (btn in activeButtons)
				{
					if (getRawState(btn, state)) return true;
				}
				return false;

			case TouchInputID.NONE:
				return false;

			default:
				var btn = activeButtons.get(id);
				if (btn != null)
				{
					return getRawState(btn, state);
				}
		}
		return false;
	}

	function checkArrayState(ids:Array<TouchInputID>, state:InputState = JUST_PRESSED):Bool
	{
		if (ids == null || ids.length == 0) return false;

		for (id in ids)
		{
			if (checkButtonState(id, state)) return true;
		}

		return false;
	}

	/**
	 * Returns the button's boolean property based on the desired state
	 */
	inline function getRawState(btn:TouchButton, state:InputState):Bool
	{
		return switch (state)
		{
			case PRESSED:       btn.pressed;
			case JUST_PRESSED:  btn.justPressed;
			case JUST_RELEASED: btn.justReleased;
		}
	}

	/**
	 * Scan all buttons added to the group and catalog them in the Map
	 */
	public function refreshMappedButtons():Void
	{
		activeButtons.clear();
		
		forEachExists(function(btn:TouchButton)
		{
			if (btn.IDs != null)
			{
				for (id in btn.IDs)
				{
					if (!activeButtons.exists(id))
					{
						activeButtons.set(id, btn);
					}
				}
			}
		});
	}
}

/**
 * Possible input states
 */
enum InputState
{
	PRESSED;
	JUST_PRESSED;
	JUST_RELEASED;
}
