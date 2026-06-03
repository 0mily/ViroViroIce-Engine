package funkin.data;

class ClientPrefs
{
	public static var data(get, never):backend.SaveVariables;
	public static var lowQuality(get, set):Bool;
	public static var shaders(get, set):Bool;
	public static var globalAntialiasing(get, set):Bool;
	public static var gpuCaching(get, set):Bool;
	public static var noteSplashes(get, set):Bool;
	public static var noteCovers(get, set):Bool;

	static var _noteCovers:Bool = true;

	static function get_data():backend.SaveVariables
		return backend.ClientPrefs.data;

	static function get_lowQuality():Bool
		return backend.ClientPrefs.data.lowQuality;

	static function set_lowQuality(value:Bool):Bool
		return backend.ClientPrefs.data.lowQuality = value;

	static function get_shaders():Bool
		return backend.ClientPrefs.data.shaders;

	static function set_shaders(value:Bool):Bool
		return backend.ClientPrefs.data.shaders = value;

	static function get_globalAntialiasing():Bool
		return backend.ClientPrefs.data.antialiasing;

	static function set_globalAntialiasing(value:Bool):Bool
		return backend.ClientPrefs.data.antialiasing = value;

	static function get_gpuCaching():Bool
		return backend.ClientPrefs.data.cacheOnGPU;

	static function set_gpuCaching(value:Bool):Bool
		return backend.ClientPrefs.data.cacheOnGPU = value;

	static function get_noteSplashes():Bool
		return backend.ClientPrefs.data.splashAlpha > 0;

	static function set_noteSplashes(value:Bool):Bool
	{
		backend.ClientPrefs.data.splashAlpha = value ? Math.max(backend.ClientPrefs.data.splashAlpha, 0.8) : 0;
		return value;
	}

	static function get_noteCovers():Bool
		return _noteCovers;

	static function set_noteCovers(value:Bool):Bool
		return _noteCovers = value;

	public static function getGameplaySetting(name:String, defaultValue:Dynamic = null, ?customDefaultValue:Bool = false):Dynamic
		return backend.ClientPrefs.getGameplaySetting(name, defaultValue, customDefaultValue);

	public static function saveSettings():Void
		backend.ClientPrefs.saveSettings();

	public static function loadPrefs():Void
		backend.ClientPrefs.loadPrefs();

	public static function applyFramerate(fps:Int = 60):Void
		backend.ClientPrefs.applyFramerate(fps);
}
