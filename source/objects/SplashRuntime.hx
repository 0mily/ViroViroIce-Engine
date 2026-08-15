package objects;

// shit for notesplashes and holdsplahing
class SplashRuntime
{
	public var game(default, null):PlayState;
	public var isHold(default, null):Bool;
	public var disabled(default, set):Bool = false;
	public var alpha(default, set):Float;
	public var visible(default, set):Bool = true;
	public var antialiasing(default, set):Bool;

	var alphaOverridden:Bool = false;
	var antialiasingOverridden:Bool = false;

	public function new(game:PlayState, isHold:Bool)
	{
		this.game = game;
		this.isHold = isHold;
		@:bypassAccessor alpha = isHold ? ClientPrefs.data.holdSplashAlpha : ClientPrefs.data.splashAlpha;
		@:bypassAccessor antialiasing = ClientPrefs.data.antialiasing;
	}

	// Hscript should be like noteSplash.skin('thing', inedx)
	public function skin(skinName:String, ?noteIndex:Int):Bool
		return isHold ? game.setHoldSplashSkin(skinName, noteIndex) : game.setSplashSkin(skinName, noteIndex);

	public inline function resolveAlpha(fallback:Float):Float
		return alphaOverridden ? alpha : fallback;

	public inline function resolveAntialiasing(fallback:Bool):Bool
		return antialiasingOverridden ? antialiasing : fallback;

	public function applyTo(splash:FlxSprite):Void
	{
		if (splash == null)
			return;
		splash.visible = visible;
		if (alphaOverridden)
			splash.alpha = alpha;
		if (antialiasingOverridden)
			splash.antialiasing = antialiasing;
	}

	function set_disabled(value:Bool):Bool
	{
		disabled = value;
		if (value)
			forEachSplash(function(splash:FlxSprite) splash.kill());
		return value;
	}

	function set_alpha(value:Float):Float
	{
		alpha = FlxMath.bound(value, 0, 1);
		alphaOverridden = true;
		forEachSplash(function(splash:FlxSprite) splash.alpha = alpha);
		return alpha;
	}

	function set_visible(value:Bool):Bool
	{
		visible = value;
		forEachSplash(function(splash:FlxSprite) splash.visible = value);
		return value;
	}

	function set_antialiasing(value:Bool):Bool
	{
		antialiasing = value;
		antialiasingOverridden = true;
		forEachSplash(function(splash:FlxSprite) splash.antialiasing = value);
		return value;
	}

	function forEachSplash(callback:FlxSprite->Void):Void
	{
		if (game == null || callback == null)
			return;

		if (isHold)
		{
			if (game.grpHoldSplashes != null)
				for (splash in game.grpHoldSplashes.members)
					if (splash != null && splash.exists)
						callback(splash);
		}
		else if (game.grpNoteSplashes != null)
		{
			for (splash in game.grpNoteSplashes.members)
				if (splash != null && splash.exists)
					callback(splash);
		}
	}
}
