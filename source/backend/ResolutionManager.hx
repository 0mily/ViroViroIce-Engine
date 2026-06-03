package backend;

import openfl.Lib;
import flixel.tweens.FlxEase.EaseFunction;

class ResolutionManager
{
	public static inline var DEFAULT_WIDTH:Int = 1280;
	public static inline var DEFAULT_HEIGHT:Int = 720;
	public static inline var DEFAULT_RESIZABLE:Bool = true;

	public static var width(default, null):Int = DEFAULT_WIDTH;
	public static var height(default, null):Int = DEFAULT_HEIGHT;
	public static var resizable(default, null):Bool = DEFAULT_RESIZABLE;
	public static var changedByScript:Bool = false;
	static var initialized:Bool = false;
	static var resolutionTween:FlxTween = null;
	static var tweenProxy:Dynamic = null;

	public static function init():Void
	{
		if(initialized)
			return;
		initialized = true;

		#if desktop
		var window = Lib.application.window;
		if(window != null)
		{
			window.onResize.add(function(windowWidth:Int, windowHeight:Int)
			{
				centerWindow(window);
			});
		}
		#end
	}

	public static function changeRes(width:Int, height:Int, resizable:Bool = true):Bool
	{
		width = Std.int(Math.max(1, width));
		height = Std.int(Math.max(1, height));

		ResolutionManager.width = width;
		ResolutionManager.height = height;
		ResolutionManager.resizable = resizable;
		changedByScript = width != DEFAULT_WIDTH || height != DEFAULT_HEIGHT || resizable != DEFAULT_RESIZABLE;

		var measureWidth:Int = getStageWidth(width);
		var measureHeight:Int = getStageHeight(height);
		var resizePhysicalWindow:Bool = true;

		#if (desktop || html5)
		var window = Lib.application.window;
		if(window != null)
		{
			if(window.fullscreen || window.maximized)
			{
				resizePhysicalWindow = false;
				if(!resizable)
				{
					if(window.fullscreen)
						window.fullscreen = false;
					if(window.maximized)
						window.maximized = false;
					resizePhysicalWindow = true;
				}
			}

			window.resizable = resizable;
			if(resizePhysicalWindow)
			{
				window.resize(width, height);
				centerWindow(window);
				measureWidth = width;
				measureHeight = height;
			}
		}
		#end

		applyBaseResolution(width, height, measureWidth, measureHeight);
		return true;
	}

	public static function tweenRes(width:Int, height:Int, duration:Float = 1, ?ease:EaseFunction, resizable:Bool = true, ?onComplete:FlxTween->Void):FlxTween
	{
		width = Std.int(Math.max(1, width));
		height = Std.int(Math.max(1, height));
		duration = Math.max(0, duration);

		cancelTweenRes();

		if(duration <= 0)
		{
			changeRes(width, height, resizable);
			if(onComplete != null)
				onComplete(null);
			return null;
		}

		var targetWidth:Int = width;
		var targetHeight:Int = height;
		tweenProxy = {
			width: ResolutionManager.width,
			height: ResolutionManager.height
		};

		resolutionTween = FlxTween.tween(tweenProxy, {width: targetWidth, height: targetHeight}, duration, {
			ease: ease ?? FlxEase.linear,
			onUpdate: function(twn:FlxTween)
			{
				changeRes(Std.int(Math.round(tweenProxy.width)), Std.int(Math.round(tweenProxy.height)), resizable);
			},
			onComplete: function(twn:FlxTween)
			{
				changeRes(targetWidth, targetHeight, resizable);
				resolutionTween = null;
				tweenProxy = null;
				if(onComplete != null)
					onComplete(twn);
			}
		});
		return resolutionTween;
	}

	public static function tweenResFrom(fromWidth:Int, fromHeight:Int, toWidth:Int, toHeight:Int, duration:Float = 1, ?ease:EaseFunction, resizable:Bool = true, ?onComplete:FlxTween->Void):FlxTween
	{
		changeRes(fromWidth, fromHeight, resizable);
		return tweenRes(toWidth, toHeight, duration, ease, resizable, onComplete);
	}

	public static function cancelTweenRes():Void
	{
		if(resolutionTween != null)
		{
			resolutionTween.cancel();
			resolutionTween.destroy();
			resolutionTween = null;
		}
		tweenProxy = null;
	}

	public static function reset():Bool
	{
		var changed:Bool = changeRes(DEFAULT_WIDTH, DEFAULT_HEIGHT, DEFAULT_RESIZABLE);
		changedByScript = false;
		return changed;
	}

	public static function resetForEditor(state:Dynamic):Void
	{
		if(!changedByScript || state == null)
			return;

		var cls = Type.getClass(state);
		var className:String = cls == null ? '' : Type.getClassName(cls);
		if(className != null && className.startsWith('states.editors.'))
			reset();
	}

	public static inline function hasCustomResolution():Bool
		return width != DEFAULT_WIDTH || height != DEFAULT_HEIGHT;

	public static function windowWidth(?fallback:Int = 0):Int
		return logicalWindowSize(true, fallback);

	public static function windowHeight(?fallback:Int = 0):Int
		return logicalWindowSize(false, fallback);

	public static function windowPixelWidth(?fallback:Int = 0):Int
	{
		var window = getApplicationWindow();
		if(window != null && window.width > 0)
			return Std.int(Math.max(1, window.width));
		return getStageWidth(normalizeFallback(fallback, width));
	}

	public static function windowPixelHeight(?fallback:Int = 0):Int
	{
		var window = getApplicationWindow();
		if(window != null && window.height > 0)
			return Std.int(Math.max(1, window.height));
		return getStageHeight(normalizeFallback(fallback, height));
	}

	static function applyBaseResolution(width:Int, height:Int, measureWidth:Int, measureHeight:Int):Void
	{
		@:privateAccess FlxG.initialWidth = width;
		@:privateAccess FlxG.initialHeight = height;
		refreshGameMeasure(measureWidth, measureHeight);
	}

	static function refreshGameMeasure(width:Int, height:Int):Void
	{
		if(FlxG.scaleMode == null)
			return;

		width = Std.int(Math.max(1, width));
		height = Std.int(Math.max(1, height));
		FlxG.resizeGame(width, height);

		if(FlxG.state != null)
			FlxG.state.onResize(width, height);

		if(FlxG.cameras != null)
			for(camera in FlxG.cameras.list)
				if(camera != null)
					camera.onResize();

		if(FlxG.signals != null)
			FlxG.signals.gameResized.dispatch(width, height);
	}

	static inline function getStageWidth(fallback:Int):Int
		return FlxG.stage != null ? Std.int(Math.max(1, FlxG.stage.stageWidth)) : fallback;

	static inline function getStageHeight(fallback:Int):Int
		return FlxG.stage != null ? Std.int(Math.max(1, FlxG.stage.stageHeight)) : fallback;

	static function logicalWindowSize(useWidth:Bool, fallback:Int):Int
	{
		fallback = normalizeFallback(fallback, useWidth ? width : height);
		var screenSize:Int = useWidth ? Std.int(Math.max(1, FlxG.width)) : Std.int(Math.max(1, FlxG.height));
		var result:Int = Std.int(Math.max(fallback, screenSize));

		if(FlxG.scaleMode != null && FlxG.scaleMode.deviceSize != null && FlxG.scaleMode.scale != null)
		{
			var scale:Float = useWidth ? FlxG.scaleMode.scale.x : FlxG.scaleMode.scale.y;
			if(scale > 0)
			{
				var device:Float = useWidth ? FlxG.scaleMode.deviceSize.x : FlxG.scaleMode.deviceSize.y;
				result = Std.int(Math.ceil(Math.max(result, device / scale)));
			}
		}
		else
		{
			var stageSize:Int = useWidth ? getStageWidth(fallback) : getStageHeight(fallback);
			result = Std.int(Math.max(result, stageSize));
		}

		return Std.int(Math.max(1, result));
	}

	static inline function normalizeFallback(fallback:Int, defaultValue:Int):Int
		return Std.int(Math.max(1, fallback > 0 ? fallback : defaultValue));

	static inline function getApplicationWindow():Dynamic
		return Lib.application != null ? Lib.application.window : null;

	static function centerWindow(window:Dynamic):Void
	{
		#if desktop
		if(window == null || window.fullscreen || window.maximized)
			return;

		var display = window.display;
		if(display == null)
			return;

		var bounds = display.safeArea != null ? display.safeArea : display.bounds;
		if(bounds == null)
			return;

		window.move(
			Std.int(bounds.x + (bounds.width - window.width) / 2),
			Std.int(bounds.y + (bounds.height - window.height) / 2)
		);
		#end
	}
}
