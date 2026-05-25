package objects;

class SustainSplash extends FlxSprite
{
	public static var startCrochet:Float;
	public static var frameRate:Int;

	public var strumNote:StrumNote;

	var timer:FlxTimer;

	public function new():Void
	{
		super();

		x = -50000;

		frames = Paths.getSparrowAtlas('holdCovers/holdCover-' + ClientPrefs.data.holdSkin);

		animation.addByPrefix('start', 'holdCoverStart0', 24, false);
		animation.addByPrefix('hold', 'holdCover0', 12, true);
		animation.addByPrefix('end', 'holdCoverEnd0', 24, false);
		if(!animation.getNameList().contains("hold")) trace("Hold splash is missing 'hold' anim!");
	}

	override function update(elapsed)
	{
		super.update(elapsed);

		if (strumNote != null)
		{
			syncToStrumNote(); // much better

			if (animation.curAnim?.name == "hold" && strumNote.animation.curAnim?.name == "static")
			{
				x = -50000;
				kill();
			}
		}
	}

	override function draw()
	{
		if (strumNote != null)
			syncToStrumNote();

		super.draw();
	}

	function syncToStrumNote():Void
	{
		setPosition(strumNote.x, strumNote.y);
		visible = strumNote.visible;
		alpha = ClientPrefs.data.holdSplashAlpha - (1 - strumNote.alpha);
	}

	public function setupSusSplash(strum:StrumNote, daNote:Note, ?playbackRate:Float = 1):Void
	{
		strumNote = strum;

		alpha = ClientPrefs.data.holdSplashAlpha * strumNote.alpha;
		offset.set(PlayState.isPixelStage ? 112.5 : 106.25, 100);
		clipRect = new flixel.math.FlxRect(0, !PlayState.isPixelStage ? 0 : -210, frameWidth, frameHeight);

		if (timer != null) timer.cancel();

		if (daNote.shader != null)
			shader = daNote.shader;
		else
			shader = null;

		animation.play('start', true);
		
		animation.finishCallback = null;

		animation.finishCallback = (name:String) ->
		{
			if (name == 'start')
			{
				animation.play('hold', true);
				if (animation.curAnim != null)
				{
					animation.curAnim.frameRate = frameRate;
					animation.curAnim.looped = true;
				}
			}
		};

		final lengthToGet:Int = !daNote.isSustainNote ? daNote.tail.length : daNote.parent.tail.length;
		final timeToGet:Float = !daNote.isSustainNote ? daNote.strumTime : daNote.parent.strumTime;
		final timeThingy:Float = (startCrochet * lengthToGet + (timeToGet - Conductor.songPosition + ClientPrefs.data.ratingOffset)) / playbackRate * 0.001;

		if (ClientPrefs.data.holdSplashAlpha > 0.01 && !daNote.hitByOpponent)
		{
			if (animation.curAnim != null && animation.curAnim.name == 'end')
			{
				strumNote.playAnim('pressed', true);
			}
			timer = new FlxTimer().start(timeThingy, (_) ->
			{
				if (animation != null)
				{
					animation.play('end', true);
					if (animation.curAnim != null)
					{
						animation.curAnim.looped = false;
						animation.curAnim.frameRate = 24;
					}
					clipRect = null;

					animation.finishCallback = (_) -> kill();
				}
				else kill();
			});
		}
	}
}
