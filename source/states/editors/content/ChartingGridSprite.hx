package states.editors.content;

import flixel.addons.display.FlxGridOverlay;

// Laggier than a single sprite for the grid, but this is to avoid having to re-create the sprite constantly
class ChartingGridSprite extends FlxSprite
{
	public var rows(default, set):Float = 16;
	public var columns(default, null):Int = 0;
	public var spacing(default, set):Int = 0;
	public var stripe:FlxSprite;
	public var stripes:Array<Int>;

	var vortexLine:FlxSprite;
	var sectionLine:FlxSprite;
	public var vortexLineEnabled:Bool = false;
	public var vortexLineSpace:Float = 0;
	public var sectionLineRows:Array<Float> = [];

	public function new(columns:Int, ?color1:FlxColor = 0xFFE6E6E6, ?color2:FlxColor = 0xFFD8D8D8)
	{
		super();
		this.columns = columns;
		scrollFactor.x = 0;
		active = false;

		scale.set(ChartingState.GRID_SIZE, ChartingState.GRID_SIZE);
		loadGrid(color1, color2);
		updateHitbox();
		recalcHeight();

		vortexLine = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		vortexLine.scale.x = this.width;
		vortexLine.scrollFactor.x = 0;
		vortexLine.color = 0xFF660000;
		vortexLine.updateHitbox();

		sectionLine = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		sectionLine.scale.x = this.width;
		sectionLine.scale.y = 3;
		sectionLine.scrollFactor.x = 0;
		sectionLine.color = 0xFF287DFF;
		sectionLine.updateHitbox();

		stripe = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		stripe.scrollFactor.x = 0;
		stripe.color = FlxColor.BLACK;
		updateStripes();
	}

	public function loadGrid(color1:FlxColor, color2:FlxColor)
	{
		loadGraphic(FlxGridOverlay.createGrid(1, 1, columns, 2, true, color1, color2), true, columns, 1);
		animation.add('odd', [0], false);
		animation.add('even', [1], false);
		animation.play('even', true);
		updateHitbox();
		recalcHeight();
	}

	override function draw()
	{
		if(!visible || alpha == 0 || rows <= 0 || camera == null) return;

		var initialFlip:Bool = flipY;
		var initialY:Float = y;
		var stride:Float = ChartingState.GRID_SIZE + spacing;
		var viewTop:Float = camera.scroll.y - ChartingState.GRID_SIZE;
		var viewBottom:Float = camera.scroll.y + camera.height + ChartingState.GRID_SIZE;
		var baseY:Float = initialFlip ? initialY + height - ChartingState.GRID_SIZE : initialY;
		var first:Int = initialFlip
			? Std.int(Math.max(0, Math.floor((baseY - viewBottom) / stride)))
			: Std.int(Math.max(0, Math.floor((viewTop - baseY) / stride)));
		var last:Int = Math.ceil(rows);

		flipY = false;
		for(i in first...last)
		{
			var rowY:Float = baseY + i * stride * (initialFlip ? -1 : 1);
			if(!initialFlip && rowY > viewBottom) break;
			if(initialFlip && rowY + ChartingState.GRID_SIZE < viewTop) break;

			y = rowY;
			animation.play((i % 2 == 1) ? 'odd' : 'even', true);
			scale.y = ChartingState.GRID_SIZE * Math.min(1, rows - i);
			offset.y = -0.5 * (scale.y - 1);
			super.draw();
		}

		animation.play('even', true);
		flipY = initialFlip;
		y = initialY;

		_drawStripes();
		drawGuideLines(viewTop, viewBottom, initialFlip);
	}

	function drawGuideLines(viewTop:Float, viewBottom:Float, reversed:Bool):Void
	{
		var anchor:Float = reversed ? y + height : y;
		var direction:Int = reversed ? -1 : 1;
		if(vortexLineEnabled && vortexLineSpace > 0)
		{
			vortexLine.x = x;
			var first:Int = Std.int(Math.max(0, Math.floor((reversed ? anchor - viewBottom : viewTop - anchor) / vortexLineSpace)));
			var max:Int = Math.ceil(height / vortexLineSpace);
			for(i in first...max + 1)
			{
				vortexLine.y = anchor + direction * i * vortexLineSpace - 1;
				if(vortexLine.y < viewTop - 3 || vortexLine.y > viewBottom + 3) continue;
				vortexLine.draw();
			}
		}

		if(sectionLineRows != null)
		{
			sectionLine.x = x;
			for(row in sectionLineRows)
			{
				sectionLine.y = anchor + direction * row * ChartingState.GRID_SIZE - 1;
				if(sectionLine.y < viewTop - 4 || sectionLine.y > viewBottom + 4) continue;
				sectionLine.draw();
			}
		}
	}

	function _drawStripes()
	{
		for (i => column in stripes)
		{
			if(column == 0)
				stripe.x = this.x;
			else 
				stripe.x = this.x + ChartingState.GRID_SIZE * column - stripe.width/2;
			stripe.draw();
		}
	}

	public function updateStripes()
	{
		if(stripe == null || !stripe.exists) return;
		stripe.y = this.y;
		stripe.setGraphicSize(2, this.height);
		stripe.updateHitbox();
	}

	function set_rows(v:Float)
	{
		rows = v;
		recalcHeight();
		return rows;
	}

	function set_spacing(v:Int)
	{
		spacing = v;
		recalcHeight();
		return spacing;
	}

	function recalcHeight()
	{
		height = ((ChartingState.GRID_SIZE + spacing) * rows) - spacing;
		updateStripes();
	}
}
