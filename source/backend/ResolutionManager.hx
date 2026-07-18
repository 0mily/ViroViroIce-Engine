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
	static var postResizeTimer:FlxTimer = null; // there, Julie
	static var rememberedWidth:Int = DEFAULT_WIDTH;
	static var rememberedHeight:Int = DEFAULT_HEIGHT;
	static var rememberedResizable:Bool = DEFAULT_RESIZABLE;
	static var suspendedForEditor:Bool = false;
	static var pendingWidth:Int = DEFAULT_WIDTH;
	static var pendingHeight:Int = DEFAULT_HEIGHT;
	static var pendingResizable:Bool = DEFAULT_RESIZABLE;
	static var hasPendingResolution:Bool = false;
	static var applyingPendingResolution:Bool = false;
	static var stateCreateResizeLock:Int = 0;
	static var suppressWindowResizeCenter:Bool = false;
	static var resolutionStateContext:Dynamic = null;
	static var windowCenterTimer:FlxTimer = null;

	public static function init():Void
	{
		if(initialized)
			return;
		initialized = true;
		FlxG.signals.preStateCreate.add(function(state)
		{
			syncForState(state);
		});

		#if desktop
		var window = Lib.application.window;
		if(window != null)
		{
			window.onResize.add(function(windowWidth:Int, windowHeight:Int)
			{
				if(!suppressWindowResizeCenter)
					requestWindowCenter(windowWidth, windowHeight);
			});
		}
		#end
	}

	public static function changeRes(width:Int, height:Int, resizable:Bool = true):Bool
	{
		width = Std.int(Math.max(1, width));
		height = Std.int(Math.max(1, height));

		rememberedWidth = width;
		rememberedHeight = height;
		rememberedResizable = resizable;
		changedByScript = width != DEFAULT_WIDTH || height != DEFAULT_HEIGHT || resizable != DEFAULT_RESIZABLE;

		if(shouldKeepDefaultResolutionActive())
		{
			suspendedForEditor = changedByScript;
			if(shouldDeferResolutionChange())
			{
				pendingWidth = DEFAULT_WIDTH;
				pendingHeight = DEFAULT_HEIGHT;
				pendingResizable = DEFAULT_RESIZABLE;
				hasPendingResolution = true;
				return true;
			}
			return applyResolution(DEFAULT_WIDTH, DEFAULT_HEIGHT, DEFAULT_RESIZABLE);
		}

		suspendedForEditor = false;
		if(shouldDeferResolutionChange())
		{
			pendingWidth = width;
			pendingHeight = height;
			pendingResizable = resizable;
			hasPendingResolution = true;
			return true;
		}
		return applyResolution(width, height, resizable);
	}

	public static function beginStateCreateResizeLock():Void
	{
		stateCreateResizeLock++;
	}

	public static function endStateCreateResizeLock():Void
	{
		stateCreateResizeLock = Std.int(Math.max(0, stateCreateResizeLock - 1));
		flushPendingResolution();
	}

	public static function flushPendingResolution():Void
	{
		if(!hasPendingResolution || stateCreateResizeLock > 0)
			return;

		hasPendingResolution = false;
		applyingPendingResolution = true;
		applyResolution(pendingWidth, pendingHeight, pendingResizable);
		applyingPendingResolution = false;
	}

	static function shouldDeferResolutionChange():Bool
	{
		if(applyingPendingResolution)
			return false;
		if(stateCreateResizeLock > 0)
			return true;
		#if GLOBAL_SCRIPTS
		return psychlua.GlobalScriptHandler.resetting;
		#else
		return false;
		#end
	}

	static function shouldKeepDefaultResolutionActive():Bool
		return suspendedForEditor || shouldUseDefaultResolution(getResolutionStateContext());

	static function applyResolution(width:Int, height:Int, resizable:Bool = true):Bool
	{
		var sameResolution:Bool = ResolutionManager.width == width && ResolutionManager.height == height && ResolutionManager.resizable == resizable;
		ResolutionManager.width = width;
		ResolutionManager.height = height;
		ResolutionManager.resizable = resizable;

		if(sameResolution)
			return true;

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
				suppressWindowResizeCenter = true;
				try
				{
					window.resize(width, height);
					requestWindowCenter(width, height);
				}
				catch(e:Dynamic)
				{
					suppressWindowResizeCenter = false;
					throw e;
				}
				suppressWindowResizeCenter = false;
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
				resolutionTween = null;
				tweenProxy = null;
				changeRes(targetWidth, targetHeight, resizable);
				requestWindowCenter(ResolutionManager.width, ResolutionManager.height);
				applyPostResizeFix();
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
		cancelTweenRes();
		rememberedWidth = DEFAULT_WIDTH;
		rememberedHeight = DEFAULT_HEIGHT;
		rememberedResizable = DEFAULT_RESIZABLE;
		suspendedForEditor = false;
		changedByScript = false;
		if(shouldDeferResolutionChange())
		{
			pendingWidth = DEFAULT_WIDTH;
			pendingHeight = DEFAULT_HEIGHT;
			pendingResizable = DEFAULT_RESIZABLE;
			hasPendingResolution = true;
			return true;
		}
		return applyResolution(DEFAULT_WIDTH, DEFAULT_HEIGHT, DEFAULT_RESIZABLE);
	}

	public static function resetForEditor(state:Dynamic):Void
	{
		resolutionStateContext = state;
		if(!changedByScript || state == null)
			return;

		if(shouldUseDefaultResolution(state))
		{
			suspendedForEditor = true;
			applyResolution(DEFAULT_WIDTH, DEFAULT_HEIGHT, DEFAULT_RESIZABLE);
		}
	}

	public static function restoreAfterEditor(state:Dynamic):Void
	{
		resolutionStateContext = state;
		if(!suspendedForEditor || !changedByScript || state == null || shouldUseDefaultResolution(state))
			return;

		suspendedForEditor = false;
		applyResolution(rememberedWidth, rememberedHeight, rememberedResizable);
	}

	public static function syncForState(state:Dynamic):Void
	{
		if(state != null)
			resolutionStateContext = state;

		if(shouldUseDefaultResolution(state))
			resetForEditor(state);
		else
			restoreAfterEditor(state);
	}

	public static inline function hasCustomResolution():Bool
		return width != DEFAULT_WIDTH || height != DEFAULT_HEIGHT;

	public static inline function hasRememberedCustomResolution():Bool
		return changedByScript;

	public static inline function isSuspendedForEditor():Bool
		return suspendedForEditor;

	public static inline function isTweening():Bool
		return resolutionTween != null;

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

		applyPostResizeFix();
	}

	static function applyPostResizeFix():Void
	{
		notifyPlayStateResize();

		if(resolutionTween != null)
			return;

		if(postResizeTimer != null)
		{
			postResizeTimer.cancel();
			postResizeTimer = null;
		}
		postResizeTimer = new FlxTimer().start(0, function(_)
		{
			CameraResizeFix.aplyAll();
			shaders.ShaderResizeFix.fixAll();
			notifyPlayStateResize();
			postResizeTimer = null;
		});
	}

	static function notifyPlayStateResize():Void
	{
		var playState = states.PlayState.instance;
		if(playState != null && (FlxG.state == playState || resolutionStateContext == playState))
			playState.applyResolutionLayout();
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

	static function requestWindowCenter(?targetWidth:Int, ?targetHeight:Int):Void
	{
		#if desktop
		var window = getApplicationWindow();
		if(window == null)
			return;

		centerWindow(window, targetWidth, targetHeight);

		if(resolutionTween != null)
			return;

		if(windowCenterTimer != null)
		{
			windowCenterTimer.cancel();
			windowCenterTimer = null;
		}

		windowCenterTimer = new FlxTimer().start(0.01, function(_)
		{
			centerWindow(window);
			windowCenterTimer = null;
		});
		#end
	}

	static function centerWindow(window:Dynamic, ?targetWidth:Int, ?targetHeight:Int):Void
	{
		#if desktop
		if(window == null || window.fullscreen || window.maximized)
			return;

		#if (cpp && windows)
		// Win32 works with the actual outer window rectangle, so it remains exact at 125%/150% DPI
		if(Native.centerWindow())
			return;
		#end

		var display = window.display;
		if(display == null)
			return;

		var bounds = display.safeArea != null ? display.safeArea : display.bounds;
		if(bounds == null)
			return;

		var centerWidth:Int = Std.int(Math.max(1, targetWidth != null && targetWidth > 0 ? targetWidth : window.width));
		var centerHeight:Int = Std.int(Math.max(1, targetHeight != null && targetHeight > 0 ? targetHeight : window.height));
		var nextX:Int = Std.int(bounds.x + (bounds.width - centerWidth) / 2);
		var nextY:Int = Std.int(bounds.y + (bounds.height - centerHeight) / 2);

		if(window.x != nextX || window.y != nextY)
			window.move(nextX, nextY);
		#end
	}

	static function getResolutionStateContext():Dynamic
		return resolutionStateContext != null ? resolutionStateContext : FlxG.state;

	static function shouldUseDefaultResolution(state:Dynamic):Bool
	{
		if(state == null)
			return false;

		var cls = Type.getClass(state);
		var className:String = cls == null ? '' : Type.getClassName(cls);
		var scriptStateName:String = null;
		if(Std.isOfType(state, backend.ScriptedSubState))
			scriptStateName = cast(state, backend.ScriptedSubState).customStateName();
		var data:Dynamic = state != null && Reflect.hasField(state, 'data') ? Reflect.field(state, 'data') : null;
		var aliasedState:Dynamic = data != null ? Reflect.field(data, 'aliasedState') : null;

		if(isDefaultResolutionStateName(className) || isDefaultResolutionStateName(scriptStateName) || isDefaultResolutionStateName(Std.string(aliasedState)))
			return true;

		return false;
	}

	static function isDefaultResolutionStateName(name:String):Bool
	{
		if(name == null)
			return false;

		name = name.trim();
		if(name.length < 1 || name == 'null')
			return false;

		var shortName:String = name;
		var dot:Int = shortName.lastIndexOf('.');
		if(dot >= 0)
			shortName = shortName.substr(dot + 1);

		if(name == 'states.editors.MasterEditorMenu' || shortName == 'MasterEditorMenu')
			return false;

		if(name == 'states.ContentMenuState' || shortName == 'ContentMenuState')
			return true;

		if(name.startsWith('states.editors.'))
			return true;

		return shortName.indexOf('Editor') >= 0 || shortName == 'ChartingState' || shortName == 'StickerTest';
	}
}
