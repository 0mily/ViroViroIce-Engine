package substates;

// btw, this substate will change drastically in the future

import backend.DeveloperMode;

class DeveloperModeSubState extends MusicBeatSubstate
{
	var pcButton:FlxSprite;
	var mobileButton:FlxSprite;
	var pcText:FlxText;
	var mobileText:FlxText;

	override function create():Void
	{
		DeveloperMode.pickerOpen = true;
		FlxG.mouse.visible = true;

		if(FlxG.cameras.list.length > 0)
			cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.65;
		bg.scrollFactor.set();
		add(bg);

		var title:FlxText = new FlxText(0, 120, FlxG.width, 'Developer Mode', 42);
		title.setFormat(Paths.font('vcr.ttf'), 42, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.borderSize = 2;
		title.scrollFactor.set();
		add(title);

		pcButton = createButton(FlxG.width * 0.5 - 360, 300, 300, 150);
		mobileButton = createButton(FlxG.width * 0.5 + 60, 300, 300, 150);
		add(pcButton);
		add(mobileButton);

		pcText = createButtonText(pcButton, 'PC');
		mobileText = createButtonText(mobileButton, 'Mobile\n2400 x 1080');
		add(pcText);
		add(mobileText);

		var desc:FlxText = new FlxText(0, 500, FlxG.width, 'Select which model you want to use.', 20);
		desc.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.GRAY, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		desc.borderSize = 1;
		desc.scrollFactor.set();
		add(desc);

		super.create();
	}

	function createButton(x:Float, y:Float, width:Int, height:Int):FlxSprite
	{
		var button:FlxSprite = new FlxSprite(x, y).makeGraphic(width, height, FlxColor.WHITE);
		button.color = 0xFF272D47;
		button.scrollFactor.set();
		return button;
	}

	function createButtonText(button:FlxSprite, text:String):FlxText
	{
		var label:FlxText = new FlxText(button.x, button.y + 42, button.width, text, 30);
		label.setFormat(Paths.font('vcr.ttf'), 30, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		label.borderSize = 1.6;
		label.scrollFactor.set();
		return label;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		DeveloperMode.update();

		updateButton(pcButton, pcText);
		updateButton(mobileButton, mobileText);

		if(FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE || FlxG.mouse.justPressedRight)
		{
			close();
			return;
		}

		if(FlxG.mouse.justPressed)
		{
			if(FlxG.mouse.overlaps(pcButton, pickerCamera()))
				DeveloperMode.selectPC();
			else if(FlxG.mouse.overlaps(mobileButton, pickerCamera()))
				DeveloperMode.selectMobile();
		}
	}

	function updateButton(button:FlxSprite, label:FlxText):Void
	{
		var hovering:Bool = FlxG.mouse.overlaps(button, pickerCamera());
		button.color = hovering ? 0xFF46558A : 0xFF272D47;
		label.color = hovering ? 0xFFFFFFFF : 0xFFE7E7E7;
	}

	function pickerCamera():FlxCamera
	{
		return (cameras != null && cameras.length > 0) ? cameras[0] : FlxG.camera;
	}

	override function destroy():Void
	{
		DeveloperMode.pickerOpen = false;
		super.destroy();
	}
}
