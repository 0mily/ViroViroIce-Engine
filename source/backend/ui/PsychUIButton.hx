package backend.ui;

import backend.ui.PsychUIBox.UIStyleData;

class PsychUIButton extends FlxSpriteGroup
{
	public static final CLICK_EVENT = 'button_click';

	public var name:String;
	public var label(default, set):String;
	public var bg:FlxSprite;
	public var text:FlxText;

	public var onChangeState:String->Void;
	public var onClick:Void->Void;
	var _buttonWidth:Int = 1;
	var _buttonHeight:Int = 1;
	
	public var clickStyle:UIStyleData = {
		bgColor: HaxeUITheme.PURPLE_DARK,
		textColor: FlxColor.WHITE,
		bgAlpha: 1
	};
	public var hoverStyle:UIStyleData = {
		bgColor: HaxeUITheme.PANEL_LIGHT,
		textColor: FlxColor.WHITE,
		bgAlpha: 1
	};
	public var normalStyle:UIStyleData = {
		bgColor: HaxeUITheme.PANEL,
		textColor: HaxeUITheme.TEXT,
		bgAlpha: 1
	};

	public function new(x:Float = 0, y:Float = 0, label:String = '', ?onClick:Void->Void = null, ?wid:Int = 80, ?hei:Int = 20)
	{
		super(x, y);
		bg = new FlxSprite();
		add(bg);

		text = new FlxText(0, 0, 1, '');
		HaxeUITheme.applyText(text);
		text.alignment = CENTER;
		text.color = normalStyle.textColor;
		add(text);
		resize(wid, hei);
		this.label = label;
		
		this.onClick = onClick;
		forceCheckNext = true;
	}

	public var isClicked:Bool = false;
	public var forceCheckNext:Bool = false;
	public var broadcastButtonEvent:Bool = true;
	var _firstFrame:Bool = true;
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(_firstFrame)
		{
			applyStyle(normalStyle);
			_firstFrame = false;
		}
		
		if(isClicked && FlxG.mouse.released)
		{
			forceCheckNext = true;
			isClicked = false;
		}

		if(forceCheckNext || FlxG.mouse.justMoved || FlxG.mouse.justPressed)
		{
			var overlapped:Bool = (FlxG.mouse.overlaps(bg, camera));

			forceCheckNext = false;

			if(!isClicked)
			{
				var style:UIStyleData = (overlapped) ? hoverStyle : normalStyle;
				applyStyle(style);
			}

			if(overlapped && FlxG.mouse.justPressed)
			{
				isClicked = true;
				applyStyle(clickStyle);
				if(onClick != null) onClick();
				if(broadcastButtonEvent) PsychUIEventHandler.event(CLICK_EVENT, this);
			}
		}
	}

	public function resize(width:Int, height:Int)
	{
		_buttonWidth = width;
		_buttonHeight = height;
		applyStyle(normalStyle);
		text.fieldWidth = width;
		text.x = bg.x;
		text.y = HaxeUITheme.snap(bg.y + height/2 - text.height/2);
	}

	function applyStyle(style:UIStyleData)
	{
		HaxeUITheme.drawRoundedBox(bg, _buttonWidth, _buttonHeight, style.bgColor, style.bgAlpha);
		text.color = style.textColor;
	}

	function set_label(v:String)
	{
		if(text != null && text.exists) text.text = v;
		return (label = v);
	}
}
