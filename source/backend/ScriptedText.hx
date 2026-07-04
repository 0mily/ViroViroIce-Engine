package backend;

class ScriptedText extends FlxText  {
	public function new(x:Float = 0, y:Float = 0, fieldWidth:Float = 0, ?text:String, size:Int = 8, embeddedFont:Bool = true)
	{
		super(x, y, fieldWidth, text, size, embeddedFont);
		antialiasing = ClientPrefs.data.antialiasing;
	}
}

// I NEED TO ORGANIZE MY IDEAS BETTER THAN THAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAATTT