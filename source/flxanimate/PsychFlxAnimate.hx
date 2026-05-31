package flxanimate;

import animate.FlxAnimate as OriginalFlxAnimate;
import animate.FlxAnimateFrames;
import animate.FlxAnimateFrames.SpritemapInput;
import backend.Paths;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.math.FlxPoint;
import flixel.math.FlxRect; // quanto import novo mds </3
import flixel.system.FlxAssets.FlxGraphicAsset;
import haxe.Json;

using StringTools;

class PsychFlxAnimate extends OriginalFlxAnimate
{
	public var showPivot:Bool = false;
	public var cullLimbs:Bool = false;
	public var forceRenderTexture:Bool = false;

	public function loadAtlasFolder(path:String)
	{
		if(path == null || path.trim().length < 1) return;

		var animateFrames = FlxAnimateFrames.fromAnimate(path, null, null, cacheKey(path, 0), true, {cacheOnLoad: true});
		if(animateFrames != null) frames = animateFrames;
	}

	public function loadAtlasEx(img:FlxGraphicAsset, ?pathOrStr:String, ?myJson:Dynamic)
	{
		var animationText:String = resolveJsonText(myJson);
		if(animationText != null)
		{
			var spriteText:String = resolveJsonText(pathOrStr);
			if(spriteText != null)
			{
				var animateFrames = FlxAnimateFrames.fromAnimate(animationText, [{source: cloneAtlasGraphic(img), json: spriteText}], null, cacheKey(animationText, 1), true);
				if(animateFrames != null) frames = animateFrames;
				return;
			}
		}

		var parsedFrames:FlxAtlasFrames = parseAtlasFrames(pathOrStr, img);
		if(parsedFrames != null) frames = parsedFrames;
	}

	public function loadAtlasExMulti(spriteMaps:Array<Dynamic>, ?animationJson:Dynamic)
	{
		var animationText:String = resolveJsonText(animationJson);
		if(animationText != null)
		{
			var inputs:Array<SpritemapInput> = [];
			if(spriteMaps != null)
			{
				for(spriteMap in spriteMaps)
				{
					if(spriteMap == null) continue;

					var spriteText:String = resolveJsonText(Reflect.field(spriteMap, 'json'));
					var spriteImage:Dynamic = Reflect.field(spriteMap, 'image');
					if(spriteText != null && spriteImage != null)
						inputs.push({source: cloneAtlasGraphic(spriteImage), json: spriteText});
				}
			}

			if(inputs.length > 0)
			{
				var animateFrames = FlxAnimateFrames.fromAnimate(animationText, inputs, null, cacheKey(animationText, inputs.length), true);
				if(animateFrames != null) frames = animateFrames;
				return;
			}
		}

		var combinedFrames:FlxAtlasFrames = null;
		if(spriteMaps != null)
		{
			for(spriteMap in spriteMaps)
			{
				if(spriteMap == null) continue;

				var atlasFrames:FlxAtlasFrames = parseAtlasFrames(Reflect.field(spriteMap, 'json'), Reflect.field(spriteMap, 'image'));
				if(atlasFrames == null) continue;

				if(combinedFrames == null)
					combinedFrames = atlasFrames;
				else
				{
					var parentFrames:FlxAtlasFrames = new FlxAtlasFrames(combinedFrames.parent);
					parentFrames.addAtlas(combinedFrames, true);
					parentFrames.addAtlas(atlasFrames, true);
					combinedFrames = parentFrames;
				}
			}
		}

		if(combinedFrames != null) frames = combinedFrames;
	}

	function parseAtlasFrames(data:Dynamic, img:FlxGraphicAsset):FlxAtlasFrames
	{
		if(data == null || img == null) return null;

		if(Std.isOfType(data, String))
		{
			var text:String = resolveText(Std.string(data));
			if(text == null || text.trim().length < 1) return null;

			var trimmed:String = _removeBOM(text.trim());
			if(trimmed.charAt(0) == '<')
				return FlxAtlasFrames.fromSparrow(img, Xml.parse(trimmed));

			return try spriteMapFrames(Json.parse(trimmed), img)
				catch(e:Dynamic)
				{
					try FlxAtlasFrames.fromSparrow(img, Xml.parse(trimmed))
					catch(xmlError:Dynamic) null;
				}
		}

		return spriteMapFrames(data, img);
	}

	function resolveJsonText(data:Dynamic):String
	{
		if(data == null) return null;
		if(!Std.isOfType(data, String)) return Json.stringify(data);

		var text:String = resolveText(Std.string(data));
		if(text == null || text.trim().length < 1) return null;
		return _removeBOM(text);
	}

	function resolveText(data:String):String
	{
		var trimmed:String = data.trim();
		if(trimmed.length < 1) return data;
		if(trimmed.charAt(0) == '{' || trimmed.charAt(0) == '[' || trimmed.charAt(0) == '<') return data;

		var text:String = Paths.getTextFromFile(trimmed);
		return text != null ? text : data;
	}

	static function cacheKey(animationText:String, spriteMapCount:Int):String
	{
		return 'psych-flixel-animate-${animationText.length}-$spriteMapCount-${Date.now().getTime()}';
	}

	static var atlasGraphicCopies:Int = 0;
	static function cloneAtlasGraphic(source:FlxGraphicAsset):FlxGraphicAsset
	{
		if(source == null) return null;

		var copy:FlxGraphic = FlxG.bitmap.add(source, true, 'psych-flixel-animate-spritemap-${atlasGraphicCopies++}');
		if(copy != null)
		{
			copy.persist = false;
			copy.destroyOnNoUse = false;
			return copy;
		}

		return source;
	}

	public static function spriteMapFrames(atlas:Dynamic, graphic:FlxGraphicAsset):FlxAtlasFrames
	{
		if(atlas == null || graphic == null) return null;

		var parent = FlxG.bitmap.add(graphic);
		if(parent == null) return null;

		var frames = new FlxAtlasFrames(parent);
		var sprites:Dynamic = Reflect.field(Reflect.field(atlas, 'ATLAS'), 'SPRITES');
		if(sprites == null) return null;

		for(sprite in cast(sprites, Array<Dynamic>))
		{
			var limb:Dynamic = Reflect.field(sprite, 'SPRITE');
			if(limb == null) continue;

			var rect = FlxRect.get(Reflect.field(limb, 'x'), Reflect.field(limb, 'y'), Reflect.field(limb, 'w'), Reflect.field(limb, 'h'));
			var size = FlxPoint.get(Reflect.field(limb, 'w'), Reflect.field(limb, 'h'));
			frames.addAtlasFrame(rect, size, FlxPoint.get(), Reflect.field(limb, 'name'),
				Reflect.field(limb, 'rotated') == true ? FlxFrameAngle.ANGLE_NEG_90 : FlxFrameAngle.ANGLE_0);
		}

		return frames;
	}

	public function addAtlasAnimation(name:String, symbol:String, ?indices:Array<Int>, framerate:Float = 24, loop:Bool = false, matX:Float = 0, matY:Float = 0)
	{
		if(!isAnimate)
		{
			if(indices != null && indices.length > 0)
				anim.addByIndices(name, symbol, indices, '', framerate, loop);
			else
				anim.addByPrefix(name, symbol, framerate, loop);
			return;
		}

		var symbolName:String = findAtlasSymbolName(symbol);
		var hasSymbol:Bool = symbolName != null;
		if(symbolName == null) symbolName = symbol;
		var useLabel:Bool = hasAtlasFrameLabel(symbol) && !hasSymbol;
		if(!hasSymbol && !useLabel && hasAtlasFramePrefix(symbol))
		{
			if(indices != null && indices.length > 0)
				anim.addByIndices(name, symbol, indices, '', framerate, loop);
			else
				anim.addByPrefix(name, symbol, framerate, loop);
			return;
		}

		if(indices != null && indices.length > 0)
		{
			if(useLabel)
				anim.addByFrameLabelIndices(name, symbol, indices, framerate, loop);
			else
				anim.addBySymbolIndices(name, symbolName, indices, framerate, loop);
			return;
		}

		if(useLabel)
			anim.addByFrameLabel(name, symbol, framerate, loop);
		else
			anim.addBySymbol(name, symbolName, framerate, loop);
	}

	public function hasAtlasSymbol(symbol:String):Bool
	{
		return findAtlasSymbolName(symbol) != null;
	}

	function findAtlasSymbolName(symbol:String):String
	{
		if(symbol == null || library == null) return null;

		var exact:Bool = symbol.endsWith('\\');
		var symbolName:String = exact ? symbol.substr(0, symbol.length - 1) : symbol;
		var names:Array<String> = getAtlasSymbolNames();
		if(hasAtlasSymbolDirectly(symbolName)) return symbolName;
		if(names.contains(symbolName)) return symbolName;
		if(symbolName.contains('/'))
		{
			var shortcut:String = symbolName.split('/').pop();
			if(hasAtlasSymbolDirectly(shortcut)) return shortcut;
			if(names.contains(shortcut)) return shortcut;
		}
		if(exact) return null;

		for(name in names)
			if(name.startsWith(symbolName))
				return name;

		return null;
	}

	function hasAtlasSymbolDirectly(symbol:String):Bool
	{
		if(symbol == null || library == null) return false;

		try
		{
			return library.getSymbol(symbol) != null;
		}
		catch(e:Dynamic) {}

		return false;
	}

	function getAtlasSymbolNames():Array<String>
	{
		var names:Array<String> = [];
		if(library == null) return names;

		try
		{
			var dictionary:Map<String, Dynamic> = cast Reflect.field(library, 'dictionary');
			if(dictionary != null)
				for(name in dictionary.keys())
					if(!names.contains(name))
						names.push(name);
		}
		catch(e:Dynamic) {}

		try
		{
			var symbolDictionary:Array<Dynamic> = cast Reflect.field(library, '_symbolDictionary');
			if(symbolDictionary != null)
			{
				for(symbolData in symbolDictionary)
				{
					var name:String = Reflect.field(symbolData, 'SN');
					if(name != null && !names.contains(name))
						names.push(name);
				}
			}
		}
		catch(e:Dynamic) {}

		try
		{
			var libraryList:Array<String> = cast Reflect.field(library, '_libraryList');
			if(libraryList != null)
				for(name in libraryList)
					if(name != null && !names.contains(name))
						names.push(name);
		}
		catch(e:Dynamic) {}

		try
		{
			var addedCollections:Array<Dynamic> = cast Reflect.field(library, 'addedCollections');
			if(addedCollections != null)
			{
				for(collection in addedCollections)
				{
					var dictionary:Map<String, Dynamic> = cast Reflect.field(collection, 'dictionary');
					if(dictionary != null)
						for(name in dictionary.keys())
							if(!names.contains(name))
								names.push(name);
				}
			}
		}
		catch(e:Dynamic) {}

		return names;
	}

	public function hasAtlasFrameLabel(label:String):Bool
	{
		if(label == null || anim == null || library == null) return false;

		var indices:Array<Int> = anim.findFrameLabelIndices(label);
		if(indices != null && indices.length > 0) return true;

		for(timeline in anim.getCollectionTimelines())
		{
			indices = anim.findFrameLabelIndices(label, timeline);
			if(indices != null && indices.length > 0) return true;
		}

		return false;
	}

	function hasAtlasFramePrefix(prefix:String):Bool
	{
		if(prefix == null || frames == null) return false; // *burp*

		var found:Bool = false;
		frames.forEachByPrefix(prefix, (_) -> found = true, false);
		return found;
	}

	public function hasActiveAtlasAnimation():Bool
	{
		try {
			return anim != null && anim.curAnim != null && anim.curAnim.numFrames > 0;
		} catch(e:Dynamic) {
			return false;
		}
	}

	public function getAtlasCurFrame():Int
	{
		try {
			return hasActiveAtlasAnimation() ? anim.curAnim.curFrame : 0;
		} catch(e:Dynamic) {
			return 0;
		}
	}

	public function setAtlasCurFrame(frame:Int):Int
	{
		try
		{
			if(hasActiveAtlasAnimation())
				anim.curAnim.curFrame = frame;
		}
		catch(e:Dynamic) {}
		return getAtlasCurFrame();
	}

	public function getAtlasLength():Int
	{
		try {
			return hasActiveAtlasAnimation() ? anim.curAnim.numFrames : 0;
		} catch(e:Dynamic) {
			return 0;
		}
	}

	public function finishAtlasAnimation():Void
	{
		try
		{
			if(hasActiveAtlasAnimation())
				anim.curAnim.finish();
		}
		catch(e:Dynamic) {}
	}

	public function getCurrentAtlasAnimationName():String
	{
		try {
			return hasActiveAtlasAnimation() ? anim.curAnim.name : null;
		} catch(e:Dynamic) {
			return null;
		}
	}

	override function draw()
	{
		if(isAnimate && !hasActiveAtlasAnimation()) return;
		super.draw();
	}

	override function checkRenderTexture():Bool
		return (isAnimate && (!cullLimbs || (useRenderTexture && forceRenderTexture))) || super.checkRenderTexture();

	override public function isOnScreen(?camera:FlxCamera):Bool
	{
		if(isAnimate && !cullLimbs)
			return true;

		return super.isOnScreen(camera);
	}

	function _removeBOM(str:String):String
	{
		if(str.charCodeAt(0) == 0xFEFF) str = str.substr(1);
		return str;
	}

	public function pauseAnimation()
	{
		if(hasActiveAtlasAnimation()) anim.pause();
	}

	public function resumeAnimation()
	{
		if(hasActiveAtlasAnimation()) anim.resume();
	}
}
