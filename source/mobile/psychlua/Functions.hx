package mobile.psychlua;

import psychlua.CustomSubstate;
#if LUA_ALLOWED
import lime.ui.Haptic;
import psychlua.FunkinLua;
import psychlua.LuaUtils;
import mobile.backend.TouchUtil;
#if android import mobile.backend.PsychJNI; #end

/**
 * ...
 * @author: Karim Akra and Lily Ross (mcagabe19)
 */
#if TOUCH_CONTROLS_ALLOWED
class MobileFunctions
{
	public static function implement()
	{
		FunkinLua.registerFunction('mobileC', Controls.instance.mobileC);

		FunkinLua.registerFunction('mobileControlsMode', getMobileControlsAsString());

		FunkinLua.registerFunction("extraHintPressed", (button:String) ->
		{
			button = button.toLowerCase();
			if (MusicBeatState.getState().hitbox != null)
			{
				switch (button)
				{
					case 'second':
						return MusicBeatState.getState().hitbox.buttonExtra2.pressed;
					default:
						return MusicBeatState.getState().hitbox.buttonExtra.pressed;
				}
			}
			return false;
		});

		FunkinLua.registerFunction("extraHintJustPressed", (button:String) ->
		{
			button = button.toLowerCase();
			if (MusicBeatState.getState().hitbox != null)
			{
				switch (button)
				{
					case 'second':
						return MusicBeatState.getState().hitbox.buttonExtra2.justPressed;
					default:
						return MusicBeatState.getState().hitbox.buttonExtra.justPressed;
				}
			}
			return false;
		});

		FunkinLua.registerFunction("extraHintJustReleased", (button:String) ->
		{
			button = button.toLowerCase();
			if (MusicBeatState.getState().hitbox != null)
			{
				switch (button)
				{
					case 'second':
						return MusicBeatState.getState().hitbox.buttonExtra2.justReleased;
					default:
						return MusicBeatState.getState().hitbox.buttonExtra.justReleased;
				}
			}
			return false;
		});

		FunkinLua.registerFunction("extraHintReleased", (button:String) ->
		{
			button = button.toLowerCase();
			if (MusicBeatState.getState().hitbox != null)
			{
				switch (button)
				{
					case 'second':
						return MusicBeatState.getState().hitbox.buttonExtra2.released;
					default:
						return MusicBeatState.getState().hitbox.buttonExtra.released;
				}
			}
			return false;
		});

		FunkinLua.registerFunction("vibrate", (?duration:Int, ?period:Int) ->
		{
			if (duration == null)
				return FunkinLua.luaTrace('vibrate: No duration specified.');
			else if (period == null)
				period = 0;
			return Haptic.vibrate(period, duration);
		});

		FunkinLua.registerFunction("addTouchPad", (DPadMode:String, ActionMode:String, ?addToCustomSubstate:Bool = false, ?posAtCustomSubstate:Int = -1) ->
		{
			PlayState.instance.makeLuaTouchPad(DPadMode, ActionMode);
			if (addToCustomSubstate)
			{
				if (PlayState.instance.luaTouchPad != null || !PlayState.instance.members.contains(PlayState.instance.luaTouchPad))
					CustomSubstate.insertLuaTpad(posAtCustomSubstate);
			}
			else
				PlayState.instance.addLuaTouchPad();
		});

		FunkinLua.registerFunction("removeTouchPad", () ->
		{
			PlayState.instance.removeLuaTouchPad();
		});

		FunkinLua.registerFunction("addTouchPadCamera", () ->
		{
			if (PlayState.instance.luaTouchPad == null)
			{
				FunkinLua.luaTrace('addTouchPadCamera: Touch Pad does not exist.');
				return;
			}
			PlayState.instance.addLuaTouchPadCamera();
		});

		FunkinLua.registerFunction("touchPadJustPressed", function(button:Dynamic):Bool
		{
			if (PlayState.instance.luaTouchPad == null)
			{
				return false;
			}
			return PlayState.instance.luaTouchPadJustPressed(button);
		});

		FunkinLua.registerFunction("touchPadPressed", function(button:Dynamic):Bool
		{
			if (PlayState.instance.luaTouchPad == null)
			{
				return false;
			}
			return PlayState.instance.luaTouchPadPressed(button);
		});

		FunkinLua.registerFunction("touchPadJustReleased", function(button:Dynamic):Bool
		{
			if (PlayState.instance.luaTouchPad == null)
			{
				return false;
			}
			return PlayState.instance.luaTouchPadJustReleased(button);
		});

		FunkinLua.registerFunction("touchPadReleased", function(button:Dynamic):Bool
		{
			if (PlayState.instance.luaTouchPad == null)
			{
				return false;
			}
			return PlayState.instance.luaTouchPadReleased(button);
		});

		FunkinLua.registerFunction("touchJustPressed", TouchUtil.justPressed);
		FunkinLua.registerFunction("touchPressed", TouchUtil.pressed);
		FunkinLua.registerFunction("touchJustReleased", TouchUtil.justReleased);
		FunkinLua.registerFunction("touchReleased", TouchUtil.released);
		FunkinLua.registerFunction("touchPressedObject", function(object:String, ?camera:String):Bool
		{
			var obj = PlayState.instance.getLuaObject(object);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if (obj == null)
			{
				FunkinLua.luaTrace('touchPressedObject: $object does not exist.');
				return false;
			}
			return TouchUtil.overlaps(obj, cam) && TouchUtil.pressed;
		});

		FunkinLua.registerFunction("touchJustPressedObject", function(object:String, ?camera:String):Bool
		{
			var obj = PlayState.instance.getLuaObject(object);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if (obj == null)
			{
				FunkinLua.luaTrace('touchJustPressedObject: $object does not exist.');
				return false;
			}
			return TouchUtil.overlaps(obj, cam) && TouchUtil.justPressed;
		});

		FunkinLua.registerFunction("touchJustReleasedObject", function(object:String, ?camera:String):Bool
		{
			var obj = PlayState.instance.getLuaObject(object);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if (obj == null)
			{
				FunkinLua.luaTrace('touchJustReleasedObject: $object does not exist.');
				return false;
			}
			return TouchUtil.overlaps(obj, cam) && TouchUtil.justReleased;
		});

		FunkinLua.registerFunction("touchReleasedObject", function(object:String, ?camera:String):Bool
		{
			var obj = PlayState.instance.getLuaObject(object);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if (obj == null)
			{
				FunkinLua.luaTrace('touchReleasedObject: $object does not exist.');
				return false;
			}
			return TouchUtil.overlaps(obj, cam) && TouchUtil.released;
		});

		FunkinLua.registerFunction("touchPressedObjectComplex", function(object:String, ?camera:String):Bool
		{
			var obj = PlayState.instance.getLuaObject(object);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if (obj == null)
			{
				FunkinLua.luaTrace('touchPressedObjectComplex: $object does not exist.');
				return false;
			}
			return TouchUtil.overlapsComplex(obj, cam) && TouchUtil.pressed;
		});

		FunkinLua.registerFunction("touchJustPressedObjectComplex", function(object:String, ?camera:String):Bool
		{
			var obj = PlayState.instance.getLuaObject(object);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if (obj == null)
			{
				FunkinLua.luaTrace('touchJustPressedObjectComplex: $object does not exist.');
				return false;
			}
			return TouchUtil.overlapsComplex(obj, cam) && TouchUtil.justPressed;
		});

		FunkinLua.registerFunction("touchJustReleasedObjectComplex", function(object:String, ?camera:String):Bool
		{
			var obj = PlayState.instance.getLuaObject(object);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if (obj == null)
			{
				FunkinLua.luaTrace('touchJustReleasedObjectComplex: $object does not exist.');
				return false;
			}
			return TouchUtil.overlapsComplex(obj, cam) && TouchUtil.justReleased;
		});

		FunkinLua.registerFunction("touchReleasedObjectComplex", function(object:String, ?camera:String):Bool
		{
			var obj = PlayState.instance.getLuaObject(object);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if (obj == null)
			{
				FunkinLua.luaTrace('touchReleasedObjectComplex: $object does not exist.');
				return false;
			}
			return TouchUtil.overlapsComplex(obj, cam) && TouchUtil.released;
		});

		FunkinLua.registerFunction("touchOverlapsObject", function(object:String, ?camera:String):Bool
		{
			var obj = PlayState.instance.getLuaObject(object);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if (obj == null)
			{
				FunkinLua.luaTrace('touchOverlapsObject: $object does not exist.');
				return false;
			}
			return TouchUtil.overlaps(obj, cam);
		});

		FunkinLua.registerFunction("touchOverlapsObjectComplex", function(object:String, ?camera:String):Bool
		{
			var obj = PlayState.instance.getLuaObject(object);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if (obj == null)
			{
				FunkinLua.luaTrace('touchOverlapsObjectComplex: $object does not exist.');
				return false;
			}
			return TouchUtil.overlapsComplex(obj, cam);
		});
	}

	public static function getMobileControlsAsString():String
		return 'hitbox';
}

class MobileDeprecatedFunctions
{
	public static function implement(funk:FunkinLua)
	{
		var lua:State = funk.lua;
		FunkinLua.registerFunction("extraButtonPressed", (button:String) ->
		{
			FunkinLua.luaTrace("extraButtonPressed is deprecated! Use extraHintPressed instead", false, true);
			button = button.toLowerCase();
			if (MusicBeatState.getState().hitbox != null)
			{
				switch (button)
				{
					case 'second':
						return MusicBeatState.getState().hitbox.buttonExtra2.pressed;
					default:
						return MusicBeatState.getState().hitbox.buttonExtra.pressed;
				}
			}
			return false;
		});

		FunkinLua.registerFunction("extraButtonJustPressed", (button:String) ->
		{
			FunkinLua.luaTrace("extraButtonJustPressed is deprecated! Use extraHintJustPressed instead", false, true);
			button = button.toLowerCase();
			if (MusicBeatState.getState().hitbox != null)
			{
				switch (button)
				{
					case 'second':
						return MusicBeatState.getState().hitbox.buttonExtra2.justPressed;
					default:
						return MusicBeatState.getState().hitbox.buttonExtra.justPressed;
				}
			}
			return false;
		});

		FunkinLua.registerFunction("extraButtonJustReleased", (button:String) ->
		{
			FunkinLua.luaTrace("extraButtonJustReleased is deprecated! Use extraHintJustReleased instead", false, true);
			button = button.toLowerCase();
			if (MusicBeatState.getState().hitbox != null)
			{
				switch (button)
				{
					case 'second':
						return MusicBeatState.getState().hitbox.buttonExtra2.justReleased;
					default:
						return MusicBeatState.getState().hitbox.buttonExtra.justReleased;
				}
			}
			return false;
		});

		FunkinLua.registerFunction("extraButtonReleased", (button:String) ->
		{
			FunkinLua.luaTrace("extraButtonReleased is deprecated! Use extraHintReleased instead", false, true);
			button = button.toLowerCase();
			if (MusicBeatState.getState().hitbox != null)
			{
				switch (button)
				{
					case 'second':
						return MusicBeatState.getState().hitbox.buttonExtra2.released;
					default:
						return MusicBeatState.getState().hitbox.buttonExtra.released;
				}
			}
			return false;
		});
	}
}
#end

#if android
class AndroidFunctions
{
	// static var spicyPillow:AndroidBatteryManager = new AndroidBatteryManager();
	public static function implement(funk:FunkinLua)
	{
		var lua:State = funk.lua;
		// FunkinLua.registerFunction("isRooted", AndroidTools.isRooted());
		FunkinLua.registerFunction("isDolbyAtmos", AndroidTools.isDolbyAtmos());
		FunkinLua.registerFunction("isAndroidTV", AndroidTools.isAndroidTV());
		FunkinLua.registerFunction("isTablet", AndroidTools.isTablet());
		FunkinLua.registerFunction("isChromebook", AndroidTools.isChromebook());
		FunkinLua.registerFunction("isDeXMode", AndroidTools.isDeXMode());
		// FunkinLua.registerFunction("isCharging", spicyPillow.isCharging());

		FunkinLua.registerFunction("backJustPressed", FlxG.android.justPressed.BACK);
		FunkinLua.registerFunction("backPressed", FlxG.android.pressed.BACK);
		FunkinLua.registerFunction("backJustReleased", FlxG.android.justReleased.BACK);

		FunkinLua.registerFunction("menuJustPressed", FlxG.android.justPressed.MENU);
		FunkinLua.registerFunction("menuPressed", FlxG.android.pressed.MENU);
		FunkinLua.registerFunction("menuJustReleased", FlxG.android.justReleased.MENU);

		FunkinLua.registerFunction("getCurrentOrientation", () -> PsychJNI.getCurrentOrientationAsString());
		FunkinLua.registerFunction("setOrientation", function(?hint:String):Void
		{
			switch (hint.toLowerCase())
			{
				case 'portrait':
					hint = 'Portrait';
				case 'portraitupsidedown' | 'upsidedownportrait' | 'upsidedown':
					hint = 'PortraitUpsideDown';
				case 'landscapeleft' | 'leftlandscape':
					hint = 'LandscapeLeft';
				case 'landscaperight' | 'rightlandscape' | 'landscape':
					hint = 'LandscapeRight';
				default:
					hint = null;
			}
			if (hint == null)
				return FunkinLua.luaTrace('setOrientation: No orientation specified.');
			PsychJNI.setOrientation(FlxG.stage.stageWidth, FlxG.stage.stageHeight, false, hint);
		});

		FunkinLua.registerFunction("minimizeWindow", () -> AndroidTools.minimizeWindow());

		FunkinLua.registerFunction("showToast", function(text:String, ?duration:Int, ?xOffset:Int, ?yOffset:Int) /* , ?gravity:Int*/
		{
			if (text == null)
				return FunkinLua.luaTrace('showToast: No text specified.');
			else if (duration == null)
				return FunkinLua.luaTrace('showToast: No duration specified.');

			if (xOffset == null)
				xOffset = 0;
			if (yOffset == null)
				yOffset = 0;

			AndroidToast.makeText(text, duration, -1, xOffset, yOffset);
		});

		FunkinLua.registerFunction("isScreenKeyboardShown", () -> PsychJNI.isScreenKeyboardShown());

		FunkinLua.registerFunction("clipboardHasText", () -> PsychJNI.clipboardHasText());
		FunkinLua.registerFunction("clipboardGetText", () -> PsychJNI.clipboardGetText());
		FunkinLua.registerFunction("clipboardSetText", function(?text:String):Void
		{
			if (text != null)
				return FunkinLua.luaTrace('clipboardSetText: No text specified.');
			PsychJNI.clipboardSetText(text);
		});

		FunkinLua.registerFunction("manualBackButton", () -> PsychJNI.manualBackButton());

		FunkinLua.registerFunction("setActivityTitle", function(text:String):Void
		{
			if (text != null)
				return FunkinLua.luaTrace('setActivityTitle: No text specified.');
			PsychJNI.setActivityTitle(text);
		});
	}
}
#end
#end
