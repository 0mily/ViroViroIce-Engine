package backend;

import flixel.util.FlxGradient;

class CustomFadeTransition extends ScriptedSubState {
	public static var finishCallback:Void->Void;
	var useDefault:Bool = true;
	var isTransIn:Bool = false;
	var transBlack:FlxSprite;
	var transGradient:FlxSprite;
	var transWidth:Float = 0;
	var transHeight:Float = 0;
	
	var time:Float = 0;
	var duration:Float;
	public function new(duration:Float, isTransIn:Bool) {
		this.duration = duration;
		this.isTransIn = isTransIn;
		this.multiScript = false;
		super();
	}

	override function create() {
		preCreate();
		
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length-1]];
		
		if (useDefault) {
			transWidth = getTransitionWidth();
			transHeight = getTransitionHeight();
			var width:Int = Std.int(transWidth);
			var height:Int = Std.int(transHeight);
			transGradient = FlxGradient.createGradientFlxSprite(1, height, [FlxColor.BLACK, 0x0]);
			transGradient.flipY = isTransIn;
			transGradient.scale.x = width;
			transGradient.updateHitbox();
			transGradient.scrollFactor.set();
			transGradient.screenCenter(X);
			add(transGradient);

			transBlack = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
			transBlack.scale.set(width, height + 400);
			transBlack.updateHitbox();
			transBlack.scrollFactor.set();
			transBlack.screenCenter(X);
			add(transBlack);

			updateGradientPosition();
		}

		super.create();
	}

	override function update(elapsed:Float) {
		preUpdate(elapsed);
		
		super.update(elapsed);
		
		time += elapsed;
		
		if (useDefault)
		{
			updateTransitionSize();
			updateGradientPosition();
		}
		
		postUpdate(elapsed);
		
		if (duration <= 0 || time >= duration)
			close();
	}
	
	function updateGradientPosition():Void {
		if (transBlack == null && transGradient == null)
			return;
		
		var totalHeight:Float = transBlack.height + transGradient.height;
		transBlack.y = FlxMath.lerp(isTransIn ? 0 : -totalHeight, isTransIn ? totalHeight : 0, Math.min(time / duration, 1));
		
		if (isTransIn) {
			transGradient.y = transBlack.y - transGradient.height;
		} else {
			transGradient.y = transBlack.y + transBlack.height;
		}
	}

	function getTransitionWidth():Float {
		return Math.max(FlxG.width, camera == null ? FlxG.width : camera.width) / Math.max(camera == null ? 1 : camera.zoom, .25);
	}

	function getTransitionHeight():Float {
		return Math.max(FlxG.height, camera == null ? FlxG.height : camera.height) / Math.max(camera == null ? 1 : camera.zoom, .25);
	}

	function updateTransitionSize():Void {
		var width:Float = getTransitionWidth();
		var height:Float = getTransitionHeight();
		if(Math.abs(width - transWidth) <= 0.001 && Math.abs(height - transHeight) <= 0.001)
			return;

		transWidth = width;
		transHeight = height;
		if(transGradient != null)
		{
			transGradient.scale.x = width;
			transGradient.updateHitbox();
			transGradient.screenCenter(X);
		}
		if(transBlack != null)
		{
			transBlack.scale.set(width, height + 400);
			transBlack.updateHitbox();
			transBlack.screenCenter(X);
		}
	}
	
	override function close():Void {
		super.close();

		if (finishCallback != null) {
			finishCallback();
			finishCallback = null;
		}
	}
}
