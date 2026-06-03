package backend;

import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxAngle;
import flixel.math.FlxMatrix;
import flixel.math.FlxRect;
import flixel.system.FlxAssets.FlxShader;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.Graphics;
import openfl.geom.ColorTransform;

using flixel.util.FlxColorTransformUtil;

// PsychCamera handles followLerp based on elapsed
// and stops camera from snapping at higher framerates
// can we change this name pls? this is fucking viroviro not fuckin psycghs

class PsychCamera extends FlxCamera
{
	public static inline final DEFAULT_ZOOM_CULL_PADDING:Float = 512;

	public var logicalWidth:Float = 0;
	public var logicalHeight:Float = 0;
	public var rotateSprite(default, set):Bool = false;

	@:noCompletion var _sinAngle:Float = 0;
	@:noCompletion var _cosAngle:Float = 1;

	function set_rotateSprite(rotate:Bool):Bool
	{
		rotateSprite = rotate;
		set_angle(angle);
		return rotateSprite;
	}

	override function set_angle(Angle:Float):Float
	{
		angle = Angle;
		flashSprite.rotation = rotateSprite ? Angle : 0;

		var radians:Float = angle * FlxAngle.TO_RAD;
		_sinAngle = Math.sin(radians);
		_cosAngle = Math.cos(radians);

		return angle;
	}

	public function setLogicalSize(width:Float = 0, height:Float = 0):Void
	{
		logicalWidth = width;
		logicalHeight = height;
		if(target != null)
			refreshDeadzone();
	}

	inline function followWidth():Float
		return logicalWidth > 0 ? logicalWidth : width;

	inline function followHeight():Float
		return logicalHeight > 0 ? logicalHeight : height;

	inline function logicalMarginX():Float
		return 0.5 * followWidth() * (scaleX - initialZoom) / scaleX;

	inline function logicalMarginY():Float
		return 0.5 * followHeight() * (scaleY - initialZoom) / scaleY;

	inline function logicalViewWidth():Float
		return followWidth() - logicalMarginX() * 2;

	inline function logicalViewHeight():Float
		return followHeight() - logicalMarginY() * 2;

	inline function logicalViewLeft():Float
		return scroll.x + logicalMarginX();

	inline function logicalViewTop():Float
		return scroll.y + logicalMarginY();

	inline function logicalViewRight():Float
		return scroll.x + followWidth() - logicalMarginX();

	inline function logicalViewBottom():Float
		return scroll.y + followHeight() - logicalMarginY();

	public static function zoomCullPadding(camera:FlxCamera, padding:Float = DEFAULT_ZOOM_CULL_PADDING):Float
	{
		if(camera == null || padding <= 0) return 0;
		return padding * Math.max(1, Math.max(camera.zoom, Math.max(camera.scaleX, camera.scaleY)));
	}

	public static function containsRectWithPadding(camera:FlxCamera, rect:FlxRect, padding:Float = DEFAULT_ZOOM_CULL_PADDING):Bool
	{
		if(camera == null || rect == null)
		{
			if(rect != null) rect.putWeak();
			return false;
		}

		var cullPadding:Float = zoomCullPadding(camera, padding);
		var contained:Bool = (rect.right > camera.viewMarginLeft - cullPadding)
			&& (rect.x < camera.viewMarginRight + cullPadding)
			&& (rect.bottom > camera.viewMarginTop - cullPadding)
			&& (rect.y < camera.viewMarginBottom + cullPadding);
		rect.putWeak();
		return contained;
	}

	override public function follow(target:FlxObject, style = LOCKON, lerp = 1.0):Void
	{
		this.style = style;
		this.target = target;
		followLerp = lerp;
		refreshDeadzone();
	}

	function refreshDeadzone():Void
	{
		_lastTargetPosition = FlxDestroyUtil.put(_lastTargetPosition);
		deadzone = FlxDestroyUtil.put(deadzone);

		switch (style)
		{
			case LOCKON:
				var w:Float = 0;
				var h:Float = 0;
				if (target != null)
				{
					w = target.width;
					h = target.height;
				}
				deadzone = FlxRect.get((followWidth() - w) / 2, (followHeight() - h) / 2 - h * 0.25, w, h);

			case PLATFORMER:
				final w:Float = (followWidth() / 8);
				final h:Float = (followHeight() / 3);
				deadzone = FlxRect.get((followWidth() - w) / 2, (followHeight() - h) / 2 - h * 0.25, w, h);

			case TOPDOWN:
				final helper = Math.max(followWidth(), followHeight()) / 4;
				deadzone = FlxRect.get((followWidth() - helper) / 2, (followHeight() - helper) / 2, helper, helper);

			case TOPDOWN_TIGHT:
				final helper = Math.max(followWidth(), followHeight()) / 8;
				deadzone = FlxRect.get((followWidth() - helper) / 2, (followHeight() - helper) / 2, helper, helper);

			case SCREEN_BY_SCREEN:
				deadzone = FlxRect.get(0, 0, followWidth(), followHeight());

			case NO_DEAD_ZONE:
				deadzone = null;
		}
	}

	override public function update(elapsed:Float):Void
	{
		// follow the target, if there is one
		if (target != null)
		{
			updateFollowDelta(elapsed);
		}

		updateScroll();
		updateFlash(elapsed);
		updateFade(elapsed);

		flashSprite.filters = filtersEnabled ? filters : null;

		updateFlashSpritePosition();
		updateShake(elapsed);
	}

	public function updateFollowDelta(?elapsed:Float = 0):Void
	{
		// Either follow the object closely,
		// or double check our deadzone and update accordingly.
		if (deadzone == null)
		{
			target.getMidpoint(_point);
			_point.addPoint(targetOffset);
			_scrollTarget.set(_point.x - followWidth() * 0.5, _point.y - followHeight() * 0.5);
		}
		else
		{
			var edge:Float;
			var targetX:Float = target.x + targetOffset.x;
			var targetY:Float = target.y + targetOffset.y;

			if (style == SCREEN_BY_SCREEN)
			{
				if (targetX >= logicalViewRight())
				{
					_scrollTarget.x += logicalViewWidth();
				}
				else if (targetX + target.width < logicalViewLeft())
				{
					_scrollTarget.x -= logicalViewWidth();
				}

				if (targetY >= logicalViewBottom())
				{
					_scrollTarget.y += logicalViewHeight();
				}
				else if (targetY + target.height < logicalViewTop())
				{
					_scrollTarget.y -= logicalViewHeight();
				}
				
				// without this we see weird behavior when switching to SCREEN_BY_SCREEN at arbitrary scroll positions
				bindScrollPos(_scrollTarget);
			}
			else
			{
				edge = targetX - deadzone.x;
				if (_scrollTarget.x > edge)
				{
					_scrollTarget.x = edge;
				}
				edge = targetX + target.width - deadzone.x - deadzone.width;
				if (_scrollTarget.x < edge)
				{
					_scrollTarget.x = edge;
				}

				edge = targetY - deadzone.y;
				if (_scrollTarget.y > edge)
				{
					_scrollTarget.y = edge;
				}
				edge = targetY + target.height - deadzone.y - deadzone.height;
				if (_scrollTarget.y < edge)
				{
					_scrollTarget.y = edge;
				}
			}

			if ((target is FlxSprite))
			{
				if (_lastTargetPosition == null)
				{
					_lastTargetPosition = FlxPoint.get(target.x, target.y); // Creates this point.
				}
				_scrollTarget.x += (target.x - _lastTargetPosition.x) * followLead.x;
				_scrollTarget.y += (target.y - _lastTargetPosition.y) * followLead.y;

				_lastTargetPosition.x = target.x;
				_lastTargetPosition.y = target.y;
			}
		}

		var mult:Float = 1 - Math.exp(-elapsed * followLerp / (1/60));
		scroll.x += (_scrollTarget.x - scroll.x) * mult;
		scroll.y += (_scrollTarget.y - scroll.y) * mult;
		//trace('lerp on this frame: $mult');
	}

	override public function snapToTarget():Void
	{
		updateFollowDelta();
		scroll.copyFrom(_scrollTarget);
	}

	function anglePivotX():Float
	{
		if(target != null)
		{
			var pivot:Float = target.x + target.width * 0.5 + targetOffset.x - scroll.x;
			if(!Math.isNaN(pivot))
				return pivot;
		}
		return followWidth() * 0.5;
	}

	function anglePivotY():Float
	{
		if(target != null)
		{
			var pivot:Float = target.y + target.height * 0.5 + targetOffset.y - scroll.y;
			if(!Math.isNaN(pivot))
				return pivot;
		}
		return followHeight() * 0.5;
	}

	function drawScreenFill(targetGraphics:Graphics, Color:FlxColor, FxAlpha:Float):Void
	{
		if(targetGraphics == null)
			return;

		var drawX:Float = CameraResizeFix.pegarFSX(this) - 1;
		var drawY:Float = CameraResizeFix.pegarFSY(this) - 1;
		var drawWidth:Float = CameraResizeFix.pegarFSL(this) + 2;
		var drawHeight:Float = CameraResizeFix.pegarFSA(this) + 2;

		targetGraphics.overrideBlendMode(null);
		targetGraphics.beginFill(Color, FxAlpha);
		targetGraphics.drawRect(drawX, drawY, drawWidth, drawHeight);
		targetGraphics.endFill();
	}

	override public function drawPixels(?frame:FlxFrame, ?pixels:BitmapData, matrix:FlxMatrix, ?transform:ColorTransform, ?blend:BlendMode, ?smoothing:Bool = false,
			?shader:FlxShader):Void
	{
		if (FlxG.renderBlit)
		{
			_helperMatrix.copyFrom(matrix);

			if (_useBlitMatrix)
			{
				_helperMatrix.concat(_blitMatrix);
				buffer.draw(pixels, _helperMatrix, null, null, null, (smoothing || antialiasing));
			}
			else
			{
				_helperMatrix.translate(-viewMarginLeft, -viewMarginTop);
				buffer.draw(pixels, _helperMatrix, null, blend, null, (smoothing || antialiasing));
			}
		}
		else
		{
			var isColored = (transform != null #if !html5 && transform.hasRGBMultipliers() #end);
			var hasColorOffsets:Bool = (transform != null && transform.hasRGBAOffsets());

			if(!rotateSprite && angle != 0)
			{
				var pivotX:Float = anglePivotX();
				var pivotY:Float = anglePivotY();
				matrix.translate(-pivotX, -pivotY);
				matrix.rotateWithTrig(_cosAngle, _sinAngle);
				matrix.translate(pivotX, pivotY);
			}

			#if FLX_RENDER_TRIANGLE
			final drawItem = startTrianglesBatch(frame.parent, smoothing, isColored, blend, hasColorOffsets, shader);
			#else
			final drawItem = startQuadBatch(frame.parent, isColored, hasColorOffsets, blend, smoothing, shader);
			#end
			drawItem.addQuad(frame, matrix, transform);
		}
	}

	override public function fill(Color:FlxColor, BlendAlpha:Bool = true, FxAlpha:Float = 1.0, ?graphics:Graphics):Void
	{
		if (FlxG.renderBlit)
		{
			if (BlendAlpha)
			{
				_fill.fillRect(_flashRect, Color);
				buffer.copyPixels(_fill, _flashRect, _flashPoint, null, null, BlendAlpha);
			}
			else
			{
				buffer.fillRect(_flashRect, Color);
			}
		}
		else
		{
			drawScreenFill((graphics == null) ? canvas.graphics : graphics, Color, FxAlpha);
		}
	}
}
