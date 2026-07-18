package backend;

import animate.FlxAnimate;
import animate.internal.Frame;
import animate.internal.SymbolItem;
import animate.internal.Timeline;
import animate.internal.elements.AtlasInstance;
import animate.internal.elements.Element;
import animate.internal.elements.FlxSpriteElement;
import animate.internal.elements.SymbolInstance;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.system.FlxAssets.FlxShader;

class AtlasUtil
{
	public static function getAtlas(target:Dynamic):FlxAnimate
	{
		if(target == null) return null;
		if(Std.isOfType(target, FlxAnimate))
		{
			var sprite:FlxAnimate = cast target;
			return sprite.library != null ? sprite : null;
		}
		return null;
	}

	public static function addAnimation(target:Dynamic, name:String, symbol:String, ?indices:Array<Int>, framerate:Float = 24, loop:Bool = false):Bool
	{
		var atlas:FlxAnimate = Std.isOfType(target, FlxAnimate) ? cast target : getAtlas(target);
		if(atlas == null || atlas.anim == null || name == null || symbol == null)
			return false;

		if(atlas.library == null)
		{
			if(indices != null && indices.length > 0)
				atlas.anim.addByIndices(name, symbol, indices, '', framerate, loop);
			else
				atlas.anim.addByPrefix(name, symbol, framerate, loop);
			return hasAnimation(atlas, name);
		}

		var symbolName:String = findSymbolName(atlas, symbol);
		var useLabel:Bool = symbolName == null && hasFrameLabel(atlas, symbol);
		if(symbolName == null && !useLabel && hasFramePrefix(atlas, symbol))
		{
			if(indices != null && indices.length > 0)
				atlas.anim.addByIndices(name, symbol, indices, '', framerate, loop);
			else
				atlas.anim.addByPrefix(name, symbol, framerate, loop);
			return hasAnimation(atlas, name);
		}

		if(symbolName == null)
			symbolName = symbol;
		if(indices != null && indices.length > 0)
		{
			if(useLabel)
				atlas.anim.addByFrameLabelIndices(name, symbol, indices, framerate, loop);
			else
				atlas.anim.addBySymbolIndices(name, symbolName, indices, framerate, loop);
		}
		else if(useLabel)
			atlas.anim.addByFrameLabel(name, symbol, framerate, loop);
		else
			atlas.anim.addBySymbol(name, symbolName, framerate, loop);
		return hasAnimation(atlas, name);
	}

	public static function hasAnimation(target:Dynamic, name:String):Bool
	{
		var atlas:FlxAnimate = Std.isOfType(target, FlxAnimate) ? cast target : getAtlas(target);
		if(atlas == null || atlas.animation == null || name == null || !atlas.animation.exists(name))
			return false;
		var animation = atlas.animation.getByName(name);
		return animation != null && animation.numFrames > 0;
	}

	public static function hasActiveAnimation(target:Dynamic):Bool
	{
		var atlas:FlxAnimate = Std.isOfType(target, FlxAnimate) ? cast target : getAtlas(target);
		return atlas != null && atlas.animation != null && atlas.animation.curAnim != null && atlas.animation.curAnim.numFrames > 0;
	}

	public static function getDefaultSymbol(target:Dynamic):String
	{
		var atlas:FlxAnimate = getAtlas(target);
		if(atlas == null || atlas.library == null) return '';

		try
		{
			var current:Dynamic = atlas.animation.curAnim;
			var timeline:Timeline = current != null ? cast Reflect.field(current, 'timeline') : null;
			if(timeline != null && timeline.name != null && timeline.name.length > 0)
				return timeline.name;
		}
		catch(e:Dynamic) {}

		if(atlas.library.timeline != null && atlas.library.timeline.name != null && atlas.library.timeline.name.length > 0)
			return atlas.library.timeline.name;
		var names:Array<String> = listSymbols(atlas);
		return names.length > 0 ? names[0] : '';
	}

	public static function listSymbols(target:Dynamic):Array<String>
	{
		var atlas:FlxAnimate = getAtlas(target);
		var names:Array<String> = [];
		if(atlas == null || atlas.library == null) return names;

		try
		{
			var dictionary:Map<String, SymbolItem> = cast Reflect.field(atlas.library, 'dictionary');
			if(dictionary != null)
				for(name in dictionary.keys())
					if(!names.contains(name)) names.push(name);
		}
		catch(e:Dynamic) {}

		try
		{
			var symbolDictionary:Dynamic = Reflect.field(atlas.library, '_symbolDictionary');
			if(symbolDictionary != null)
			{
				var length:Int = Reflect.getProperty(symbolDictionary, 'length');
				for(i in 0...length)
				{
					var symbolData:Dynamic = Reflect.getProperty(symbolDictionary, Std.string(i));
					var name:String = Reflect.field(symbolData, 'SN');
					if(name != null && !names.contains(name)) names.push(name);
				}
			}
		}
		catch(e:Dynamic) {}

		try
		{
			var libraryList:Array<String> = cast Reflect.field(atlas.library, '_libraryList');
			if(libraryList != null)
				for(name in libraryList)
					if(name != null && !names.contains(name)) names.push(name);
		}
		catch(e:Dynamic) {}

		try
		{
			var collections:Array<Dynamic> = cast Reflect.field(atlas.library, 'addedCollections');
			if(collections != null)
				for(collection in collections)
				{
					var dictionary:Map<String, Dynamic> = cast Reflect.field(collection, 'dictionary');
					if(dictionary != null)
						for(name in dictionary.keys())
							if(!names.contains(name)) names.push(name);
				}
		}
		catch(e:Dynamic) {}
		return names;
	}

	public static function getFramesWithKeyword(target:Dynamic, keyword:String, ?symbolKeyword:String = null, exact:Bool = false):Array<Frame>
	{
		var atlas:FlxAnimate = getAtlas(target);
		var found:Array<Frame> = [];
		if(atlas == null || keyword == null) return found;

		for(symbolName in listSymbols(atlas))
		{
			var symbol:SymbolItem = getSymbol(atlas, symbolName);
			if(symbol == null || !matchesName(symbol.name, symbolKeyword, false)) continue;

			var symbolMatches:Bool = matchesName(symbol.name, keyword, exact);
			for(layer in symbol.timeline.layers)
			{
				var layerMatches:Bool = matchesName(layer.name, keyword, exact);
				for(frame in layer.frames)
					if((symbolMatches || layerMatches || frameMatches(frame, keyword, exact)) && !found.contains(frame))
						found.push(frame);
			}
		}
		return found;
	}

	public static function addSpriteElement(target:Dynamic, sprite:Dynamic, keyword:String, insertIndex:Int = -1, ?symbolKeyword:String = null, exact:Bool = false, elementActive:Bool = true):Int
	{
		if(!Std.isOfType(sprite, FlxSprite)) return 0;
		var changed:Int = 0;
		for(frame in getFramesWithKeyword(target, keyword, symbolKeyword, exact))
		{
			var element = new FlxSpriteElement(cast sprite);
			element.active = elementActive;
			if(insertIndex >= 0 && insertIndex < frame.elements.length)
				frame.insert(insertIndex, element);
			else
				frame.add(element);
			frame.setDirty();
			changed++;
		}
		return changed;
	}

	public static function applySettings(target:Dynamic, settings:Dynamic):Bool
	{
		var atlas:FlxAnimate = getAtlas(target);
		if(atlas == null || settings == null) return false;

		var changed:Bool = false;
		var onSymbolCreate:Dynamic = Reflect.field(settings, 'onSymbolCreate');
		if(Reflect.isFunction(onSymbolCreate))
		{
			for(symbolName in listSymbols(atlas))
			{
				var symbol:SymbolItem = getSymbol(atlas, symbolName);
				if(symbol == null) continue;
				Reflect.callMethod(settings, onSymbolCreate, [symbol]);
				markTimelineDirty(symbol.timeline);
				changed = true;
			}
		}

		changed = applyLayerList(atlas, settings, 'hideLayers', false) || changed;
		changed = applyLayerList(atlas, settings, 'hiddenLayers', false) || changed;
		changed = applyLayerList(atlas, settings, 'showLayers', true) || changed;
		changed = applyLayerList(atlas, settings, 'visibleLayers', true) || changed;
		return changed;
	}

	public static function setLayerVisible(target:Dynamic, layerKeyword:String, visible:Bool, ?symbolKeyword:String = null, exact:Bool = false):Int
	{
		var atlas:FlxAnimate = getAtlas(target);
		if(atlas == null || layerKeyword == null) return 0;
		var changed:Int = 0;
		for(symbolName in listSymbols(atlas))
		{
			var symbol:SymbolItem = getSymbol(atlas, symbolName);
			if(symbol == null || !matchesName(symbol.name, symbolKeyword, false)) continue;
			for(layer in symbol.timeline.layers)
				if(layer != null && matchesName(layer.name, layerKeyword, exact))
				{
					layer.visible = visible;
					for(frame in layer.frames) frame.setDirty();
					changed++;
				}
		}
		return changed;
	}

	public static function setElementVisible(target:Dynamic, keyword:String, visible:Bool, exact:Bool = false):Int
	{
		var atlas:FlxAnimate = getAtlas(target);
		if(atlas == null || keyword == null) return 0;
		var changed:Int = 0;
		for(symbolName in listSymbols(atlas))
		{
			var symbol:SymbolItem = getSymbol(atlas, symbolName);
			if(symbol == null) continue;
			for(layer in symbol.timeline.layers)
				for(frame in layer.frames)
					for(element in frame.elements)
						if(matchesName(getElementName(element), keyword, exact))
						{
							element.visible = visible;
							frame.setDirty();
							changed++;
						}
		}
		return changed;
	}

	public static function syncFrameToSongPosition(target:Dynamic, fps:Float = 24, frameOffset:Int = -1):Int
		return setFrame(target, Math.floor((Conductor.songPosition / 1000) * fps) + frameOffset);

	public static function setFrame(target:Dynamic, frame:Int = 0):Int
	{
		var atlas:FlxAnimate = getAtlas(target);
		if(!hasActiveAnimation(atlas)) return 0;
		var length:Int = atlas.animation.curAnim.numFrames;
		atlas.animation.curAnim.curFrame = Std.int(FlxMath.bound(frame, 0, Math.max(0, length - 1)));
		return atlas.animation.curAnim.curFrame;
	}

	public static function getFrame(target:Dynamic):Int
	{
		var atlas:FlxAnimate = getAtlas(target);
		return hasActiveAnimation(atlas) ? atlas.animation.curAnim.curFrame : 0;
	}

	public static function getLength(target:Dynamic):Int
	{
		var atlas:FlxAnimate = getAtlas(target);
		return hasActiveAnimation(atlas) ? atlas.animation.curAnim.numFrames : 0;
	}

	public static function copyShader(source:Dynamic, target:Dynamic):Bool
	{
		if(!Std.isOfType(source, FlxSprite) || !Std.isOfType(target, FlxSprite)) return false;
		(cast target : FlxSprite).shader = (cast source : FlxSprite).shader;
		return true;
	}

	public static function setShader(target:Dynamic, shader:FlxShader):Bool
	{
		if(!Std.isOfType(target, FlxSprite)) return false;
		(cast target : FlxSprite).shader = shader;
		return true;
	}

	public static function getObject(name:String):Dynamic
	{
		if(name == null) return null;
		var variables = MusicBeatState.getVariables();
		if(variables != null && variables.exists(name)) return variables.get(name);
		return FlxG.state != null ? Reflect.getProperty(FlxG.state, name) : null;
	}

	static function getSymbol(atlas:FlxAnimate, name:String):SymbolItem
	{
		if(atlas == null || atlas.library == null || name == null) return null;
		try return atlas.library.getSymbol(name) catch(e:Dynamic) return null;
	}

	static function findSymbolName(atlas:FlxAnimate, symbol:String):String
	{
		if(atlas == null || symbol == null) return null;
		var exact:Bool = symbol.endsWith('\\');
		var wanted:String = exact ? symbol.substr(0, symbol.length - 1) : symbol;
		var names:Array<String> = listSymbols(atlas);
		if(getSymbol(atlas, wanted) != null || names.contains(wanted)) return wanted;
		if(wanted.contains('/'))
		{
			var shortcut:String = wanted.split('/').pop();
			if(getSymbol(atlas, shortcut) != null || names.contains(shortcut)) return shortcut;
		}
		if(!exact)
			for(name in names)
				if(name.startsWith(wanted)) return name;
		return null;
	}

	static function hasFrameLabel(atlas:FlxAnimate, label:String):Bool
	{
		if(atlas == null || atlas.anim == null || label == null) return false;
		var indices:Array<Int> = atlas.anim.findFrameLabelIndices(label);
		if(indices != null && indices.length > 0) return true;
		for(timeline in atlas.anim.getCollectionTimelines())
		{
			indices = atlas.anim.findFrameLabelIndices(label, timeline);
			if(indices != null && indices.length > 0) return true;
		}
		return false;
	}

	static function hasFramePrefix(atlas:FlxAnimate, prefix:String):Bool
	{
		if(atlas == null || atlas.frames == null || prefix == null) return false;
		var found:Bool = false;
		atlas.frames.forEachByPrefix(prefix, _ -> found = true, false);
		return found;
	}

	static function matchesName(name:String, keyword:String, exact:Bool):Bool
	{
		if(keyword == null || keyword.length < 1) return true;
		return name != null && (exact ? name == keyword : name.contains(keyword));
	}

	static function getElementName(element:Element):String
	{
		if(element == null) return null;
		if(Std.isOfType(element, SymbolInstance)) return cast(element, SymbolInstance).symbolName;
		if(Std.isOfType(element, AtlasInstance))
		{
			var instance:AtlasInstance = cast element;
			return instance.frame != null ? instance.frame.name : null;
		}
		if(Std.isOfType(element, FlxSpriteElement))
		{
			var spriteElement:FlxSpriteElement = cast element;
			return spriteElement.basic != null ? Type.getClassName(Type.getClass(spriteElement.basic)) : null;
		}
		return Std.string(element.elementType);
	}

	static function frameMatches(frame:Frame, keyword:String, exact:Bool):Bool
	{
		if(frame == null) return false;
		if(matchesName(frame.name, keyword, exact) || (frame.layer != null && matchesName(frame.layer.name, keyword, exact))) return true;
		for(element in frame.elements)
			if(matchesName(getElementName(element), keyword, exact)) return true;
		return false;
	}

	static function applyLayerList(atlas:FlxAnimate, settings:Dynamic, field:String, visible:Bool):Bool
	{
		var value:Dynamic = Reflect.field(settings, field);
		if(value == null) return false;
		var layers:Array<Dynamic> = Std.isOfType(value, Array) ? cast value : Std.string(value).split(',');
		var changed:Int = 0;
		for(layer in layers)
		{
			var name:String = Std.string(layer).trim();
			if(name.length > 0) changed += setLayerVisible(atlas, name, visible);
		}
		return changed > 0;
	}

	static function markTimelineDirty(timeline:Timeline):Void
	{
		if(timeline == null || timeline.layers == null) return;
		for(layer in timeline.layers)
			if(layer != null && layer.frames != null)
				for(frame in layer.frames)
					if(frame != null) frame.setDirty();
	}
}
