package funkin.utils;

class CoolUtil
{
	public static function getEase(?ease:String = '')
		return psychlua.LuaUtils.getTweenEaseByString(ease);
}
