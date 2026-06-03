package funkin.objects;

import flixel.FlxBasic;
import flixel.FlxSprite;

class SnowEmitter extends FlxBasic
{
	public var frequency:Float = 0.05;
	public var speed:SnowEmitterRange = new SnowEmitterRange();
	public var alpha:SnowEmitterRange = new SnowEmitterRange(1, 1);
	public var scrollFactor:SnowEmitterScrollFactor = new SnowEmitterScrollFactor();
	public var onEmit:SnowEmitterSignal = new SnowEmitterSignal();

	public function new(x:Float = 0, y:Float = 0, width:Float = 0)
	{
		super();
	}

	public function start(explode:Bool = false, frequency:Float = 0.05):SnowEmitter
	{
		this.frequency = frequency;
		return this;
	}
}

class SnowEmitterRange
{
	public var min:Float;
	public var max:Float;
	public var active:Bool = true;

	public function new(min:Float = 0, max:Float = 0)
	{
		this.min = min;
		this.max = max;
	}

	public function set(min:Float = 0, max:Float = 0):SnowEmitterRange
	{
		this.min = min;
		this.max = max;
		return this;
	}
}

class SnowEmitterScrollFactor
{
	public var x:SnowEmitterRange = new SnowEmitterRange(1, 1);
	public var y:SnowEmitterRange = new SnowEmitterRange(1, 1);

	public function new() {}
}

class SnowEmitterSignal
{
	var callbacks:Array<FlxSprite->Void> = [];

	public function new() {}

	public function add(callback:FlxSprite->Void):Void
	{
		if(callback != null && !callbacks.contains(callback))
			callbacks.push(callback);
	}
}
