package mobile.backend;

import flixel.FlxObject;
import flixel.input.touch.FlxTouch;

/**
 * ...
 * @author: Karim Akra
 */
class TouchUtil
{
	public static inline var MAX_TAP_MOVEMENT:Float = 24;

	public static var pressed(get, never):Bool;
	public static var justPressed(get, never):Bool;
	public static var justReleased(get, never):Bool;
	public static var released(get, never):Bool;
	public static var justMoved(get, never):Bool;
	public static var deltaViewX(get, never):Float;
	public static var deltaViewY(get, never):Float;
	public static var viewX(get, never):Float;
	public static var viewY(get, never):Float;
	public static var touch(get, never):FlxTouch;

	static var trackingTap:Bool = false;
	static var tapMovedTooFar:Bool = false;
	static var tapStartX:Float = 0;
	static var tapStartY:Float = 0;
	static var lastDeltaTick:Int = -1;
	static var hasLastViewPosition:Bool = false;
	static var lastViewX:Float = 0;
	static var lastViewY:Float = 0;
	static var currentDeltaViewX:Float = 0;
	static var currentDeltaViewY:Float = 0;

	public static function overlaps(object:FlxObject, ?camera:FlxCamera):Bool
	{
		if(simulateMouseTouch() && FlxG.mouse.overlaps(object, camera ?? object.camera))
			return true;

		for (touch in FlxG.touches.list)
			if (touch.overlaps(object, camera ?? object.camera))
				return true;

		return false;
	}

	public static function overlapsComplex(object:FlxObject, ?camera:FlxCamera):Bool
	{
		if(simulateMouseTouch())
		{
			if (camera == null)
				for (camera in object.cameras)
					@:privateAccess
					if (object.overlapsPoint(FlxG.mouse.getWorldPosition(camera, object._point), true, camera))
						return true;
			else
				@:privateAccess
				if (object.overlapsPoint(FlxG.mouse.getWorldPosition(camera, object._point), true, camera))
					return true;
		}

		if (camera == null)
			for (camera in object.cameras)
				for (touch in FlxG.touches.list)
					@:privateAccess
					if (object.overlapsPoint(touch.getWorldPosition(camera, object._point), true, camera))
						return true;
		else
			@:privateAccess
			if (object.overlapsPoint(touch.getWorldPosition(camera, object._point), true, camera))
				return true;

		return false;
	}

	public static function pressAction(?object:FlxObject, ?camera:FlxCamera, useOverlapsComplex:Bool = true):Bool
	{
		syncTapState();

		if(!rawJustReleased() || tapMovedTooFar)
			return false;

		if(object == null)
			return true;

		return useOverlapsComplex ? overlapsComplex(object, camera) : overlaps(object, camera);
	}

	@:noCompletion
	private static function get_pressed():Bool
	{
		syncTapState();
		return rawPressed();
	}

	@:noCompletion
	private static function get_justPressed():Bool
	{
		syncTapState();
		return rawJustPressed();
	}

	@:noCompletion
	private static function get_justReleased():Bool
	{
		syncTapState();
		return rawJustReleased();
	}

	@:noCompletion
	private static function get_released():Bool
	{
		return rawReleased();
	}

	@:noCompletion
	private static function get_justMoved():Bool
		return Math.abs(deltaViewX) > 0 || Math.abs(deltaViewY) > 0;

	@:noCompletion
	private static function get_deltaViewX():Float
	{
		if(simulateMouseTouch())
			return FlxG.mouse.deltaViewX;

		syncPointerDelta();
		return currentDeltaViewX;
	}

	@:noCompletion
	private static function get_deltaViewY():Float
	{
		if(simulateMouseTouch())
			return FlxG.mouse.deltaViewY;

		syncPointerDelta();
		return currentDeltaViewY;
	}

	@:noCompletion
	private static function get_viewX():Float
		return rawViewX();

	@:noCompletion
	private static function get_viewY():Float
		return rawViewY();

	static function rawViewX():Float
	{
		if(simulateMouseTouch())
			return FlxG.mouse.viewX;

		var currentTouch:FlxTouch = touch;
		return currentTouch != null ? currentTouch.viewX : 0;
	}

	static function rawViewY():Float
	{
		if(simulateMouseTouch())
			return FlxG.mouse.viewY;

		var currentTouch:FlxTouch = touch;
		return currentTouch != null ? currentTouch.viewY : 0;
	}

	static function syncPointerDelta():Void
	{
		var tick:Int = FlxG.game != null ? FlxG.game.ticks : 0;
		if(lastDeltaTick == tick)
			return;
		lastDeltaTick = tick;

		var pointerActive:Bool = rawPressed() || rawJustPressed() || rawJustReleased();
		if(!pointerActive)
		{
			hasLastViewPosition = false;
			currentDeltaViewX = 0;
			currentDeltaViewY = 0;
			return;
		}

		var currentViewX:Float = rawViewX();
		var currentViewY:Float = rawViewY();
		if(!hasLastViewPosition || rawJustPressed())
		{
			currentDeltaViewX = 0;
			currentDeltaViewY = 0;
			hasLastViewPosition = true;
		}
		else
		{
			currentDeltaViewX = currentViewX - lastViewX;
			currentDeltaViewY = currentViewY - lastViewY;
		}

		lastViewX = currentViewX;
		lastViewY = currentViewY;
	}

	static function rawPressed():Bool
	{
		if(simulateMouseTouch())
			return FlxG.mouse.pressed;

		for (touch in FlxG.touches.list)
			if (touch.pressed)
				return true;

		return false;
	}

	static function rawJustPressed():Bool
	{
		if(simulateMouseTouch())
			return FlxG.mouse.justPressed;

		for (touch in FlxG.touches.list)
			if (touch.justPressed)
				return true;

		return false;
	}

	static function rawJustReleased():Bool
	{
		if(simulateMouseTouch())
			return FlxG.mouse.justReleased;

		for (touch in FlxG.touches.list)
			if (touch.justReleased)
				return true;

		return false;
	}

	static function rawReleased():Bool
	{
		if(simulateMouseTouch())
			return FlxG.mouse.released;

		for (touch in FlxG.touches.list)
			if (touch.released)
				return true;

		return false;
	}

	static function syncTapState():Void
	{
		var pointerJustPressed:Bool = rawJustPressed();
		var pointerPressed:Bool = rawPressed();
		var pointerJustReleased:Bool = rawJustReleased();

		if(pointerJustPressed || (pointerPressed && !trackingTap))
		{
			trackingTap = true;
			tapMovedTooFar = false;
			tapStartX = viewX;
			tapStartY = viewY;
		}

		if(trackingTap && (pointerPressed || pointerJustReleased))
		{
			var dx:Float = viewX - tapStartX;
			var dy:Float = viewY - tapStartY;
			if(Math.sqrt(dx * dx + dy * dy) > MAX_TAP_MOVEMENT)
				tapMovedTooFar = true;
		}

		if(trackingTap && !pointerPressed && !pointerJustReleased)
			trackingTap = false;
	}

	@:noCompletion
	private static function get_touch():FlxTouch
	{
		for (touch in FlxG.touches.list)
			if (touch != null)
				return touch;

		return FlxG.touches.getFirst();
	}

	static inline function simulateMouseTouch():Bool
	{
		#if desktop
		return backend.DeveloperMode.mobileSimulation;
		#else
		return false;
		#end
	}
}
