package objects; // supostamente feito pra não bugar em músicas com mt zoom!!!!!

import backend.PsychCamera;
import backend.CameraResizeFix;
import backend.VignetteUtil;
import flixel.FlxCamera;
import flixel.util.FlxColor;

class VVIESpriteHandler extends flixel.FlxSprite
{
	public var screenCullPadding:Float = PsychCamera.DEFAULT_ZOOM_CULL_PADDING;
	var vignetteActive:Bool = false;
	var vignetteAutoSize:Bool = false;
	var vignetteWidth:Int = 0;
	var vignetteHeight:Int = 0;
	var vignetteColor:FlxColor = FlxColor.BLACK;
	var vignetteStrength:Float = VignetteUtil.DEFAULT_STRENGTH;
	var vignetteRadius:Float = VignetteUtil.DEFAULT_RADIUS;
	var vignetteSoftness:Float = VignetteUtil.DEFAULT_SOFTNESS;
	var lastVignetteWidth:Int = -1;
	var lastVignetteHeight:Int = -1;
	var lastVignetteX:Float = Math.NaN;
	var lastVignetteY:Float = Math.NaN;
	var cameraFitActive:Bool = false;
	var lastCameraFitWidth:Int = -1;
	var lastCameraFitHeight:Int = -1;
	var lastCameraFitX:Float = Math.NaN;
	var lastCameraFitY:Float = Math.NaN;

	public function makeVignette(width:Int = 0, height:Int = 0, color:FlxColor = FlxColor.BLACK, strength:Float = VignetteUtil.DEFAULT_STRENGTH,
			radius:Float = VignetteUtil.DEFAULT_RADIUS, softness:Float = VignetteUtil.DEFAULT_SOFTNESS):VVIESpriteHandler
	{
		vignetteActive = true;
		vignetteAutoSize = width <= 0 || height <= 0;
		vignetteWidth = width;
		vignetteHeight = height;
		vignetteColor = color;
		vignetteStrength = strength;
		vignetteRadius = radius;
		vignetteSoftness = softness;
		scrollFactor.set();
		refreshVignette(true);
		return this;
	}

	public inline function makeVig(width:Int = 0, height:Int = 0, color:FlxColor = FlxColor.BLACK, strength:Float = VignetteUtil.DEFAULT_STRENGTH,
			radius:Float = VignetteUtil.DEFAULT_RADIUS, softness:Float = VignetteUtil.DEFAULT_SOFTNESS):VVIESpriteHandler
		return makeVignette(width, height, color, strength, radius, softness);

	public function fitToCamera(?camera:FlxCamera = null, autoUpdate:Bool = true):VVIESpriteHandler
	{
		if(camera != null)
			cameras = [camera];
		cameraFitActive = autoUpdate;
		scrollFactor.set();
		refreshCameraFit(true);
		return this;
	}

	public function stopCameraFit():VVIESpriteHandler
	{
		cameraFitActive = false;
		return this;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if(vignetteActive && vignetteAutoSize)
			refreshVignette(false);
		else if(cameraFitActive)
			refreshCameraFit(false);
	}

	override public function isOnScreen(?camera:FlxCamera):Bool
	{
		if(camera == null)
			camera =getDefaultCamera();

		return PsychCamera.containsRectWithPadding(camera, getScreenBounds(_rect, camera), screenCullPadding);
	}

	function refreshVignette(force:Bool = false):Void
	{
		var targetWidth:Int = vignetteWidth;
		var targetHeight:Int = vignetteHeight;
		var targetX:Float = x;
		var targetY:Float = y;

		if(vignetteAutoSize)
		{
			var camera:FlxCamera = getVignetteCamera();
			targetWidth = Std.int(Math.ceil(CameraResizeFix.pegarFSL(camera)));
			targetHeight = Std.int(Math.ceil(CameraResizeFix.pegarFSA(camera)));
			targetX = CameraResizeFix.pegarFSX(camera);
			targetY = CameraResizeFix.pegarFSY(camera);
		}

		targetWidth = Std.int(Math.max(1, targetWidth));
		targetHeight = Std.int(Math.max(1, targetHeight));

		if(force || targetWidth != lastVignetteWidth || targetHeight != lastVignetteHeight)
		{
			loadGraphic(VignetteUtil.makeGraphic(targetWidth, targetHeight, vignetteColor, vignetteStrength, vignetteRadius, vignetteSoftness));
			lastVignetteWidth = targetWidth;
			lastVignetteHeight = targetHeight;
		}

		if(force || targetX != lastVignetteX || targetY != lastVignetteY)
		{
			setPosition(targetX, targetY);
			lastVignetteX = targetX;
			lastVignetteY = targetY;
		}
	}

	function getVignetteCamera():FlxCamera
	{
		if(cameras != null && cameras.length > 0 && cameras[0] != null)
			return cameras[0];
		return getDefaultCamera();
	}

	function refreshCameraFit(force:Bool = false):Void
	{
		var camera:FlxCamera = getVignetteCamera();
		var targetWidth:Int = Std.int(Math.ceil(CameraResizeFix.pegarFSL(camera)));
		var targetHeight:Int = Std.int(Math.ceil(CameraResizeFix.pegarFSA(camera)));
		var targetX:Float = CameraResizeFix.pegarFSX(camera);
		var targetY:Float = CameraResizeFix.pegarFSY(camera);

		targetWidth = Std.int(Math.max(1, targetWidth));
		targetHeight = Std.int(Math.max(1, targetHeight));

		if(force || targetX != lastCameraFitX || targetY != lastCameraFitY)
		{
			setPosition(targetX, targetY);
			lastCameraFitX = targetX;
			lastCameraFitY = targetY;
		}

		if(force || targetWidth != lastCameraFitWidth || targetHeight != lastCameraFitHeight)
		{
			setGraphicSize(targetWidth, targetHeight);
			updateHitbox();
			lastCameraFitWidth = targetWidth;
			lastCameraFitHeight = targetHeight;
		}
	}
}
