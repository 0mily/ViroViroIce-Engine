package milyMC;

import states.PlayState;

// shit to help Hscriptersss
class MilyMCFlow
{
	static inline function currentStep():Int
		return PlayState.instance?.curStep ?? 0;

	static inline function currentBeat():Int
		return PlayState.instance?.curBeat ?? 0;

	static function run(callback:Dynamic):Bool
	{
		if (callback == null || !Reflect.isFunction(callback))
			return false;
		Reflect.callMethod(null, callback, []);
		return true;
	}

	public static function range(first:Float, last:Float, callback:Dynamic, ?position:Null<Float>):Bool
	{
		var value:Float = position ?? currentStep();
		if (value < Math.min(first, last) || value > Math.max(first, last))
			return false;
		return run(callback);
	}

	public static function every(amount:Int, type:String, callback:Dynamic, ?position:Null<Int>):Bool
	{
		if (amount <= 0)
			return false;

		var mode:String = type == null ? 'steps' : type.toLowerCase();
		if (mode != 'steps' && mode != 'beats')
			return false;

		var value:Int = position ?? (mode == 'beats' ? currentBeat() : currentStep());
		if (value % amount != 0)
			return false;
		return run(callback);
	}

	public static function onSection(many:Int = 1, steps:Dynamic = null, callback:Dynamic = null, ?position:Null<Int>):Bool
	{
		if (Reflect.isFunction(steps) && callback == null)
		{
			callback = steps;
			steps = 0;
		}

		many = Std.int(Math.max(1, many));
		var localStep:Int = (position ?? currentStep()) % (many * 16);
		if (localStep < 0)
			localStep += many * 16;

		var matches:Bool = false;
		if (Std.isOfType(steps, Array))
		{
			for (step in (cast steps:Array<Dynamic>))
				if (Std.int(step) == localStep)
				{
					matches = true;
					break;
				}
		}
		else
			matches = Std.int(steps ?? 0) == localStep;

		return matches && run(callback);
	}
}
