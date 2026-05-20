package objects;

import backend.animation.PsychAnimationController;

import flixel.util.FlxSort;
import flixel.util.FlxDestroyUtil;

import openfl.utils.AssetType;
import openfl.utils.Assets;
import haxe.Json;

import backend.Song;
import states.stages.objects.TankmenBG;

import shaders.DropShadowShader;

typedef CharacterFile = {
	var animations:Array<AnimArray>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;

	var flip_x:Bool;
	var no_antialiasing:Bool;
	var healthbar_colors:Array<Int>;
	var vocals_file:String;
	@:optional var vslice_sustains:Null<Bool>;
}

typedef AnimArray = {
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
	@:optional var offsets_player:Null<Array<Int>>; // ce acredita que eu esqueci de colocar isso?
	@:optional var name_player:Null<String>;
	@:optional var name_opponent:Null<String>;
	@:optional var indices_player:Null<Array<Int>>;
	@:optional var indices_opponent:Null<Array<Int>>;
}

typedef CharacterDataCacheEntry = {
	var stamp:Float;
	var data:Dynamic;
}

class Character extends FlxSprite
{
	/**
	 * In case a character isMissing, it will use this on its place
	**/
	public static final DEFAULT_CHARACTER:String = 'bf';
	public static final NONE_CHARACTER:String = 'none';

	public var animOffsets:Map<String, Array<Dynamic>>;
	public var debugMode:Bool = false;

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var animationNotes:Array<Dynamic> = [];
	public var stunned:Bool = false;
	public var singDuration:Float = 4; //Multiplier of how long a character holds the sing pose
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false; //Character use "danceLeft" and "danceRight" instead of "idle"
	public var skipDance:Bool = false;

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimArray> = [];

	public var positionArray:Array<Float> = [0, 0];
	public var cameraPosition:Array<Float> = [0, 0];
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public var MissingCharacter:Bool = false;
	public var isNullCharacter:Bool = false;
	public var MissingText:FlxText;
	public var hasMissAnimations:Bool = false;
	public var vocalsFile:String = '';

	//Used on Character Editor
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var vSliceSustains:Bool = false;
	
	public var canPlayComboAnim:Bool = true;
	public var canPlayDropAnim:Bool = true;
	
	public var comboNoteCounts:Array<Int> = [];
	public var dropNoteCounts:Array<Int> = [];

    public var dropShadow:DropShadowShader;

	public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false)
	{
		super(x, y);

		animation = new PsychAnimationController(this);

		animOffsets = new Map<String, Array<Dynamic>>();
		this.isPlayer = isPlayer;
		changeCharacter(character);
		
		switch(curCharacter)
		{
			case 'pico-speaker':
				skipDance = true;
				loadMappedAnims();
				playAnim("shoot1");
			case 'pico-blazin', 'darnell-blazin':
				skipDance = true;
		}
	}

	public function changeCharacter(character:String)
	{
		animationsArray = [];
		animOffsets = [];
		character = normalizeCharacterName(character);
		curCharacter = character;

		if(isNoneCharacter(character))
		{
			loadNullCharacter();
			skipDance = false;
			return;
		}

		if(isNullCharacter)
		{
			visible = true;
			active = true;
		}
		isNullCharacter = false;
		var path:String = getCharacterPath(character);
		if (path == null)
		{
			path = getCharacterPath(DEFAULT_CHARACTER); //If a character couldn't be found, change him to BF just to prevent a crash
			MissingCharacter = true;
			
			if (MissingText == null) {
				MissingText = new FlxText(0, 0, 300, 'ERROR:\n$character', 16);
				MissingText.alignment = CENTER;
			}
			MissingText.revive();
		} else {
			MissingCharacter = false;
			
			MissingText?.kill();
		}

		try
		{
			if(path != null)
				loadCharacterFile(getCharacterData(path));
		}
		catch(e:Dynamic)
		{
			trace('Error loading character file of "$character": $e');
		}

		skipDance = false;
		hasMissAnimations = hasAnimation('singLEFTmiss') || hasAnimation('singDOWNmiss') || hasAnimation('singUPmiss') || hasAnimation('singRIGHTmiss');
		recalculateDanceIdle();
		dance();
	}

	public static final CHARACTER_FILE_FOLDERS:Array<String> = ['data/chrs/', 'data/characters/']; // wink
	public static final CHARACTER_FILE_EXTENSIONS:Array<String> = ['.xml', '.json'];
	static inline final MissING_CHARACTER_PATH:String = '\x00';
	static inline final NONE_CHARACTER_PATH:String = '\x01';
	static var characterPathCache:Map<String, String> = new Map<String, String>();
	static var characterDataCache:Map<String, CharacterDataCacheEntry> = new Map<String, CharacterDataCacheEntry>();
	static var characterCacheContext:String = null;

	static function getCharacterCacheContext():String
	{
		#if MODS_ALLOWED
		return [
			Mods.getSelectedContentDirectory(),
			Mods.currentModDirectory ?? '',
			Mods.currentPackageDirectory ?? '',
			Mods.globalMods.join('|'),
			Mods.globalPackageMods.join('|')
		].join('\n');
		#else
		return '';
		#end
	}

	static function syncCharacterCacheContext():Void
	{
		var context:String = getCharacterCacheContext();
		if(characterCacheContext == context) return;

		characterCacheContext = context;
		characterPathCache = new Map<String, String>();
		characterDataCache = new Map<String, CharacterDataCacheEntry>();
	}

	static function getCharacterCacheKey(character:String):String
	{
		syncCharacterCacheContext();
		return '$characterCacheContext\n${character.trim()}';
	}

	public static function normalizeCharacterName(character:String):String
	{
		if(character == null) return '';
		return character.trim();
	}

	public static function isNoneCharacter(character:String):Bool
		return normalizeCharacterName(character).toLowerCase() == NONE_CHARACTER;

	public static function clearCharacterCache(?character:String):Void
	{
		syncCharacterCacheContext();
		if(character == null || character.trim().length < 1)
		{
			characterPathCache = new Map<String, String>();
			characterDataCache = new Map<String, CharacterDataCacheEntry>();
			return;
		}

		var key:String = getCharacterCacheKey(character);
		var path:String = characterPathCache.get(key);
		characterPathCache.remove(key);
		if(path != null && path !=MissING_CHARACTER_PATH && path != NONE_CHARACTER_PATH)
			characterDataCache.remove(path);
	}

	static function cloneCharacterData(data:Dynamic):Dynamic
	{
		if(data == null) return null;
		return Json.parse(Json.stringify(data));
	}

	static function getCharacterFileStamp(path:String):Float
	{
		#if sys
		try
		{
			if(path != null && FileSystem.exists(path))
				return FileSystem.stat(path).mtime.getTime();
		}
		catch(e:Dynamic) {}
		#end
		return 0;
	}

	static function pathExists(path:String):Bool
	{
		if(path == null || path.length < 1) return false;
		#if sys
		return FileSystem.exists(path);
		#else
		return Assets.exists(path);
		#end
	}

	public static function getCharacterPath(character:String):String
	{
		character = normalizeCharacterName(character);
		if(character.length < 1) return null;
		var cacheKey:String = getCharacterCacheKey(character);
		if(characterPathCache.exists(cacheKey))
		{
			var cachedPath:String = characterPathCache.get(cacheKey);
			return cachedPath !=MissING_CHARACTER_PATH ? cachedPath : null;
		}

		if(isNoneCharacter(character))
		{
			characterPathCache.set(cacheKey, NONE_CHARACTER_PATH);
			return NONE_CHARACTER_PATH;
		}

		for(folder in CHARACTER_FILE_FOLDERS)
		{
			for(ext in CHARACTER_FILE_EXTENSIONS)
			{
				var path:String = Paths.getPath(folder + character + ext, TEXT);
				if(pathExists(path))
				{
					characterPathCache.set(cacheKey, path);
					return path;
				}
			}
		}
		return null;
	}

	public static function appendCharacterFileList(list:Array<String>):Array<String>
	{
		if(list == null) list = [];
		if(!list.contains(NONE_CHARACTER)) list.insert(0, NONE_CHARACTER);

		#if sys
		for(folder in CHARACTER_FILE_FOLDERS)
		{
			for(directory in Mods.directoriesWithFile(Paths.getSharedPath(), folder))
			{
				for(file in FileSystem.readDirectory(directory))
				{
					var lower:String = file.toLowerCase();
					for(ext in CHARACTER_FILE_EXTENSIONS)
					{
						if(lower.endsWith(ext))
						{
							var charToCheck:String = file.substr(0, file.length - ext.length);
							if(charToCheck.length > 0 && !list.contains(charToCheck))
								list.push(charToCheck);
							break;
						}
					}
				}
			}
		}
		#end
		return list;
	}

	public static function readCharacterPath(path:String):String
	{
		#if MODS_ALLOWED
		return Paths.getTextFromFile(path);
		#else
		return Assets.getText(path);
		#end
	}

	public static function getCharacterData(path:String):Dynamic
	{
		if(path == null) return {};
		if(path == NONE_CHARACTER_PATH) return getNullCharacterData();
		syncCharacterCacheContext();
		var stamp:Float = getCharacterFileStamp(path);
		var cached:CharacterDataCacheEntry = characterDataCache.get(path);
		if(cached != null && cached.stamp == stamp)
			return cloneCharacterData(cached.data);

		var data:Dynamic = parseCharacterData(readCharacterPath(path), path);
		characterDataCache.set(path, {stamp: stamp, data: data});
		return cloneCharacterData(data);
	}

	public static function getNullCharacterData():Dynamic
	{
		return {
			is_null_character: true,
			animations: [],
			image: '',
			scale: 1,
			sing_duration: 4,
			healthicon: NONE_CHARACTER,
			position: [0, 0],
			camera_position: [0, 0],
			flip_x: false,
			no_antialiasing: false,
			healthbar_colors: [161, 161, 161],
			vocals_file: '',
			vslice_sustains: false
		};
	}

	public static function parseCharacterData(raw:String, ?path:String):Dynamic
	{
		if(raw == null) return {};
		var lowerPath:String = path == null ? '' : path.toLowerCase();
		if(lowerPath.endsWith('.xml') || raw.trim().startsWith('<'))
			return parseCharacterXml(raw);
		return Json.parse(raw);
	}

	static function firstField(data:Dynamic, fields:Array<String>):Dynamic
	{
		if (data == null) return null;
		for (field in fields)
			if (Reflect.hasField(data, field))
				return Reflect.field(data, field);
		return null;
	}

	static function readString(value:Dynamic, fallback:String):String
	{
		if (value == null) return fallback;
		return Std.string(value);
	}

	static function readBool(value:Dynamic, fallback:Bool):Bool
	{
		if (value == null) return fallback;
		if (Std.isOfType(value, Bool)) return value == true;

		switch (Std.string(value).trim().toLowerCase())
		{
			case 'true' | '1' | 'yes' | 'y' | 'on':
				return true;
			case 'false' | '0' | 'no' | 'n' | 'off':
				return false;
		}
		return fallback;
	}

	static function readFloat(value:Dynamic, fallback:Float):Float
	{
		if (value == null) return fallback;
		var parsed:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	static function readFloatArray(value:Dynamic, fallback:Array<Float>):Array<Float>
	{
		var output:Array<Float> = fallback.copy();
		if (value == null || !Std.isOfType(value, Array)) return output;

		var values:Array<Dynamic> = cast value;
		for (i in 0...Std.int(Math.min(output.length, values.length)))
			output[i] = readFloat(values[i], output[i]);
		return output;
	}

	static function readIntArray(value:Dynamic, fallback:Array<Int>):Array<Int>
	{
		var output:Array<Int> = fallback.copy();
		if (value == null || !Std.isOfType(value, Array)) return output;

		var values:Array<Dynamic> = cast value;
		if (fallback.length < 1) output = [];
		for (i in 0...values.length)
		{
			var parsed:Float = readFloat(values[i], Math.NaN);
			if (!Math.isNaN(parsed))
			{
				if (fallback.length > 0 && i < output.length)
					output[i] = Math.round(parsed);
				else
					output.push(Math.round(parsed));
			}
		}
		return output;
	}

	static function readOptionalIntArray(value:Dynamic):Null<Array<Int>>
	{
		if (value == null || !Std.isOfType(value, Array)) return null;
		return readIntArray(value, []);
	}

	static function readColorArray(value:Dynamic, fallback:Array<Int>):Array<Int>
	{
		if (value != null && Std.isOfType(value, Array))
			return readIntArray(value, fallback);

		var color:Null<FlxColor> = null;
		if (value != null)
		{
			color = FlxColor.fromString(Std.string(value));
			if (color == null)
			{
				var parsed:Float = readFloat(value, Math.NaN);
				if (!Math.isNaN(parsed)) color = FlxColor.fromInt(Math.round(parsed));
			}
		}

		return color != null ? [color.red, color.green, color.blue] : fallback.copy();
	}

	static function xmlAttr(node:Xml, names:Array<String>, ?fallback:String = null):String
	{
		if(node == null) return fallback;
		for(name in names)
		{
			var value:String = node.get(name);
			if(value != null)
				return value;
		}
		return fallback;
	}

	static function parseXmlIndices(value:String):Array<Int>
	{
		var indices:Array<Int> = [];
		if(value == null || value.trim().length < 1) return indices;

		for(raw in value.split(','))
		{
			var parsed:Null<Int> = Std.parseInt(raw.trim());
			if(parsed != null)
				indices.push(parsed);
		}
		return indices;
	}

	static function xmlOffset(node:Xml, xNames:Array<String>, yNames:Array<String>):Array<Int>
	{
		return [
			Math.round(readFloat(xmlAttr(node, xNames), 0)),
			Math.round(readFloat(xmlAttr(node, yNames), 0))
		];
	}

	static function parseCharacterXml(raw:String):Dynamic
	{
		var root:Xml = Xml.parse(raw).firstElement();
		if(root == null || root.nodeName != 'character')
			return {};

		var assets:Array<String> = [];
		pushAssetPath(assets, xmlAttr(root, ['assetPath', 'image']));
		for(assetsNode in root.elementsNamed('assets'))
		{
			for(assetNode in assetsNode.elementsNamed('asset'))
				pushAssetPath(assets, xmlAttr(assetNode, ['path', 'assetPath', 'image']));
		}
		if(assets.length < 1)
			assets.push('characters/bf');

		var animations:Array<AnimArray> = [];
		for(animationsNode in root.elementsNamed('animations'))
		{
			for(animNode in animationsNode.elementsNamed('anim'))
			{
				pushAssetPath(assets, xmlAttr(animNode, ['assetPath', 'image']));
				pushAssetPath(assets, xmlAttr(animNode, ['playerAssetPath', 'assetPathPlayer']));
				pushAssetPath(assets, xmlAttr(animNode, ['opponentAssetPath', 'assetPathOpponent']));
				var animName:String = xmlAttr(animNode, ['id', 'anim', 'name'], 'idle');
				var symbol:String = xmlAttr(animNode, ['symbol', 'prefix'], animName);
				var animData:AnimArray = {
					anim: animName,
					name: symbol,
					fps: Math.round(readFloat(xmlAttr(animNode, ['fps', 'frameRate']), 24)),
					loop: readBool(xmlAttr(animNode, ['loop', 'looped']), false),
					indices: parseXmlIndices(xmlAttr(animNode, ['indices', 'frameIndices'])),
					offsets: xmlOffset(animNode, ['x', 'offsetX'], ['y', 'offsetY'])
				};

				var playerX:String = xmlAttr(animNode, ['playerX', 'xPlayer', 'offsetPlayerX']); //whatever who is reading this, make ts better
				var playerY:String = xmlAttr(animNode, ['playerY', 'yPlayer', 'offsetPlayerY']);
				if(playerX != null || playerY != null)
					animData.offsets_player = xmlOffset(animNode, ['playerX', 'xPlayer', 'offsetPlayerX'], ['playerY', 'yPlayer', 'offsetPlayerY']);

				var playerSymbol:String = xmlAttr(animNode, ['playerSymbol', 'symbolPlayer', 'playerPrefix', 'prefixPlayer', 'playerName', 'namePlayer']);
				if(playerSymbol != null)
					animData.name_player = playerSymbol;
				var opponentSymbol:String = xmlAttr(animNode, ['opponentSymbol', 'symbolOpponent', 'opponentPrefix', 'prefixOpponent', 'opponentName', 'nameOpponent']);
				if(opponentSymbol != null)
					animData.name_opponent = opponentSymbol;

				var playerIndices:Array<Int> = parseXmlIndices(xmlAttr(animNode, ['playerIndices', 'indicesPlayer', 'playerFrameIndices', 'frameIndicesPlayer']));
				if(playerIndices.length > 0)
					animData.indices_player = playerIndices;
				var opponentIndices:Array<Int> = parseXmlIndices(xmlAttr(animNode, ['opponentIndices', 'indicesOpponent', 'opponentFrameIndices', 'frameIndicesOpponent']));
				if(opponentIndices.length > 0)
					animData.indices_opponent = opponentIndices;
				animations.push(animData);
			}
		}

		return {
			animations: animations,
			image: assets.join(','),
			scale: readFloat(xmlAttr(root, ['scale']), 1),
			sing_duration: readFloat(xmlAttr(root, ['singDuration', 'sing_duration', 'singTime']), 4),
			healthicon: xmlAttr(root, ['icon', 'healthIcon', 'healthicon'], 'face'),
			position: [
				readFloat(xmlAttr(root, ['x', 'positionX']), 0),
				readFloat(xmlAttr(root, ['y', 'positionY']), 0)
			],
			camera_position: [
				readFloat(xmlAttr(root, ['cameraX', 'camX']), 0),
				readFloat(xmlAttr(root, ['cameraY', 'camY']), 0)
			],
			flip_x: readBool(xmlAttr(root, ['flipX', 'flip_x']), false),
			no_antialiasing: readBool(xmlAttr(root, ['noAntialiasing', 'no_antialiasing', 'isPixel']), false),
			healthbar_colors: readColorArray(xmlAttr(root, ['healthColor', 'healthbarColor', 'healthBarColor']), [161, 161, 161]),
			vocals_file: xmlAttr(root, ['vocalsFile', 'vocals_file'], ''),
			vslice_sustains: readBool(xmlAttr(root, ['vsliceHolds', 'vslice_holds', 'vslice_sustains', 'vSliceSustains']), false)
		};
	}

	static function normalizeImageKey(value:Dynamic):String
	{
		var key:String = readString(value, '').replace('\\', '/').trim();
		if (key.length < 1) return '';

		var slashIndex:Int = key.indexOf('/');
		var colonIndex:Int = key.indexOf(':');
		if (colonIndex >= 0 && (slashIndex < 0 || colonIndex < slashIndex))
			key = key.substr(colonIndex + 1);

		var marker:String = '/images/';
		var markerIndex:Int = key.indexOf(marker);
		if (markerIndex >= 0)
			key = key.substr(markerIndex + marker.length);
		else if (key.startsWith('images/'))
			key = key.substr('images/'.length);

		for (ext in ['.png', '.xml', '.txt', '.json'])
			if (key.toLowerCase().endsWith(ext))
				key = key.substr(0, key.length - ext.length);
		return key;
	}

	static function pushAssetPath(paths:Array<String>, value:Dynamic):Void
	{
		var key:String = normalizeImageKey(value);
		if (key.length > 0 && !paths.contains(key))
			paths.push(key);
	}

	static function normalizeCharacterImage(data:Dynamic):String
	{
		var paths:Array<String> = [];
		var oldImage:Dynamic = firstField(data, ['image']);
		if (oldImage != null)
		{
			for (image in Std.string(oldImage).split(','))
				pushAssetPath(paths, image);
		}
		else
		{
			pushAssetPath(paths, firstField(data, ['assetPath']));
			var animations:Dynamic = firstField(data, ['animations']);
			if (animations != null && Std.isOfType(animations, Array))
			{
				for (anim in (cast animations : Array<Dynamic>))
					pushAssetPath(paths, firstField(anim, ['assetPath']));
			}
		}

		if (paths.length < 1)
			paths.push('characters/bf');
		return paths.join(',');
	}

	static function normalizeCharacterAnimations(value:Dynamic):Array<AnimArray>
	{
		var output:Array<AnimArray> = [];
		if (value == null || !Std.isOfType(value, Array)) return output;

		for (anim in (cast value : Array<Dynamic>))
		{
			if (anim == null) continue;

			var psychAnimName:String = readString(firstField(anim, ['anim']), null);
			var animName:String = psychAnimName != null ? psychAnimName : readString(firstField(anim, ['name']), 'idle');
			if (animName.endsWith('-hold'))
				animName = animName.substr(0, animName.length - '-hold'.length) + '-loop';

			var prefix:String = psychAnimName != null ? readString(firstField(anim, ['name', 'prefix']), animName) : readString(firstField(anim, ['prefix']), animName);
			var animData:AnimArray = {
				offsets: readIntArray(firstField(anim, ['offsets']), [0, 0]),
				loop: readBool(firstField(anim, ['loop', 'looped']), false),
				fps: Math.round(readFloat(firstField(anim, ['fps', 'frameRate']), 24)),
				anim: animName,
				indices: readIntArray(firstField(anim, ['indices', 'frameIndices']), []),
				name: prefix
			};

			var playerOffsets:Null<Array<Int>> = readOptionalIntArray(firstField(anim, ['offsets_player']));
			if (playerOffsets != null && playerOffsets.length > 1)
				animData.offsets_player = playerOffsets;

			var playerName:String = readString(firstField(anim, ['name_player', 'namePlayer', 'playerName', 'prefix_player', 'prefixPlayer', 'playerPrefix', 'symbol_player', 'symbolPlayer', 'playerSymbol']), null);
			if(playerName != null && playerName.length > 0)
				animData.name_player = playerName;
			var opponentName:String = readString(firstField(anim, ['name_opponent', 'nameOpponent', 'opponentName', 'prefix_opponent', 'prefixOpponent', 'opponentPrefix', 'symbol_opponent', 'symbolOpponent', 'opponentSymbol']), null);
			if(opponentName != null && opponentName.length > 0)
				animData.name_opponent = opponentName;

			var playerIndices:Null<Array<Int>> = readOptionalIntArray(firstField(anim, ['indices_player', 'indicesPlayer', 'playerIndices', 'frameIndicesPlayer', 'playerFrameIndices']));
			if(playerIndices != null)
				animData.indices_player = playerIndices;
			var opponentIndices:Null<Array<Int>> = readOptionalIntArray(firstField(anim, ['indices_opponent', 'indicesOpponent', 'opponentIndices', 'frameIndicesOpponent', 'opponentFrameIndices']));
			if(opponentIndices != null)
				animData.indices_opponent = opponentIndices;
			output.push(animData);
		}
		return output;
	}

	static function normalizeCharacterFile(data:Dynamic):Dynamic
	{
		var healthIconData:Dynamic = firstField(data, ['healthIcon']);
		var healthIcon:String = readString(firstField(data, ['healthicon']), null);
		if (healthIcon == null && healthIconData != null)
			healthIcon = readString(firstField(healthIconData, ['id']), null);
		if (healthIcon == null)
			healthIcon = 'face';

		return {
			animations: normalizeCharacterAnimations(firstField(data, ['animations'])),
			image: normalizeCharacterImage(data),
			scale: readFloat(firstField(data, ['scale']), 1),
			sing_duration: readFloat(firstField(data, ['sing_duration', 'singTime']), 4),
			healthicon: healthIcon,
			position: readFloatArray(firstField(data, ['position', 'offsets']), [0, 0]),
			camera_position: readFloatArray(firstField(data, ['camera_position', 'cameraOffsets']), [0, 0]),
			flip_x: readBool(firstField(data, ['flip_x', 'flipX']), false),
			no_antialiasing: readBool(firstField(data, ['no_antialiasing', 'isPixel']), false),
			healthbar_colors: readColorArray(firstField(data, ['healthbar_colors', 'healthbarColors', 'healthBarColor']), [161, 161, 161]),
			vocals_file: readString(firstField(data, ['vocals_file']), ''),
			vslice_sustains: readBool(firstField(data, ['vslice_sustains', 'vSliceSustains', 'vsliceHolds', 'vslice_holds']), false)
		};
	}

	function loadNullCharacter():Void
	{
		isNullCharacter = true;
		MissingCharacter = false;
		MissingText?.kill();

		#if flxanimate
		atlas = null;
		#end
		isAnimateAtlas = false;
		animation.destroyAnimations();
		makeGraphic(1, 1, 0x00000000);

		imageFile = '';
		jsonScale = 1;
		scale.set(1, 1);
		updateHitbox();
		offset.set();
		positionArray = [0, 0];
		cameraPosition = [0, 0];

		healthIcon = NONE_CHARACTER;
		healthColorArray = [161, 161, 161];
		vocalsFile = '';
		singDuration = 4;
		originalFlipX = false;
		flipX = false;
		noAntialiasing = false;
		vSliceSustains = false;
		hasMissAnimations = false;
		comboNoteCounts = [];
		dropNoteCounts = [];
		_lastPlayedAnimation = null;
		visible = false;
		active = false;
	}

	public function loadCharacterFile(json:Dynamic) // finalmente, personagens a mão
	{
		if(json != null && Reflect.field(json, 'is_null_character') == true)
		{
			loadNullCharacter();
			return;
		}

		if(isNullCharacter)
		{
			visible = true;
			active = true;
		}
		isNullCharacter = false;
		json = normalizeCharacterFile(json);

		isAnimateAtlas = false;

		isAnimateAtlas = false;

		#if flxanimate
		isAnimateAtlas = Paths.isAnimateAtlas(json.image);
		#end

		scale.set(1, 1);
		updateHitbox();

		if(!isAnimateAtlas)
		{
			frames = Paths.getMultiAtlas(json.image.split(','));
		}
		#if flxanimate
		else
		{
			atlas = new FlxAnimate();
			atlas.showPivot = false;
			try
			{
				Paths.loadAnimateAtlas(atlas, json.image);
			}
			catch(e:haxe.Exception)
			{
				FlxG.log.warn('Could not load atlas ${json.image}: $e');
				trace(e.stack);
			}
		}
		#end

		imageFile = json.image;
		jsonScale = readFloat(json.scale, 1);
		if(jsonScale != 1) {
			scale.set(jsonScale, jsonScale);
			updateHitbox();
		}

		// positioning
		positionArray = readFloatArray(json.position, [0, 0]);
		cameraPosition = readFloatArray(json.camera_position, [0, 0]);

		// data
		healthIcon = json.healthicon;
		singDuration = readFloat(json.sing_duration, 4);
		flipX = (json.flip_x != isPlayer);
		healthColorArray = (json.healthbar_colors != null && json.healthbar_colors.length > 2) ? json.healthbar_colors : [161, 161, 161];
		vocalsFile = json.vocals_file != null ? json.vocals_file : '';
		originalFlipX = (json.flip_x == true);
		vSliceSustains = json.vslice_sustains == true;

		// antialiasing
		noAntialiasing = (json.no_antialiasing == true);
		antialiasing = ClientPrefs.data.antialiasing ? !noAntialiasing : false;

		// animations
		animationsArray = json.animations;
		if(animationsArray != null && animationsArray.length > 0) {
			for (anim in animationsArray) {
				if (anim.anim == null || anim.name == null) continue;
				
				addCharacterAnimation(anim);

				/*if(anim.offsets != null && anim.offsets.length > 1) addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
				else addOffset(anim.anim, 0, 0);*/
			}
		}

		
		refreshOffsets(); // aplica as bct
		
		comboNoteCounts = findCountAnims('combo');
		dropNoteCounts = findCountAnims('drop');
		
		#if flxanimate
		if (isAnimateAtlas) copyAtlasValues();
		#end
		//trace('Loaded file to character ' + curCharacter);
	}

	override function update(elapsed:Float)
	{
		if(isAnimateAtlas) atlas.update(elapsed);

		if(debugMode || (!isAnimateAtlas && animation.curAnim == null) || (isAnimateAtlas && !atlas.hasActiveAtlasAnimation()))
		{
			super.update(elapsed);
			return;
		}

		if(heyTimer > 0)
		{
			var rate:Float = (PlayState.instance != null ? PlayState.instance.playbackRate : 1.0);
			heyTimer -= elapsed * rate;
			if(heyTimer <= 0)
			{
				var anim:String = getAnimationName();
				if(specialAnim && (anim == 'hey' || anim == 'cheer'))
				{
					specialAnim = false;
					dance();
				}
				heyTimer = 0;
			}
		}
		else if(specialAnim && isAnimationFinished())
		{
			specialAnim = false;
			dance();
		}
		else if (getAnimationName().endsWith('miss') && isAnimationFinished())
		{
			dance();
			finishAnimation();
		}

		switch(curCharacter)
		{
			case 'pico-speaker':
				if(animationNotes.length > 0 && Conductor.songPosition > animationNotes[0][0])
				{
					var noteData:Int = 1;
					if(animationNotes[0][1] > 2) noteData = 3;

					noteData += FlxG.random.int(0, 1);
					playAnim('shoot' + noteData, true);
					animationNotes.shift();
				}
				if(isAnimationFinished()) playAnim(getAnimationName(), false, false, animation.curAnim.frames.length - 3);
		}

		if (getAnimationName().startsWith('sing')) holdTimer += elapsed;
		else if(isPlayer) holdTimer = 0;

		if (!isPlayer && holdTimer >= Conductor.stepCrochet * (0.0011 #if FLX_PITCH / (FlxG.sound.music != null ? FlxG.sound.music.pitch : 1) #end) * singDuration)
		{
			dance();
			holdTimer = 0;
		}

		var name:String = getAnimationName();
		if(isAnimationFinished() && hasAnimation('$name-loop'))
			playAnim('$name-loop');

		super.update(elapsed);
	}

	inline public function isAnimationNull():Bool
	{
		return !isAnimateAtlas ? (animation.curAnim == null) : !atlas.hasActiveAtlasAnimation();
	}

	var _lastPlayedAnimation:String;
	inline public function getAnimationName():String
	{
		return _lastPlayedAnimation;
	}

	public function isAnimationFinished():Bool
	{
		if(isAnimationNull()) return false;
		return !isAnimateAtlas ? animation.curAnim.finished : atlas.anim.finished;
	}

	public function finishAnimation():Void
	{
		if(isAnimationNull()) return;

		if(!isAnimateAtlas) animation.curAnim.finish();
		else atlas.finishAtlasAnimation();
	}

	public function hasAnimation(anim:String):Bool
	{
		return animOffsets.exists(anim);
	}

	public function playSingAnimation(animToPlay:String, isSustainNote:Bool):Bool
	{
		if(isNullCharacter) return false;

		if(isSustainNote)
		{
			if(vSliceSustains)
			{
				animToPlay = resolveSingAnimation(animToPlay);
				var loopAnim:String = resolveSingLoopAnimation(animToPlay);
				var currentAnim:String = getAnimationName();
				if(currentAnim != animToPlay && currentAnim != loopAnim)
				{
					if(hasAnimation(animToPlay))
						playAnim(animToPlay, true);
					else if(loopAnim != null)
						playAnim(loopAnim, true);
					else
						return false;
					return true;
				}
				if(currentAnim == animToPlay && isAnimationFinished() && loopAnim != null)
				{
					playAnim(loopAnim, true);
					return true;
				}
				return false;
			}

			var holdAnim:String = animToPlay + '-hold';
			if(!hasAnimation(holdAnim))
			{
				var resolvedAnim:String = resolveSingAnimation(animToPlay);
				var resolvedHoldAnim:String = resolvedAnim + '-hold';
				if(hasAnimation(resolvedHoldAnim))
					holdAnim = resolvedHoldAnim;
				else
					animToPlay = resolvedAnim;
			}
			else
				animToPlay = holdAnim;

			if(hasAnimation(holdAnim))
				animToPlay = holdAnim;
			if(getAnimationName() == holdAnim || getAnimationName() == holdAnim + '-loop')
				return false;
		}

		animToPlay = resolveSingAnimation(animToPlay);
		if(!hasAnimation(animToPlay)) return false;
		playAnim(animToPlay, true);
		return true;
	}

	function resolveSingAnimation(anim:String):String
	{
		if(anim == null || hasAnimation(anim)) return anim;

		for(direction in ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT'])
			if(anim.startsWith(direction) && hasAnimation(direction))
				return direction;
		return anim;
	}

	function resolveSingLoopAnimation(anim:String):String
	{
		if(anim == null) return null;

		var directLoop:String = anim + '-loop';
		if(hasAnimation(directLoop)) return directLoop;

		var baseAnim:String = resolveSingAnimation(anim);
		var baseLoop:String = baseAnim + '-loop';
		if(baseAnim != anim && hasAnimation(baseLoop)) return baseLoop;
		return null;
	}

	public var animPaused(get, set):Bool;
	private function get_animPaused():Bool
	{
		if(isAnimationNull()) return false;
		return !isAnimateAtlas ? animation.curAnim.paused : atlas.anim.curAnim.paused;
	}
	private function set_animPaused(value:Bool):Bool
	{
		if(isAnimationNull()) return value;
		if(!isAnimateAtlas) animation.curAnim.paused = value;
		else
		{
			if(value) atlas.pauseAnimation();
			else atlas.resumeAnimation();
		}

		return value;
	}

	public var danced:Bool = false;

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance(?force:Bool = false)
	{
		if (!debugMode && !skipDance && !specialAnim)
		{
			if(danceIdle)
			{
				danced = !danced;

				if (danced)
					playAnim('danceRight' + idleSuffix, force);
				else
					playAnim('danceLeft' + idleSuffix, force);
			}
			else if(hasAnimation('idle' + idleSuffix))
				playAnim('idle' + idleSuffix, force);
		}
	}
	
	public function findCountAnims(prefix:String):Array<Int> {
		var counts:Array<Int> = [];
		
		for (anim => _ in animOffsets) {
			if (anim.startsWith(prefix)) {
				var number:Null<Int> = Std.parseInt(anim.substring(prefix.length));
				if (number != null)
					counts.push(number);
			}
		}
		
		counts.sort((a:Int, b:Int) -> a - b);
		return counts;
	}
	
	public function playComboAnim(combo:Int):Void {
		if (!canPlayComboAnim || comboNoteCounts.length == 0) return;
		
		var animToPlay:String = 'combo$combo';
		
		if (hasAnimation(animToPlay)) {
			playAnim(animToPlay, true);
			specialAnim = true;
		}
	}
	
	public function playComboDropAnim(lastCombo:Int):Void {
		if (!canPlayDropAnim) return;
		
		if (dropNoteCounts.length == 0) { // classic mode
			if (hasAnimation('sad')) {
				playAnim('sad', true);
				specialAnim = true;
			}
			return;
		}
		
		var dropAnim:Null<String> = null;
		for (count in dropNoteCounts) {
			if (count >= lastCombo)
				dropAnim = 'drop$count';
		}
		
		if (dropAnim != null && hasAnimation(dropAnim)) {
			playAnim(dropAnim, true);
			specialAnim = true;
		}
	}

	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		if(isNullCharacter || AnimName == null) return;

		specialAnim = false;
		if(!isAnimateAtlas)
		{
			animation.play(AnimName, Force, Reversed, Frame);
		}
		else
		{
			atlas.anim.play(AnimName, Force, Reversed, Frame);
			atlas.update(0);
		}
		_lastPlayedAnimation = AnimName;

		if (hasAnimation(AnimName))
		{
			var daOffset = animOffsets.get(AnimName);
			offset.set(daOffset[0], daOffset[1]);
		}
		//else offset.set(0, 0);

		if (curCharacter.startsWith('gf-') || curCharacter == 'gf')
		{
			if (AnimName == 'singLEFT')
				danced = true;

			else if (AnimName == 'singRIGHT')
				danced = false;

			if (AnimName == 'singUP' || AnimName == 'singDOWN')
				danced = !danced;
		}
	}

	function loadMappedAnims():Void
	{
		try
		{
			var songData:SwagSong = Song.getChart('picospeaker', Paths.formatToSongPath(Song.loadedSongName));
			if(songData != null)
				for (section in songData.notes)
					for (songNotes in section.sectionNotes)
						animationNotes.push(songNotes);

			TankmenBG.animationNotes = animationNotes;
			animationNotes.sort(sortAnims);
		}
		catch(e:Dynamic) {}
	}

	function sortAnims(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	public var danceEveryNumBeats:Int = 2;
	private var settingCharacterUp:Bool = true;
	public function recalculateDanceIdle() {
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (hasAnimation('danceLeft' + idleSuffix) && hasAnimation('danceRight' + idleSuffix));

		if(settingCharacterUp)
		{
			danceEveryNumBeats = (danceIdle ? 1 : 2);
		}
		else if(lastDanceIdle != danceIdle)
		{
			var calc:Float = danceEveryNumBeats;
			if(danceIdle)
				calc /= 2;
			else
				calc *= 2;

			danceEveryNumBeats = Math.round(Math.max(calc, 1));
		}
		settingCharacterUp = false;
	}

	/*
	    eu crashei o jogo mais vezes doq eu gostaria de afirmar
	 */
	public function refreshOffsets()
	{
		animOffsets = new Map<String, Array<Dynamic>>();
		for (anim in animationsArray)
		{
			if (anim == null || anim.anim == null) continue;

			var useOffsets:Array<Int>;
			if (isPlayer && anim.offsets_player != null && anim.offsets_player.length > 1)
				useOffsets = anim.offsets_player;
			else if (anim.offsets != null && anim.offsets.length > 1)
				useOffsets = anim.offsets;
			else
				useOffsets = [0, 0];

			addOffset(anim.anim, useOffsets[0], useOffsets[1]);
		}
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
	{
		animOffsets[name] = [x, y];
	}

	public function getAnimationSymbolForSide(anim:AnimArray, player:Bool):String
	{
		if(anim == null) return '';
		if(player && anim.name_player != null && anim.name_player.length > 0)
			return anim.name_player;
		if(!player && anim.name_opponent != null && anim.name_opponent.length > 0)
			return anim.name_opponent;
		return anim.name;
	}

	public function getCurrentAnimationSymbol(anim:AnimArray):String
		return getAnimationSymbolForSide(anim, isPlayer);

	public function getAnimationIndicesForSide(anim:AnimArray, player:Bool):Array<Int>
	{
		if(anim == null) return [];
		if(player && anim.indices_player != null)
			return anim.indices_player;
		if(!player && anim.indices_opponent != null)
			return anim.indices_opponent;
		return anim.indices;
	}

	public function getCurrentAnimationIndices(anim:AnimArray):Array<Int>
		return getAnimationIndicesForSide(anim, isPlayer);

	public function reloadAnimationsForCurrentSide():Void
	{
		if(!isAnimateAtlas)
			animation.destroyAnimations();
		#if flxanimate
		else if(atlas != null && atlas.anim != null)
		{
			for(anim in animationsArray)
				if(anim != null && anim.anim != null)
					atlas.anim.remove(anim.anim);
		}
		#end

		for(anim in animationsArray)
			addCharacterAnimation(anim);
	}

	function addCharacterAnimation(anim:AnimArray):Void
	{
		if(anim == null || anim.anim == null || anim.name == null) return;

		var animFps:Int = anim.fps;
		var animAnim:String = anim.anim;
		var animName:String = getCurrentAnimationSymbol(anim);
		var animLoop:Bool = (anim.loop == true);
		var animIndices:Array<Int> = getCurrentAnimationIndices(anim);

		if(!isAnimateAtlas)
		{
			if(animIndices != null && animIndices.length > 0)
				animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
			else
				animation.addByPrefix(animAnim, animName, animFps, animLoop);
		}
		#if flxanimate
		else
			atlas.addAtlasAnimation(animAnim, animName, animIndices, animFps, animLoop);
		#end
	}

	public function quickAnimAdd(name:String, anim:String)
	{
		animation.addByPrefix(name, anim, 24, false);
	}

	// Atlas support
	// special thanks ne_eo for the references, you're the goat!!
	@:allow(states.editors.CharacterEditorState)
	public var isAnimateAtlas(default, null):Bool = false;
	#if flxanimate
	public var atlas:FlxAnimate;
	public override function draw()
	{
		var lastAlpha:Float = alpha;
		var lastColor:FlxColor = color;
		if(MissingCharacter)
		{
			alpha *= 0.6;
			color = FlxColor.BLACK;
		}

		if(isAnimateAtlas)
		{
			if(atlas.hasActiveAtlasAnimation())
			{
				copyAtlasValues();
				atlas.draw();
				if(MissingCharacter && visible)
				{
					MissingText.alpha = lastAlpha;
					MissingText.x = getMidpoint().x - 150;
					MissingText.y = getMidpoint().y - 10;
					MissingText.cameras = cameras;
					MissingText.draw();
				}
				alpha = lastAlpha;
				color = lastColor;
			}
			return;
		}
		super.draw();
		if(MissingCharacter && visible)
		{
			MissingText.alpha = lastAlpha;
			MissingText.x = getMidpoint().x - 150;
			MissingText.y = getMidpoint().y - 10;
			MissingText.cameras = cameras;
			MissingText.draw();
			alpha = lastAlpha;
			color = lastColor;
		}
	}

	public function copyAtlasValues()
	{
		@:privateAccess
		{
			atlas.cameras = cameras;
			atlas.scrollFactor = scrollFactor;
			atlas.scale = scale;
			atlas.offset = offset;
			atlas.origin = origin;
			atlas.x = x;
			atlas.y = y;
			atlas.angle = angle;
			atlas.alpha = alpha;
			atlas.visible = visible;
			atlas.flipX = flipX;
			atlas.flipY = flipY;
			atlas.shader = shader;
			atlas.antialiasing = antialiasing;
			atlas.colorTransform = colorTransform;
			atlas.color = color;
		}
	}

	public override function destroy()
	{
		atlas = FlxDestroyUtil.destroy(atlas);
		super.destroy();
	}
	#end
}
