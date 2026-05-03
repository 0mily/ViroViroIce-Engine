package backend; // um dia eu me acostumo

import flixel.FlxCamera;
import flixel.FlxG;

class CameraResizeFix
{
	public static var enabled:Bool = true;
	public static var largMulti:Float = 2.5;
	public static var altuMulti:Float = 3.5;

	public static function pegarExtraX(camera:FlxCamera):Float
		return camera == null ? 0 : Math.max(0, camera.width - FlxG.width);

	public static function pegarExtraY(camera:FlxCamera):Float
		return camera == null ? 0 : Math.max(0, camera.height - FlxG.height);

	public static function pegarFSX(camera:FlxCamera):Float
		return -pegarExtraX(camera) * 0.5;

	public static function pegarFSY(camera:FlxCamera):Float
		return -pegarExtraY(camera) * 0.5;

	public static function pegarFSL(camera:FlxCamera):Float
		return camera == null ? FlxG.width : Math.max(FlxG.width, camera.width);

	public static function pegarFSA(camera:FlxCamera):Float
		return camera == null ? FlxG.height : Math.max(FlxG.height, camera.height);

	public static function aplyExpand(camera:FlxCamera, minlargMulti:Float = 1, minaltuMulti:Float = 1, centroCu:Bool = true):Void
	{
		if(!enabled || camera == null)
		return;
		var screenWidth:Int = Std.int(Math.max(1, FlxG.width));
		var screenHeight:Int = Std.int(Math.max(1, FlxG.height));
		var scaleX:Float = Math.max(0.001, FlxG.scaleMode.scale.x);
		var scaleY:Float = Math.max(0.001, FlxG.scaleMode.scale.y);
		var windowWidth:Int = Std.int(Math.ceil(Math.max(screenWidth, FlxG.scaleMode.deviceSize.x / scaleX)));
		var windowHeight:Int = Std.int(Math.ceil(Math.max(screenHeight, FlxG.scaleMode.deviceSize.y / scaleY)));
		var cameraWidth:Int = Std.int(Math.max(windowWidth, screenWidth * minlargMulti));
		var cameraHeight:Int = Std.int(Math.max(windowHeight, screenHeight * minaltuMulti));

		camera.setSize(cameraWidth, cameraHeight);
		camera.x = -(cameraWidth - screenWidth) * 0.5;
		camera.y = -(cameraHeight - screenHeight) * 0.5;
		if(centroCu)
			aplyCentroOFS(camera);
	}

	public static function aplyCentroOFS(camera:FlxCamera):Void
	{
		if(!enabled || camera == null || !precisaCentraliza(camera))
			return;

		var offsetX:Float = pegarExtraX(camera) * 0.5;
		var offsetY:Float = pegarExtraY(camera) * 0.5;

		@:privateAccess camera.updateInternalSpritePositions();
		if(FlxG.renderBlit)
		{
			@:privateAccess if(camera._flashBitmap != null)
			{
				camera._flashBitmap.x += offsetX * camera.totalScaleX;
				camera._flashBitmap.y += offsetY * camera.totalScaleY;
			}
		}
		else if(camera.canvas != null)
		{
			camera.canvas.x += offsetX * camera.totalScaleX;
			camera.canvas.y += offsetY * camera.totalScaleY;

			#if FLX_DEBUG // amem
			if(camera.debugLayer != null)
			{
				camera.debugLayer.x += offsetX * camera.totalScaleX;
				camera.debugLayer.y += offsetY * camera.totalScaleY;
			}
			#end
		}
	}

	static function precisaCentraliza(camera:FlxCamera):Bool
	{
		var playState = states.PlayState.instance;
		if(playState == null)
			return false;

		return camera == playState.camHUD || camera == playState.camOther;
	}

	public static function aplyAll():Void
	{
		if(!enabled)
			return;

		var playState = states.PlayState.instance;
		if(playState != null)
		{
			aplyExpand(playState.camGame, largMulti, altuMulti, false);
			aplyExpand(playState.camHUD);
			aplyExpand(playState.camOther);
		}
	}
}
