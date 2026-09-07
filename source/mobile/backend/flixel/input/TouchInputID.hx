package mobile.backend.flixel.input;

import flixel.system.macros.FlxMacroUtil;

/**
 * just one class to store the IDs
 * @author StarNovaBR
 */
@:runtimeValue
enum abstract TouchInputID(Int) from Int to Int {
	public static var fromStringMap(default, null):Map<String, TouchInputID> = FlxMacroUtil.buildMap("mobile.backend.flixel.input.TouchInputID");
	public static var toStringMap(default, null):Map<TouchInputID, String> = FlxMacroUtil.buildMap("mobile.backend.flixel.input.TouchInputID", true);
	
	var ANY = -2;
	var NONE = -1;
	
	var A = 0;
	var B = 1;
	var C = 2;
	var D = 3;
	var E = 4;
	var V = 5;
	var X = 6;
	var Y = 7;
	var Z = 8;
	
	var UP = 9;
	var UP2 = 10;
	var DOWN = 11;
	var DOWN2 = 12;
	var LEFT = 13;
	var LEFT2 = 14;
	var RIGHT = 15;
	var RIGHT2 = 16;
	
	var NOTE_UP = 17;
	var NOTE_DOWN = 18;
	var NOTE_LEFT = 19;
	var NOTE_RIGHT = 20;

	@:from
	public static inline function fromString(s:String) {
		s = s.toUpperCase();
		return fromStringMap.exists(s) ? fromStringMap.get(s) : NONE;
	}

	@:to
	public inline function toString():String {
		return toStringMap.get(this);
	}
}