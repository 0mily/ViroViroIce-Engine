package flxanimate;

import flixel.math.FlxRect;
import flixel.util.FlxDestroyUtil;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flxanimate.frames.FlxAnimateFrames;
import flxanimate.data.SpriteMapData;
import flxanimate.data.AnimationData;
import flxanimate.FlxAnimate as OriginalFlxAnimate;

class PsychFlxAnimate extends OriginalFlxAnimate
{
	public function loadAtlasEx(img:FlxGraphicAsset, ?pathOrStr:String, ?myJson:Dynamic)
	{
		var parsedFrames:FlxAtlasFrames = parseAtlasFrames(pathOrStr, img);
		if(parsedFrames != null) frames = parsedFrames;

		loadAnimationData(myJson);
		syncAnimateOrigin();
	}

	public function loadAtlasExMulti(spriteMaps:Array<Dynamic>, ?animationJson:Dynamic)
	{
		var combinedFrames:FlxAtlasFrames = null;
		if(spriteMaps != null)
		{
			for(spriteMap in spriteMaps)
			{
				if(spriteMap == null) continue;

				var atlasFrames:FlxAtlasFrames = parseAtlasFrames(Reflect.field(spriteMap, 'json'), Reflect.field(spriteMap, 'image'));
				if(atlasFrames == null) continue;

				if(combinedFrames == null)
				{
					combinedFrames = atlasFrames;
				}
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
		loadAnimationData(animationJson);
		syncAnimateOrigin();
	}

	function loadAnimationData(data:Dynamic)
	{
		if(data == null) return;

		if(data is String)
		{
			var text:String = resolveText(data);
			if(text == null || text.trim().length < 1) return;

			anim._loadAtlas(haxe.Json.parse(_removeBOM(text)));
		}
		else
		{
			anim._loadAtlas(data);
		}
	}

	function parseAtlasFrames(data:Dynamic, img:FlxGraphicAsset):FlxAtlasFrames
	{
		if(data == null) return null;

		if(data is String)
		{
			var text:String = resolveText(data);
			if(text == null || text.trim().length < 1) return null;

			var trimmed:String = text.trim();
			if(trimmed.charAt(0) == '<')
				return FlxAnimateFrames.fromSparrow(Xml.parse(_removeBOM(trimmed)), img);

			return try spriteMapFrames(haxe.Json.parse(_removeBOM(trimmed)), img)
				catch(e:Dynamic)
				{
					try FlxAnimateFrames.fromSparrow(Xml.parse(_removeBOM(trimmed)), img)
					catch(xmlError:Dynamic) null;
				}
		}

		return spriteMapFrames(data, img);
	}

	function resolveText(data:String):String
	{
		var trimmed:String = data.trim();
		if(trimmed.length < 1) return data;
		if(trimmed.charAt(0) == '{' || trimmed.charAt(0) == '[' || trimmed.charAt(0) == '<') return data;

		var text:String = Paths.getTextFromFile(trimmed);
		return text != null ? text : data;
	}
	
	public static function spriteMapFrames(atlas:AnimateAtlas, graphic:FlxGraphicAsset):FlxAtlasFrames {
		if(atlas == null || graphic == null) return null;

		var parent = FlxG.bitmap.add(graphic);
		if(parent == null) return null;

		var frames = new FlxAtlasFrames(parent);
		
		for (sprite in atlas.ATLAS.SPRITES) {
			var limb = sprite.SPRITE;
			var rect = FlxRect.get(limb.x, limb.y, limb.w, limb.h);
			if (limb.rotated == true) rect.setSize(rect.height, rect.width);
			
			FlxAnimateFrames.sliceFrame(limb.name, limb.rotated, rect, frames);
		}
		
		return frames;
	}

	public function addAtlasAnimation(name:String, symbol:String, ?indices:Array<Int>, framerate:Float = 24, loop:Bool = false, matX:Float = 0, matY:Float = 0)
	{
		if(indices != null && indices.length > 0)
		{
			if(hasAtlasFrameLabel(symbol) && !hasAtlasSymbol(symbol))
				anim.addBySymbolIndices(name, anim.stageInstance.symbol.name, remapFrameLabelIndices(symbol, indices), framerate, loop, matX, matY);
			else
				anim.addBySymbolIndices(name, symbol, indices, framerate, loop, matX, matY);

			return;
		}

		if(hasAtlasFrameLabel(symbol) && !hasAtlasSymbol(symbol))
			anim.addByFrameLabel(name, symbol, framerate, loop, matX, matY);
		else
			anim.addBySymbol(name, symbol, framerate, loop, matX, matY);
	}

	public function hasAtlasSymbol(symbol:String):Bool
	{
		if(symbol == null || anim == null || anim.library == null) return false;

		var exact:Bool = symbol.endsWith('\\');
		var symbolName:String = exact ? symbol.substr(0, symbol.length - 1) : symbol;
		for(name in anim.library.getList().keys())
		{
			if((exact && name == symbolName) || (!exact && name.startsWith(symbolName)))
				return true;
		}

		return false;
	}

	public function hasAtlasFrameLabel(label:String):Bool
	{
		return findAtlasFrameLabel(label) != null;
	}

	function findAtlasFrameLabel(label:String):Dynamic
	{
		if(label == null || anim == null || anim.curSymbol == null) return null;

		for(frameLabel in anim.getFrameLabels())
		{
			if(frameLabel != null && frameLabel.name == label)
				return frameLabel;
		}

		return null;
	}

	function remapFrameLabelIndices(label:String, indices:Array<Int>):Array<Int>
	{
		var frameLabel:Dynamic = findAtlasFrameLabel(label);
		if(frameLabel == null) return indices;

		var labelIndices:Array<Int> = frameLabel.getFrameIndices();
		var remapped:Array<Int> = [];
		for(index in indices)
		{
			if(index >= 0 && index < labelIndices.length)
				remapped.push(labelIndices[index]);
			else
				remapped.push(index);
		}

		return remapped;
	}

	function syncAnimateOrigin()
	{
		if(anim != null && anim.curInstance != null && anim.curInstance.symbol != null)
			origin = anim.curInstance.symbol.transformationPoint;
	}

	override function draw()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;
		super.draw();
	}

	override function destroy()
	{
		try
		{
			super.destroy();
		}
		catch(e:haxe.Exception)
		{
			anim.stageInstance = FlxDestroyUtil.destroy(anim.stageInstance);
			anim.metadata = FlxDestroyUtil.destroy(anim.metadata);
		}
	}

	function _removeBOM(str:String) //Removes BOM byte order indicator
	{
		if (str.charCodeAt(0) == 0xFEFF) str = str.substr(1); //myData = myData.substr(2);
		return str;
	}

	public function pauseAnimation()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;
		anim.pause();
	}
	public function resumeAnimation()
	{
		if(anim.curInstance == null || anim.curSymbol == null) return;
		anim.play();
	}
}