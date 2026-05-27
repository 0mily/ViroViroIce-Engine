package objects; // supostamente feito pra não bugar em músicas com mt zoom!!!!!

import backend.PsychCamera;

class vvieSpriteHandler extends flixel.FlxSprite
{
	public var screenCullPadding:Float = PsychCamera.DEFAULT_ZOOM_CULL_PADDING;

	override public function isOnScreen(?camera:FlxCamera):Bool
	{
		if(camera == null)
			camera =getDefaultCamera();

		return PsychCamera.containsRectWithPadding(camera, getScreenBounds(_rect, camera), screenCullPadding);
	}
}
