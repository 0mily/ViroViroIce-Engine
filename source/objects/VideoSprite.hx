package objects;

import flixel.addons.display.FlxPieDial;

#if hxvlc
import hxvlc.flixel.FlxVideoSprite;
#elseif js
import openfl.events.NetStatusEvent;
import openfl.media.SoundTransform;
import openfl.media.Video;
import openfl.net.NetConnection;
import openfl.net.NetStream;
#end

class VideoSprite extends FlxSpriteGroup {
	#if VIDEOS_ALLOWED
	public var finishCallback:Void->Void = null;
	public var onSkip:Void->Void = null;

	final _timeToSkip:Float = 1;
	public var tag:String = null;
	public var pauseWithGame:Bool = true;
	public var syncWithSong:Bool = false;
	public var playOnAdd:Bool = false;
	public var holdingTime:Float = 0;
	public var skipSprite:FlxPieDial;
	public var cover:FlxSprite;
	public var canSkip(default, set):Bool = false;
	public var readyCallback:Void->Void = null;
	public var errorCallback:String->Void = null;
	public var ready(get, never):Bool;

	private var videoName:String;

	public var waiting:Bool = false;
	var baseVideoScaleX:Float = 1;
	var baseVideoScaleY:Float = 1;
	var lastVideoScaleX:Float = -1;
	var lastVideoScaleY:Float = -1;
	var playTimer:FlxTimer = null;
	var pendingPlay:Bool = false;
	var playAttempts:Int = 0;
	var nativePlayStarted:Bool = false;
	var textureReady:Bool = false;
	static inline final MAX_PLAY_ATTEMPTS:Int = 12;

	#if js
	public var videoSprite:FlxVideo;
	#else
	public var videoSprite:FlxVideoSprite;
	#end
	public function new(videoName:String, isWaiting:Bool, canSkip:Bool = false, shouldLoop:Dynamic = false) {
		super();

		this.videoName = videoName;
		scrollFactor.set();
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		waiting = isWaiting;
		if(!waiting)
		{
			cover = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
			cover.scale.set(FlxG.width + 100, FlxG.height + 100);
			cover.screenCenter();
			cover.scrollFactor.set();
			add(cover);
		}

		// initialize sprites
		
		#if js
		videoSprite = new FlxVideo(videoName);
		videoSprite.finishCallback= finishVideo;
		#else
		videoSprite = new FlxVideoSprite();
		if(!shouldLoop) videoSprite.bitmap.onEndReached.add(finishVideo);
		#end
		videoSprite.antialiasing = ClientPrefs.data.antialiasing;

		#if hxvlc
		videoSprite.load(videoName, shouldLoop ? ['input-repeat=65545'] : null);
		videoSprite.bitmap.onEncounteredError.add(function(message:String)
		{
			notifyError(message);
		});
		
		videoSprite.bitmap.onFormatSetup.add(function()
		#else
		videoSprite.bitmap.onEncounteredError.add(function()
		{
			notifyError('Video playback error');
		});
		videoSprite.bitmap.onTextureSetup.add(function()
		#end
		{
			textureReady = true;
			pendingPlay = false;
			/*
			#if hxvlc
			var wd:Int = videoSprite.bitmap.formatWidth;
			var hg:Int = videoSprite.bitmap.formatHeight;
			trace('Video Resolution: ${wd}x${hg}');
			videoSprite.scale.set(FlxG.width / wd, FlxG.height / hg);
			#end
			*/
			videoSprite.setGraphicSize(FlxG.width);
			videoSprite.updateHitbox();
			storeBaseVideoScale();
			applyVideoScale(true);
			notifyReady();
		});

		// callbacks
		add(videoSprite);
		storeBaseVideoScale();
		if(canSkip) this.canSkip = true;
	
		// start video and adjust resolution to screen size
	}

	var alreadyDestroyed:Bool = false;
	override function destroy()
	{
		if(alreadyDestroyed)
			return;

		trace('Video destroyed');
		if(cover != null)
		{
			remove(cover);
			cover.destroy();
		}
		if(playTimer != null)
		{
			playTimer.cancel();
			playTimer = null;
		}
		pendingPlay = false;
		
		readyCallback = null;
		errorCallback = null;
		finishCallback = null;
		onSkip = null;

		if(FlxG.state != null)
		{
			if(FlxG.state.members.contains(this))
				FlxG.state.remove(this);

			if(FlxG.state.subState != null && FlxG.state.subState.members.contains(this))
				FlxG.state.subState.remove(this);
		}
		super.destroy();
		alreadyDestroyed = true;
	}
	function finishVideo()
	{
		if (!alreadyDestroyed)
		{
			if(finishCallback != null)
				finishCallback();
			
			destroy();
		}
	}

	override function update(elapsed:Float)
	{
		applyVideoScale(false);

		if(canSkip)
		{
			if(Controls.instance.pressed('accept'))
			{
				holdingTime = Math.max(0, Math.min(_timeToSkip, holdingTime + elapsed));
			}
			else if (holdingTime > 0)
			{
				holdingTime = Math.max(0, FlxMath.lerp(holdingTime, -0.1, FlxMath.bound(elapsed * 3, 0, 1)));
			}
			updateSkipAlpha();

			if(holdingTime >= _timeToSkip)
			{
				if(onSkip != null) onSkip();
				finishCallback = null;
				#if js
				videoSprite.finishVideo();
				#else
				videoSprite.bitmap.onEndReached.dispatch();
				#end
				trace('Skipped video');
				return;
			}
		}
		super.update(elapsed);
	}

	function storeBaseVideoScale():Void
	{
		if(videoSprite == null)
			return;

		baseVideoScaleX = videoSprite.scale.x;
		baseVideoScaleY = videoSprite.scale.y;
		lastVideoScaleX = -1;
		lastVideoScaleY = -1;
	}

	function applyVideoScale(forceCenter:Bool):Void
	{
		if(videoSprite == null)
			return;

		var targetScaleX:Float = baseVideoScaleX * scale.x;
		var targetScaleY:Float = baseVideoScaleY * scale.y;
		if(forceCenter || targetScaleX != lastVideoScaleX || targetScaleY != lastVideoScaleY)
		{
			videoSprite.scale.set(targetScaleX, targetScaleY);
			videoSprite.updateHitbox();
			videoSprite.screenCenter();
			lastVideoScaleX = targetScaleX;
			lastVideoScaleY = targetScaleY;
		}
	}

	function set_canSkip(newValue:Bool)
	{
		canSkip = newValue;
		if(canSkip)
		{
			if(skipSprite == null)
			{
				skipSprite = new FlxPieDial(0, 0, 40, FlxColor.WHITE, 40, true, 24);
				skipSprite.replaceColor(FlxColor.BLACK, FlxColor.TRANSPARENT);
				skipSprite.x = FlxG.width - (skipSprite.width + 80);
				skipSprite.y = FlxG.height - (skipSprite.height + 72);
				skipSprite.amount = 0;
				add(skipSprite);
			}
		}
		else if(skipSprite != null)
		{
			remove(skipSprite);
			skipSprite.destroy();
			skipSprite = null;
		}
		return canSkip;
	}

	function updateSkipAlpha()
	{
		if(skipSprite == null) return;

		skipSprite.amount = Math.min(1, Math.max(0, (holdingTime / _timeToSkip) * 1.025));
		skipSprite.alpha = FlxMath.remapToRange(skipSprite.amount, 0.025, 1, 0, 1);
	}

	#if js
	public function play() videoSprite?.resumeVideo();
	public function resume() videoSprite?.resumeVideo();
	public function pause() videoSprite?.pauseVideo();
	#else
	public function play()
	{
		pendingPlay = true;
		nativePlayStarted = false;
		playAttempts = 0;
		schedulePlayAttempt(0.02);
	}

	function get_ready():Bool
		return textureReady;

	function notifyReady():Void
	{
		if(readyCallback != null)
			readyCallback();
	}

	function notifyError(message:String):Void
	{
		pendingPlay = false;
		nativePlayStarted = false;
		if(playTimer != null)
		{
			playTimer.cancel();
			playTimer = null;
		}
		if(errorCallback != null)
			errorCallback(message);
	}

	function schedulePlayAttempt(delay:Float):Void
	{
		if(playTimer != null)
			playTimer.cancel();
		playTimer = new FlxTimer().start(delay, function(_)
		{
			playTimer = null;
			attemptPlay();
		});
	}

	function attemptPlay():Void
	{
		if(videoSprite == null || alreadyDestroyed)
			return;

		if(nativePlayStarted)
			return;

		nativePlayStarted = startNativePlayback();
		playAttempts++;

		if(pendingPlay && !textureReady && !nativePlayStarted && playAttempts < MAX_PLAY_ATTEMPTS)
			schedulePlayAttempt(0.25);
		else if(!nativePlayStarted && !textureReady)
			notifyError('Video playback failed to start');
		else if(textureReady)
			pendingPlay = false;
	}

	function startNativePlayback():Bool
	{
		return videoSprite != null && videoSprite.play();
	}

	public function resume() videoSprite?.resume();
	public function pause() videoSprite?.pause();
	#end
	public function stop() destroy();

	public function muteForPreload():Void
	{
		if(videoSprite != null && videoSprite.bitmap != null)
			videoSprite.bitmap.volumeAdjust = 0;
	}

	public function setTime(timeMs:Float):Void
	{
		if(Math.isNaN(timeMs))
			timeMs = 0;
		timeMs = Math.max(0, timeMs);

		#if js
		videoSprite?.seekVideo(timeMs / 1000);
		#else
		if(videoSprite != null && videoSprite.bitmap != null)
			videoSprite.bitmap.time = Std.int(timeMs);
		#end
	}

	public function getTime():Float
	{
		#if js
		return videoSprite != null ? videoSprite.getTime() : 0;
		#else
		if(videoSprite != null && videoSprite.bitmap != null)
			return Std.parseFloat(Std.string(videoSprite.bitmap.time));
		#end
		return 0;
	}

	public function getLength():Float
	{
		#if !js
		if(videoSprite != null && videoSprite.bitmap != null)
			return Std.parseFloat(Std.string(videoSprite.bitmap.length));
		#end
		return 0;
	}

	public function isSeekable():Bool
	{
		#if !js
		return videoSprite != null && videoSprite.bitmap != null && videoSprite.bitmap.isSeekable;
		#end
		return true;
	}

	public function setPlaybackRate(rate:Float):Void
	{
		#if !js
		if(videoSprite != null && videoSprite.bitmap != null)
			videoSprite.bitmap.rate = rate;
		#end
	}
	#end
}
/**
 * Plays a video via a NetStream. Only works on HTML5.
 * This does NOT replace hxvlc, nor does hxvlc replace this.
 * hxvlc only works on desktop and does not work on HTML5!
 * Ripped from Funkin'.
 *  
*/
class FlxVideo extends FlxSprite
{
	#if html5
	var video:Video;
  	var netStream:NetStream;
  	var videoPath:String;

  	/**
   	* A callback to execute when the video finishes.
   	*/
  	public var finishCallback:Void->Void;

  	public function new(videoPath:String)
  	{
    super();

    this.videoPath = videoPath;

    makeGraphic(2, 2, FlxColor.TRANSPARENT);

    video = new Video();
    video.x = 0;
    video.y = 0;
    video.alpha = 0;

    FlxG.game.addChild(video);

    var netConnection:NetConnection = new NetConnection();
    netConnection.connect(null);

    netStream = new NetStream(netConnection);
    netStream.client = {onMetaData: onClientMetaData};
    netConnection.addEventListener(NetStatusEvent.NET_STATUS, onNetConnectionNetStatus);
    netStream.play(videoPath);
  }

  /**
   * Tell the FlxVideo to pause playback.
   */
  public function pauseVideo():Void
  {
    if (netStream != null)
    {
      netStream.pause();
    }
  }

  /**
   * Tell the FlxVideo to resume if it is paused.
   */
  public function resumeVideo():Void
  {
    // Resume playing the video.
    if (netStream != null)
    {
      netStream.resume();
    }
  }

  var videoAvailable:Bool = false;
  var frameTimer:Float;

  static final FRAME_RATE:Float = 60;

  public override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (frameTimer >= (1 / FRAME_RATE))
    {
      frameTimer = 0;
      // TODO: We just draw the video buffer to the sprite 60 times a second.
      // Can we copy the video buffer instead somehow?
      pixels.draw(video);
    }

    if (videoAvailable) frameTimer += elapsed;
  }

  /**
   * Tell the FlxVideo to seek to the beginning.
   */
  public function restartVideo():Void
  {
    // Seek to the beginning of the video.
    if (netStream != null)
    {
      netStream.seek(0);
    }
  }

  /**
   * Tell the FlxVideo to seek to a position in seconds.
   */
  public function seekVideo(timeSeconds:Float):Void
  {
    if (netStream != null)
    {
      netStream.seek(Math.max(0, timeSeconds));
    }
  }

  public function getTime():Float
  {
    return netStream != null ? netStream.time * 1000 : 0;
  }

  /**
   * Tell the FlxVideo to end.
   */
  public function finishVideo():Void
  {
    netStream.dispose();
    FlxG.removeChild(video);

    if (finishCallback != null) finishCallback();
  }

  public override function destroy():Void
  {
    if (netStream != null)
    {
      netStream.dispose();

      if (FlxG.game.contains(video)) FlxG.game.removeChild(video);
    }

    super.destroy();
  }

  /**
   * Callback executed when the video stream loads.
   * @param metaData The metadata of the video
   */
  public function onClientMetaData(metaData:Dynamic):Void
  {
    video.attachNetStream(netStream);

    onVideoReady();
  }

  function onVideoReady():Void
  {
    video.width = FlxG.width;
    video.height = FlxG.height;

    videoAvailable = true;

    //FunkinSound.onVolumeChanged.add(onVolumeChanged);
    onVolumeChanged(FlxG.sound.muted ? 0 : FlxG.sound.volume);

    makeGraphic(Std.int(video.width), Std.int(video.height), FlxColor.TRANSPARENT);
  }

  function onVolumeChanged(volume:Float):Void
  {
    netStream.soundTransform = new SoundTransform(volume);
  }

  function onNetConnectionNetStatus(event:NetStatusEvent):Void
  {
    if (event.info.code == 'NetStream.Play.Complete') finishVideo();
  }
  #end
}
