package backend;

// cara, tbh eu fiz isso ano passado. Funcionou de primeira, ent nem vou mexer

import openfl.display.BitmapData;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

class CustomCursor
{
	public static var ativo(default, null):Bool = false;
	public static var curPath(default, null):String = null;

	public static function reloadFromMods():Bool
	{
		var image:String = 'cursor';
		var scale:Float = 1;
		var hotspotX:Int = 0;
		var hotspotY:Int = 0;
		var visible:Null<Bool> = null;

		var config:Dynamic = loadConfig();
		if(config != null)
		{
			image = getString(config, 'image', image);
			scale = getFloat(config, 'scale', scale);
			hotspotX = getInt(config, 'hotspotX', getInt(config, 'xOffset', hotspotX));
			hotspotY = getInt(config, 'hotspotY', getInt(config, 'yOffset', hotspotY));
			visible = getOptionalBool(config, 'visible');
		}

		if(set(image, scale, hotspotX, hotspotY))
		{
			if(visible != null)
				FlxG.mouse.visible = visible;
			return true;
		}

		reset();
		return false;
	}

	public static function set(image:String = 'cursor', scale:Float = 1, hotspotX:Int = 0, hotspotY:Int = 0):Bool
	{
		if(FlxG.mouse == null)
			return false;

		var path:String = getImagePath(image);
		var bitmap:BitmapData = loadBitmap(path);
		if(bitmap == null)
			return false;

		FlxG.mouse.useSystemCursor = false;
		FlxG.mouse.load(bitmap, scale, -hotspotX, -hotspotY);
		ativo = true;
		curPath = path;
		return true;
	}

	public static function reset():Void
	{
		if(FlxG.mouse == null)
			return;

		ativo = false;
		curPath = null;
		FlxG.mouse.useSystemCursor = false;
		FlxG.mouse.unload();
	}

	static function getImagePath(image:String):String
	{
		if(image == null || image.trim().length < 1)
			image = 'cursor';

		image = image.replace('\\', '/').trim();
		if(image.endsWith('.png') || image.startsWith('images/') || image.startsWith('assets/') || image.startsWith('mods/'))
			return Paths.getPath(image, AssetType.IMAGE, null, true);
		return Paths.getPath('images/$image.png', AssetType.IMAGE, null, true);
	}

	static function loadBitmap(path:String):BitmapData
	{
		if(path == null || path.length < 1)
			return null;

		#if sys
		if(FileSystem.exists(path))
			return BitmapData.fromFile(path);
		#end

		if(OpenFlAssets.exists(path, AssetType.IMAGE))
			return OpenFlAssets.getBitmapData(path);
		return null;
	}

	static function loadConfig():Dynamic
	{
		var path:String = Paths.getPath('images/cursor.json', AssetType.TEXT, null, true);
		var raw:String = null;

		#if sys
		if(FileSystem.exists(path))
			raw = File.getContent(path);
		else
		#end
		if(OpenFlAssets.exists(path, AssetType.TEXT))
			raw = OpenFlAssets.getText(path);

		if(raw == null || raw.trim().length < 1)
			return null;

		try {
			return haxe.Json.parse(raw);
		}
		catch(e:Dynamic)
		{
			trace('Invalid custom cursor config: $path ($e)');
			return null;
		}
	}

	static function getString(data:Dynamic, key:String, fallback:String):String
	{
		var value:Dynamic = Reflect.field(data, key);
		return value == null ? fallback : Std.string(value);
	}

	static function getFloat(data:Dynamic, key:String, fallback:Float):Float
	{
		var value:Dynamic = Reflect.field(data, key);
		if(value == null)
			return fallback;

		var parsed:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	static function getInt(data:Dynamic, key:String, fallback:Int):Int
		return Std.int(getFloat(data, key, fallback));

	static function getOptionalBool(data:Dynamic, key:String):Null<Bool>
	{
		var value:Dynamic = Reflect.field(data, key);
		if(value == null)
			return null;

		if(Std.isOfType(value, Bool))
			return value;

		return switch(Std.string(value).toLowerCase().trim())
		{
			case 'true' | '1' | 'yes' | 'on': true;
			case 'false' | '0' | 'no' | 'off': false;
			default: null;
		}
	}
}
