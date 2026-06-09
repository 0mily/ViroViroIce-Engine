package backend;

import flixel.FlxG;
import flash.media.Sound;

class EditorSFX
{
	static final CLICK_SOUNDS:Array<String> = ['click', 'click-alt']; // heheheheheh thats col

	public static function update():Void
	{
		if(!isEditorContext() || !FlxG.mouse.visible || (!FlxG.mouse.justPressed && !FlxG.mouse.justPressedRight))
			return;

		playClick();
	}

	public static function playClick(?volume:Float = 0.45):Void
	{
		if(!ClientPrefs.data.editorSFX)
			return;

		playEditorSound(CLICK_SOUNDS[FlxG.random.int(0, CLICK_SOUNDS.length - 1)], volume);
	}

	public static function playEditorSound(key:String, ?volume:Float = 0.65):Void
	{
		if(!ClientPrefs.data.editorSFX)
			return;

		play(Paths.editorSound(key), volume);
	}

	public static function playChartSound(key:String, ?volume:Float = 0.7):Void
	{
		if(!ClientPrefs.data.editorSFX)
			return;

		play(Paths.chartEditorSound(key), volume);
	}

	static function play(sound:Sound, volume:Float):Void
	{
		if(sound != null)
			FlxG.sound.play(sound, volume);
	}

	static function isEditorContext():Bool
	{
		if(isEditorObject(FlxG.state))
			return true;

		var subState:Dynamic = FlxG.state != null ? FlxG.state.subState : null;
		return isEditorObject(subState);
	}

	static function isEditorObject(object:Dynamic):Bool
	{
		if(object == null)
			return false;

		var cls = Type.getClass(object);
		var className:String = cls != null ? Type.getClassName(cls) : null;
		return className != null && className.indexOf('states.editors.') == 0;
	}
}
