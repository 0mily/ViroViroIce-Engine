package states;

import flixel.math.FlxRect;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxGradient;
import openfl.display.BitmapData;

// mano, eu genuinamente fiquei com preguiça de continuar

class ContentMenuState extends MusicBeatState
{
	static inline var BANNER_WIDTH:Int = 772;
	static inline var BANNER_HEIGHT:Int = 278;

	var bg:FlxSprite;
	var listBg:FlxSprite;
	var detailBg:FlxSprite;
	var bannerFrame:FlxSprite;
	var banner:FlxSprite;
	var bannerShade:FlxSprite;
	var rows:FlxTypedGroup<ContentRow>;
	var entries:Array<ContentEntry> = [];

	var titleText:FlxText;
	var metaText:FlxText;
	var descText:FlxText;
	var addonPrefixText:FlxText;
	var icon:FlxSprite;
	var scrollTrack:FlxSprite;
	var scrollThumb:FlxSprite;
	var addonButton:ContentMenuButton;
	var enterButton:ContentMenuButton;
	var backButton:ContentMenuButton;

	var curSelected:Int = 0;
	var centerContent:Int = 3;
	var holdTime:Float = 0;
	var descScroll:Float = 0;
	var descScrollTarget:Float = 0;
	var descBaseY:Float = 0;
	var descAreaHeight:Float = 144;
	var descClipRect:FlxRect;
	var draggingDescription:Bool = false;
	var draggingScrollbar:Bool = false;
	var dragMouseY:Float = 0;
	var dragStartScroll:Float = 0;
	var quitting:Bool = false;

	override function create()
	{
		rpcDetails = 'Contents Menu';
		persistentUpdate = false;
		FlxG.mouse.visible = true;

		entries = buildEntries();

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF2D7D73;
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.screenCenter();
		add(bg);

		listBg = FlxSpriteUtil.drawRoundRect(new FlxSprite(38, 42).makeGraphic(360, 612, FlxColor.TRANSPARENT), 0, 0, 360, 612, 15, 15, FlxColor.BLACK);
		listBg.alpha = 0.62;
		add(listBg);

		detailBg = FlxSpriteUtil.drawRoundRect(new FlxSprite(420, 42).makeGraphic(820, 612, FlxColor.TRANSPARENT), 0, 0, 820, 612, 15, 15, FlxColor.BLACK);
		detailBg.alpha = 0.62;
		add(detailBg);

		bannerFrame = FlxSpriteUtil.drawRoundRect(new FlxSprite(detailBg.x + 24, detailBg.y + 24).makeGraphic(BANNER_WIDTH, BANNER_HEIGHT, FlxColor.TRANSPARENT), 0, 0, BANNER_WIDTH, BANNER_HEIGHT, 10, 10, FlxColor.BLACK);
		bannerFrame.alpha = 0.52;
		add(bannerFrame);

		banner = new FlxSprite(bannerFrame.x, bannerFrame.y);
		add(banner);

		bannerShade = FlxGradient.createGradientFlxSprite(BANNER_WIDTH, 150, [0x00000000, 0x99000000, 0xE0000000]);
		bannerShade.setPosition(bannerFrame.x, bannerFrame.y + BANNER_HEIGHT - bannerShade.height);
		add(bannerShade);

		rows = new FlxTypedGroup<ContentRow>();
		for (entry in entries)
			rows.add(new ContentRow(entry));
		add(rows);

		icon = new FlxSprite(bannerFrame.x + 18, bannerFrame.y + BANNER_HEIGHT - 124);
		add(icon);

		titleText = new FlxText(icon.x + 128, bannerFrame.y + BANNER_HEIGHT - 54, 500, '', 32);
		titleText.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 1;
		add(titleText);

		metaText = new FlxText(detailBg.x + 520, bannerFrame.y + BANNER_HEIGHT + 8, 276, '', 18);
		metaText.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, RIGHT);
		add(metaText);

		descBaseY = bannerFrame.y + BANNER_HEIGHT + 40;
		descText = new FlxText(detailBg.x + 38, descBaseY, detailBg.width - 112, '', 20);
		descText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, LEFT);
		descClipRect = new FlxRect(0, 0, descText.width, descAreaHeight);
		descText.clipRect = descClipRect;
		add(descText);

		scrollTrack = new FlxSprite(detailBg.x + detailBg.width - 28, descBaseY).makeGraphic(4, Std.int(descAreaHeight), 0x77FFFFFF);
		add(scrollTrack);

		scrollThumb = new FlxSprite(scrollTrack.x - 3, scrollTrack.y).makeGraphic(10, 32, 0xFFFFFFFF);
		add(scrollThumb);

		addonButton = new ContentMenuButton(detailBg.x + 24, detailBg.y + detailBg.height - 54, 'addon', false, 48);
		add(addonButton);

		addonPrefixText = new FlxText(addonButton.x + 52, addonButton.y + 15, 430, '', 19);
		addonPrefixText.setFormat(Paths.font('vcr.ttf'), 19, 0xFFB7FFF7, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		addonPrefixText.borderSize = 0.7;
		add(addonPrefixText);

		backButton = new ContentMenuButton(detailBg.x + detailBg.width - 188, detailBg.y + detailBg.height - 56, 'back', true, 58);
		add(backButton);
		enterButton = new ContentMenuButton(detailBg.x + detailBg.width - 84, detailBg.y + detailBg.height - 56, 'enter', true, 58);
		add(enterButton);

		var selectedContent:String = Mods.getSelectedContentDirectory();
		for (i => entry in entries)
			if (entry.folder == selectedContent)
				curSelected = i;
		updateSelection(true);
		super.create();
	}

	function buildEntries():Array<ContentEntry>
	{
		var list:Array<ContentEntry> = [ContentEntry.baseGame()];
		#if MODS_ALLOWED
		Mods.clearContentCaches();
		for (folder in Mods.getContentDirectories())
			list.push(new ContentEntry(folder));
		#end
		return list;
	}

	override function update(elapsed:Float)
	{
		if (quitting)
		{
			super.update(elapsed); // bug maldito
			return;
		}

		if (entries.length > 1)
		{
			var shiftMult:Int = (FlxG.keys.pressed.SHIFT || FlxG.gamepads.anyPressed(LEFT_SHOULDER) || FlxG.gamepads.anyPressed(RIGHT_SHOULDER)) ? 4 : 1;

			if (controls.UI_UP_P)
			{
				changeSelection(-shiftMult);
				holdTime = 0;
			}
			else if (controls.UI_DOWN_P)
			{
				changeSelection(shiftMult);
				holdTime = 0;
			}
			else if (controls.UI_UP || controls.UI_DOWN)
			{
				var lastHoldTime:Float = holdTime;
				holdTime += elapsed;
				if (holdTime > 0.5 && Math.floor(lastHoldTime * 8) != Math.floor(holdTime * 8))
					changeSelection(shiftMult * (controls.UI_UP ? -1 : 1));
			}

			if (FlxG.mouse.justPressed)
			{
				for (i in centerContent - 3...centerContent + 4)
				{
					var row:ContentRow = rows.members[i];
					if (row != null && row.visible && FlxG.mouse.overlaps(row))
					{
						if (curSelected == i)
							acceptContent();
						else
						{
							curSelected = i;
							updateSelection();
						}
						break;
					}
				}
			}

			if (FlxG.mouse.visible && FlxG.mouse.justMoved)
			{
				for (i in centerContent - 3...centerContent + 4)
				{
					var row:ContentRow = rows.members[i];
					if (row != null && row.visible && FlxG.mouse.overlaps(row) && curSelected != i)
					{
						curSelected = i;
						updateSelection();
						break;
					}
				}
			}
		}

		updateDescriptionScroll(elapsed);
		addonButton.updateButton(elapsed);
		enterButton.updateButton(elapsed, acceptContent);
		backButton.updateButton(elapsed, function() exitToMenu());

		if (quitting)
		{
			super.update(elapsed);
			return;
		}

		if (controls.ACCEPT)
			acceptContent();
		else if (controls.BACK || FlxG.keys.justPressed.TAB)
			exitToMenu();

		super.update(elapsed);
	}

	function changeSelection(change:Int = 0):Void
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, entries.length - 1);
		updateSelection();
	}

	function updateSelection(force:Bool = false):Void
	{
		var entry:ContentEntry = entries[curSelected];
		if (entry == null)
			return;

		centerContent = Std.int(Math.max(3, Math.min(curSelected, rows.length - 1 - 3)));
		var minVisible:Int = Std.int(Math.max(0, centerContent - 3));
		var maxVisible:Int = Std.int(Math.max(6, centerContent + 3));
		var selectedContent:String = Mods.getSelectedContentDirectory();

		for (i => row in rows.members)
		{
			if (row == null)
				continue;
			row.visible = i >= minVisible && i <= maxVisible;
			row.setPosition(listBg.x + 10, listBg.y + 12 + (i - centerContent + 3) * 84);
			row.setSelected(i == curSelected);
			row.setActive(row.entry.folder == selectedContent);
		}

		FlxTween.cancelTweensOf(bg);
		if (!force)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.5);
		FlxTween.color(bg, force ? 0.01 : 0.35, bg.color, entry.color);

		loadBanner(entry);
		loadIcon(entry);
		titleText.text = entry.name;
		titleText.size = titleText.text.length > 26 ? 25 : 32;
		metaText.text = entry.meta;
		updateAddonIndicator(entry);
		descText.text = entry.description;
		descScroll = 0;
		descScrollTarget = 0;
		updateDescriptionScroll(0, true);
	}

	function loadBanner(entry:ContentEntry):Void
	{
		bannerFrame.color = entry.color;

		var bitmap:BitmapData = null;
		if (entry.thumbPath != null && FileSystem.exists(entry.thumbPath))
			bitmap = BitmapData.fromFile(entry.thumbPath);

		if (bitmap == null)
		{
			banner.visible = false;
			banner.clipRect = null;
			return;
		}

		banner.visible = true;
		banner.loadGraphic(Paths.cacheBitmap(entry.thumbPath, bitmap));
		banner.antialiasing = ClientPrefs.data.antialiasing;
		banner.setGraphicSize(BANNER_WIDTH, BANNER_HEIGHT);
		banner.updateHitbox();
		banner.setPosition(bannerFrame.x, bannerFrame.y);
		banner.clipRect = null;
	}

	function loadIcon(entry:ContentEntry):Void
	{
		var bitmap:BitmapData = null;
		if (entry.iconPath != null && FileSystem.exists(entry.iconPath))
			bitmap = BitmapData.fromFile(entry.iconPath);

		if (bitmap != null)
			icon.loadGraphic(Paths.cacheBitmap(entry.iconPath, bitmap), true, 150, 150);
		else
			icon.loadGraphic(Paths.image('unknownMod'), true, 150, 150);

		icon.setGraphicSize(118, 118);
		icon.updateHitbox();
		icon.antialiasing = ClientPrefs.data.antialiasing;
	}

	function acceptContent():Void
	{
		var entry:ContentEntry = entries[curSelected];
		if (entry == null)
			return;

		var changed:Bool = entry.folder != Mods.getSelectedContentDirectory();
		FlxG.sound.play(Paths.sound('confirmMenu'));

		if (changed)
		{
			if (FlxG.sound.music != null)
				FlxG.sound.music.fadeOut(0.3);
			if (FreeplayState.vocals != null)
			{
				FreeplayState.vocals.fadeOut(0.3);
				FreeplayState.vocals = null;
			}

			quitting = true;
			FlxG.camera.fade(FlxColor.BLACK, 0.35, false, function() {
				if (!Mods.selectContent(entry.folder))
				{
					quitting = false;
					FlxG.camera.fade(FlxColor.BLACK, 0.2, true);
					return;
				}

				TitleState.initialized = false;
				TitleState.closedState = false;

				Language.reloadPhrases();
				Difficulty.resetList();

				MusicBeatState.switchState(new TitleState());
			});
		}
		else
			exitToMenu(false);
	}

	function updateDescriptionScroll(elapsed:Float = 0, force:Bool = false):Void
	{
		var maxScroll:Float = Math.max(0, descText.textField.textHeight + 8 - descAreaHeight);
		if (maxScroll <= 0)
		{
			descScroll = 0;
			descScrollTarget = 0;
			draggingDescription = false;
			draggingScrollbar = false;
			scrollTrack.visible = scrollThumb.visible = false;
		}
		else
		{
			if (!force && FlxG.mouse.justPressed)
			{
				if (mouseOverScrollThumb())
					startDescriptionDrag(true);
				else if (mouseOverDescription())
					startDescriptionDrag(false);
			}

			if (!FlxG.mouse.pressed)
			{
				draggingDescription = false;
				draggingScrollbar = false;
			}

			if (draggingScrollbar)
			{
				var scrollableTrack:Float = Math.max(1, scrollTrack.height - scrollThumb.height);
				descScrollTarget = FlxMath.bound(dragStartScroll + ((FlxG.mouse.y - dragMouseY) / scrollableTrack) * maxScroll, 0, maxScroll);
			}
			else if (draggingDescription)
				descScrollTarget = FlxMath.bound(dragStartScroll - (FlxG.mouse.y - dragMouseY), 0, maxScroll);

			if (!force && FlxG.mouse.wheel != 0 && mouseOverDescription())
				descScrollTarget = FlxMath.bound(descScrollTarget - FlxG.mouse.wheel * 38, 0, maxScroll);

			scrollTrack.visible = scrollThumb.visible = true;
			descScrollTarget = FlxMath.bound(descScrollTarget, 0, maxScroll);
			descScroll = force ? descScrollTarget : FlxMath.lerp(descScroll, descScrollTarget, Math.min(1, elapsed * 14));
			if (Math.abs(descScroll - descScrollTarget) < 0.25)
				descScroll = descScrollTarget;
			scrollThumb.y = scrollTrack.y + (scrollTrack.height - scrollThumb.height) * (descScroll / maxScroll);
		}

		descText.y = descBaseY - descScroll;
		descClipRect.set(0, descScroll, descText.width, descAreaHeight);
		descText.clipRect = descClipRect;
	}

	function startDescriptionDrag(scrollbar:Bool):Void
	{
		draggingScrollbar = scrollbar;
		draggingDescription = !scrollbar;
		dragMouseY = FlxG.mouse.y;
		dragStartScroll = descScrollTarget;
	}

	function mouseOverDescription():Bool
	{
		return FlxG.mouse.visible
			&& FlxG.mouse.x >= detailBg.x
			&& FlxG.mouse.x <= detailBg.x + detailBg.width
			&& FlxG.mouse.y >= descBaseY
			&& FlxG.mouse.y <= descBaseY + descAreaHeight;
	}

	function mouseOverScrollThumb():Bool
	{
		return FlxG.mouse.visible && scrollThumb.visible && FlxG.mouse.overlaps(scrollThumb);
	}

	function updateAddonIndicator(entry:ContentEntry):Void
	{
		addonButton.setAvailable(entry.addonsAllowed);
		addonPrefixText.visible = entry.addonsAllowed;
		if (entry.addonsAllowed)
			addonPrefixText.text = ': "' + entry.addonPrefix + '"';
	}

	function exitToMenu(playSound:Bool = true):Void
	{
		if (playSound)
			FlxG.sound.play(Paths.sound('cancelMenu'));
		quitting = true;
		MusicBeatState.switchState(new MainMenuState());
	}
}

class ContentMenuButton extends FlxSprite
{
	var clickable:Bool = false;
	var available:Bool = true;
	var wasHover:Bool = false;
	var idleAlpha:Float = 0.5;
	var baseScaleX:Float = 1;
	var baseScaleY:Float = 1;
	var centerX:Float = 0;
	var centerY:Float = 0;

	public function new(x:Float, y:Float, anim:String, clickable:Bool, size:Int = 48)
	{
		super(x, y);
		this.clickable = clickable;
		idleAlpha = clickable ? 0.42 : 1;

		frames = Paths.getSparrowAtlas('content_buttons');
		animation.addByPrefix('button', anim, 24, true);
		animation.play('button');
		antialiasing = ClientPrefs.data.antialiasing;
		setGraphicSize(size);
		updateHitbox();
		origin.set(frameWidth * 0.5, frameHeight * 0.5);
		baseScaleX = scale.x;
		baseScaleY = scale.y;
		centerX = x + width * 0.5;
		centerY = y + height * 0.5;
		alpha = idleAlpha;
	}

	public function setAvailable(value:Bool):Void
	{
		available = value;
		if (!available)
			wasHover = false;
		alpha = available ? idleAlpha : 0.12;
	}

	public function updateButton(elapsed:Float, ?onClick:Void->Void):Void
	{
		var hover:Bool = available && clickable && onClick != null && FlxG.mouse.visible && FlxG.mouse.overlaps(this);
		if (hover && !wasHover)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.45);

		var ease:Float = Math.min(1, elapsed * 12);
		var targetAlpha:Float = available ? (hover ? 1 : idleAlpha) : 0.12;
		var targetScale:Float = hover ? 1.2 : 1;
		alpha = FlxMath.lerp(alpha, targetAlpha, ease);
		scale.set(FlxMath.lerp(scale.x, baseScaleX * targetScale, ease), FlxMath.lerp(scale.y, baseScaleY * targetScale, ease));
		updateHitbox();
		setPosition(centerX - width * 0.5, centerY - height * 0.5);

		if (hover && FlxG.mouse.justPressed)
			onClick();
		wasHover = hover;
	}
}

class ContentEntry
{
	public var folder:String = '';
	public var name:String = 'Base Game';
	public var description:String = 'Bundled game assets with the regular enabled addons.';
	public var version:String = '';
	public var author:String = '';
	public var iconPath:String = null;
	public var thumbPath:String = null;
	public var color:FlxColor = 0xFF2D7D73;
	public var meta:String = 'Default content';
	public var addonsAllowed:Bool = true;
	public var addonPrefix:String = '';

	public function new(folder:String)
	{
		this.folder = folder;
		var data:Dynamic = Mods.getContentData(folder);
		name = folder;
		description = 'No description provided.';

		if (data != null)
		{
			if (data.name != null) name = Std.string(data.name);
			if (data.description != null) description = Std.string(data.description);
			if (data.version != null) version = Std.string(data.version);
			if (data.author != null) author = Std.string(data.author);
			if (data.icon != null)
			{
				var customIcon:String = Paths.contents('$folder/${Std.string(data.icon)}');
				if (FileSystem.exists(customIcon))
					iconPath = customIcon;
			}
			if (data.thumb != null)
			{
				var customThumb:String = Paths.contents('$folder/${Std.string(data.thumb)}');
				if (FileSystem.exists(customThumb))
					thumbPath = customThumb;
			}
		}

		if (thumbPath == null)
		{
			var thumbFile:String = Paths.contents('$folder/thumb.png');
			var thumbPixelFile:String = Paths.contents('$folder/thumb-pixel.png');
			if (FileSystem.exists(thumbFile))
				thumbPath = thumbFile;
			else if (FileSystem.exists(thumbPixelFile))
				thumbPath = thumbPixelFile;
		}

		if (iconPath == null)
		{
			var iconFile:String = Paths.contents('$folder/icon.png');
			var iconPixelFile:String = Paths.contents('$folder/icon-pixel.png');
			var packIcon:String = Paths.contents('$folder/pack.png');
			if (FileSystem.exists(iconFile))
				iconPath = iconFile;
			else if (FileSystem.exists(iconPixelFile))
				iconPath = iconPixelFile;
			else if (FileSystem.exists(packIcon))
				iconPath = packIcon;
		}

		var metaParts:Array<String> = [];
		if (version.length > 0) metaParts.push('v$version');
		if (author.length > 0) metaParts.push('by $author');
		meta = metaParts.length > 0 ? metaParts.join('  |  ') : folder;

		readAddonsData(data);

		color = colorFromName(name);
	}

	public static function baseGame():ContentEntry
	{
		var entry:ContentEntry = Type.createEmptyInstance(ContentEntry);
		entry.folder = '';
		entry.name = 'Base Game';
		entry.description = 'Bundled game assets with the regular enabled addons.';
		entry.version = '';
		entry.author = '';
		entry.iconPath = null;
		entry.thumbPath = null;
		entry.color = 0xFF2D7D73;
		entry.meta = 'Default content';
		entry.addonsAllowed = true;
		entry.addonPrefix = '';
		return entry;
	}

	function readAddonsData(data:Dynamic):Void
	{
		addonsAllowed = data != null && data.addons != null && data.addons.allowAddons == true;
		addonPrefix = '';

		if (addonsAllowed && data.addons.addonPrefix != null)
			addonPrefix = Std.string(data.addons.addonPrefix).trim();
	}

	function colorFromName(value:String):FlxColor
	{
		var hash:Int = 0;
		for (i in 0...value.length)
		{
			var code:Null<Int> = value.charCodeAt(i);
			hash = (hash * 31 + (code ?? 0)) % 0xFFFFFF;
		}
		var r:Int = 60 + (hash % 0x5F);
		var g:Int = 70 + (Std.int(hash / 0x100) % 0x5F);
		var b:Int = 85 + (Std.int(hash / 0x10000) % 0x5F);
		return FlxColor.fromRGB(r, g, b);
	}
}

class ContentRow extends FlxSpriteGroup
{
	public var entry:ContentEntry;
	var bg:FlxSprite;
	var activeMark:FlxText;
	var title:FlxText;
	var meta:FlxText;
	var rowIcon:FlxSprite;

	public function new(entry:ContentEntry)
	{
		super();
		this.entry = entry;

		bg = FlxSpriteUtil.drawRoundRect(new FlxSprite().makeGraphic(340, 72, FlxColor.TRANSPARENT), 0, 0, 340, 72, 10, 10, FlxColor.WHITE);
		bg.alpha = 0.16;
		add(bg);

		activeMark = new FlxText(10, 10, 28, '', 18);
		activeMark.setFormat(Paths.font('vcr.ttf'), 18, 0xFF9CFFE9, CENTER);
		add(activeMark);

		title = new FlxText(42, 10, 212, entry.name, 20);
		title.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.borderSize = 0.7;
		add(title);

		meta = new FlxText(42, 42, 212, entry.folder.length > 0 ? entry.folder : 'base game', 13);
		meta.setFormat(Paths.font('vcr.ttf'), 13, 0xFFD8D8D8, LEFT);
		add(meta);

		rowIcon = new FlxSprite(266, 4);
		var bitmap:BitmapData = null;
		if (entry.iconPath != null && FileSystem.exists(entry.iconPath))
			bitmap = BitmapData.fromFile(entry.iconPath);
		if (bitmap != null)
			rowIcon.loadGraphic(Paths.cacheBitmap(entry.iconPath, bitmap), true, 150, 150);
		else
			rowIcon.loadGraphic(Paths.image('unknownMod'), true, 150, 150);
		rowIcon.setGraphicSize(64, 64);
		rowIcon.updateHitbox();
		rowIcon.antialiasing = ClientPrefs.data.antialiasing;
		add(rowIcon);
	}

	public function setSelected(value:Bool):Void
	{
		bg.alpha = value ? 0.82 : 0.16;
		bg.color = value ? FlxColor.WHITE : FlxColor.BLACK;
		title.color = value ? FlxColor.BLACK : FlxColor.WHITE;
		meta.color = value ? 0xFF222222 : 0xFFD8D8D8;
		rowIcon.alpha = value ? 1 : 0.82;
	}

	public function setActive(value:Bool):Void
	{
		activeMark.text = value ? '>' : '';
	}
}
