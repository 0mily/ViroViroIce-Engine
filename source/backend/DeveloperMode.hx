package backend;

import flixel.FlxG;
import openfl.Lib;

/*
	still working on ts but you guys can actually use it, still pretty buggy, but it should work for most cases......
	You just need to reopen the game if volume and shit aint working well
*/

class DeveloperMode
{
	public static inline var TARGET_PC:String = 'pc';
	public static inline var TARGET_MOBILE:String = 'mobile';
	public static inline var MOBILE_WIDTH:Int = 1600;
	public static inline var MOBILE_HEIGHT:Int = 720;

	public static var target(default, null):String = TARGET_PC;
	public static var mobileSimulation(default, null):Bool = false;
	public static var pickerOpen:Bool = false;

	public static inline function actualMobileBuild():Bool
	{
		#if mobile
		return true;
		#else
		return false;
		#end
	}

	public static inline function isMobileLike():Bool
		return actualMobileBuild() || mobileSimulation;

	public static function getActualBuildTarget():String // luaUtils this is ugly
	{
		#if windows
		#if x86_BUILD
		return 'windows_x86'; #else return 'windows'; #end
		#elseif linux return 'linux';
		#elseif mac return 'mac';
		#elseif html5 return 'browser';
		#elseif android return 'android';
		// #elseif switch return 'switch'; who would even use this on switch lmao
		#else return 'unknown'; #end
	}

	public static inline function getScriptBuildTarget():String
		return mobileSimulation ? TARGET_MOBILE : getActualBuildTarget();

	public static function openPickerAllowed():Bool
		return ClientPrefs.data.developerMode && !pickerOpen;

	public static function selectPC():Void
	{
		target = TARGET_PC;
		mobileSimulation = false;
		FlxG.game.focusLostFramerate = 60; // reset to default value, just in case
		ResolutionManager.reset();
		hardReset();
	}

	public static function selectMobile():Void
	{
		target = TARGET_MOBILE;
		mobileSimulation = true;
		applyCurrentTarget();
		hardReset();
	}

	public static function applyCurrentTarget():Void
	{
		if(mobileSimulation)
		{
			forceWindowed();
			ResolutionManager.changeRes(MOBILE_WIDTH, MOBILE_HEIGHT, true);
			FlxG.game.focusLostFramerate = 30; // mobile games usually run at 30 fps when not focused, so might as well simulate that
			FlxG.mouse.visible = true;
		}
	}

	public static function update():Void
	{
		if(mobileSimulation)
			FlxG.mouse.visible = true;
	}

	static function hardReset():Void
	{
		pickerOpen = false;
		FlxG.resetGame();
	}

	static function forceWindowed():Void
	{
		#if desktop
		var window = Lib.application.window;
		if(window == null)
			return;
		window.fullscreen = false;
		window.maximized = false;
		#end
	}
}
