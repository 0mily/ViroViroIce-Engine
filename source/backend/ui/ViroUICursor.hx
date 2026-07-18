package backend.ui;

import backend.CustomCursor;
import flixel.FlxG;

class ViroUICursor
{
	static var current:String = '';

	public static function set(kind:String):Void
	{
		if(kind == null || kind.length < 1)
			kind = 'default';
		var expectedLeaf = 'cursor-$kind.png';
		if(current == kind && CustomCursor.ativo && FlxG.mouse != null && !FlxG.mouse.useSystemCursor && CustomCursor.curPath != null && CustomCursor.curPath.replace('\\', '/').endsWith(expectedLeaf))
			return;

		var scale:Float = switch(kind)
		{
			case 'cross': 0.65; // CARA É MUITO ENGRAÇADO GRANDEKKKKKKKKKKK
			case 'text': 0.22;
			default: 1;
		}
		CustomCursor.set('editors/ui/cursor/cursor-$kind', scale);
		current = kind;
	}

	public static function reset():Void
	{
		current = '';
		CustomCursor.reset();
	}
}
