package psychlua;

import openfl.utils.Assets;

#if LUA_ALLOWED
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
			return true;
		};
		FunkinLua.registerFunction("makeFlxAnimateSprite", makeAtlasSprite);
		FunkinLua.registerFunction("makeLuaAtlasSprite", makeAtlasSprite);
		FunkinLua.registerFunction("makeLuaAnimateSprite", makeAtlasSprite);
		FunkinLua.registerFunction("makeAtlasSprite", makeAtlasSprite);

		var loadAtlas = function(tag:String, folderOrImg:String, ?spriteJson:String = null, ?animationJson:String = null) {
			var spr:FlxAnimate = LuaUtils.getObjectDirectly(tag);
			if (spr != null) {
				Paths.loadAnimateAtlas(spr, folderOrImg, spriteJson, animationJson);
				return true;
			}
			return false;
		};
		FunkinLua.registerFunction("loadAnimateAtlas", loadAtlas);
		FunkinLua.registerFunction("loadLuaAtlas", loadAtlas);
		FunkinLua.registerFunction("loadAtlas", loadAtlas);

		var makeAtlasLipSyncSprite = function(tag:String, folder:String, ?x:Float = 0, ?y:Float = 0, ?symbol:String = null, ?framerate:Float = 24) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);

			var spr:ModchartAnimateSprite = new ModchartAnimateSprite(x, y);
			Paths.loadAnimateAtlas(spr, folder);

			var symbolName:String = symbol;
			if(symbolName == null || symbolName.length < 1)
				symbolName = AtlasUtil.getDefaultSymbol(spr);
			if(symbolName == null || symbolName.length < 1)
				symbolName = folder;

			AtlasUtil.addAnimation(spr, 'lipsync', symbolName, null, framerate, false);
			spr.playAnim('lipsync', true);
			spr.active = true;
			MusicBeatState.getVariables().set(tag, spr);
			return true;
		};
		FunkinLua.registerFunction("makeAtlasLipSyncSprite", makeAtlasLipSyncSprite);
		FunkinLua.registerFunction("makeLuaAtlasLipSyncSprite", makeAtlasLipSyncSprite);
		
		var addAtlasAnim = function(tag:String, name:String, symbol:String, ?framerate:Float = 24, ?loop:Bool = false, ?matX:Float = 0, ?matY:Float = 0) {
			var obj:FlxAnimate = LuaUtils.getObjectDirectly(tag);
			if (obj == null) return false;

			AtlasUtil.addAnimation(obj, name, symbol, null, framerate, loop);
			if(!AtlasUtil.hasActiveAnimation(obj)) {
				if(Std.isOfType(obj, ModchartAnimateSprite)) cast(obj, ModchartAnimateSprite).playAnim(name, true);
				else obj.animation.play(name, true);
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
			AtlasUtil.addAnimation(obj, name, symbol, animIndices, framerate, loop);
			if(!AtlasUtil.hasActiveAnimation(obj))
			{
				if(Std.isOfType(obj, ModchartAnimateSprite)) cast(obj, ModchartAnimateSprite).playAnim(name, true);
				else obj.animation.play(name, true);
			}
			return true;
		};
		FunkinLua.registerFunction("addAnimationBySymbolIndices", addAtlasAnimByIndices);
		FunkinLua.registerFunction("addAtlasAnimByIndices", addAtlasAnimByIndices);
		FunkinLua.registerFunction("addLuaAtlasAnimByIndices", addAtlasAnimByIndices);

		FunkinLua.registerFunction("getAtlasDefaultSymbol", function(?tag:String = null)
			return backend.AtlasUtil.getDefaultSymbol(getAtlasObject(tag)));
		FunkinLua.registerFunction("getAtlasSymbols", function(?tag:String = null)
			return backend.AtlasUtil.listSymbols(getAtlasObject(tag)));
		FunkinLua.registerFunction("listAtlasSymbols", function(?tag:String = null)
			return backend.AtlasUtil.listSymbols(getAtlasObject(tag)));
		FunkinLua.registerFunction("getAtlasFrameKeywordCount", function(tag:String, keyword:String) {
			var atlas:FlxAnimate = cast backend.AtlasUtil.getAtlas(getAtlasObject(tag));
			return atlas != null ? backend.AtlasUtil.getFramesWithKeyword(atlas, keyword).length : 0;
		});
		var addAtlasSpriteElement = function(atlasOrSpriteTag:String, spriteOrKeyword:String, ?keyword:String = null, ?insertIndex:Int = -1, ?symbolKeyword:String = null, ?exact:Bool = false, ?elementActive:Bool = true) {
			var atlasTarget:Dynamic = null;
			var spriteTag:String = null;
			var frameKeyword:String = null;
			var explicitTarget:Bool = hasObjectDirectly(atlasOrSpriteTag) && keyword != null;

			if(explicitTarget)
			{
				atlasTarget = getAtlasObject(atlasOrSpriteTag);
				spriteTag = spriteOrKeyword;
				frameKeyword = keyword;
			}
			else
			{
				atlasTarget = getCurrentCharacterObject();
				spriteTag = atlasOrSpriteTag;
				frameKeyword = spriteOrKeyword;
			}
			return backend.AtlasUtil.addSpriteElement(atlasTarget, getAtlasObject(spriteTag), frameKeyword, insertIndex, symbolKeyword, exact, elementActive);
		};
		FunkinLua.registerFunction("addAtlasSpriteElement", addAtlasSpriteElement);
		FunkinLua.registerFunction("addSpriteToAtlasFrames", addAtlasSpriteElement);
		FunkinLua.registerFunction("addAtlasSpriteToFrames", addAtlasSpriteElement);

		var setAtlasLayerVisible = function(tagOrLayer:String, ?layerKeyword:String = null, visible:Bool = true, ?symbolKeyword:String = null, ?exact:Bool = false) {
			var explicitTarget:Bool = hasObjectDirectly(tagOrLayer) && layerKeyword != null;
			var target:Dynamic = explicitTarget ? getAtlasObject(tagOrLayer) : getCurrentCharacterObject();
			var layer:String = explicitTarget ? layerKeyword : tagOrLayer;
			var symbol:String = explicitTarget ? symbolKeyword : layerKeyword;
			return backend.AtlasUtil.setLayerVisible(target, layer, visible, symbol, exact);
		};
		FunkinLua.registerFunction("setAtlasLayerVisible", setAtlasLayerVisible);
		FunkinLua.registerFunction("setAtlasLayersVisible", setAtlasLayerVisible);
		FunkinLua.registerFunction("setCharacterAtlasLayerVisible", setAtlasLayerVisible);
		FunkinLua.registerFunction("hideAtlasLayer", function(tagOrLayer:String, ?layerKeyword:String = null, ?symbolKeyword:String = null, ?exact:Bool = false) {
			var explicitTarget:Bool = hasObjectDirectly(tagOrLayer) && layerKeyword != null;
			return explicitTarget ? setAtlasLayerVisible(tagOrLayer, layerKeyword, false, symbolKeyword, exact) : setAtlasLayerVisible(tagOrLayer, null, false, layerKeyword, exact);
		});
		FunkinLua.registerFunction("showAtlasLayer", function(tagOrLayer:String, ?layerKeyword:String = null, ?symbolKeyword:String = null, ?exact:Bool = false) {
			var explicitTarget:Bool = hasObjectDirectly(tagOrLayer) && layerKeyword != null;
			return explicitTarget ? setAtlasLayerVisible(tagOrLayer, layerKeyword, true, symbolKeyword, exact) : setAtlasLayerVisible(tagOrLayer, null, true, layerKeyword, exact);
		});

		var setAtlasElementVisible = function(tagOrKeyword:String, ?keyword:String = null, visible:Bool = true, ?exact:Bool = false) {
			var explicitTarget:Bool = hasObjectDirectly(tagOrKeyword) && keyword != null;
			var target:Dynamic = explicitTarget ? getAtlasObject(tagOrKeyword) : getCurrentCharacterObject();
			var elementKeyword:String = explicitTarget ? keyword : tagOrKeyword;
			return backend.AtlasUtil.setElementVisible(target, elementKeyword, visible, exact);
		};
		FunkinLua.registerFunction("setAtlasElementVisible", setAtlasElementVisible);
		FunkinLua.registerFunction("setAtlasElementsVisible", setAtlasElementVisible);
		FunkinLua.registerFunction("hideAtlasElement", function(tagOrKeyword:String, ?keyword:String = null, ?exact:Bool = false)
			return setAtlasElementVisible(tagOrKeyword, keyword, false, exact));
		FunkinLua.registerFunction("showAtlasElement", function(tagOrKeyword:String, ?keyword:String = null, ?exact:Bool = false)
			return setAtlasElementVisible(tagOrKeyword, keyword, true, exact));

		FunkinLua.registerFunction("syncAtlasFrameToSongPosition", function(?tag:String = null, ?framerate:Float = 24, ?frameOffset:Int = -1)
			return backend.AtlasUtil.syncFrameToSongPosition(getAtlasObject(tag), framerate, frameOffset));
		FunkinLua.registerFunction("syncAtlasFrameToSong", function(?tag:String = null, ?framerate:Float = 24, ?frameOffset:Int = -1)
			return backend.AtlasUtil.syncFrameToSongPosition(getAtlasObject(tag), framerate, frameOffset));
		FunkinLua.registerFunction("setAtlasFrame", function(?tag:String = null, ?frame:Int = 0)
			return backend.AtlasUtil.setFrame(getAtlasObject(tag), frame));
		FunkinLua.registerFunction("setAtlasCurFrame", function(?tag:String = null, ?frame:Int = 0)
			return backend.AtlasUtil.setFrame(getAtlasObject(tag), frame));
		FunkinLua.registerFunction("getAtlasFrame", function(?tag:String = null)
			return backend.AtlasUtil.getFrame(getAtlasObject(tag)));
		FunkinLua.registerFunction("getAtlasCurFrame", function(?tag:String = null)
			return backend.AtlasUtil.getFrame(getAtlasObject(tag)));
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

	static function getAtlasObject(tag:String):Dynamic
	{
		if(tag == null || tag.trim().length < 1)
			return getCurrentCharacterObject();
		var obj:Dynamic = getObjectDirectlySafe(tag);
		return obj != null ? obj : getCurrentCharacterObject();
	}

	static function getCurrentCharacterObject():Dynamic
	{
		var script:FunkinLua = FunkinLua.lastCalledScript;
		return script != null ? script.characterScriptCharacter : null;
	}

	static function hasObjectDirectly(tag:String):Bool
	{
		return getObjectDirectlySafe(tag) != null;
	}

	static function getObjectDirectlySafe(tag:String):Dynamic
	{
		if(tag == null || tag.trim().length < 1)
			return null;
		try return LuaUtils.getObjectDirectly(tag)
		catch(e:Dynamic) return null;
	}
}
#end
