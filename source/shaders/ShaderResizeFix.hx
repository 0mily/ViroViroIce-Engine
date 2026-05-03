package shaders;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.addons.display.FlxRuntimeShader;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.filters.ShaderFilter;

class ShaderResizeFix
{
	public static var enabled:Bool = true;

	public static function fixAll():Void
	{
		if(!enabled) return;

		if(Lib.current != null)
		{
			refreshScreenShaderUniforms(Lib.current);
			fixSprite(Lib.current);
		}

		if(FlxG.game != null)
		{
			refreshScreenShaderUniforms(FlxG.game);
			fixSprite(FlxG.game);
		}

		if(FlxG.cameras == null)
			return;

		for(cam in FlxG.cameras.list)
			if(cam != null && cam.flashSprite != null)
				fixCamera(cam);
	}

	public static function fixCamera(camera:FlxCamera):Void
	{
		if(!enabled || camera == null)
			return;

		refreshCameraShaderUniforms(camera);
		fixSprite(camera.flashSprite);
	}

	static function refreshCameraShaderUniforms(camera:FlxCamera):Void
	{
		if(camera == null || camera.filters == null)
			return;

		for(filter in camera.filters)
		{
			if(!Std.isOfType(filter, ShaderFilter))
				continue;

			var rawShader:Dynamic = cast(filter, ShaderFilter).shader;
			if(Std.isOfType(rawShader, FlxRuntimeShader))
			{
				var shader:FlxRuntimeShader = cast rawShader;
				CodenameRuntimeShader.applyCameraUniforms(shader, camera);
			}
		}
	}

	static function refreshScreenShaderUniforms(sprite:Sprite):Void
	{
		if(sprite == null || sprite.filters == null)
			return;

		for(filter in sprite.filters)
		{
			if(!Std.isOfType(filter, ShaderFilter))
				continue;

			var rawShader:Dynamic = cast(filter, ShaderFilter).shader;
			if(Std.isOfType(rawShader, FlxRuntimeShader))
			{
				var shader:FlxRuntimeShader = cast rawShader;
				CodenameRuntimeShader.applyScreenUniforms(shader);
			}
		}
	}

	public static function fixSprite(sprite:Sprite):Void
	{
		if(sprite == null)
			return;

		@:privateAccess
		{
			sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
			sprite.__cacheBitmapData2 = null;
			sprite.__cacheBitmapData3 = null;
			sprite.__cacheBitmapColorTransform = null;
		}
	}
}
