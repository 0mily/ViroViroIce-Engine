package backend;


import openfl.display.BitmapData;
import openfl.utils.Assets;

import objects.Character;
import shaders.DropShadowShader;

typedef CharacterSpecificFile = 
{
	@:optional var enabled:Null<Bool>;
	@:optional var color:Null<String>;
	@:optional var distance:Null<Float>;
	@:optional var strength:Null<Float>;
	@:optional var threshold:Null<Float>;
	@:optional var antialiasAmt:Null<Float>;
	@:optional var hue:Null<Float>;
	@:optional var saturation:Null<Float>;
	@:optional var brightness:Null<Float>;
	@:optional var contrast:Null<Float>;
	@:optional var angle:Null<Float>;
	@:optional var altMaskImage:Null<String>;
	@:optional var altMaskPath:Null<String>;
	@:optional var useAltMask:Null<Bool>;
	@:optional var maskThreshold:Null<Float>;
}
typedef DropShadowFile = 
{
	@:optional var enabled:Null<Bool>;
	@:optional var color:Null<String>;
	@:optional var distance:Null<Float>;
	@:optional var strength:Null<Float>;
	@:optional var threshold:Null<Float>;
	@:optional var antialiasAmt:Null<Float>;
	@:optional var hue:Null<Float>;
	@:optional var saturation:Null<Float>;
	@:optional var brightness:Null<Float>;
	@:optional var contrast:Null<Float>;
	@:optional var girlfriend:CharacterSpecificFile;
	@:optional var boyfriend:CharacterSpecificFile;
	@:optional var dad:CharacterSpecificFile;
}

typedef CharacterSpecificData = 
{
	var enabled:Bool;
	var color:FlxColor;
	var distance:Float;
	var strength:Float;
	var threshold:Float;
	var antialiasAmt:Float;
	var hue:Float;
	var saturation:Float;
	var brightness:Float;
	var contrast:Float;
	var angle:Float;
	var altMaskImage:Null<BitmapData>;
	var altMaskPath:String;
	var useAltMask:Bool;
	var maskThreshold:Float;
}
class DropShadowData 
{
	public var enabled:Bool = false;
	public var color:FlxColor = 0xFFFFFFFF;
	public var distance:Float = 0;
	public var strength:Float = 0;
	public var threshold:Float = 0;
	public var antialiasAmt:Float = 2;
	public var hue:Float = 0;
	public var saturation:Float = 0;
	public var brightness:Float = 0;
	public var contrast:Float = 0;

	public var girlfriend:CharacterSpecificData = defaultCharacterData('girlfriend');
	public var boyfriend:CharacterSpecificData = defaultCharacterData('boyfriend');
	public var dad:CharacterSpecificData = defaultCharacterData('dad');

	public var dropshadowFile:DropShadowFile;

	public function new(?stage:String)
	{
		load(stage);
	}

	public function load(?stage:String):Void
	{
		setFromFile(getDropshadowFile(stageName(stage)));
	}

	public function setFromFile(file:DropShadowFile):Void
	{
		var data:DropShadowFile = fixNullValues(file);
		enabled = data.enabled == true;
		color = parseColor(data.color, 0xFFFFFFFF);
		distance = readFloat(data.distance, 0);
		strength = readFloat(data.strength, 0);
		threshold =  readFloat(data.threshold, 0);
		antialiasAmt = readFloat(data.antialiasAmt, 2);
		hue = readFloat(data.hue, 0);
		saturation = readFloat(data.saturation, 0);
		brightness = readFloat(data.brightness, 0);
		contrast = readFloat(data.contrast, 0);

		girlfriend = fileToData(data.girlfriend, 'girlfriend');
		boyfriend = fileToData(data.boyfriend, 'boyfriend');
		dad = fileToData(data.dad, 'dad');
		dropshadowFile = data;
	}

	public function setDataToFile():DropShadowFile
	{
		enabled = dad.enabled || girlfriend.enabled || boyfriend.enabled; //deixar mais fofo

		var data:DropShadowFile =
		{
			enabled: enabled,
			color: colorToString(color),
			distance: distance,
			strength: strength,
			threshold: threshold,
			antialiasAmt: antialiasAmt,
			hue: hue,
			saturation: saturation,
			brightness: brightness,
			contrast: contrast,
			girlfriend: dataToFile(girlfriend),
			boyfriend: dataToFile(boyfriend),
			dad: dataToFile(dad)
		};
		dropshadowFile = data;
		return data;
	}

	public function buildXml(?stage:String):String
	{
		var data:DropShadowFile = setDataToFile();
		var output:StringBuf = new StringBuf();
		output.add('<?xml version="1.0" encoding="utf-8"?>\n');
		output.add('<dropShadow');
		if(stage != null && stage.trim().length > 0)
			output.add(' stage="${xmlEscape(stage)}"');
		output.add(' enabled="${xmlBool(data.enabled)}">\n');
		addCharacterXml(output, 'dad', data.dad);
		addCharacterXml(output, 'girlfriend', data.girlfriend);
		addCharacterXml(output, 'boyfriend', data.boyfriend);
		output.add('</dropShadow>\n');
		return output.toString();
	}

	public static function getDropshadowFile(stage:String):DropShadowFile
	{
		stage = stageName(stage);
		try
		{
			var xmlPath:String = Paths.getPath('data/stages/$stage.xml', TEXT, null, true);
			if(pathExists(xmlPath))
				return fixNullValues(parseXml(readText(xmlPath)));

			var jsonPath:String = Paths.getPath('data/stages/$stage-dropshadow.json', TEXT, null, true);
			if(pathExists(jsonPath))
				return fixNullValues(cast tjson.TJSON.parse(readText(jsonPath)));

		}
		catch(e:Dynamic)
		{
			trace('Error loading dropshadow data for "$stage": $e');
		}
		return dummy();
	}

	public static function dummy():DropShadowFile // eu meio q só peguei do tankman erect xd
	{
		return {
			enabled: false,
			color: '#DFEF3C',
			distance: 15,
			strength: 1,
			threshold: 0.1,
			antialiasAmt: 2,
			hue: 0,
			saturation: 0,
			brightness: 0,
			contrast: 0,
			boyfriend: defaultCharacterFile('boyfriend'),
			girlfriend: defaultCharacterFile('girlfriend'),
			dad: defaultCharacterFile('dad')
		};
	}

	public static function fixNullValues(data:DropShadowFile):DropShadowFile
	{
		if(data == null)
			data = dummy();

		if(data.enabled == null) data.enabled = false;
		if(data.color == null) data.color = '#DFEF3C';
		if(data.distance == null) data.distance = 15;
		if(data.strength == null) data.strength = 1;
		if(data.threshold == null) data.threshold = 0.1;
		if(data.antialiasAmt == null) data.antialiasAmt = 2;
		if(data.hue == null) data.hue = 0;
		if(data.saturation == null) data.saturation = 0;
		if(data.brightness == null) data.brightness = 0;
		if(data.contrast == null) data.contrast = 0;

		data.girlfriend = fixCharacterValues(data.girlfriend, data, 'girlfriend');
		data.boyfriend = fixCharacterValues(data.boyfriend, data, 'boyfriend');
		data.dad = fixCharacterValues(data.dad, data, 'dad');
		return data;
	}

	public static function applyToCharacter(character:Character, data:CharacterSpecificData, enableShaders:Bool = true):Void
	{
		if(character == null || data == null)
			return;

		if(character.dropShadow == null)
			character.dropShadow = new DropShadowShader(character);
		else
			character.dropShadow.attachedSprite = character;

		var shader:DropShadowShader = character.dropShadow;
		shader.enabled = data.enabled;
		shader.color = data.color;
		shader.distance = data.distance;
		shader.strength = data.strength;
		shader.antialiasAmt = data.antialiasAmt;
		shader.baseHue = data.hue;
		shader.baseBrightness = data.brightness;
		shader.baseContrast = data.contrast;
		shader.baseSaturation = data.saturation;
		shader.threshold = data.threshold;
		shader.angle = data.angle;
		shader.maskThreshold = data.maskThreshold;
		shader.useAltMask = data.useAltMask;

		if(data.useAltMask && data.altMaskPath != null && data.altMaskPath.trim().length > 0)
			shader.loadAltMask(data.altMaskPath);

		if(data.enabled && enableShaders)
			character.shader = shader;
		else if(character.shader == shader)
			character.shader = null;
	}

	public static function stageName(?stage:String):String
	{
		if(stage == null || stage.trim().length < 1)
		{
			if(PlayState.SONG != null && PlayState.curStage != null && PlayState.curStage.length > 0)
				return PlayState.curStage;
			return 'stage';
		}
		return stage.trim();
	}

	static function defaultCharacterData(?side:String):CharacterSpecificData
	{
		var angle:Float = 90;
		var threshold:Float = 0.1;
		if(side == 'dad')
		{
			angle = 135;
			threshold = 0.3;
		}

		return {
			enabled: false,
			color: 0xFFDFEF3C,
			distance: 15,
			strength: 1,
			threshold: threshold,
			antialiasAmt: 2,
			hue: 0,
			saturation: 0,
			brightness: 0,
			contrast: 0,
			angle: angle,
			altMaskImage: null,
			altMaskPath: '',
			useAltMask: false,
			maskThreshold: 1
		};
	}

	static function defaultCharacterFile(?side:String):CharacterSpecificFile
	{
		var angle:Float = 90;
		var threshold:Float = 0.1;
		if(side == 'dad')
		{
			angle = 135;
			threshold = 0.3;
		}

		return {
			enabled: false,
			color: '#DFEF3C',
			distance: 15,
			strength: 1,
			threshold: threshold,
			antialiasAmt: 2,
			hue: 0,
			saturation: 0,
			brightness: 0,
			contrast: 0,
			angle: angle,
			altMaskImage: '',
			altMaskPath: '',
			useAltMask: false,
			maskThreshold: 1
		};
	}

	static function fixCharacterValues(data:CharacterSpecificFile, global:DropShadowFile, ?side:String):CharacterSpecificFile
	{
		if(data == null)
			data = {};
		var defaults:CharacterSpecificFile = defaultCharacterFile(side);

		if(data.enabled == null) data.enabled = global.enabled == true;
		if(data.color == null) data.color = global.color != null ? global.color : defaults.color;
		if(data.distance == null) data.distance = global.distance != null ? global.distance : defaults.distance;
		if(data.strength == null) data.strength = global.strength != null ? global.strength : defaults.strength;
		if(data.threshold == null) data.threshold = global.threshold != null ? global.threshold : defaults.threshold;
		if(data.antialiasAmt == null) data.antialiasAmt = global.antialiasAmt != null ? global.antialiasAmt : defaults.antialiasAmt;
		if(data.hue == null) data.hue = global.hue != null ? global.hue : defaults.hue;
		if(data.saturation == null) data.saturation = global.saturation != null ? global.saturation : defaults.saturation;
		if(data.brightness == null) data.brightness = global.brightness != null ? global.brightness : defaults.brightness;
		if(data.contrast == null) data.contrast = global.contrast != null ? global.contrast : defaults.contrast;
		if(data.angle == null) data.angle = defaults.angle;
		if(data.altMaskImage == null)
			data.altMaskImage = data.altMaskPath != null ? data.altMaskPath : '';
		if(data.altMaskPath == null)
			data.altMaskPath = data.altMaskImage != null ? data.altMaskImage : '';
		if(data.useAltMask == null) data.useAltMask = false;
		if(data.maskThreshold == null) data.maskThreshold = defaults.maskThreshold;
		return data;
	}

	static function fileToData(data:CharacterSpecificFile, ?side:String):CharacterSpecificData
	{
		data = fixCharacterValues(data, dummy(), side);
		var maskPath:String = data.altMaskImage != null ? data.altMaskImage : data.altMaskPath;
		var mask:BitmapData = null;
		if(data.useAltMask == true && maskPath != null && maskPath.trim().length > 0)
		{
			try
				mask = BitmapData.fromFile(Paths.getPath('images/$maskPath', IMAGE))
			catch(e:Dynamic)
				mask = null;
		}

		return {
			enabled: data.enabled == true,
			color: parseColor(data.color, 0xFFFFFFFF),
			distance: readFloat(data.distance, 0),
			strength: readFloat(data.strength, 0),
			threshold: readFloat(data.threshold, 0),
			antialiasAmt: readFloat(data.antialiasAmt, 2),
			hue: readFloat(data.hue, 0),
			saturation: readFloat(data.saturation, 0),
			brightness: readFloat(data.brightness, 0),
			contrast: readFloat(data.contrast, 0),
			angle: readFloat(data.angle, 0),
			altMaskImage: mask,
			altMaskPath: maskPath != null ? maskPath : '',
			useAltMask: data.useAltMask == true,
			maskThreshold: readFloat(data.maskThreshold, 0)
		};
	}

	static function dataToFile(data:CharacterSpecificData):CharacterSpecificFile
	{
		return {
			enabled: data.enabled,
			color: colorToString(data.color),
			distance: data.distance,
			strength: data.strength,
			threshold: data.threshold,
			antialiasAmt: data.antialiasAmt,
			hue: data.hue,
			saturation: data.saturation,
			brightness: data.brightness,
			contrast: data.contrast,
			angle: data.angle,
			altMaskImage: data.altMaskPath,
			altMaskPath: data.altMaskPath,
			useAltMask: data.useAltMask,
			maskThreshold: data.maskThreshold
		};
	}

	static function addCharacterXml(output:StringBuf, nodeName:String, data:CharacterSpecificFile):Void
	{
		output.add('\t<$nodeName');
		output.add(' enabled="${xmlBool(data.enabled == true)}"');
		output.add(' color="${xmlEscape(normalizeColorString(data.color))}"');
		output.add(' distance="${xmlNumber(data.distance)}"');
		output.add(' antialiasAmt="${xmlNumber(data.antialiasAmt)}"');
		output.add(' strength="${xmlNumber(data.strength)}"');
		output.add(' threshold="${xmlNumber(data.threshold)}"');
		output.add(' brightness="${xmlNumber(data.brightness)}"');
		output.add(' hue="${xmlNumber(data.hue)}"');
		output.add(' saturation="${xmlNumber(data.saturation)}"');
		output.add(' contrast="${xmlNumber(data.contrast)}"');
		output.add(' angle="${xmlNumber(data.angle)}"');
		output.add(' useAltMask="${xmlBool(data.useAltMask == true)}"');
		output.add(' maskThreshold="${xmlNumber(data.maskThreshold)}"');
		output.add(' altMaskImage="${xmlEscape(data.altMaskImage)}"');
		output.add('/>\n');
	}

	static function parseXml(raw:String):DropShadowFile
	{
		var root:Xml = Xml.parse(raw).firstElement();
		if(root == null)
			return dummy();

		var data:DropShadowFile = {
			enabled: parseBool(xmlAttr(root, ['enabled'])),
			color: xmlAttr(root, ['color']),
			distance: parseFloat(xmlAttr(root, ['distance', 'dist'])),
			strength: parseFloat(xmlAttr(root, ['strength', 'str'])),
			threshold: parseFloat(xmlAttr(root, ['threshold', 'thr'])),
			antialiasAmt: parseFloat(xmlAttr(root, ['antialiasAmt', 'antiAliasAmt', 'antialiasingAmount'])),
			hue: parseFloat(xmlAttr(root, ['hue'])),
			saturation: parseFloat(xmlAttr(root, ['saturation'])),
			brightness: parseFloat(xmlAttr(root, ['brightness'])),
			contrast: parseFloat(xmlAttr(root, ['contrast'])),
			boyfriend: null,
			girlfriend: null,
			dad: null
		};

		for(child in root.elements())
		{
			switch(child.nodeName.toLowerCase())
			{
				case 'dad' | 'opponent':
					data.dad = parseCharacterXml(child);
				case 'girlfriend' | 'gf':
					data.girlfriend = parseCharacterXml(child);
				case 'boyfriend' | 'bf' | 'player':
					data.boyfriend = parseCharacterXml(child);
			}
		}
		return data;
	}

	static function parseCharacterXml(node:Xml):CharacterSpecificFile
	{
		return {
			enabled: parseBool(xmlAttr(node, ['enabled'])),
			color: xmlAttr(node, ['color']),
			distance: parseFloat(xmlAttr(node, ['distance', 'dist'])),
			strength: parseFloat(xmlAttr(node, ['strength', 'str'])),
			threshold: parseFloat(xmlAttr(node, ['threshold', 'thr'])),
			antialiasAmt: parseFloat(xmlAttr(node, ['antialiasAmt', 'antiAliasAmt', 'antialiasingAmount'])),
			hue: parseFloat(xmlAttr(node, ['hue'])),
			saturation: parseFloat(xmlAttr(node, ['saturation'])),
			brightness: parseFloat(xmlAttr(node, ['brightness'])),
			contrast: parseFloat(xmlAttr(node, ['contrast'])),
			angle: parseFloat(xmlAttr(node, ['angle', 'ang'])),
			altMaskImage: xmlAttr(node, ['altMaskImage', 'altMask', 'mask']),
			altMaskPath: xmlAttr(node, ['altMaskPath', 'altMaskImage', 'altMask', 'mask']),
			useAltMask: parseBool(xmlAttr(node, ['useAltMask', 'useMask'])),
			maskThreshold: parseFloat(xmlAttr(node, ['maskThreshold', 'thr2']))
		};
	}

	static function pathExists(path:String):Bool
	{
		#if sys
		return FileSystem.exists(path);
		#else
		return Assets.exists(path);
		#end
	}

	static function readText(path:String):String
	{
		#if sys
		return Paths.getTextFromFile(path);
		#else
		return Assets.getText(path);
		#end
	}

	static function xmlAttr(node:Xml, names:Array<String>):String
	{
		if(node == null) return null;
		for(name in names)
		{
			var value:String = node.get(name);
			if(value != null)
				return value;
		}
		return null;
	}

	static function parseBool(value:String):Null<Bool>
	{
		if(value == null) return null;
		switch(value.trim().toLowerCase())
		{
			case 'true' | '1' | 'yes' | 'y' | 'on':
				return true;
			case 'false' | '0' | 'no' | 'n' | 'off':
				return false;
		}
		return null;
	}

	static function parseFloat(value:String):Null<Float>
	{
		if(value == null) return null;
		var parsed:Float = Std.parseFloat(value);
		return Math.isNaN(parsed) ? null : parsed;
	}

	static function readFloat(value:Dynamic, fallback:Float):Float
	{
		if(value == null) return fallback;
		var parsed:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	static function parseColor(value:String, fallback:FlxColor):FlxColor
	{
		var rgbColor:Null<FlxColor> = parseRgbColor(value);
		if(rgbColor != null)
			return rgbColor;

		var parsed:Null<FlxColor> = FlxColor.fromString(normalizeColorString(value));
		return parsed != null ? parsed : fallback;
	}

	static function parseRgbColor(value:String):Null<FlxColor>
	{
		if(value == null || value.indexOf(',') < 0)
			return null;

		var values:Array<String> = value.split(',');
		if(values.length < 3)
			return null;

		var rgb:Array<Int> = [];
		for(i in 0...3)
		{
			var parsed:Null<Int> = Std.parseInt(values[i].trim());
			if(parsed == null)
				return null;
			rgb.push(Std.int(FlxMath.bound(parsed, 0, 255)));
		}
		return FlxColor.fromRGB(rgb[0], rgb[1], rgb[2]);
	}

	static function normalizeColorString(value:String):String
	{
		if(value == null || value.trim().length < 1)
			return '#FFFFFF';

		var raw:String = value.trim();
		if(raw.startsWith('0x') || raw.startsWith('0X'))
			raw = '#' + raw.substr(raw.length - 6);
		else if(!raw.startsWith('#'))
			raw = '#' + raw;
		return raw;
	}

	static function colorToString(color:FlxColor):String
		return '#' + color.toHexString(false, false);

	static function xmlEscape(value:String):String
	{
		if(value == null) return '';
		return value.replace('&', '&amp;').replace('"', '&quot;').replace('<', '&lt;').replace('>', '&gt;');
	}

	static function xmlBool(value:Bool):String
		return value ? 'true' : 'false';

	static function xmlNumber(value:Dynamic):String
		return Std.string(FlxMath.roundDecimal(readFloat(value, 0), 4));
}
