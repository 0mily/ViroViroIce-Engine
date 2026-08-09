package objects;

import flixel.addons.display.FlxPieDial;

#if hxvlc
import hxvlc.flixel.FlxVideoSprite;
import lime.app.Future; // and here we go
import lime.app.Promise;
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
	public var syncWithSong(get, set):Bool;
	var _syncWithSong:Bool = false;
	public var loops(default, null):Bool = false;
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
	var pendingSeekTime:Null<Float> = null;
	var syncSeekCooldown:Float = 0;
	var songSyncOrigin:Null<Float> = null;
	var playbackRequested:Bool = false;
	static inline final MAX_PLAY_ATTEMPTS:Int = 12;
	static inline final MAX_SYNC_DRIFT:Float = 160;

	#if hxvlc
	static var warmedPlayers:Map<String, FlxVideoSprite> = new Map();
	static var pendingWarmups:Map<String, Future<String>> = new Map();
	#end

	#if js
	public var videoSprite:FlxVideo;
	#else
	public var videoSprite:FlxVideoSprite;
	#end
	public function new(videoName:String, isWaiting:Bool, canSkip:Bool = false, shouldLoop:Dynamic = false) {
		super();

		this.videoName = videoName;
		loops = shouldLoop == true;
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
		videoSprite.finishCallback = finishVideo;
		videoSprite.readyCallback = handleTextureReady;
		#else
		var wasWarmed:Bool = false;
		if(!loops)
		{
			videoSprite = takeWarmedPlayer(videoName);
			wasWarmed = videoSprite != null;
		}

		/*{
			textureReady = true;
			pendingPlay = false;
			
			#if hxvlc
			var wd:Int = videoSprite.bitmap.formatWidth;
			var hg:Int = videoSprite.bitmap.formatHeight;
			trace('Video Resolution: ${wd}x${hg}');
			videoSprite.scale.set(FlxG.width / wd, FlxG.height / hg);
			#end
			
			videoSprite.setGraphicSize(FlxG.width);
			videoSprite.updateHitbox();
			storeBaseVideoScale();
			applyVideoScale(true);
			notifyReady();
		});*/

		if(videoSprite == null)
			videoSprite = new FlxVideoSprite();
		if(!loops) videoSprite.bitmap.onEndReached.add(finishVideo);
		#end
		videoSprite.antialiasing = ClientPrefs.data.antialiasing;

		#if hxvlc
		videoSprite.bitmap.onEncounteredError.add(function(message:String)
		{
			notifyError(message);
		});
		videoSprite.bitmap.onFormatSetup.add(handleTextureReady);
		if(wasWarmed)
		{
			videoSprite.bitmap.volumeAdjust = 1;
			videoSprite.bitmap.time = 0;
			handleTextureReady();
		}
		else if(!videoSprite.load(videoName, loops ? ['input-repeat=65545'] : null))
			notifyError('Video failed to load');
		#elseif !js
		videoSprite.bitmap.onEncounteredError.add(function()
		{
			notifyError('Video playback error');
		});
		videoSprite.bitmap.onTextureSetup.add(handleTextureReady);
		#end

		// callbacks
		add(videoSprite);
		storeBaseVideoScale();
		if(canSkip) this.canSkip = true;
	
		// start video and adjust resolution to screen size
	}

	function handleTextureReady():Void
	{
		if(alreadyDestroyed || textureReady)
			return;

		textureReady = true;
		pendingPlay = false;
		videoSprite.setGraphicSize(FlxG.width);
		videoSprite.updateHitbox();
		storeBaseVideoScale();
		applyVideoScale(true);
		applyPendingSeek();
		notifyReady();
	}

	#if hxvlc
	/**
	 * Opens a video during the loading screen and keeps its initialized player
	 * ready for the first matching VideoSprite created by gameplay.

	 * It probably worked?
	 */
	public static function warmup(videoName:String, timeout:Float = 15):Dynamic
	{
		if(videoName == null || videoName.length < 1)
			return null;
		if(warmedPlayers.exists(videoName))
			return Future.withValue(videoName);
		if(pendingWarmups.exists(videoName))
			return pendingWarmups.get(videoName);

		var promise:Promise<String> = new Promise<String>();
		var player:FlxVideoSprite = new FlxVideoSprite();
		var timer:FlxTimer = null;
		var settled:Bool = false;

		function cleanup(success:Bool, ?message:String):Void
		{
			if(settled)
				return;
			settled = true;
			pendingWarmups.remove(videoName);
			if(timer != null)
			{
				timer.cancel();
				timer = null;
			}

			if(success)
			{
				player.pause();
				player.bitmap.time = 0;
				warmedPlayers.set(videoName, player);
				trace('[Video preload] decoder ready: $videoName');
				promise.complete(videoName);
			}
			else
			{
				trace('[Video preload] failed: $videoName -> $message');
				player.destroy();
				promise.error(message ?? 'Video warmup failed');
			}
		}

		player.visible = false;
		player.bitmap.visible = false;
		player.bitmap.volumeAdjust = 0;
		player.bitmap.onEncounteredError.add((message:String) -> cleanup(false, message));
		player.bitmap.onFormatSetup.add(() -> cleanup(true));

		pendingWarmups.set(videoName, promise.future);
		if(!player.load(videoName))
			cleanup(false, 'Video failed to load');
		else
		{	
			/*
			 * hxvlc recomends starting playback on the next tick after load
			 * waiting onformatsetup basically means the file was actually opened and its decoder/first texture were initialized, not merely read into RAM
			*/

			timer = new FlxTimer().start(0.01, (_) -> {
				timer = null;
				if(settled)
					return;
				if(!player.play())
					cleanup(false, 'Video playback failed to start');
				else
					timer = new FlxTimer().start(timeout, (_) -> cleanup(false, 'Video warmup timed out'));
			});
		}
		return promise.future;
	}

	static function takeWarmedPlayer(videoName:String):FlxVideoSprite
	{
		var player:FlxVideoSprite = warmedPlayers.get(videoName);
		if(player != null)
		{
			warmedPlayers.remove(videoName);
			player.exists = true;
			player.active = true;
			player.visible = true;
			trace('[Video preload] claimed by gameplay: $videoName');
		}
		return player;
	}

	public static function clearWarmups():Void
	{
		for(player in warmedPlayers)
			if(player != null)
				player.destroy();
		warmedPlayers.clear();
	}
	#else
	public static function warmup(videoName:String, timeout:Float = 15):Dynamic
		return videoName;

	public static function clearWarmups():Void {}
	#end

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
		syncSeekCooldown = Math.max(0, syncSeekCooldown - elapsed);
		applyPendingSeek();
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
	

	function get_ready():Bool
		return textureReady;

	function get_syncWithSong():Bool
		return _syncWithSong;

	function set_syncWithSong(value:Bool):Bool
	{
		if(_syncWithSong == value)
			return value;

		_syncWithSong = value;
		songSyncOrigin = null;
		if(value && playbackRequested)
		{
			var songTime:Float = Math.max(0, Conductor.songPosition - Conductor.offset);
			var videoTime:Float = pendingSeekTime != null ? pendingSeekTime : Math.max(0, getTime());
			songSyncOrigin = songTime - videoTime;
		}
		return value;
	}

	function prepareSongSync():Void
	{
		playbackRequested = true;
		if(!syncWithSong || songSyncOrigin != null)
			return;
		var songTime:Float = Math.max(0, Conductor.songPosition - Conductor.offset);
		var videoTime:Float = pendingSeekTime != null ? pendingSeekTime : (textureReady ? Math.max(0, getTime()) : 0);
		songSyncOrigin = songTime - videoTime;
	}

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

	#if js
	public function play()
	{
		prepareSongSync();
		videoSprite?.resumeVideo();
	}
	public function resume()
	{
		prepareSongSync();
		videoSprite?.resumeVideo();
	}
	public function pause() videoSprite?.pauseVideo();
	#else
	public function play()
	{
		prepareSongSync();
		pendingPlay = true;
		nativePlayStarted = false;
		playAttempts = 0;
		schedulePlayAttempt(0.02);
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
		if(nativePlayStarted)
			applyPendingSeek();

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

	public function resume()
	{
		prepareSongSync();
		videoSprite?.resume();
	}
	public function pause() videoSprite?.pause();
	#end
	public function stop() destroy();

	public function muteForPreload():Void
	{
		#if js
		videoSprite?.setVolume(0);
		#else
		if(videoSprite != null && videoSprite.bitmap != null)
			videoSprite.bitmap.volumeAdjust = 0;
		#end
	}

	public function setTime(timeMs:Float):Void
	{
		if(Math.isNaN(timeMs))
			timeMs = 0;
		pendingSeekTime = Math.max(0, timeMs);
		applyPendingSeek();
	}

	function applyPendingSeek():Void
	{
		if(pendingSeekTime == null || !textureReady || !isSeekable())
			return;

		var timeMs:Float = pendingSeekTime;
		pendingSeekTime = null;

		#if js
		videoSprite?.seekVideo(timeMs / 1000);
		#else
		if(videoSprite != null && videoSprite.bitmap != null)
			videoSprite.bitmap.time = Std.int(timeMs);
		#end
	}

	/* Keeps a songsynced video aligned without seeking on evry frame */              //IT SHOULD BUT IT DOESN'T AAAAAAAAAAAAAAAAAAAGGRRRHHHH
	public function syncToTime(timeMs:Float, force:Bool = false):Void
	{
		if(alreadyDestroyed)
			return;
		if(Math.isNaN(timeMs))
			timeMs = 0;
		timeMs = Math.max(0, timeMs);
		if(songSyncOrigin == null)
		{
			if(!playbackRequested)
				return;
			var currentTime:Float = textureReady ? Math.max(0, getTime()) : 0;
			songSyncOrigin = timeMs - currentTime;
		}
		timeMs = Math.max(0, timeMs - songSyncOrigin);

		var length:Float = getLength();
		if(!loops && length > 0 && timeMs >= length - 1)
		{
			finishVideo();
			return;
		}

		if(force)
		{
			syncSeekCooldown = 0.25;
			setTime(timeMs);
			return;
		}

		if(pendingSeekTime != null || syncSeekCooldown > 0)
			return;
		var currentTime:Float = getTime();
		if(currentTime < 0 || Math.abs(currentTime - timeMs) > MAX_SYNC_DRIFT)
		{
			syncSeekCooldown = 0.25;
			setTime(timeMs);
		}
	}

	public function syncAfterSongSeek(songTimeMs:Float, deltaMs:Float):Void
	{
		if(alreadyDestroyed || !syncWithSong || !playbackRequested || Math.isNaN(deltaMs))
			return;

		var currentTime:Float = pendingSeekTime != null ? pendingSeekTime : getTime();
		if(Math.isNaN(currentTime) || currentTime < 0)
			currentTime = 0;
		var targetTime:Float = Math.max(0, currentTime + deltaMs);
		var length:Float = getLength();
		if(!loops && length > 0 && targetTime >= length - 1)
		{
			finishVideo();
			return;
		}

		songSyncOrigin = Math.max(0, songTimeMs) - targetTime;
		syncSeekCooldown = 0.25;
		setTime(targetTime);
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
	public var readyCallback:Void->Void;

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

	public function setVolume(volume:Float):Void
	{
		onVolumeChanged(volume);
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

	if (readyCallback != null) readyCallback();
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
