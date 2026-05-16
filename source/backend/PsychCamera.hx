package backend;

import flixel.math.FlxRect;
import flixel.util.FlxDestroyUtil;

// PsychCamera handles followLerp based on elapsed
// and stops camera from snapping at higher framerates

class PsychCamera extends FlxCamera
{
	public var logicalWidth:Float = 0;
	public var logicalHeight:Float = 0;

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
}
