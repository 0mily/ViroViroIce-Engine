package funkin.objects;

class BGSprite extends objects.BGSprite
{
	public function new(?image:String, x:Float = 0, y:Float = 0, ?scrollX:Float = 1, ?scrollY:Float = 1, ?animArray:Array<String> = null, ?loop:Bool = false)
	{
		super(image, x, y, scrollX, scrollY, animArray, loop);
	}
}
