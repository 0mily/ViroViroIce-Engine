package backend;

import flixel.FlxSprite;
import flixel.FlxG;
import flixel.system.FlxAssets.FlxShader;

#if flxanimate
import flxanimate.PsychFlxAnimate as FlxAnimate;
import objects.Character;
#end

class AtlasUtil
{
	public static function getAtlas(target:Dynamic):Dynamic
	{
		#if flxanimate
		if(target == null)
			return null;
		if(Std.isOfType(target, Character))
		{
			var character:Character = cast target;
			return character.isAnimateAtlas ? character.atlas : null;
		}
		if(Std.isOfType(target, FlxAnimate))
			return target;
		var atlas:Dynamic = Reflect.getProperty(target, 'atlas');
		if(atlas != null && Std.isOfType(atlas, FlxAnimate))
			return atlas;
		#end
		return null;
	}

	public static function getDefaultSymbol(target:Dynamic):String
	{
		#if flxanimate
		var atlas:FlxAnimate = cast getAtlas(target);
		return atlas != null ? atlas.getAtlasDefaultSymbol() : '';
		#else
		return '';
		#end
	}

	public static function listSymbols(target:Dynamic):Array<String>
	{
		#if flxanimate
		var atlas:FlxAnimate = cast getAtlas(target);
		return atlas != null ? atlas.listAtlasSymbolNames() : [];
		#else
		return [];
		#end
	}

	public static function setLayerVisible(target:Dynamic, layerKeyword:String, visible:Bool, ?symbolKeyword:String = null, exact:Bool = false):Int
	{
		#if flxanimate
		var atlas:FlxAnimate = cast getAtlas(target);
		return atlas != null ? atlas.setAtlasLayersVisible(symbolKeyword, layerKeyword, visible, exact) : 0;
		#else
		return 0;
		#end
	}

	public static function setElementVisible(target:Dynamic, keyword:String, visible:Bool, exact:Bool = false):Int
	{
		#if flxanimate
		var atlas:FlxAnimate = cast getAtlas(target);
		return atlas != null ? atlas.setAtlasElementsVisible(keyword, visible, exact) : 0;
		#else
		return 0;
		#end
	}

	public static function addSpriteElement(target:Dynamic, sprite:Dynamic, keyword:String, insertIndex:Int = -1, ?symbolKeyword:String = null, exact:Bool = false, elementActive:Bool = true):Int
	{
		#if flxanimate
		var atlas:FlxAnimate = cast getAtlas(target);
		if(atlas == null || !Std.isOfType(sprite, FlxSprite))
			return 0;
		return atlas.addSpriteElementToAtlasFrames(cast sprite, keyword, insertIndex, symbolKeyword, exact, elementActive);
		#else
		return 0;
		#end
	}

	public static function applySettings(target:Dynamic, settings:Dynamic):Bool
	{
		#if flxanimate
		var atlas:FlxAnimate = cast getAtlas(target);
		return atlas != null && atlas.applyAtlasSettings(settings);
		#else
		return false;
		#end
	}

	public static function syncFrameToSongPosition(target:Dynamic, fps:Float = 24, frameOffset:Int = -1):Int
	{
		#if flxanimate
		var atlas:FlxAnimate = cast getAtlas(target);
		if(atlas == null)
			return 0;
		return atlas.setAtlasCurFrameFromTime(Conductor.songPosition, fps, frameOffset);
		#else
		return 0;
		#end
	}

	public static function setFrame(target:Dynamic, frame:Int = 0):Int
	{
		#if flxanimate
		var atlas:FlxAnimate = cast getAtlas(target);
		if(atlas == null)
			return 0;
		return atlas.setAtlasCurFrame(frame);
		#else
		return 0;
		#end
	}

	public static function getFrame(target:Dynamic):Int
	{
		#if flxanimate
		var atlas:FlxAnimate = cast getAtlas(target);
		if(atlas == null)
			return 0;
		return atlas.getAtlasCurFrame();
		#else
		return 0;
		#end
	}

	public static function copyShader(source:Dynamic, target:Dynamic):Bool
	{
		if(!Std.isOfType(source, FlxSprite) || !Std.isOfType(target, FlxSprite))
			return false;

		var sourceSprite:FlxSprite = cast source;
		var targetSprite:FlxSprite = cast target;
		targetSprite.shader = sourceSprite.shader;
		#if flxanimate
		var targetAtlas:FlxAnimate = cast getAtlas(target);
		if(targetAtlas != null)
			targetAtlas.shader = sourceSprite.shader;
		#end
		return true;
	}

	public static function setShader(target:Dynamic, shader:FlxShader):Bool
	{
		if(!Std.isOfType(target, FlxSprite))
			return false;

		var sprite:FlxSprite = cast target;
		sprite.shader = shader;
		#if flxanimate
		var atlas:FlxAnimate = cast getAtlas(target);
		if(atlas != null)
			atlas.shader = shader;
		#end
		return true;
	}

	public static function getObject(name:String):Dynamic
	{
		if(name == null)
			return null;
		var variables = MusicBeatState.getVariables();
		if(variables != null && variables.exists(name))
			return variables.get(name);
		if(FlxG.state != null)
			return Reflect.getProperty(FlxG.state, name);
		return null;
	}
}
