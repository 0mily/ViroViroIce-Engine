package objects;

class SustainSplash extends FlxSprite
{
	public static var startCrochet:Float;
	public static var frameRate:Int;

	public var strumNote:StrumNote;
	public var texture(default, null):String;

	var timer:FlxTimer;

	public function new():Void
	{
		super();

		x = -50000;
		loadSplash(defaultTexture());
	}

	public function loadSplash(path:String):Void
	{
		path = NoteSkinData.resolveHoldSplashPath(path);
		if (path == null || path.length < 1 || texture == path)
			return;

		texture = path;
		frames = Paths.getSparrowAtlas(texture);
		animation.addByPrefix('start', 'holdCoverStart0', 24, false);
		animation.addByPrefix('hold', 'holdCover0', 12, true);
		animation.addByPrefix('end', 'holdCoverEnd0', 24, false);
		if(!animation.getNameList().contains("hold")) trace("Hold splash is missing 'hold' anim!");
	}

	static function defaultTexture():String
	{
		if (PlayState.SONG != null && PlayState.SONG.holdSplashSkin != null && PlayState.SONG.holdSplashSkin.length > 0)
			return PlayState.SONG.holdSplashSkin;
		return 'holdCovers/holdCover-${ClientPrefs.data.holdSkin}';
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
		var runtime:SplashRuntime = PlayState.instance?.holdSplash;
		visible = strumNote.visible && (runtime == null || runtime.visible);
		var baseAlpha:Float = ClientPrefs.data.holdSplashAlpha - (1 - strumNote.alpha);
		alpha = runtime != null ? runtime.resolveAlpha(baseAlpha) : baseAlpha;
		if (runtime != null)
			antialiasing = runtime.resolveAntialiasing(antialiasing);
	}

	public function setupSusSplash(strum:StrumNote, daNote:Note, ?playbackRate:Float = 1):Void
	{
		loadSplash(daNote != null && daNote.holdSplashTexture != null ? daNote.holdSplashTexture : defaultTexture());
		strumNote = strum;

		var runtime:SplashRuntime = PlayState.instance?.holdSplash;
		var baseAlpha:Float = ClientPrefs.data.holdSplashAlpha * strumNote.alpha;
		alpha = runtime != null ? runtime.resolveAlpha(baseAlpha) : baseAlpha;
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
