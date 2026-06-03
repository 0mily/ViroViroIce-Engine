package objects;

import tjson.TJSON;

// remind of me from the future: ,AKE THE NOTE SPLASH SYSTEM BETTER HOLY JESUS

typedef NoteSkinOffset = {
	var x:Float;
	var y:Float;
	var angle:Float;
}

typedef NoteSkinConfig = {
	var source:String;
	var image:String;
	var offsets:Map<String, Array<NoteSkinOffset>>;
	var fps:Map<String, Int>;
	var properties:Dynamic;
}

class NoteSkinData
{
	public static inline final NOTES_PATH:String = 'noteskins/notes';
	public static inline final SPLASHES_PATH:String = 'noteskins/splashes';
	public static inline final LEGACY_NOTES_PATH:String = 'noteSkins';
	public static inline final LEGACY_SPLASHES_PATH:String = 'noteSplashes'; // haha old

	static final OFFSET_FIELDS:Map<String, String> = [
		'static' => 'offsets_static',
		'press' => 'offsets_static_press',
		'confirm' => 'offsets_static_confirm',
		'notes' => 'offsets_notes',
		'sustain' => 'offsets_sustain',
		'sustain_end' => 'offsets_sustain_end'
	];

	static var jsonCache:Map<String, Dynamic> = new Map();
	static var noteConfigCache:Map<String, NoteSkinConfig> = new Map();
	static var noteConfigByImage:Map<String, NoteSkinConfig> = new Map();

	public static function resolveNoteSkinPath(skin:String, player:Int = 1):String
	{
		skin = normalizeImageKey(skin);
		if (skin == null || skin.length < 1)
			return skin;

		if (imageExists(skin))
			return skin;

		var config:NoteSkinConfig = getNoteConfig(skin, player);
		if (config != null && config.image != null && config.image.length > 0)
			return config.image;

		var candidates:Array<String> = [];
		var postfix:String = optionPostfix(skin);
		var bare:String = stripKnownPrefixes(skin);

		addCandidate(candidates, '$NOTES_PATH/$bare');
		addCandidate(candidates, '$NOTES_PATH/NOTE_assets-$postfix');
		addCandidate(candidates, '$LEGACY_NOTES_PATH/$bare');
		addCandidate(candidates, '$LEGACY_NOTES_PATH/NOTE_assets-$postfix');

		if (postfix == 'default' || postfix == 'viroviroice')
		{
			addCandidate(candidates, '$NOTES_PATH/NOTE_assets');
			addCandidate(candidates, '$LEGACY_NOTES_PATH/NOTE_assets');
		}

		for (candidate in candidates)
			if (imageExists(candidate))
				return candidate;

		return skin;
	}

	public static function resolveSplashPath(splash:String):String
	{
		splash = normalizeImageKey(splash);
		if (splash == null || splash.length < 1)
			return splash;

		if (imageExists(splash))
			return splash;

		var candidates:Array<String> = [];
		var postfix:String = optionPostfix(splash).replace('_', '-');
		var bare:String = stripKnownPrefixes(splash);

		addCandidate(candidates, '$SPLASHES_PATH/$bare');
		addCandidate(candidates, '$SPLASHES_PATH/noteSplashes-$postfix');
		addCandidate(candidates, '$LEGACY_SPLASHES_PATH/$bare');
		addCandidate(candidates, '$LEGACY_SPLASHES_PATH/noteSplashes-$postfix');

		if (postfix == 'default' || postfix == 'psych' || postfix == 'viroviroice')
		{
			addCandidate(candidates, '$SPLASHES_PATH/noteSplashes');
			addCandidate(candidates, '$LEGACY_SPLASHES_PATH/noteSplashes');
		}

		for (candidate in candidates)
			if (imageExists(candidate))
				return candidate;

		return splash;
	}

	public static function getNoteConfigForImage(image:String):NoteSkinConfig
	{
		image = normalizeImageKey(image);
		if (image == null || image.length < 1)
			return null;

		if (noteConfigByImage.exists(image))
			return noteConfigByImage.get(image);

		var config:NoteSkinConfig = getNoteConfig(image);
		if (config != null)
			return config;

		var bare:String = image;
		if (bare.contains('/'))
			bare = bare.substr(bare.lastIndexOf('/') + 1);

		return getNoteConfig(bare);
	}

	public static function getNoteConfig(skin:String, player:Int = 1):NoteSkinConfig
	{
		skin = normalizeImageKey(skin);
		if (skin == null || skin.length < 1)
			return null;

		var key:String = stripKnownPrefixes(skin);
		var shortKey:String = stripNoteImageSuffix(key);
		var candidates:Array<String> = [];
		addJsonCandidate(candidates, 'images/$skin.json');
		addJsonCandidate(candidates, 'images/$NOTES_PATH/$key.json');
		if (shortKey != key)
			addJsonCandidate(candidates, 'images/$NOTES_PATH/$shortKey.json');
		if (skin.contains('/'))
		{
			addJsonCandidate(candidates, 'images/$NOTES_PATH/${skin.substr(skin.lastIndexOf('/') + 1)}.json'); // in case the key has folders but the config is directly in the noteskins folder
			var fileName:String = skin.substr(skin.lastIndexOf('/') + 1);
			var shortFileName:String = stripNoteImageSuffix(fileName);
			if (shortFileName != fileName)
				addJsonCandidate(candidates, 'images/$NOTES_PATH/$shortFileName.json');
		}
		addJsonCandidate(candidates, 'noteskins/$key.json');
		if (shortKey != key)
			addJsonCandidate(candidates, 'noteskins/$shortKey.json');

		for (path in candidates)
		{
			var config:NoteSkinConfig = loadNoteConfig(path, skin, player);
			if (config != null)
				return config;
		}
		return null;
	}

	public static function getOffset(config:NoteSkinConfig, type:String, noteData:Int):NoteSkinOffset
	{
		if (config == null || type == null)
			return zeroOffset();

		var offsets:Array<NoteSkinOffset> = config.offsets.get(type);
		if (offsets == null)
			return zeroOffset();

		var index:Int = Std.int(Math.abs(noteData) % Note.dirArray.length);
		return offsets[index] ?? zeroOffset();
	}

	public static function getFPS(config:NoteSkinConfig, type:String, fallback:Int = 24):Int
	{
		if (config == null || type == null)
			return fallback;

		var fps:Null<Int> = config.fps.get(type);
		if (fps == null)
			fps = config.fps.get('default');

		return fps != null && fps >= 0 ? fps : fallback;
	}

	public static function applyPropertiesToNote(note:Note, config:NoteSkinConfig):Void // fuck txt, me and the gals love using json or xml
	{
		var props:Dynamic = config?.properties;
		if (note == null || props == null)
			return;

		applyBool(props, 'noAnimation', value -> note.noAnimation = value);
		applyBool(props, 'noMissAnimation', value -> note.noMissAnimation = value);
		applyBool(props, 'ignoreNote', value -> note.ignoreNote = value);
		applyBool(props, 'hitCausesMiss', value -> note.hitCausesMiss = value);
		applyBool(props, 'blockHit', value -> note.blockHit = value);
		applyBool(props, 'hitsoundDisabled', value -> note.hitsoundDisabled = value);
		applyBool(props, 'noteSplashDisabled', value -> note.noteSplashData.disabled = value);
		applyBool(props, 'useRGBShader', value -> note.useRGBShader = value);
		applyBool(props, 'allowRGB', value -> note.useRGBShader = value);
		applyBool(props, 'antialiasing', value -> note.antialiasing = value);
	}

	public static function applyPropertiesToStrum(strum:StrumNote, config:NoteSkinConfig):Void
	{
		var props:Dynamic = config?.properties;
		if (strum == null || props == null)
			return;

		applyBool(props, 'useRGBShader', value -> strum.setRGBAllowed(value));
		applyBool(props, 'allowRGB', value -> strum.setRGBAllowed(value));
		applyBool(props, 'antialiasing', value -> strum.antialiasing = value);
	}

	public static function applyStrumOffset(strum:StrumNote, anim:String, config:NoteSkinConfig):Void
	{
		if (strum == null || config == null)
			return;

		var type:String = switch (anim)
		{
			case 'pressed': 'press';
			case 'confirm': config.offsets.exists('confirm') ? 'confirm' : 'press';
			default: 'static';
		}
		var offset:NoteSkinOffset = getOffset(config, type, strum.noteData);
		strum.offset.x += offset.x;
		strum.offset.y += offset.y;
		strum.angle -= strum.skinOffsetAngle;
		strum.skinOffsetAngle = offset.angle;
		strum.angle += offset.angle;
	}

	static function loadNoteConfig(path:String, skin:String, player:Int = 1):NoteSkinConfig
	{
		if (noteConfigCache.exists(path))
			return noteConfigCache.get(path);

		var rawData:Dynamic = loadJson(path);
		if (rawData == null)
		{
			noteConfigCache.set(path, null);
			return null;
		}

		var image:String = readSideImage(rawData, player);
		if (image == null || image.length < 1)
			image = readString(rawData, 'image') ?? readString(rawData, 'texture') ?? readString(rawData, 'asset');
		if (image == null || image.length < 1)
			image = imageExists(skin) ? skin : null;
		else
			image = normalizeNoteImagePath(image);

		var config:NoteSkinConfig = {
			source: path,
			image: image,
			offsets: new Map(),
			fps: new Map(),
			properties: Reflect.field(rawData, 'properties')
		};

		if (config.properties == null)
			config.properties = Reflect.field(rawData, 'flags');

		parseOffsets(rawData, config);
		parseFPS(rawData, config);

		noteConfigCache.set(path, config);
		if (image != null && image.length > 0)
			noteConfigByImage.set(image, config);
		return config;
	}

	static function parseOffsets(data:Dynamic, config:NoteSkinConfig):Void
	{
		for (type => field in OFFSET_FIELDS)
		{
			var source:Dynamic = Reflect.field(data, field);
			if (source == null)
				continue;
			config.offsets.set(type, readOffsetArray(source));
		}
	}

	static function parseFPS(data:Dynamic, config:NoteSkinConfig):Void
	{
		var defaultFPS:Null<Int> = readInt(data, 'fps');
		if (defaultFPS != null)
			config.fps.set('default', defaultFPS);

		var fpsData:Dynamic = Reflect.field(data, 'fps');
		if (fpsData != null && !Std.isOfType(fpsData, String) && !Std.isOfType(fpsData, Int) && !Std.isOfType(fpsData, Float))
		{
			for (type in ['static', 'press', 'confirm', 'notes', 'sustain', 'sustain_end'])
			{
				var value:Null<Int> = readInt(fpsData, type);
				if (value != null)
					config.fps.set(type, value);
			}
		}

		for (type in ['static', 'press', 'confirm', 'notes', 'sustain', 'sustain_end'])
		{
			var value:Null<Int> = readInt(data, 'fps_$type');
			if (value != null)
				config.fps.set(type, value);
		}
	}

	static function readOffsetArray(data:Dynamic):Array<NoteSkinOffset>
	{
		var offsets:Array<NoteSkinOffset> = [for (_ in 0...Note.dirArray.length) zeroOffset()];

		for (i in 0...Note.dirArray.length)
		{
			var direction:String = Note.dirArray[i];
			var value:Dynamic = Reflect.field(data, direction);
			if (value == null)
				value = Reflect.field(data, Std.string(i));
			if (value == null)
				value = Reflect.field(data, Note.colArray[i]);
			if (value != null)
				offsets[i] = readOffset(value);
		}
		return offsets;
	}

	static function readOffset(value:Dynamic):NoteSkinOffset
	{
		if (value == null)
			return zeroOffset();

		if (Std.isOfType(value, Int) || Std.isOfType(value, Float))
			return {x: parseFloat(value, 0), y: 0, angle: 0};

		if (Std.isOfType(value, String))
		{
			var parts:Array<String> = Std.string(value).replace(',', ' ').split(' ');
			parts = [for (part in parts) if (part.trim().length > 0) part.trim()];
			return {
				x: parseFloat(parts[0], 0),
				y: parseFloat(parts[1], 0),
				angle: parseFloat(parts[2], 0)
			};
		}

		if (Std.isOfType(value, Array))
		{
			var values:Array<Dynamic> = cast value;
			return {
				x: parseFloat(values[0], 0),
				y: parseFloat(values[1], 0),
				angle: parseFloat(values[2], 0)
			};
		}

		return {
			x: parseFloat(Reflect.field(value, 'x'), 0),
			y: parseFloat(Reflect.field(value, 'y'), 0),
			angle: parseFloat(Reflect.field(value, 'angle'), 0)
		};
	}

	static function readSideImage(data:Dynamic, player:Int):String
	{
		var field:String = player == 0 ? 'opponentSkin' : 'playerSkin';
		var value:String = readString(data, field);
		if (value == null || value.length < 1)
			value = readString(data, 'globalSkin');
		if (value == null || value.length < 1)
			value = readString(data, 'extraSkin');
		return value;
	}

	static function normalizeNoteImagePath(image:String):String
	{
		image = normalizeImageKey(image);
		if (image == null || image.length < 1)
			return image;
		if (!image.contains('/'))
			image = '$NOTES_PATH/$image';
		return image;
	}

	static function normalizeImageKey(key:String):String
	{
		if (key == null)
			return null;

		key = key.replace('\\', '/').trim();
		if (key.startsWith('images/'))
			key = key.substr('images/'.length);
		if (key.endsWith('.png') || key.endsWith('.xml') || key.endsWith('.json') || key.endsWith('.txt'))
			key = key.substr(0, key.lastIndexOf('.'));
		while (key.startsWith('/'))
			key = key.substr(1);
		return key;
	}

	static function stripKnownPrefixes(key:String):String
	{
		key = normalizeImageKey(key);
		for (prefix in [NOTES_PATH, SPLASHES_PATH, LEGACY_NOTES_PATH, LEGACY_SPLASHES_PATH, 'noteskins'])
			if (key.startsWith(prefix + '/'))
				return key.substr(prefix.length + 1);
		return key;
	}

	static function stripNoteImageSuffix(key:String):String
	{
		key = normalizeImageKey(key);
		if (key == null)
			return null;

		if (key.endsWith('_NOTE'))
			return key.substr(0, key.length - '_NOTE'.length);
		if (key.endsWith('-NOTE'))
			return key.substr(0, key.length - '-NOTE'.length);
		if (key.endsWith('NOTE') && key.length > 'NOTE'.length)
			return key.substr(0, key.length - 'NOTE'.length);
		return key;
	}

	public static function optionPostfix(value:String):String
	{
		value = stripKnownPrefixes(value);
		if (value == null || value.length < 1)
			return '';
		if (value.startsWith('NOTE_assets-'))
			value = value.substr('NOTE_assets-'.length);
		if (value.startsWith('noteSplashes-'))
			value = value.substr('noteSplashes-'.length);
		if (value == 'NOTE_assets' || value == 'noteSplashes')
			value = 'default';
		return value.trim().toLowerCase().replace(' ', '_');
	}

	static function imageExists(key:String):Bool
		return key != null && key.length > 0 && Paths.fileExists('images/$key.png', IMAGE);

	static function addCandidate(list:Array<String>, value:String):Void
	{
		value = normalizeImageKey(value);
		if (value != null && value.length > 0 && !list.contains(value))
			list.push(value);
	}

	static function addJsonCandidate(list:Array<String>, value:String):Void
	{
		value = value.replace('\\', '/').trim();
		if (value != null && value.length > 0 && !list.contains(value))
			list.push(value);
	}

	static function loadJson(path:String):Dynamic
	{
		if (jsonCache.exists(path))
			return jsonCache.get(path);

		var parsed:Dynamic = null;
		try
		{
			var raw:String = Paths.getTextFromFile(path);
			if (raw != null && raw.trim().length > 0)
				parsed = TJSON.parse(raw);
		}
		catch(e:Dynamic) {}

		jsonCache.set(path, parsed);
		return parsed;
	}

	static function readString(data:Dynamic, field:String):String
	{
		if (data == null || field == null || !Reflect.hasField(data, field))
			return null;

		var value:Dynamic = Reflect.field(data, field);
		return value != null ? Std.string(value) : null;
	}

	static function readInt(data:Dynamic, field:String):Null<Int>
	{
		if (data == null || field == null || !Reflect.hasField(data, field))
			return null;

		var value:Dynamic = Reflect.field(data, field);
		if (Std.isOfType(value, Array))
		{
			var arr:Array<Dynamic> = cast value;
			value = arr[0];
		}

		var parsed:Float = parseFloat(value, Math.NaN);
		return Math.isNaN(parsed) ? null : Std.int(parsed);
	}

	static function applyBool(data:Dynamic, field:String, setter:Bool->Void):Void
	{
		if (data == null || !Reflect.hasField(data, field))
			return;
		setter(parseBool(Reflect.field(data, field), false));
	}

	static function parseBool(value:Dynamic, fallback:Bool):Bool
	{
		if (value == null)
			return fallback;
		if (Std.isOfType(value, Bool))
			return value;

		return switch (Std.string(value).toLowerCase().trim())
		{
			case 'true' | '1' | 'yes' | 'on': true;
			case 'false' | '0' | 'no' | 'off': false;
			default: fallback;
		}
	}

	static function parseFloat(value:Dynamic, fallback:Float):Float
	{
		if (value == null)
			return fallback;

		var parsed:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	static function zeroOffset():NoteSkinOffset
		return {x: 0, y: 0, angle: 0};
}
