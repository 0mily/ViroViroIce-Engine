package backend.ui;

import backend.ui.PsychUIBox.UIStyleData;

class PsychUIDropDownMenu extends PsychUIInputText
{
	public static final REVEAL_EVENT = "dropdown_reveal";
	public static final CLICK_EVENT = "dropdown_click";

	public var list(default, set):Array<String> = [];
	public var button:FlxSprite;
	public var onSelect:Int->String->Void;

	public var selectedIndex(default, set):Int = -1;
	public var selectedLabel(default, set):String = null;

	var _curFilter:Array<String>;
	var _itemWidth:Float = 0;
	public function new(x:Float, y:Float, list:Array<String>, callback:Int->String->Void, ?width:Float = 100)
	{
		super(x, y);
		if(list == null) list = [];

		_itemWidth = width - 2;
		setGraphicSize(width, 20);
		fieldWidth = Std.int(width);
		updateHitbox();
		textObj.y += 2;

		button = new FlxSprite(behindText.width + 1, 0).loadGraphic(Paths.image('psych-ui/dropdown_button', 'embed'), true, 20, 20);
		button.animation.add('normal', [0], false);
		button.animation.add('pressed', [1], false);
		button.animation.play('normal', true);
		button.color = HaxeUITheme.PURPLE_DARK;
		add(button);

		onSelect = callback;

		onChange = function(old:String, cur:String)
		{
			if(old != cur)
			{
				_curFilter = this.list.filter(function(str:String) return str.startsWith(cur));
				showDropDown(true, 0, _curFilter);
			}
		}
		unfocus = function()
		{
			showDropDownClickFix();
			showDropDown(false);
		}

		for (option in list)
			addOption(option);

		selectedIndex = 0;
		showDropDown(false);
	}

	function set_selectedIndex(v:Int)
	{
		selectedIndex = v;
		if(selectedIndex < 0 || selectedIndex >= list.length) selectedIndex = -1;

		@:bypassAccessor selectedLabel = selectedIndex >= 0 ? list[selectedIndex] : null;
		text = (selectedLabel != null) ? selectedLabel : '';
		return selectedIndex;
	}

	function set_selectedLabel(v:String)
	{
		var id:Int = list.indexOf(v);
		if(id >= 0)
		{
			@:bypassAccessor selectedIndex = id;
			selectedLabel = v;
			text = selectedLabel;
		}
		else
		{
			@:bypassAccessor selectedIndex = -1;
			selectedLabel = null;
			text = '';
		}
		return selectedLabel;
	}

	var _items:Array<PsychUIDropDownItem> = [];
	public var curScroll:Int = 0;
	override function update(elapsed:Float)
	{
		if(!exists)
			return;

		var lastFocus = PsychUIInputText.focusOn;
		super.update(elapsed);
		if(PsychUIInputText.dropdownBlocks(this)) return;
		if(button == null || !button.exists)
			return;

		var inputCamera:FlxCamera = PsychUIInputText.getInputCamera(camera); // no more softlocks and crashes i think
		if(inputCamera == null)
			return;

		if(FlxG.mouse.justPressed)
		{
			if(FlxG.mouse.overlaps(button, inputCamera))
			{
				button.animation.play('pressed', true);
				if(lastFocus != this)
					PsychUIInputText.focusOn = this;
				else if(PsychUIInputText.focusOn == this)
					PsychUIInputText.focusOn = null;
			}
		}
		else if(FlxG.mouse.released && button.animation.curAnim != null && button.animation.curAnim.name != 'normal') button.animation.play('normal', true);

		if(lastFocus != PsychUIInputText.focusOn)
		{
			var isFocused:Bool = (PsychUIInputText.focusOn == this);
			if (isFocused && broadcastDropDownEvent)
				PsychUIEventHandler.event(REVEAL_EVENT, this);
			showDropDown(isFocused);
		}
		else if(PsychUIInputText.focusOn == this)
		{
			var wheel:Int = FlxG.mouse.wheel;
			if(FlxG.keys.justPressed.UP) wheel++;
			if(FlxG.keys.justPressed.DOWN) wheel--;
			if(wheel != 0) showDropDown(true, curScroll - wheel, _curFilter);
		}
	}

	private function showDropDownClickFix()
	{
		if(FlxG.mouse.justPressed && _items != null)
		{
			for (item in liveItems()) //extra update to fix a little bug where it wouldnt click on any option if another input text was behind the drop down
				if(item != null && item.active && item.visible)
					item.update(0);
		}
	}

	public function showDropDown(vis:Bool = true, scroll:Int = 0, onlyAllowed:Array<String> = null)
	{
		if(!exists || _items == null)
			return;

		if(!vis)
		{
			text = selectedLabel ?? '';
			_curFilter = null;
		}

		var items:Array<PsychUIDropDownItem> = liveItems();
		curScroll = Std.int(Math.max(0, Math.min(onlyAllowed != null ? (onlyAllowed.length - 1) : (list.length - 1), scroll)));
		if(vis)
		{
			var n:Int = 0;
			for (item in items)
			{
				if(onlyAllowed != null)
				{
					if(onlyAllowed.contains(item.label))
					{
						item.active = item.visible = (n >= curScroll);
						n++;
					}
					else item.active = item.visible = false;
				}
				else
				{
					item.active = item.visible = (n >= curScroll);
					n++;
				}
			}

			var txtY:Float = behindText.y + behindText.height + 1;
			for (item in items)
			{
				if(!item.visible) continue;
				item.x = behindText.x;
				item.y = txtY;
				txtY += item.dropdownHeight();
				item.forceNextUpdate = true;
			}
			bg.scale.y = 1;
			bg.updateHitbox();
		}
		else
		{
			for (item in items)
				item.active = item.visible = false;

			bg.scale.y = 1;
			bg.updateHitbox();
		}
	}

	function liveItems():Array<PsychUIDropDownItem>
	{
		if(_items == null)
			return [];

		var items:Array<PsychUIDropDownItem> = [];
		for(item in _items)
			if(item != null && item.exists && item.bg != null && item.bg.exists && item.text != null && item.text.exists)
				items.push(item);
		_items = items;
		return items;
	}

	public var broadcastDropDownEvent:Bool = true;
	function clickedOn(num:Int, label:String)
	{
		selectedIndex = num;
		showDropDown(false);
		if(PsychUIInputText.focusOn == this)
			PsychUIInputText.focusOn = null;
		if(onSelect != null) onSelect(num, label);
		if(broadcastDropDownEvent) PsychUIEventHandler.event(CLICK_EVENT, this);
	}

	function addOption(option:String)
	{
		@:bypassAccessor list.push(option);
		var curID:Int = list.length - 1;
		var item:PsychUIDropDownItem = cast recycle(PsychUIDropDownItem, () -> new PsychUIDropDownItem(1, 1, this._itemWidth), true);
		item.resizeItem(this._itemWidth);
		item.cameras = cameras;
		item.label = option;
		item.visible = item.active = false;
		item.onClick = function() clickedOn(curID, option);
		item.forceNextUpdate = true;
		_items.push(item);
		insert(1, item);
	}

	function set_list(v:Array<String>)
	{
		if(v == null) v = [];
		var selected:String = selectedLabel;
		showDropDown(false);

		for (item in liveItems())
		{
			remove(item, true);
			item.kill();
		}

		_items = [];
		list = [];
		for (option in v)
			addOption(option);

		if(selectedLabel != null) selectedLabel = selected;
		return v;
	}

	override public function destroy()
	{
		if(PsychUIInputText.focusOn == this)
			PsychUIInputText.focusOn = null;
		onSelect = null;
		if(_items != null)
			for(item in _items)
				if(item != null)
					item.onClick = null;
		_items = null;
		button = null;
		super.destroy();
	}
}

class PsychUIDropDownItem extends FlxSpriteGroup
{
	public var hoverStyle:UIStyleData = {
		bgColor: HaxeUITheme.PURPLE_DARK,
		textColor: FlxColor.WHITE,
		bgAlpha: 1
	};
	public var normalStyle:UIStyleData = {
		bgColor: HaxeUITheme.INPUT_FILL,
		textColor: HaxeUITheme.INPUT_TEXT,
		bgAlpha: 1
	};

	public var bg:FlxSprite;
	public var text:FlxText;
	var _itemWidth:Float = 1;
	var _itemHeight:Float = 20;
	public function new(x:Float = 0, y:Float = 0, width:Float = 100)
	{
		super(x, y);

		_itemWidth = width;
		bg = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
		bg.setGraphicSize(width, 20);
		bg.color = HaxeUITheme.INPUT_FILL;
		bg.updateHitbox();
		add(bg);

		text = new FlxText(0, 0, width, 8);
		HaxeUITheme.applyText(text, 8);
		text.color = HaxeUITheme.INPUT_TEXT;
		add(text);
	}

	public function resizeItem(width:Float)
	{
		if(bg == null || text == null)
			return;

		_itemWidth = width;
		bg.makeGraphic(Std.int(Math.max(1, Math.ceil(_itemWidth))), Std.int(Math.max(1, Math.ceil(_itemHeight))), HaxeUITheme.INPUT_FILL, true);
		bg.scale.set(1, 1);
		bg.color = HaxeUITheme.INPUT_FILL;
		bg.updateHitbox();
		bg.visible = true;
		bg.alpha = 1;
		text.fieldWidth = _itemWidth;
	}

	public var onClick:Void->Void;
	public var forceNextUpdate:Bool = false;
	override function update(elapsed:Float)
	{
		if(!exists || bg == null || text == null)
			return;

		super.update(elapsed);
		if(bg == null || !bg.exists || bg.scrollFactor == null || text == null || !text.exists)
			return;

		if(FlxG.mouse.justMoved || FlxG.mouse.justPressed || forceNextUpdate)
		{
			var inputCamera:FlxCamera = PsychUIInputText.getInputCamera(camera);
			if(inputCamera == null)
				return;
			var overlapped:Bool = (FlxG.mouse.overlaps(bg, inputCamera));

			var style = overlapped ? hoverStyle : normalStyle;
			applyStyle(style);
			forceNextUpdate = false;

			if(overlapped && FlxG.mouse.justPressed && onClick != null)
				onClick();
		}
		
		text.x = bg.x;
		text.y = HaxeUITheme.snap(bg.y + bg.height/2 - text.height/2);
	}

	public var label(default, set):String;
	function set_label(v:String)
	{
		label = v;
		if(text != null)
		{
			text.text = v;
			_itemHeight = text.height + 6;
			resizeItem(_itemWidth);
		}
		return v;
	}

	public function dropdownHeight():Float
	{
		if(Math.isNaN(_itemHeight) || _itemHeight <= 0)
			return 20;
		return _itemHeight;
	}

	function applyStyle(style:UIStyleData)
	{
		if(bg == null)
			return;

		bg.color = style.bgColor;
		bg.alpha = style.bgAlpha;
		if(text != null) text.color = style.textColor;
	}

	override public function destroy()
	{
		onClick = null;
		super.destroy();
		bg = null;
		text = null;
	}
}
