package objects;

import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.geom.Matrix;
import tjson.TJSON;

class HealthIcon extends FlxSprite
{
	public static inline final ICON_SIZE:Float = 150;

	public var sprTracker:FlxSprite;
	public var bop:Bool = true;
	public var bitmapSize(get, set):Float;
	public var bitmapWidth(get, set):Int;
	public var bitmapHeight(get, set):Int;
	private var isPlayer:Bool = false;
	private var char:String = '';
	private var sourceIconGraphic:FlxGraphic = null;
	private var sourceIconImage:String = null;
	private var sourceFrameWidth:Int = Std.int(ICON_SIZE);
	private var sourceFrameHeight:Int = Std.int(ICON_SIZE);
	private var currentBitmapWidth:Int = Std.int(ICON_SIZE);
	private var currentBitmapHeight:Int = Std.int(ICON_SIZE);
	private var currentIconConfig:Dynamic = null;
	private var currentIconHasConfig:Bool = false;
	private var currentConfigChar:String = '';
	private var currentPivot:String = 'center';
	private var iconAllowsGPU:Bool = true;
	private var neutralTag:String = null;
	private var dyingTag:String = null;
	private var winningTag:String = null;
	private var currentIconTag:String = null;
	private var currentIconFrame:Int = 0;
	private var scriptProperties:Map<String, Dynamic> = [];

	#if LUA_ALLOWED
	var luaArray:Array<psychlua.FunkinLua> = [];
	#end
	#if HSCRIPT_ALLOWED
	var hscriptArray:Array<psychlua.HScript> = [];
	#end

	public function new(char:String = 'face', isPlayer:Bool = false, ?allowGPU:Bool = true)
	{
		super();
		this.isPlayer = isPlayer;
		changeIcon(char, allowGPU);
		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 12, sprTracker.y - 30);

		#if LUA_ALLOWED
		if(luaArray != null)
			for(lua in luaArray)
				if(lua != null && !lua.closed && !shouldBlockForEditor(lua.get('editorBlock')))
					lua.call('onUpdate', [elapsed]);
		#end
		#if HSCRIPT_ALLOWED
		if(hscriptArray != null)
			for(script in hscriptArray)
				if(script != null && !script.closed && script.exists('onUpdate') && !shouldBlockForEditor(script.get('editorBlock')))
					script.call('onUpdate', [elapsed]);
		#end
	}

	private var iconOffsets:Array<Float> = [0, 0];

	public function changeIcon(char:String, ?allowGPU:Bool = true) {
		if(char == null || char.length < 1) char = 'face';
		if(this.char != char) {
			destroyIconScripts();
			sourceIconGraphic = null;
			sourceIconImage = null;
			sourceFrameWidth = Std.int(ICON_SIZE);
			sourceFrameHeight = Std.int(ICON_SIZE);
			currentBitmapWidth = Std.int(ICON_SIZE);
			currentBitmapHeight = Std.int(ICON_SIZE);
			currentIconConfig = null;
			currentIconHasConfig = false;
			currentConfigChar = '';
			currentPivot = 'center';
			iconAllowsGPU = allowGPU;
			neutralTag = null;
			dyingTag = null;
			winningTag = null;

			if(Character.isNoneCharacter(char))
			{
				makeGraphic(1, 1, 0x00000000);
				iconOffsets[0] = 0;
				iconOffsets[1] = 0;
				updateHitbox();
				animation.add(char, [0], 0, false, isPlayer);
				animation.play(char);
				this.char = char;
				antialiasing = false;
				return;
			}

			var customPath:String = getNewIconImage(char);
			var configChar:String = char;
			if(customPath == null && char != 'face')
			{
				customPath = getNewIconImage('face');
				configChar = 'face';
			}

			if(customPath != null)
			{
				loadNovoIcon(configChar, customPath, allowGPU);
				this.char = char;
				loadIconScripts(char);
				return;
			}

			makeGraphic(1, 1, 0x00000000);
			iconOffsets[0] = 0;
			iconOffsets[1] = 0;
			updateHitbox();
			this.char = char;
			antialiasing = false;
		}
	}

	function getNewIconImage(char:String):String {
		var candidates:Array<String> = [
			'game/icons/$char/icon',
			'game/icons/$char',
			'game/icons/icon-$char'
		];

		for(candidate in candidates)
			if(Paths.fileExists('images/$candidate.png', IMAGE))
				return candidate;
		return null;
	}

	function loadNovoIcon(char:String, image:String, allowGPU:Bool):Void {
		var graphic = Paths.image(image, allowGPU);
		if(graphic == null)
			return;

		var config:Dynamic = loadIconConfig(char);
		var hasConfig:Bool = Reflect.field(config, '__hasIconConfig') == true;
		var frameSize:Array<Int> = readIntArray(Reflect.field(config, 'frame_size'), [Std.int(ICON_SIZE), Std.int(ICON_SIZE)]);
		var frameWidth:Int = Std.int(Math.max(1, frameSize[0]));
		var frameHeight:Int = Std.int(Math.max(1, frameSize.length > 1 ? frameSize[1] : frameSize[0]));
		var bitmapSize:Array<Int> = readIntArray(Reflect.field(config, 'bitmap_size'), [frameWidth, frameHeight]);
		var bitmapWidth:Int = Std.int(Math.max(1, bitmapSize[0]));
		var bitmapHeight:Int = Std.int(Math.max(1, bitmapSize.length > 1 ? bitmapSize[1] : bitmapSize[0]));

		sourceIconGraphic = graphic;
		sourceIconImage = image;
		sourceFrameWidth = frameWidth;
		sourceFrameHeight = frameHeight;
		currentIconConfig = config;
		currentIconHasConfig = hasConfig;
		currentConfigChar = char;
		currentPivot = readString(Reflect.field(config, 'pivot'), 'center');
		iconAllowsGPU = allowGPU;

		antialiasing = readBoolAliases(config, [
			'anti_aliasing', 'antialiasing', 'antiAliasing', 'antiAlising', 'anti_alising'
		], !char.endsWith('-pixel') && ClientPrefs.data.antialiasing);
		applyBitmapSize(bitmapWidth, bitmapHeight);
		configureIconAnimations(config, hasConfig, char);
	}

	function configureIconAnimations(config:Dynamic, hasConfig:Bool, iconChar:String):Void {

		var animated:Bool = readBool(Reflect.field(config, 'animated'), false);
		var fps:Int = 0;
		var animData:Dynamic = null;
		if(animated)
		{
			animData = Reflect.field(config, 'if_animated');
			fps = readInt(Reflect.field(animData, 'fps'), 24);
		}

		var defaultFrames:Array<Int> = [for(i in 0...frames.frames.length) i];
		if(animated && animData != null)
		{
			for(field in Reflect.fields(animData))
			{
				if(field == 'fps')
					continue;
				var animFrames:Array<Int> = readIntArray(Reflect.field(animData, field), []);
				if(animFrames.length > 0)
					animation.add(field, animFrames, fps, true, isPlayer);
			}
		}

		neutralTag = newIconTag(readString(Reflect.field(config, 'tag_toNeutral'), null), 'neutral', defaultFrames, 0, !hasConfig);
		dyingTag = newIconTag(readString(Reflect.field(config, 'tag_toDying'), null), 'death', defaultFrames, 1, !hasConfig);
		winningTag = newIconTag(readString(Reflect.field(config, 'tag_toWinning'), null), 'winning', defaultFrames, 2, !hasConfig);

		if(animation.getByName(iconChar) == null)
			animation.add(iconChar, defaultFrames, 0, false, isPlayer);

		playIconTag(neutralTag ?? iconChar);
	}

	function getSizedIconGraphic(bitmapWidth:Int, bitmapHeight:Int):FlxGraphic {
		if(sourceIconGraphic == null || sourceIconGraphic.bitmap == null)
			return sourceIconGraphic;
		if(bitmapWidth == sourceFrameWidth && bitmapHeight == sourceFrameHeight)
			return sourceIconGraphic;

		var scaledKey:String = 'health-icon-bitmap:$sourceIconImage:${bitmapWidth}x$bitmapHeight:aa-$antialiasing';
		if(Paths.currentTrackedAssets.exists(scaledKey))
		{
			Paths.localTrackedAssets.push(scaledKey);
			return Paths.currentTrackedAssets.get(scaledKey);
		}

		var targetWidth:Int = Std.int(Math.max(1, Math.round(sourceIconGraphic.width * bitmapWidth / sourceFrameWidth)));
		var targetHeight:Int = Std.int(Math.max(1, Math.round(sourceIconGraphic.height * bitmapHeight / sourceFrameHeight)));
		var bitmap:BitmapData = new BitmapData(targetWidth, targetHeight, true, 0x00000000);
		var matrix:Matrix = new Matrix(targetWidth / sourceIconGraphic.bitmap.width, 0, 0, targetHeight / sourceIconGraphic.bitmap.height);
		bitmap.draw(sourceIconGraphic.bitmap, matrix, null, null, null, antialiasing);
		return Paths.cacheBitmap(scaledKey, null, bitmap, iconAllowsGPU);
	}

	function applyBitmapSize(bitmapWidth:Int, bitmapHeight:Int):Bool {
		if(sourceIconGraphic == null)
			return false;

		var graphic:FlxGraphic = getSizedIconGraphic(bitmapWidth, bitmapHeight);
		if(graphic == null)
			return false;

		currentBitmapWidth = bitmapWidth;
		currentBitmapHeight = bitmapHeight;
		loadGraphic(graphic, true, bitmapWidth, bitmapHeight);
		iconOffsets[0] = (bitmapWidth - ICON_SIZE) * 0.5;
		iconOffsets[1] = (bitmapHeight - ICON_SIZE) * 0.5;
		updateHitbox();
		applyPivot(currentPivot, bitmapWidth, bitmapHeight);
		return true;
	}

	public function setIconSize(width:Float, height:Float = -1):Bool {
		var newWidth:Int = Std.int(Math.max(1, Math.round(width)));
		var newHeight:Int = height <= 0 ? newWidth : Std.int(Math.max(1, Math.round(height)));
		if(newWidth == currentBitmapWidth && newHeight == currentBitmapHeight)
			return true;

		var previousFrame:Int = currentIconFrame;
		var previousTag:String = currentIconTag;
		if(!applyBitmapSize(newWidth, newHeight))
			return false;

		configureIconAnimations(currentIconConfig ?? {}, currentIconHasConfig, currentConfigChar);
		if(!playIconTag(previousTag))
			setIconFrame(previousFrame);
		return true;
	}

	inline function get_bitmapSize():Float
		return currentBitmapWidth;

	function set_bitmapSize(value:Float):Float {
		setIconSize(value, value);
		return currentBitmapWidth;
	}

	inline function get_bitmapWidth():Int
		return currentBitmapWidth;

	function set_bitmapWidth(value:Int):Int {
		setIconSize(value, currentBitmapHeight);
		return currentBitmapWidth;
	}

	inline function get_bitmapHeight():Int
		return currentBitmapHeight;

	function set_bitmapHeight(value:Int):Int {
		setIconSize(currentBitmapWidth, value);
		return currentBitmapHeight;
	}

	function loadIconConfig(char:String):Dynamic {
		var json:String = Paths.getTextFromFile('images/game/icons/$char/icon.json');
		if(json != null && json.trim().length > 0)
		{
			try {
				var data:Dynamic = TJSON.parse(json);
				Reflect.setField(data, '__hasIconConfig', true);
				return data;
			} catch(e:Dynamic) {
				Log.print('Could not parse icon JSON for "$char": $e', ERROR);
			}
		}

		var toml:String = Paths.getTextFromFile('images/game/icons/$char/icon.toml');
		if(toml != null && toml.trim().length > 0)
		{
			try {
				var data:Dynamic = backend.Toml.parse(toml, 'images/game/icons/$char/icon.toml').root;
				Reflect.setField(data, '__hasIconConfig', true);
				return data;
			} catch(e:Dynamic) {
				Log.print('Could not parse icon TOML for "$char": $e', ERROR);
			}
		}

		return {};
	}

	function newIconTag(tag:String, fallback:String, frameList:Array<Int>, frameIndex:Int, makeFallback:Bool):String {
		if(tag == null)
		{
			if(!makeFallback)
				return null;
			tag = fallback;
		}

		if(animation.getByName(tag) == null)
		{
			if(frameList.length <= frameIndex)
				return null;
			animation.add(tag, [frameList[frameIndex]], 0, false, isPlayer);
		}
		return tag;
	}

	function playIconTag(tag:String):Bool {
		if(tag != null && animation.getByName(tag) != null)
		{
			animation.play(tag, true);
			currentIconTag = tag;
			return true;
		}
		return false;
	}

	function applyPivot(pivot:String, frameWidth:Int, frameHeight:Int):Void {
		switch((pivot ?? 'center').toLowerCase()) {
			case 'up':
				origin.set(frameWidth * 0.5, 0);
			case 'down':
				origin.set(frameWidth * 0.5, frameHeight);
			case 'left':
				origin.set(0, frameHeight * 0.5);
			case 'right':
				origin.set(frameWidth, frameHeight * 0.5);
			case 'd-upleft':
				origin.set(0, 0);
			case 'd-upright':
				origin.set(frameWidth, 0);
			case 'd-downleft':
				origin.set(0, frameHeight);
			case 'd-downright':
				origin.set(frameWidth, frameHeight);
			default:
				origin.set(frameWidth * 0.5, frameHeight * 0.5);
		}
	}

	static function readString(value:Dynamic, fallback:String):String {
		return value == null ? fallback : Std.string(value);
	}

	static function readBool(value:Dynamic, fallback:Bool):Bool {
		if(value == null)
			return fallback;
		if(Std.isOfType(value, Bool))
			return cast value;
		switch(Std.string(value).toLowerCase()) {
			case 'true' | '1' | 'yes' | 'on': return true;
			case 'false' | '0' | 'no' | 'off': return false;
		}
		return fallback;
	}

	static function readBoolAliases(data:Dynamic, fields:Array<String>, fallback:Bool):Bool {
		if(data != null)
			for(field in fields)
				if(Reflect.hasField(data, field))
					return readBool(Reflect.field(data, field), fallback);
		return fallback;
	}

	static function readInt(value:Dynamic, fallback:Int):Int {
		if(value == null)
			return fallback;
		var parsed:Null<Int> = Std.parseInt(Std.string(value));
		return parsed == null ? fallback : parsed;
	}

	static function readFloat(value:Dynamic, fallback:Float):Float {
		if(value == null)
			return fallback;
		var parsed:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	static function readIntArray(value:Dynamic, fallback:Array<Int>):Array<Int> {
		if(value == null)
			return fallback.copy();
		var source:Array<Dynamic> = Std.isOfType(value, Array) ? cast value : Std.string(value).split(',');
		var result:Array<Int> = [];
		for(item in source)
		{
			var parsed:Null<Int> = Std.parseInt(Std.string(item).trim());
			if(parsed != null)
				result.push(parsed);
		}
		return result.length > 0 ? result : fallback.copy();
	}

	public var autoAdjustOffset:Bool = true;
	override function updateHitbox()
	{
		super.updateHitbox();
		if(autoAdjustOffset)
		{
			offset.x = iconOffsets[0];
			offset.y = iconOffsets[1];
		}
	}

	public function centerIconOrigin():Void
	{
		origin.set(ICON_SIZE * 0.5, ICON_SIZE * 0.5);
	}

	public function getIconDisplayWidth():Float
	{
		return ICON_SIZE * Math.abs(scale.x);
	}

	public function getIconDisplayHeight():Float
	{
		return ICON_SIZE * Math.abs(scale.y);
	}

	public function centerIconOn(x:Float, y:Float):Void
	{
		updateHitbox();
		centerIconOrigin();
		setPosition(x - getIconDisplayWidth() * 0.5, y - getIconDisplayHeight() * 0.5);
	}

	public function getIconFrameCount():Int
	{
		if(frames != null && frames.frames != null)
			return frames.frames.length;
		return (animation.curAnim != null) ? animation.curAnim.numFrames : 0;
	}

	public function setIconFrame(frame:Int):Void
	{
		currentIconFrame = frame;
		switch(frame)
		{
			case 0:
				if(playIconTag(neutralTag))
					return;
			case 1:
				if(playIconTag(dyingTag))
					return;
			case 2:
				if(playIconTag(winningTag))
					return;
		}

		var total:Int = getIconFrameCount();
		if(total > 0)
			animation.curAnim.curFrame = Std.int(FlxMath.wrap(frame, 0, total - 1));
	}

	public inline function isDyingIcon():Bool
		return currentIconFrame == 1 || (dyingTag != null && currentIconTag == dyingTag);

	public inline function isWinningIcon():Bool
		return currentIconFrame == 2 || (winningTag != null && currentIconTag == winningTag);

	public inline function isNeutralIcon():Bool
		return !isDyingIcon() && !isWinningIcon();

	public inline function getIconFrame():Int
		return currentIconFrame;

	public function getCharacter():String {
		return char;
	}

	function loadIconScripts(char:String):Void {
		#if LUA_ALLOWED
		var luaPath:String = getIconScriptPath(char, '.lua');
		if(luaPath != null)
			initLuaIconScript(luaPath);
		#end

		#if HSCRIPT_ALLOWED
		for(ext in psychlua.HScript.SCRIPT_EXTENSIONS)
		{
			var hxPath:String = getIconScriptPath(char, ext);
			if(hxPath != null)
			{
				initHScriptIcon(hxPath);
				break;
			}
		}
		#end
	}

	function getIconScriptPath(char:String, extension:String):String {
		var path:String = Paths.getPath('images/game/icons/$char/icon$extension', TEXT);
		#if sys
		return sys.FileSystem.exists(path) ? path : null;
		#else
		return openfl.utils.Assets.exists(path, TEXT) ? path : null;
		#end
	}

	function getScriptTargetState():Dynamic {
		return PlayState.instance != null ? PlayState.instance : FlxG.state;
	}

	static function firstPropertySegment(variable:String):String {
		if(variable == null)
			return '';

		var dot:Int = variable.indexOf('.');
		var bracket:Int = variable.indexOf('[');
		var end:Int = variable.length;
		if(dot >= 0 && dot < end) end = dot;
		if(bracket >= 0 && bracket < end) end = bracket;
		return variable.substr(0, end);
	}

	function resolveScriptProperty(variable:String):Dynamic {
		var key:String = variable == null ? '' : variable.trim();
		var base:Dynamic = this;

		if(key.startsWith('icon.'))
			key = key.substr(5);
		else if(key.startsWith('this.'))
			key = key.substr(5);
		else if(key.startsWith('game.'))
		{
			key = key.substr(5);
			base = getScriptTargetState();
		}
		else if(key.startsWith('state.'))
		{
			key = key.substr(6);
			base = FlxG.state;
		}
		else if(key.indexOf('.') != -1 || key.indexOf('[') != -1)
		{
			var first:String = firstPropertySegment(key);
			if(first.length > 0 && !psychlua.LuaUtils.hasField(this, first))
				base = getScriptTargetState();
		}

		return {base: base, key: key};
	}

	function getIconScriptProperty(variable:String, allowMaps:Bool = false):Dynamic {
		var resolved:Dynamic = resolveScriptProperty(variable);
		if(resolved.base == this && resolved.key.indexOf('.') == -1 && resolved.key.indexOf('[') == -1)
		{
			switch(resolved.key)
			{
				case 'bitmapSize' | 'bitmap_size': return bitmapSize;
				case 'bitmapWidth' | 'bitmap_width': return bitmapWidth;
				case 'bitmapHeight' | 'bitmap_height': return bitmapHeight;
			}
			if(scriptProperties.exists(resolved.key))
				return scriptProperties.get(resolved.key);
		}
		return psychlua.LuaUtils.getPropertyLoop(resolved.key, allowMaps, resolved.base);
	}

	function setIconScriptProperty(variable:String, value:Dynamic, allowMaps:Bool = false):Dynamic {
		var resolved:Dynamic = resolveScriptProperty(variable);
		if(resolved.base == this && resolved.key.indexOf('.') == -1 && resolved.key.indexOf('[') == -1)
		{
			switch(resolved.key)
			{
				case 'bitmapSize' | 'bitmap_size':
					bitmapSize = readFloat(value, bitmapSize);
					return bitmapSize;
				case 'bitmapWidth' | 'bitmap_width':
					bitmapWidth = readInt(value, bitmapWidth);
					return bitmapWidth;
				case 'bitmapHeight' | 'bitmap_height':
					bitmapHeight = readInt(value, bitmapHeight);
					return bitmapHeight;
			}
		}
		if(resolved.base == this && resolved.key.indexOf('.') == -1 && resolved.key.indexOf('[') == -1 && !psychlua.LuaUtils.hasField(this, resolved.key))
		{
			scriptProperties.set(resolved.key, value);
			return value;
		}
		return psychlua.LuaUtils.setPropertyLoop(resolved.key, value, allowMaps, resolved.base);
	}

	static function shouldBlockForEditor(editorBlock:Dynamic):Bool {
		return isEditorStateTree() && editorBlock != false;
	}

	static function isEditorStateTree():Bool {
		var state:flixel.FlxState = FlxG.state;
		while(state != null)
		{
			if(isEditorState(state))
				return true;
			state = state.subState;
		}
		return false;
	}

	static function isEditorState(state:flixel.FlxState):Bool {
		if(state == null)
			return false;

		var cls = Type.getClass(state);
		var className:String = cls == null ? null : Type.getClassName(cls);
		return className != null && className.startsWith('states.editors.');
	}

	function scaleIconScriptObject(objName:String, x:Float, y:Float, updateHitbox:Bool = true):Bool {
		var name:String = objName == null ? '' : objName.trim();
		var obj:Dynamic = null;
		if(name.length < 1 || name == 'icon' || name == 'this')
			obj = this;
		else
			obj = psychlua.LuaUtils.getObjectDirectly(name, false, getScriptTargetState());

		if(obj == null || Reflect.field(obj, 'scale') == null)
			return false;

		obj.scale.set(x, y);
		if(updateHitbox && Reflect.field(obj, 'updateHitbox') != null)
			obj.updateHitbox();
		return true;
	}

	#if LUA_ALLOWED
	function initLuaIconScript(path:String):Void {
		try {
			var lua:psychlua.FunkinLua = new psychlua.FunkinLua(path, FlxG.state);
			configureLuaIconScript(lua);
			luaArray.push(lua);
			lua.call('onCreate');
		} catch(e:Dynamic) {
			Log.print(e, FATAL);
		}
	}

	function configureLuaIconScript(lua:psychlua.FunkinLua):Void {
		lua.set('icon', this);
		lua.set('this', this);
		lua.set('iconName', char);
		lua.set('isPlayerIcon', isPlayer);
		lua.set('isIconScript', true);
		lua.set('editorBlock', true);
		lua.addLocalCallback('getProperty', function(variable:String, allowMaps:Bool = false) {
			return getIconScriptProperty(variable, allowMaps);
		});
		lua.addLocalCallback('setProperty', function(variable:String, value:Dynamic, allowMaps:Bool = false, allowInstances:Bool = false) {
			if(allowInstances) value = psychlua.ReflectionFunctions.parseInstances(value);
			return setIconScriptProperty(variable, value, allowMaps);
		});
		lua.addLocalCallback('updateHitbox', function() {
			updateHitbox();
		});
		lua.addLocalCallback('scaleObject', function(objName:String, x:Float, y:Float, updateHitbox:Bool = true) {
			return scaleIconScriptObject(objName, x, y, updateHitbox);
		});
		lua.addLocalCallback('setIconSize', function(width:Float, height:Float = -1) {
			return setIconSize(width, height);
		});
		lua.addLocalCallback('setIconBitmapSize', function(width:Float, height:Float = -1) {
			return setIconSize(width, height);
		});
		lua.addLocalCallback('isDyingIcon', function() return isDyingIcon());
		lua.addLocalCallback('isWinningIcon', function() return isWinningIcon());
		lua.addLocalCallback('isNeutralIcon', function() return isNeutralIcon());
		lua.addLocalCallback('getIconFrame', function() return getIconFrame());
		lua.addLocalCallback('playIconAnim', function(tag:String, force:Bool = true) {
			if(tag != null && animation.getByName(tag) != null)
			{
				animation.play(tag, force);
				currentIconTag = tag;
				return true;
			}
			return false;
		});
	}
	#end

	#if HSCRIPT_ALLOWED
	function initHScriptIcon(path:String):Void {
		var script:psychlua.HScript = null;
		try {
			script = new psychlua.HScript(null, path, null, true, FlxG.state);
			configureHScriptIcon(script);
			script.unsafe = true;
			script.execute();
			if(script.exists('onCreate'))
				script.call('onCreate');
			script.unsafe = false;
			hscriptArray.push(script);
		} catch(e:Dynamic) {
			psychlua.HScript.catchError(script, e);
			script?.destroy();
		}
	}

	function configureHScriptIcon(script:psychlua.HScript):Void {
		script.set('icon', this);
		script.set('this', this);
		script.set('iconName', char);
		script.set('isPlayerIcon', isPlayer);
		script.set('isIconScript', true);
		script.set('editorBlock', true);
		script.set('getProperty', function(variable:String, allowMaps:Bool = false) {
			return getIconScriptProperty(variable, allowMaps);
		});
		script.set('setProperty', function(variable:String, value:Dynamic, allowMaps:Bool = false) {
			return setIconScriptProperty(variable, value, allowMaps);
		});
		script.set('updateHitbox', function() {
			updateHitbox();
		});
		script.set('scaleObject', function(objName:String, x:Float, y:Float, updateHitbox:Bool = true) {
			return scaleIconScriptObject(objName, x, y, updateHitbox);
		});
		script.set('setIconSize', function(width:Float, height:Float = -1) {
			return setIconSize(width, height);
		});
		script.set('setIconBitmapSize', function(width:Float, height:Float = -1) {
			return setIconSize(width, height);
		});
		script.set('isDyingIcon', function() return isDyingIcon());
		script.set('isWinningIcon', function() return isWinningIcon());
		script.set('isNeutralIcon', function() return isNeutralIcon());
		script.set('getIconFrame', function() return getIconFrame());
		script.set('playIconAnim', function(tag:String, force:Bool = true) {
			if(tag != null && animation.getByName(tag) != null)
			{
				animation.play(tag, force);
				currentIconTag = tag;
				return true;
			}
			return false;
		});
	}
	#end

	function destroyIconScripts():Void {
		#if LUA_ALLOWED
		if(luaArray != null)
		{
			for(lua in luaArray)
				if(lua != null)
				{
					lua.call('onDestroy');
					lua.stop();
				}
			luaArray.resize(0);
		}
		#end

		#if HSCRIPT_ALLOWED
		if(hscriptArray != null)
		{
			for(script in hscriptArray)
				if(script != null)
				{
					if(script.exists('onDestroy'))
						script.call('onDestroy');
					script.destroy();
				}
			hscriptArray.resize(0);
		}
		#end
	}

	override function destroy():Void {
		destroyIconScripts();
		super.destroy();
	}
}
