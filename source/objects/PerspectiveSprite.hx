package objects;

import flixel.FlxCamera;
import flixel.FlxStrip;
import flixel.math.FlxPoint;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.util.FlxDestroyUtil;

class PerspectiveSprite extends FlxStrip
{
	public var sprite(get, never):PerspectiveSprite;
	public var bottomPosition:FlxPoint = FlxPoint.get();
	public var topPosition:FlxPoint = FlxPoint.get();
	public var bottomScrollFactor:FlxPoint = FlxPoint.get(1, 1);
	public var topScrollFactor:FlxPoint = FlxPoint.get(1, 1);
	public var topWidth(get, set):Float;
	public var bottomWidth(get, set):Float;

	var _topWidth:Float = Math.NaN;
	var _bottomWidth:Float = Math.NaN;

	public function new(x:Float = 0, y:Float = 0, ?graphic:FlxGraphicAsset)
	{
		super(x, y);
		indices.push(0);
		indices.push(1);
		indices.push(2);
		indices.push(1);
		indices.push(3);
		indices.push(2);
		uvtData.push(0);
		uvtData.push(0);
		uvtData.push(1);
		uvtData.push(0);
		uvtData.push(0);
		uvtData.push(1);
		uvtData.push(1);
		uvtData.push(1);
		if(graphic != null)
			loadGraphic(graphic);
	}

	function get_sprite():PerspectiveSprite
		return this;

	override public function graphicLoaded():Void
	{
		super.graphicLoaded();
		updateVertices();
	}

	override public function destroy():Void
	{
		bottomPosition = FlxDestroyUtil.put(bottomPosition);
		topPosition = FlxDestroyUtil.put(topPosition);
		bottomScrollFactor = FlxDestroyUtil.put(bottomScrollFactor);
		topScrollFactor = FlxDestroyUtil.put(topScrollFactor);
		super.destroy();
	}

	public function setPositions(bottomX:Float, bottomY:Float, topX:Float, topY:Float):PerspectiveSprite
	{
		bottomPosition.set(bottomX, bottomY);
		topPosition.set(topX, topY);
		updateVertices();
		return this;
	}

	public function setWidths(bottom:Float, top:Float):PerspectiveSprite
	{
		_bottomWidth = bottom;
		_topWidth = top;
		updateVertices();
		return this;
	}

	public function setScrollFactors(bottomX:Float, bottomY:Float, topX:Float, topY:Float):PerspectiveSprite
	{
		bottomScrollFactor.set(bottomX, bottomY);
		topScrollFactor.set(topX, topY);
		scrollFactor.set(bottomX, bottomY);
		return this;
	}

	public function updateSkew(?camera:FlxCamera):Void
	{
		if(camera == null)
			camera = getDefaultCamera();
		if(camera == null)
			return;

		x = camera.scroll.x * (bottomScrollFactor.x - 1);
		y = camera.scroll.y * (bottomScrollFactor.y - 1);
		updateVertices(camera);
	}

	function updateVertices(?camera:FlxCamera):Void
	{
		vertices.length = 0;
		var frameW:Float = frameWidth > 0 ? frameWidth : width;
		if(Math.isNaN(frameW) || frameW <= 0)
			frameW = 1;
		var bw:Float = Math.isNaN(_bottomWidth) || _bottomWidth <= 0 ? frameW : _bottomWidth;
		var tw:Float = Math.isNaN(_topWidth) || _topWidth <= 0 ? frameW : _topWidth;
		var dx:Float = 0;
		var dy:Float = 0;
		if(camera != null)
		{
			dx = camera.scroll.x * (topScrollFactor.x - bottomScrollFactor.x);
			dy = camera.scroll.y * (topScrollFactor.y - bottomScrollFactor.y);
		}

		var topX:Float = topPosition.x + dx;
		var topY:Float = topPosition.y + dy;
		var bottomX:Float = bottomPosition.x;
		var bottomY:Float = bottomPosition.y;
		vertices.push(topX - tw * 0.5);
		vertices.push(topY);
		vertices.push(topX + tw * 0.5);
		vertices.push(topY);
		vertices.push(bottomX - bw * 0.5);
		vertices.push(bottomY);
		vertices.push(bottomX + bw * 0.5);
		vertices.push(bottomY);

		width = Math.max(topX + tw * 0.5, bottomX + bw * 0.5) - Math.min(topX - tw * 0.5, bottomX - bw * 0.5);
		height = Math.abs(bottomY - topY);
	}

	function get_topWidth():Float
		return _topWidth;

	function set_topWidth(value:Float):Float
	{
		_topWidth = value;
		updateVertices();
		return value;
	}

	function get_bottomWidth():Float
		return _bottomWidth;

	function set_bottomWidth(value:Float):Float
	{
		_bottomWidth = value;
		updateVertices();
		return value;
	}
}
