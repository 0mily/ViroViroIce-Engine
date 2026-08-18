package objects;

import flixel.FlxStrip; // ah!!!
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.frames.FlxFrame.FlxFrameAngle;

class SustainMesh extends FlxStrip
{
	static inline final POINT_EPSILON:Float = 0.01;
	static inline final CLIP_EPSILON:Float = 0.0001;
	static inline final MAX_MITER:Float = 2;

	static inline final CURVE_SUBDIVISIONS:Int = 8;

	var sourceFrame:FlxFrame;
	var pointX:Array<Float> = [];
	var pointY:Array<Float> = [];
	var pointWidth:Array<Float> = [];
	var pointDistance:Array<Float> = [];
	var smoothX:Array<Float> = [];
	var smoothY:Array<Float> = [];
	var smoothWidth:Array<Float> = [];

	public function new()
	{
		super();
		scrollFactor.set();
		moves = false;
		x = y = 0;
	}

	public function rebuild(parent:Note, body:Array<Note>, end:Note, clipTargetX:Float, clipTargetY:Float):Bool
	{
		if (parent == null || (body.length < 1 && end == null))
			return false;

		body.sort(sortByStrumTime);
		var source:Note = body.length > 0 ? body[0] : end;
		var frame:FlxFrame = source?.getSustainBodyFrame();
		if (source == null || frame == null || frame.parent == null)
			return false;

		setSource(source, frame);
		clearGeometry();

		if (body.length > 0)
		{
			var hasVisibleBody:Bool = false;
			var hadClippedBody:Bool = false;
			var fallbackClipX:Float = Math.NaN;
			var fallbackClipY:Float = Math.NaN;
			var bridgeWidth:Float = bodyWidth(end != null ? end : body[body.length - 1], frame);
			var visibleEndX:Float = 0;
			var visibleEndY:Float = 0;
			var visibleEndWidth:Float = 0;
			for (index in 0...body.length)
			{
				var note:Note = body[index];
				var startX:Float = anchorX(note);
				var startY:Float = anchorY(note);
				var length:Float = segmentLength(note);
				var radians:Float = note.angle * Math.PI / 180;
				var directionX:Float = -Math.sin(radians);
				var directionY:Float = Math.cos(radians);

				var clipped:Float = 0;
				if (note.clipRect != null && note.frameHeight > 0)
				{
					var rawClipped:Float = Math.max(0, note.clipRect.y / note.frameHeight);
					clipped = FlxMath.bound(rawClipped, 0, 1);
					hadClippedBody = true;
					fallbackClipX = startX + directionX * length * rawClipped;
					fallbackClipY = startY + directionY * length * rawClipped;
					bridgeWidth = bodyWidth(note, frame);
					if (clipped >= 1 - CLIP_EPSILON)
						continue;
				}

				startX += directionX * length * clipped;
				startY += directionY * length * clipped;
				if (!hasVisibleBody && clipped > 0 && !Math.isNaN(clipTargetX) && !Math.isNaN(clipTargetY))
				{
					startX = clipTargetX;
					startY = clipTargetY;
				}
				var width:Float = bodyWidth(note, frame);

				addPoint(startX, startY, width);
				hasVisibleBody = true;
				visibleEndX = anchorX(note) + directionX * length;
				visibleEndY = anchorY(note) + directionY * length;
				visibleEndWidth = width;
			}

			if (hasVisibleBody)
				addPoint(visibleEndX, visibleEndY, visibleEndWidth);
			else if (hadClippedBody && end != null) {
				var visualEnd:Float = end.visualStrumTime != null ? end.visualStrumTime : end.strumTime;
				if (Conductor.songPosition < visualEnd)
				{
					var bridgeX:Float = !Math.isNaN(clipTargetX) ? clipTargetX : fallbackClipX;
					var bridgeY:Float = !Math.isNaN(clipTargetY) ? clipTargetY : fallbackClipY;
					if (!Math.isNaN(bridgeX) && !Math.isNaN(bridgeY))
						addPoint(bridgeX, bridgeY, bridgeWidth);
				}
			}
		} else {
			var startX:Float = anchorX(parent);
			var startY:Float = anchorY(parent);
			var endX:Float = anchorX(end);
			var endY:Float = anchorY(end);
			var ratio:Float = 0;
			var visualEnd:Float = end.visualStrumTime != null ? end.visualStrumTime : parent.strumTime + parent.sustainLength;
			if (parent.wasGoodHit && visualEnd > parent.strumTime)
				ratio = FlxMath.bound((Conductor.songPosition - parent.strumTime) / (visualEnd - parent.strumTime), 0, 1);
			startX = FlxMath.lerp(startX, endX, ratio);
			startY = FlxMath.lerp(startY, endY, ratio);
			addPoint(startX, startY, bodyWidth(end, frame));
		}

		if (end != null)
			addPoint(anchorX(end), anchorY(end), bodyWidth(end, frame));

		if (pointX.length < 2)
			return false;

		smoothCurve();
		buildTriangles(source);
		return indices.length >= 6;
	}

	function setSource(source:Note, frame:FlxFrame):Void
	{
		if (sourceFrame != frame || graphic != frame.parent)
		{
			loadGraphic(frame.parent);
			sourceFrame = frame;
		}

		antialiasing = source.antialiasing;
		blend = source.blend;
		shader = source.shader;
		var transform = source.colorTransform;
		setColorTransform(transform.redMultiplier, transform.greenMultiplier, transform.blueMultiplier, transform.alphaMultiplier,
			transform.redOffset, transform.greenOffset, transform.blueOffset, transform.alphaOffset);
	}

	function clearGeometry():Void
	{
		pointX.resize(0);
		pointY.resize(0);
		pointWidth.resize(0);
		pointDistance.resize(0);
		vertices.length = 0;
		indices.length = 0;
		uvtData.length = 0;
		colors.length = 0;
	}

	function addPoint(x:Float, y:Float, width:Float):Void
	{
		var last:Int = pointX.length - 1;
		if (last >= 0)
		{
			var dx:Float = x - pointX[last];
			var dy:Float = y - pointY[last];
			if (dx * dx + dy * dy <= POINT_EPSILON * POINT_EPSILON)
			{
				pointX[last] = x;
				pointY[last] = y;
				pointWidth[last] = width;
				return;
			}
		}

		pointX.push(x);
		pointY.push(y);
		pointWidth.push(Math.max(0.001, width));
	}

	function smoothCurve():Void
	{
		var count:Int = pointX.length;
		if (count < 3 || !containsBend(count))
			return;

		smoothX.resize(0);
		smoothY.resize(0);
		smoothWidth.resize(0);

		for (index in 0...(count - 1))
		{
			var first:Int = index > 0 ? index - 1 : index;
			var second:Int = index;
			var third:Int = index + 1;
			var fourth:Int = index + 2 < count ? index + 2 : index + 1;
			var subdivisions:Int = hasBend(first, second, third) || hasBend(second, third, fourth)
				? CURVE_SUBDIVISIONS : 1;

			for (step in 0...(subdivisions + 1))
			{
				if (index > 0 && step == 0)
					continue;

				var ratio:Float = step / subdivisions;
				var ratioSquared:Float = ratio * ratio;
				var ratioCubed:Float = ratioSquared * ratio;
				smoothX.push(catmullRom(pointX[first], pointX[second], pointX[third], pointX[fourth], ratio, ratioSquared, ratioCubed));
				smoothY.push(catmullRom(pointY[first], pointY[second], pointY[third], pointY[fourth], ratio, ratioSquared, ratioCubed));
				smoothWidth.push(FlxMath.lerp(pointWidth[second], pointWidth[third], ratio));
			}
		}

		var oldX:Array<Float> = pointX;
		var oldY:Array<Float> = pointY;
		var oldWidth:Array<Float> = pointWidth;
		pointX = smoothX;
		pointY = smoothY;
		pointWidth = smoothWidth;
		smoothX = oldX;
		smoothY = oldY;
		smoothWidth = oldWidth;
	}

	function containsBend(count:Int):Bool
	{
		for (index in 1...(count - 1))
			if (hasBend(index - 1, index, index + 1))
				return true;
		return false;
	}

	function hasBend(first:Int, second:Int, third:Int):Bool
	{
		if (first == second || second == third)
			return false;

		var firstX:Float = pointX[second] - pointX[first];
		var firstY:Float = pointY[second] - pointY[first];
		var secondX:Float = pointX[third] - pointX[second];
		var secondY:Float = pointY[third] - pointY[second];
		var firstLength:Float = Math.sqrt(firstX * firstX + firstY * firstY);
		var secondLength:Float = Math.sqrt(secondX * secondX + secondY * secondY);
		if (firstLength <= POINT_EPSILON || secondLength <= POINT_EPSILON)
			return false;

		var inverseLength:Float = 1 / (firstLength * secondLength);
		var cross:Float = Math.abs(firstX * secondY - firstY * secondX) * inverseLength;
		var dot:Float = (firstX * secondX + firstY * secondY) * inverseLength;
		return cross > 0.001 || dot < 0.999999;
	}

	static inline function catmullRom(first:Float, second:Float, third:Float, fourth:Float,
			ratio:Float, ratioSquared:Float, ratioCubed:Float):Float
	{
		return 0.5 * ((2 * second) + (-first + third) * ratio
			+ (2 * first - 5 * second + 4 * third - fourth) * ratioSquared
			+ (-first + 3 * second - 3 * third + fourth) * ratioCubed);
	}

	function buildTriangles(source:Note):Void
	{
		var count:Int = pointX.length;
		var totalDistance:Float = 0;
		pointDistance.push(0);
		for (index in 1...count)
		{
			var dx:Float = pointX[index] - pointX[index - 1];
			var dy:Float = pointY[index] - pointY[index - 1];
			totalDistance += Math.sqrt(dx * dx + dy * dy);
			pointDistance.push(totalDistance);
		}

		if (totalDistance <= POINT_EPSILON)
			return;

		var mirrorTexture:Bool = source.flipX != (source.scale.x < 0);
		var halfTexelU:Float = source.antialiasing ? 0.5 / sourceFrame.parent.width : 0;
		var halfTexelV:Float = source.antialiasing ? 0.5 / sourceFrame.parent.height : 0;
		var atlasLeft:Float = sourceFrame.uv.left + halfTexelU;
		var atlasTop:Float = sourceFrame.uv.top + halfTexelV;
		var atlasRight:Float = sourceFrame.uv.right - halfTexelU;
		var atlasBottom:Float = sourceFrame.uv.bottom - halfTexelV;

		for (index in 0...count)
		{
			var previous:Int = index > 0 ? index - 1 : index;
			var next:Int = index < count - 1 ? index + 1 : index;
			var previousX:Float = pointX[index] - pointX[previous];
			var previousY:Float = pointY[index] - pointY[previous];
			var nextX:Float = pointX[next] - pointX[index];
			var nextY:Float = pointY[next] - pointY[index];
			normalize(previousX, previousY, _previousDirection);
			normalize(nextX, nextY, _nextDirection);

			if (index == 0)
				_previousDirection.copyFrom(_nextDirection);
			else if (index == count - 1)
				_nextDirection.copyFrom(_previousDirection);

			var tangentX:Float = _previousDirection.x + _nextDirection.x;
			var tangentY:Float = _previousDirection.y + _nextDirection.y;
			var tangentLength:Float = Math.sqrt(tangentX * tangentX + tangentY * tangentY);
			if (tangentLength <= POINT_EPSILON)
			{
				tangentX = _nextDirection.x;
				tangentY = _nextDirection.y;
				tangentLength = 1;
			}
			tangentX /= tangentLength;
			tangentY /= tangentLength;

			var normalX:Float = -tangentY;
			var normalY:Float = tangentX;
			var nextNormalX:Float = -_nextDirection.y;
			var nextNormalY:Float = _nextDirection.x;
			var denominator:Float = Math.abs(normalX * nextNormalX + normalY * nextNormalY);
			var halfWidth:Float = pointWidth[index] * 0.5;
			var miter:Float = halfWidth / Math.max(0.5, denominator);
			miter = Math.min(miter, halfWidth * MAX_MITER);

			vertices.push(pointX[index] + normalX * miter);
			vertices.push(pointY[index] + normalY * miter);
			vertices.push(pointX[index] - normalX * miter);
			vertices.push(pointY[index] - normalY * miter);

			var progress:Float = pointDistance[index] / totalDistance;
			pushFrameUV(progress, mirrorTexture, atlasLeft, atlasTop, atlasRight, atlasBottom);

			if (index < count - 1)
			{
				var vertex:Int = index * 2;
				indices.push(vertex);
				indices.push(vertex + 1);
				indices.push(vertex + 2);
				indices.push(vertex + 1);
				indices.push(vertex + 3);
				indices.push(vertex + 2);
			}
		}
	}

	function pushFrameUV(progress:Float, mirrorTexture:Bool, atlasLeft:Float, atlasTop:Float,
			atlasRight:Float, atlasBottom:Float):Void
	{
		if (sourceFrame.angle == FlxFrameAngle.ANGLE_90)
		{
			var along:Float = FlxMath.lerp(atlasLeft, atlasRight, progress);
			uvtData.push(along);
			uvtData.push(mirrorTexture ? atlasTop : atlasBottom);
			uvtData.push(along);
			uvtData.push(mirrorTexture ? atlasBottom : atlasTop);
		}
		else if (sourceFrame.angle == FlxFrameAngle.ANGLE_NEG_90)
		{
			var along:Float = FlxMath.lerp(atlasRight, atlasLeft, progress);
			uvtData.push(along);
			uvtData.push(mirrorTexture ? atlasBottom : atlasTop);
			uvtData.push(along);
			uvtData.push(mirrorTexture ? atlasTop : atlasBottom);
		}
		else
		{
			var along:Float = FlxMath.lerp(atlasTop, atlasBottom, progress);
			uvtData.push(mirrorTexture ? atlasRight : atlasLeft);
			uvtData.push(along);
			uvtData.push(mirrorTexture ? atlasLeft : atlasRight);
			uvtData.push(along);
		}
	}

	static var _previousDirection:FlxPoint = FlxPoint.get();
	static var _nextDirection:FlxPoint = FlxPoint.get();

	static function normalize(x:Float, y:Float, output:FlxPoint):Void
	{
		var length:Float = Math.sqrt(x * x + y * y);
		if (length <= POINT_EPSILON)
			output.set(0, 1);
		else
			output.set(x / length, y / length);
	}

	static inline function anchorX(note:Note):Float
	{
		if (note.offset != null && note.origin != null)
			return note.x - note.offset.x + note.origin.x;
		if (!Math.isNaN(note.sustainMeshStartX))
			return note.sustainMeshStartX;
		return note.x + note.width * 0.5;
	}

	static inline function anchorY(note:Note):Float
	{
		if (note.offset != null && note.origin != null)
			return note.y - note.offset.y + note.origin.y;
		if (!Math.isNaN(note.sustainMeshStartY))
			return note.sustainMeshStartY;
		return note.y + note.height * 0.5;
	}

	static inline function segmentLength(note:Note):Float
		return Math.max(0, note.milyMCSustainDrawLength > 0 ? note.milyMCSustainDrawLength : Math.abs(note.scale.y * note.frameHeight));

	static inline function bodyWidth(note:Note, frame:FlxFrame):Float
	{
		var packedWidth:Float = frame.angle == FlxFrameAngle.ANGLE_0 ? frame.frame.width : frame.frame.height;
		return packedWidth * Math.abs(note.scale.x);
	}

	static function sortByStrumTime(first:Note, second:Note):Int
		return first.strumTime < second.strumTime ? -1 : (first.strumTime > second.strumTime ? 1 : 0);
}
