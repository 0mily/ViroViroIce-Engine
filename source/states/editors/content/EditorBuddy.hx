package states.editors.content;

using StringTools;

class EditorBuddy extends FlxSprite // sei lá porra, metade eu roubei da nightmare vision e adaptei
{
	static final ANIM_PREFIXES:Array<String> = ['l', 'd', 'u', 'r'];
	static final SING_NAMES:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'];
	static final OFFSET_ALIASES:Array<String> = ['left', 'down', 'up', 'right'];

	var idleName:String = 'idle';
	public var danceEveryNumBeats:Int = 2;
	public var holdSingTimer:Float = 0;
	public var holdTimer:Float = 0;
	public var singDuration:Float = 4;
	var animOffsets:Map<String, FlxPoint> = new Map<String, FlxPoint>();

	public function new(x:Float, y:Float, asset:String, ?config:Dynamic)
	{
		super(x, y);

		var image:String = getString(config, 'image', asset);
		frames = Paths.getSparrowAtlas('editors/friends/$image');
		animation.addByPrefix(idleName, 'i', 12, true);
		for(i in 0...ANIM_PREFIXES.length)
			animation.addByPrefix(directionName(i), ANIM_PREFIXES[i], 24, false);

		loadOffsets(image);
		loadConfigOffsets(config);
		antialiasing = ClientPrefs.data.antialiasing;
		var targetWidth:Float = getFloat(config, 'width', 100);
		if(targetWidth > 0)
			setGraphicSize(Std.int(targetWidth));
		else
		{
			var targetScale:Float = getFloat(config, 'scale', 1);
			scale.set(targetScale, targetScale);
		}
		updateHitbox();
		playBuddyAnim(idleName);
		updateHitbox();
	}

	override function update(elapsed:Float):Void
	{
		if(holdSingTimer > 0)
		{
			holdSingTimer -= elapsed;
			if(holdSingTimer <= 0)
				holdSingTimer = 0;

			holdTimer = 0;
			keepCurrentSingAlive();
		}

		super.update(elapsed);

		if(getAnimationName().startsWith('sing'))
		{
			holdTimer += elapsed;
			var pitch:Float = 1;
			#if FLX_PITCH
			if(FlxG.sound.music != null)
				pitch = FlxG.sound.music.pitch;
			#end
			if(holdSingTimer <= 0 && holdTimer >= Conductor.stepCrochet * (0.0011 / Math.max(0.001, pitch)) * singDuration)
			{
				dance(true);
				holdTimer = 0;
			}
		}
		else
			holdTimer = 0;
	}

	public function holdSing(anim:String, time:Float = 0):Void
	{
		holdSingTimer = Math.max(holdSingTimer, time);
		holdTimer = 0;
		playAnim(anim, true);
	}

	public function replayHeldSing():Void
	{
		var name:String = getAnimationName();
		if(holdSingTimer > 0 && name.startsWith('sing'))
			playAnim(name, true);
	}

	public function playDirection(direction:Int):Void
	{
		holdSing(directionName(direction), 0);
	}

	public function dance(?force:Bool = false):Void
	{
		if(force || !getAnimationName().startsWith('sing'))
			playAnim(idleName, true);
	}

	public function playAnim(animName:String, force:Bool = false):Void
	{
		playBuddyAnim(normalizeAnimName(animName), force);
	}

	public function getAnimationName():String
	{
		return animation.curAnim != null ? animation.curAnim.name : '';
	}

	function keepCurrentSingAlive():Void
	{
		var name:String = getAnimationName();
		if(name.startsWith('sing') && animation.curAnim != null && animation.curAnim.finished)
			playAnim(name, true);
	}

	function directionName(direction:Int):String
		return switch(direction % ANIM_PREFIXES.length)
		{
			case 0: SING_NAMES[0];
			case 1: SING_NAMES[1];
			case 2: SING_NAMES[2];
			default: SING_NAMES[3];
		}

	function playBuddyAnim(name:String, force:Bool = false):Void
	{
		if(!animation.exists(name))
			name = idleName;
		animation.play(name, force);
		centerOffsets();
		var point:FlxPoint = animOffsets.get(name);
		if(point != null)
		{
			offset.x += point.x * scale.x;
			offset.y += point.y * scale.y;
		}
	}

	function loadOffsets(asset:String):Void
	{
		var raw:String = Paths.getTextFromFile('images/editors/friends/$asset.txt');
		var names:Array<String> = SING_NAMES.concat([idleName]);
		for(i in 0...names.length)
			animOffsets.set(names[i], FlxPoint.get());

		if(raw == null)
			return;

		var lines:Array<String> = raw.replace('\r', '').split('\n');
		for(i in 0...Std.int(Math.min(lines.length, names.length)))
		{
			var parts:Array<String> = lines[i].split(',');
			if(parts.length < 2)
				continue;

			var x:Float = Std.parseFloat(parts[0].trim());
			var y:Float = Std.parseFloat(parts[1].trim());
			if(Math.isNaN(x)) x = 0;
			if(Math.isNaN(y)) y = 0;
			animOffsets.set(names[i], FlxPoint.get(x, y));
		}
	}

	function loadConfigOffsets(?config:Dynamic):Void
	{
		if(config == null || !Reflect.hasField(config, 'offsets'))
			return;

		var rawOffsets:Dynamic = Reflect.field(config, 'offsets');
		if(rawOffsets == null)
			return;

		for(i in 0...SING_NAMES.length + 1)
		{
			var name:String = i < SING_NAMES.length ? SING_NAMES[i] : idleName;
			var value:Dynamic = null;
			if(Reflect.hasField(rawOffsets, name))
				value = Reflect.field(rawOffsets, name);
			else
			{
				var alias:String = i < OFFSET_ALIASES.length ? OFFSET_ALIASES[i] : idleName;
				if(Reflect.hasField(rawOffsets, alias))
					value = Reflect.field(rawOffsets, alias);
			}

			var point:FlxPoint = parsePoint(value);
			if(point != null)
				animOffsets.set(name, point);
		}
	}

	function normalizeAnimName(animName:String):String
	{
		return switch(animName)
		{
			case 'left': 'singLEFT';
			case 'down': 'singDOWN';
			case 'up': 'singUP';
			case 'right': 'singRIGHT';
			default: animName;
		}
	}

	static function parsePoint(value:Dynamic):FlxPoint
	{
		if(value == null)
			return null;

		try
		{
			var arr:Array<Dynamic> = cast value;
			if(arr != null && arr.length >= 2)
				return FlxPoint.get(parseFloat(arr[0], 0), parseFloat(arr[1], 0));
		}
		catch(e:Dynamic) {}

		return null;
	}

	static function getString(config:Dynamic, field:String, fallback:String):String
	{
		if(config == null || !Reflect.hasField(config, field))
			return fallback;
		var value:Dynamic = Reflect.field(config, field);
		return value == null ? fallback : Std.string(value);
	}

	static function getFloat(config:Dynamic, field:String, fallback:Float):Float
	{
		if(config == null || !Reflect.hasField(config, field))
			return fallback;
		return parseFloat(Reflect.field(config, field), fallback);
	}

	static function parseFloat(value:Dynamic, fallback:Float):Float
	{
		var parsed:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}
}
