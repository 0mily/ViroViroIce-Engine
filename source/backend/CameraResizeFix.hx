package backend; // um dia eu me acostumo

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.math.FlxPoint;

class CameraResizeFix
{
	public static var enabled:Bool = true;
	public static var largMulti:Float = 2.5;
	public static var altuMulti:Float = 3.5;
	public static inline var BASE_WIDTH:Int = 1280;
	public static inline var BASE_HEIGHT:Int = 720;

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

	public static function pegarLarguraLogica(camera:FlxCamera):Float
	{
		if(Std.isOfType(camera, PsychCamera))
		{
			var psychCamera:PsychCamera = cast camera;
			if(psychCamera.logicalWidth > 0)
				return psychCamera.logicalWidth;
		}
		return camera == null ? FlxG.width : camera.width;
	}

	public static function pegarAlturaLogica(camera:FlxCamera):Float
	{
		if(Std.isOfType(camera, PsychCamera))
		{
			var psychCamera:PsychCamera = cast camera;
			if(psychCamera.logicalHeight > 0)
				return psychCamera.logicalHeight;
		}
		return camera == null ? FlxG.height : camera.height;
	}

	public static function centralizarScroll(camera:FlxCamera, x:Float, y:Float):Void
	{
		if(camera == null)
			return;

		camera.scroll.set(pegarScrollX(camera, x), pegarScrollY(camera, y));
	}

	public static function pegarScrollX(camera:FlxCamera, x:Float):Float
		return x - pegarLarguraLogica(camera) * 0.5;

	public static function pegarScrollY(camera:FlxCamera, y:Float):Float
		return y - pegarAlturaLogica(camera) * 0.5;

	public static function desgracaX(camera:FlxCamera):Float
		return camera == null ? 0 : camera.scroll.x + pegarLarguraLogica(camera) * 0.5;

	public static function desgracaY(camera:FlxCamera):Float
		return camera == null ? 0 : camera.scroll.y + pegarAlturaLogica(camera) * 0.5;

	public static function focarEm(camera:FlxCamera, point:FlxPoint):Void
	{
		if(camera != null && point != null)
			centralizarScroll(camera, point.x, point.y);
		if(point != null)
			point.putWeak();
	}

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

		var offsetX:Float = pegarCentroOFSX(camera);
		var offsetY:Float = pegarCentroOFSY(camera);

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

	public static function resetGameCamera(camera:FlxCamera):Void
	{
		if(camera == null)
			return;

		camera.setSize(Std.int(Math.max(1, FlxG.width)), Std.int(Math.max(1, FlxG.height)));
		camera.x = 0;
		camera.y = 0;
		if(Std.isOfType(camera, PsychCamera))
			cast(camera, PsychCamera).setLogicalSize();
	}

	public static function aplyGameCamera(camera:FlxCamera):Void
	{
		if(!enabled || camera == null)
			return;

		if(Std.isOfType(camera, PsychCamera))
			cast(camera, PsychCamera).setLogicalSize(BASE_WIDTH, BASE_HEIGHT);

		aplyExpand(camera, largMulti, altuMulti);
	}

	static function precisaCentraliza(camera:FlxCamera):Bool
	{
		var playState = states.PlayState.instance;
		if(playState == null)
			return false;

		return camera == playState.camGame || camera == playState.camHUD || camera == playState.camOther;
	}

	static function pegarCentroBaseX(camera:FlxCamera):Float
	{
		var playState = states.PlayState.instance;
		if(playState != null && camera == playState.camGame)
			return BASE_WIDTH;
		return FlxG.width;
	}

	static function pegarCentroBaseY(camera:FlxCamera):Float
	{
		var playState = states.PlayState.instance;
		if(playState != null && camera == playState.camGame)
			return BASE_HEIGHT;
		return FlxG.height;
	}

	static function pegarCentroOFSX(camera:FlxCamera):Float
	{
		if(camera == null)
			return 0;
		return Math.max(0, camera.width - pegarCentroBaseX(camera)) * 0.5;
	}

	static function pegarCentroOFSY(camera:FlxCamera):Float
	{
		if(camera == null)
			return 0;
		return Math.max(0, camera.height - pegarCentroBaseY(camera)) * 0.5;
	}

	public static function aplyAll():Void
	{
		if(!enabled)
			return;

		var playState = states.PlayState.instance;
		if(playState != null)
		{
			aplyGameCamera(playState.camGame);
			aplyExpand(playState.camHUD);
			aplyExpand(playState.camOther);
		}
	}
}
