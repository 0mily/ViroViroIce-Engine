package backend.ui;

import flixel.util.FlxDestroyUtil;
import flixel.math.FlxPoint;
import backend.ui.PsychUIBox.UIStyleData;

class PsychUITab extends FlxSprite
{
	public var name(default, set):String;
	public var text:FlxText;
	public var menu:FlxSpriteGroup = new FlxSpriteGroup();
	var _tabWidth:Int = 1;
	var _tabHeight:Int = 1;
	var _lastBgColor:FlxColor = 0x00000000;
	var _lastBgAlpha:Float = -1;

	public function new(name:String)
	{
		super();
		HaxeUITheme.drawRoundedBox(this, 1, 1, HaxeUITheme.PANEL);

		@:bypassAccessor this.name = name;
		text = new FlxText(0, 0, 100, name);
		HaxeUITheme.applyText(text);
		text.alignment = CENTER;
		text.color = HaxeUITheme.TEXT_MUTED;
	}

	override function draw()
	{
		super.draw();

		if(visible && text != null && text.exists && text.visible)
		{
			text.x = x;
			text.y = HaxeUITheme.snap(y + height/2 - text.height/2);
			text.draw();
		}
	}

	override function destroy()
	{
		text = FlxDestroyUtil.destroy(text);
		menu = FlxDestroyUtil.destroy(menu);
		super.destroy();
	}
	
	public function updateMenu(parent:PsychUIBox, elapsed:Float)
	{
		if(menu != null && menu.exists && menu.active)
		{
			menu.scrollFactor.set(parent.scrollFactor.x, parent.scrollFactor.y);
			menu.update(elapsed);
		}
	}

	public function drawMenu(parent:PsychUIBox)
	{
		if(menu != null && menu.exists && menu.visible)
		{
			menu.x = parent.x;
			menu.y = parent.y + parent.tabHeight;
			menu.draw();
		}
	}

	public function resize(width:Int, height:Int)
	{
		_tabWidth = width;
		_tabHeight = height;
		_lastBgAlpha = -1;
		applyRawStyle(HaxeUITheme.PANEL, 1);
		text.fieldWidth = width;
	}

	public function applyStyle(style:UIStyleData)
	{
		applyRawStyle(style.bgColor, style.bgAlpha);
		text.color = style.textColor;
	}

	function applyRawStyle(bgColor:FlxColor, bgAlpha:Float)
	{
		if(_lastBgColor == bgColor && _lastBgAlpha == bgAlpha) return;

		HaxeUITheme.drawRoundedBox(this, _tabWidth, _tabHeight, bgColor, bgAlpha);
		_lastBgColor = bgColor;
		_lastBgAlpha = bgAlpha;
	}

	function set_name(v:String)
	{
		text.text = v;
		return (name = v);
	}


	override function set_cameras(v:Array<FlxCamera>)
	{
		text.cameras = v;
		menu.cameras = v;
		return super.set_cameras(v);
	}

	override function set_camera(v:FlxCamera)
	{
		text.camera = v;
		menu.camera = v;
		return super.set_camera(v);
	}
}
