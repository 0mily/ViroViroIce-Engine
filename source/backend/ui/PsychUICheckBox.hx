package backend.ui;

class PsychUICheckBox extends FlxSpriteGroup
{
	public static final CLICK_EVENT = 'checkbox_click';

	public var name:String;
	public var box:FlxSprite;
	public var text:FlxText;
	public var label(get, set):String;

	public var checked(default, set):Bool = false;
	public var onClick:Void->Void = null;

	public function new(x:Float, y:Float, label:String, ?textWid:Int = 100, ?callback:Void->Void)
	{
		super(x, y);

		box = new FlxSprite();
		boxGraphic();
		add(box);

		text = new FlxText(box.width + 4, 0, textWid, label);
		HaxeUITheme.applyText(text);
		text.color = HaxeUITheme.TEXT;
		text.y = HaxeUITheme.snap(text.y + box.height/2 - text.height/2);
		add(text);

		this.onClick = callback;
	}

	public function boxGraphic()
	{
		box.loadGraphic(Paths.image('psych-ui/checkbox', 'embed'), true, 16, 16);
		box.animation.add('false', [0]);
		box.animation.add('true', [1]);
		box.animation.play('false');
		box.color = HaxeUITheme.PURPLE;
	}

	public var broadcastCheckBoxEvent:Bool = true;
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(FlxG.mouse.justPressed && !PsychUIInputText.dropdownBlocks(this))
		{
			var inputCamera:FlxCamera = PsychUIInputText.getInputCamera(camera);
			if(inputCamera != null && (FlxG.mouse.overlaps(box, inputCamera) || FlxG.mouse.overlaps(text, inputCamera)))
			{
				checked = !checked;
				if(onClick != null) onClick();
				if(broadcastCheckBoxEvent) PsychUIEventHandler.event(CLICK_EVENT, this);
			}
		}
	}

	function set_checked(v:Any)
	{
		var v:Bool = (v != null && v != false);
		box.animation.play(Std.string(v));
		return (checked = v);
	}

	function get_label():String {
		return text.text;
	}
	function set_label(v:String):String {
		return (text.text = v);
	}
}
