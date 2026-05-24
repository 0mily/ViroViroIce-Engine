package backend;

import openfl.Lib;

class ResolutionManager
{
	public static inline var DEFAULT_WIDTH:Int = 1280;
	public static inline var DEFAULT_HEIGHT:Int = 720;
	public static inline var DEFAULT_RESIZABLE:Bool = true;

	public static var width(default, null):Int = DEFAULT_WIDTH;
	public static var height(default, null):Int = DEFAULT_HEIGHT;
	public static var resizable(default, null):Bool = DEFAULT_RESIZABLE;
	public static var changedByScript:Bool = false;

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
