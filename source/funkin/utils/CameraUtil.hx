package funkin.utils;

class CameraUtil
{
	public static var lastCamera(get, never):FlxCamera;

	static function get_lastCamera():FlxCamera
		return FlxG.cameras.list[FlxG.cameras.list.length - 1];

	public static function quickCreateCam(add:Bool = true):FlxCamera
	{
		var cam = new FlxCamera();
		cam.bgColor = 0x0;
		if(add) FlxG.cameras.add(cam, false);
		return cam;
	}
}
