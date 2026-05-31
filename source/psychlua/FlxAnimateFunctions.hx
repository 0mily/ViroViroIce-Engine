package psychlua;

import openfl.utils.Assets;

#if (LUA_ALLOWED && flxanimate)
class FlxAnimateFunctions {
	public static function implement() {
		var makeAtlasSprite = function(tag:String, ?first:Dynamic = 0, ?second:Dynamic = 0, ?third:Dynamic = null) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);

			var x:Float = 0;
			var y:Float = 0;
			var loadFolder:String = null;
			if(Std.isOfType(first, String))
			{
				loadFolder = Std.string(first);
				x = atlasFloat(second, 0);
				y = atlasFloat(third, 0);
			}
			else
			{
				x = atlasFloat(first, 0);
				y = atlasFloat(second, 0);
				if(third != null) loadFolder = Std.string(third);
			}

			var mySprite:ModchartAnimateSprite = new ModchartAnimateSprite(x, y);
			if(loadFolder != null) Paths.loadAnimateAtlas(mySprite, loadFolder);
			MusicBeatState.getVariables().set(tag, mySprite);
			mySprite.active = true;
		};
		FunkinLua.registerFunction("makeFlxAnimateSprite", makeAtlasSprite);
		FunkinLua.registerFunction("makeLuaAtlasSprite", makeAtlasSprite);
		FunkinLua.registerFunction("makeLuaAnimateSprite", makeAtlasSprite);
		FunkinLua.registerFunction("makeAtlasSprite", makeAtlasSprite);

		var loadAtlas = function(tag:String, folderOrImg:String, ?spriteJson:String = null, ?animationJson:String = null) {
			var spr:FlxAnimate = LuaUtils.getObjectDirectly(tag);
			if (spr != null) Paths.loadAnimateAtlas(spr, folderOrImg, spriteJson, animationJson);
		};
		FunkinLua.registerFunction("loadAnimateAtlas", loadAtlas);
		FunkinLua.registerFunction("loadLuaAtlas", loadAtlas);
		FunkinLua.registerFunction("loadAtlas", loadAtlas);
		
		var addAtlasAnim = function(tag:String, name:String, symbol:String, ?framerate:Float = 24, ?loop:Bool = false, ?matX:Float = 0, ?matY:Float = 0) {
			var obj:FlxAnimate = LuaUtils.getObjectDirectly(tag);
			if (obj == null) return false;

			obj.addAtlasAnimation(name, symbol, null, framerate, loop, matX, matY);
			if(!obj.hasActiveAtlasAnimation()) {
				var obj2:ModchartAnimateSprite = cast (obj, ModchartAnimateSprite);
				if(obj2 != null) obj2.playAnim(name, true); //is ModchartAnimateSprite
				else obj.anim.play(name, true);
			}
			return true;
		};
		FunkinLua.registerFunction("addAnimationBySymbol", addAtlasAnim);
		FunkinLua.registerFunction("addAtlasAnim", addAtlasAnim);
		FunkinLua.registerFunction("addLuaAtlasAnim", addAtlasAnim);

		var addAtlasAnimByIndices = function(tag:String, name:String, symbol:String, ?indices:Any = null, ?framerate:Float = 24, ?loop:Bool = false, ?matX:Float = 0, ?matY:Float = 0) {
			var obj:FlxAnimate = LuaUtils.getObjectDirectly(tag);
			if (obj == null) return false;

			if(indices == null)
				indices = [0];
			else if(Std.isOfType(indices, String))
			{
				var strIndices:Array<String> = cast (indices, String).trim().split(',');
				var myIndices:Array<Int> = [];
				for (i in 0...strIndices.length) {
					myIndices.push(Std.parseInt(strIndices[i]));
				}
				indices = myIndices;
			}

			var animIndices:Array<Int> = cast indices;
			obj.addAtlasAnimation(name, symbol, animIndices, framerate, loop, matX, matY);
			if(!obj.hasActiveAtlasAnimation())
			{
				var obj2:ModchartAnimateSprite = cast (obj, ModchartAnimateSprite);
				if(obj2 != null) obj2.playAnim(name, true); //is ModchartAnimateSprite
				else obj.anim.play(name, true);
			}
			return true;
		};
		FunkinLua.registerFunction("addAnimationBySymbolIndices", addAtlasAnimByIndices);
		FunkinLua.registerFunction("addAtlasAnimByIndices", addAtlasAnimByIndices);
		FunkinLua.registerFunction("addLuaAtlasAnimByIndices", addAtlasAnimByIndices);
	}

	static function atlasFloat(value:Dynamic, fallback:Float = 0):Float
	{
		if(value == null)
			return fallback;

		if(Std.isOfType(value, Float) || Std.isOfType(value, Int))
			return cast value;

		var parsed:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}
}
#end
