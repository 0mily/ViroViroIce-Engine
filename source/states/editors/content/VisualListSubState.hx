package states.editors.content;

import backend.lists.ListLoader.ListCategoryData;
import backend.lists.ListLoader.ListKind;
import flixel.util.FlxGradient;
import objects.Character as GameCharacter;
import objects.HealthIcon;
import openfl.filters.BitmapFilter;
import openfl.filters.BitmapFilterQuality;
import openfl.filters.BlurFilter;
import openfl.utils.AssetType;

class VisualListSubState extends MusicBeatSubstate
{
	public static inline final SIDE_MARGIN:Float = 42;
	public static inline final ITEM_WIDTH:Float = 112;
	public static inline final ITEM_HEIGHT:Float = 108;
	public static inline final CELL_WIDTH:Float = 122;
	public static inline final CELL_HEIGHT:Float = 118;
	public static inline final ICON_BOX:Float = 74;
	public static inline final SCROLL_STEP:Float = 72;
	public static inline final BLUR_STRENGTH:Float = 7; // NEVER believing on Clip Studio EVER again.
	public static inline final OPEN_DURATION:Float = 0.2;
	public static inline final CLOSE_DURATION:Float = 0.16;

	var kind:ListKind;
	var categories:Array<ListCategoryData>;
	var selectedValue:String;
	var onSelected:String->Void;
	var useBlur:Bool;
	var displayNames:Map<String, String>;

	var pickerCamera:FlxCamera;
	var oldCameraFilters:Array<CameraFilterState> = [];
	var scrollEntries:Array<VisualScrollEntry> = [];
	var items:Array<VisualListItem> = [];
	var scroll:Float = 0;
	var targetScroll:Float = 0;
	var maxScroll:Float = 0;
	var transitionAmount:Float = 0;
	var transitionTween:FlxTween;
	var closing:Bool = false;
	var finishedClosing:Bool = false;
	var viewportTop:Float = 58;
	var viewportBottom:Float = 0;
	var inputDelay:Float = 0.12;

	var scrollTrack:FlxSprite;
	var scrollThumb:FlxSprite;
	var draggingScroll:Bool = false;
	var scrollDragOffset:Float = 0;

	public function new(kind:ListKind, categories:Array<ListCategoryData>, selectedValue:String, onSelected:String->Void, useBlur:Bool = true,
		?displayNames:Map<String, String>)
	{
		this.kind = kind;
		this.categories = categories ?? [];
		this.selectedValue = selectedValue ?? '';
		this.onSelected = onSelected;
		this.useBlur = useBlur;
		this.displayNames = displayNames;
		super();
	}

	override function create():Void
	{
		var camerasBehind:Array<FlxCamera> = FlxG.cameras.list.copy();
		if(useBlur)
		{
			for(camera in camerasBehind)
			{
				if(camera == null)
					continue;
				var previous:Array<BitmapFilter> = camera.filters != null ? camera.filters.copy() : [];
				var blur:BlurFilter = new BlurFilter(0, 0, BitmapFilterQuality.MEDIUM);
				var blurred:Array<BitmapFilter> = previous.copy();
				blurred.push(blur);
				camera.filters = blurred;
				oldCameraFilters.push({camera: camera, filters: previous, blur: blur});
			}
		}

		pickerCamera = new FlxCamera(0, 0, FlxG.width, FlxG.height, 1);
		pickerCamera.bgColor.alpha = 0;
		pickerCamera.alpha = 0;
		FlxG.cameras.add(pickerCamera, false);
		cameras = [pickerCamera];

		viewportBottom = FlxG.height - 24;

		var shade:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF020807);
		shade.alpha = 0.76;
		shade.scrollFactor.set();
		shade.cameras = cameras;
		add(shade);

		var header:FlxText = makePixelText(SIDE_MARGIN, 13, FlxG.width - SIDE_MARGIN * 2, 'Select ${kind}', 18, LEFT);
		header.alpha = 0.72;
		add(header);

		buildCategories();
		buildScrollBar();
		positionScrolledContent();
		super.create();
		startTransition(0, 1, OPEN_DURATION, FlxEase.quadOut);
	}

	function buildCategories():Void
	{
		var contentLeft:Float = SIDE_MARGIN;
		var contentRight:Float = FlxG.width - SIDE_MARGIN - 22;
		var contentWidth:Float = contentRight - contentLeft;
		var columns:Int = Std.int(Math.max(1, Math.floor(contentWidth / CELL_WIDTH)));
		var gridWidth:Float = columns * CELL_WIDTH;
		var gridLeft:Float = contentLeft + Math.max(0, (contentWidth - gridWidth) * 0.5);
		var y:Float = viewportTop + 8;

		if(categories.length < 1)
		{
			var emptyText:FlxText = makePixelText(contentLeft, y + 40, contentWidth, 'No items found.', 20, CENTER);
			add(emptyText);
			scrollEntries.push({member: emptyText, baseY: emptyText.y, height: emptyText.height});
			y += 100;
		}

		for(groupIndex => group in categories)
		{
			if(group == null || group.names == null || group.names.length < 1)
				continue;

			var categoryTitle:FlxText = makePixelText(contentLeft + 7, y, contentWidth - 14, group.category, 25, LEFT);
			categoryTitle.borderStyle = OUTLINE_FAST;
			categoryTitle.borderSize = 1;
			categoryTitle.borderColor = FlxColor.BLACK;
			add(categoryTitle);
			scrollEntries.push({member: categoryTitle, baseY: y, height: 34});
			y += 39;

			for(index => value in group.names)
			{
				var column:Int = index % columns;
				var row:Int = Std.int(index / columns);
				var itemX:Float = gridLeft + column * CELL_WIDTH + (CELL_WIDTH - ITEM_WIDTH) * 0.5;
				var itemY:Float = y + row * CELL_HEIGHT;
				var displayName:String = displayNames != null ? displayNames.get(value) : null;
				var item:VisualListItem = new VisualListItem(itemX, itemY, kind, value, chooseValue, displayName);
				item.cameras = cameras;
				item.clickEnabled = false;
				add(item);
				items.push(item);
				scrollEntries.push({member: item, baseY: itemY, height: ITEM_HEIGHT});
			}

			var rows:Int = Std.int(Math.ceil(group.names.length / columns));
			y += rows * CELL_HEIGHT + 8;

			if(groupIndex < categories.length - 1)
			{
				var separator:FlxSprite = FlxGradient.createGradientFlxSprite(Std.int(contentWidth), 3,
					[0x00FFFFFF, 0x88FFFFFF, 0x00FFFFFF], 1, 180, true);
				separator.setPosition(contentLeft, y);
				separator.cameras = cameras;
				add(separator);
				scrollEntries.push({member: separator, baseY: y, height: 3});
				y += 24;
			}
		}

		maxScroll = Math.max(0, y - viewportBottom + 10);
	}

	function buildScrollBar():Void
	{
		var trackHeight:Float = viewportBottom - viewportTop;
		scrollTrack = new FlxSprite(FlxG.width - 16, viewportTop).makeGraphic(5, Std.int(trackHeight), FlxColor.WHITE);
		scrollTrack.alpha = maxScroll > 0 ? 0.16 : 0;
		scrollTrack.cameras = cameras;
		add(scrollTrack);

		var visibleRatio:Float = maxScroll > 0 ? trackHeight / (trackHeight + maxScroll) : 1;
		var thumbHeight:Int = Std.int(Math.max(38, trackHeight * visibleRatio));
		scrollThumb = new FlxSprite(FlxG.width - 19, viewportTop).makeGraphic(11, thumbHeight, FlxColor.WHITE);
		scrollThumb.alpha = maxScroll > 0 ? 0.62 : 0;
		scrollThumb.cameras = cameras;
		add(scrollThumb);
	}

	override function update(elapsed:Float):Void
	{
		inputDelay = Math.max(0, inputDelay - elapsed);
		for(item in items)
			if(item != null)
				item.clickEnabled = inputDelay <= 0;

		if(maxScroll > 0)
		{
			if(FlxG.mouse.wheel != 0)
				targetScroll -= FlxG.mouse.wheel * SCROLL_STEP;
			targetScroll = FlxMath.bound(targetScroll, 0, maxScroll);

			var mouse = FlxG.mouse.getScreenPosition(pickerCamera);
			if(inputDelay <= 0 && FlxG.mouse.justPressed && FlxG.mouse.overlaps(scrollThumb, pickerCamera))
			{
				draggingScroll = true;
				scrollDragOffset = mouse.y - scrollThumb.y;
			}
			if(draggingScroll && FlxG.mouse.pressed)
			{
				var travel:Float = Math.max(1, scrollTrack.height - scrollThumb.height);
				var thumbY:Float = FlxMath.bound(mouse.y - scrollDragOffset, scrollTrack.y, scrollTrack.y + travel);
				targetScroll = scroll = (thumbY - scrollTrack.y) / travel * maxScroll;
			}
			if(FlxG.mouse.justReleased)
				draggingScroll = false;
			mouse.put();
		}

		if(!draggingScroll)
		{
			var smoothing:Float = 1 - Math.pow(0.0001, elapsed);
			scroll = FlxMath.lerp(scroll, targetScroll, smoothing);
			if(Math.abs(scroll - targetScroll) < 0.1)
				scroll = targetScroll;
		}
		positionScrolledContent();

		super.update(elapsed);

		if(inputDelay <= 0)
		{
			if(FlxG.keys.justPressed.ESCAPE || FlxG.keys.justPressed.BACKSPACE || FlxG.mouse.justPressedRight)
			{
				close();
				return;
			}
		}
	}

	function positionScrolledContent():Void
	{
		for(entry in scrollEntries)
		{
			if(entry == null || entry.member == null)
				continue;
			var member:FlxObject = entry.member;
			member.y = entry.baseY - scroll;
			var visible:Bool = member.y + entry.height >= viewportTop && member.y <= viewportBottom;
			member.visible = visible;
			member.active = visible;
		}

		if(scrollThumb != null && maxScroll > 0)
		{
			var travel:Float = Math.max(1, scrollTrack.height - scrollThumb.height);
			scrollThumb.y = scrollTrack.y + (scroll / maxScroll) * travel;
		}
	}

	function chooseValue(value:String):Void
	{
		if(inputDelay > 0)
			return;
		var callback = onSelected;
		onSelected = null;
		if(callback != null)
			callback(value);
		close();
	}

	function startTransition(from:Float, to:Float, duration:Float, ease:Float->Float, ?onComplete:Void->Void):Void
	{
		if(transitionTween != null)
		{
			transitionTween.cancel();
			transitionTween.destroy();
			transitionTween = null;
		}

		applyTransition(from);
		transitionTween = FlxTween.num(from, to, duration, {
			ease: ease,
			onComplete: function(_)
			{
				transitionTween = null;
				applyTransition(to);
				if(onComplete != null)
					onComplete();
			}
		}, applyTransition);
	}

	function applyTransition(value:Float):Void
	{
		transitionAmount = FlxMath.bound(value, 0, 1);
		if(pickerCamera != null)
			pickerCamera.alpha = transitionAmount;

		if(useBlur)
		{
			for(entry in oldCameraFilters)
			{
				if(entry == null || entry.camera == null || entry.blur == null)
					continue;
				entry.blur.blurX = BLUR_STRENGTH * transitionAmount;
				entry.blur.blurY = BLUR_STRENGTH * transitionAmount;
				var filters:Array<BitmapFilter> = entry.filters.copy();
				filters.push(entry.blur);
				entry.camera.filters = filters;
			}
		}
	}

	function restoreCameraFilters():Void
	{
		for(entry in oldCameraFilters)
			if(entry != null && entry.camera != null)
				entry.camera.filters = entry.filters;
	}

	override function close():Void
	{
		if(closing || finishedClosing)
			return;

		closing = true;
		inputDelay = 999;
		startTransition(transitionAmount, 0, CLOSE_DURATION, FlxEase.quadIn, function()
			finishClose());
	}

	function finishClose():Void
	{
		if(finishedClosing)
			return;
		finishedClosing = true;
		restoreCameraFilters();
		super.close();
	}

	function makePixelText(x:Float, y:Float, width:Float, text:String, size:Int, align:FlxTextAlign):FlxText
	{
		var label:FlxText = new FlxText(x, y, width, text, size);
		label.setFormat(Paths.font('pixel-latin.ttf'), size, FlxColor.WHITE, align);
		label.pixelText = true;
		label.antialiasing = false;
		label.scrollFactor.set();
		label.cameras = cameras;
		return label;
	}

	override function destroy():Void
	{
		if(transitionTween != null)
		{
			transitionTween.cancel();
			transitionTween.destroy();
			transitionTween = null;
		}
		restoreCameraFilters();
		oldCameraFilters = [];

		var cameraToRemove:FlxCamera = pickerCamera;
		pickerCamera = null;
		onSelected = null;
		items = null;
		scrollEntries = null;
		super.destroy();
		if(cameraToRemove != null)
			FlxG.cameras.remove(cameraToRemove, true);
	}
}

private class VisualListItem extends FlxSpriteGroup
{
	public var clickEnabled:Bool = false;

	var kind:ListKind;
	var value:String;
	var callback:String->Void;
	var panel:FlxSprite;
	var icon:FlxSprite;
	var label:FlxText;
	var baseScaleX:Float = 1;
	var baseScaleY:Float = 1;
	var hoverAmount:Float = 0;

	public function new(x:Float, y:Float, kind:ListKind, value:String, callback:String->Void, ?requestedDisplayName:String)
	{
		super(x, y);
		this.kind = kind;
		this.value = value ?? '';
		this.callback = callback;

		panel = new FlxSprite().makeGraphic(Std.int(VisualListSubState.ITEM_WIDTH), Std.int(VisualListSubState.ITEM_HEIGHT), FlxColor.WHITE);
		panel.color = FlxColor.BLACK;
		panel.alpha = 0.001;
		add(panel);

		var hasRequestedDisplayName:Bool = requestedDisplayName != null && requestedDisplayName.trim().length > 0;
		var displayName:String = hasRequestedDisplayName ? requestedDisplayName.trim() : this.value;
		icon = createIcon(kind, this.value, function(name:String)
		{
			if(!hasRequestedDisplayName)
				displayName = name;
		});
		if(Std.isOfType(icon, HealthIcon))
			(cast icon:HealthIcon).autoAdjustOffset = false;
		fitIcon(icon, VisualListSubState.ICON_BOX, VisualListSubState.ICON_BOX);
		centerIcon(icon, VisualListSubState.ITEM_WIDTH * 0.5, 5 + VisualListSubState.ICON_BOX * 0.5);
		icon.color = 0xFF686868;
		icon.active = false;
		baseScaleX = icon.scale.x;
		baseScaleY = icon.scale.y;
		add(icon);

		if(displayName == null || displayName.trim().length < 1)
			displayName = switch(kind) {
				case EVENT: 'No Event';
				case CHARACTER: 'Default';
				default: 'None';
			};

		label = new FlxText(4, 82, VisualListSubState.ITEM_WIDTH - 8, displayName, 11);
		label.setFormat(Paths.font('pixel-latin.ttf'), 11, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		label.borderSize = 1;
		label.pixelText = true;
		label.antialiasing = false;
		label.wordWrap = true;
		add(label);
	}

	override function update(elapsed:Float):Void
	{
		if(!exists || panel == null)
			return;
		super.update(elapsed);

		var inputCamera:FlxCamera = cameras != null && cameras.length > 0 ? cameras[0] : FlxG.camera;
		var hovering:Bool = visible && FlxG.mouse.overlaps(panel, inputCamera);
		var target:Float = hovering ? 1 : 0;
		hoverAmount = FlxMath.lerp(hoverAmount, target, 1 - Math.pow(0.00001, elapsed));
		if(Math.abs(hoverAmount - target) < 0.01)
			hoverAmount = target;

		var scaleFactor:Float = FlxMath.lerp(0.88, 1.05, hoverAmount);
		icon.scale.set(baseScaleX * scaleFactor, baseScaleY * scaleFactor);
		icon.color = FlxColor.interpolate(0xFF686868, FlxColor.WHITE, hoverAmount);
		panel.alpha = 0.001;

		if(clickEnabled && hovering && FlxG.mouse.justPressed && callback != null)
			callback(value);
	}

	static function createIcon(kind:ListKind, value:String, setDisplayName:String->Void):FlxSprite
	{
		var imageKey:String = null;
		var fallbackKey:String = null;
		switch(kind)
		{
			case CHARACTER:
				var data = value.length > 0 ? GameCharacter.getEditorIconData(value) : null;
				if(data != null)
					setDisplayName(data.displayName);

				imageKey = findImageKey([
					'editors/lists/characters/$value',
					'editors/lists/characters/$value/icon'
				]);
				if(imageKey != null)
					return loadImageSprite(imageKey);

				var healthIcon:String = getCharacterHealthIcon(value);
				if(healthIcon.length > 0 && hasHealthIcon(healthIcon)) //made this shit just to don't be so ugly xd
					return new HealthIcon(healthIcon, false, false);
				fallbackKey = 'editors/lists/default-characters';
			case EVENT:
				imageKey = findImageKey(['editors/lists/events/$value']);
				fallbackKey = 'editors/lists/default-events';
			case STAGE:
				imageKey = findImageKey(['editors/lists/stages/$value']);
				fallbackKey = 'editors/lists/default-stages';
			case LEVEL:
				imageKey = findImageKey(['editors/lists/levels/$value']);
				fallbackKey = 'editors/lists/default-levels';
		}

		if(imageKey == null)
			imageKey = fallbackKey;
		return loadImageSprite(imageKey);
	}

	static function findImageKey(candidates:Array<String>):String
	{
		if(candidates == null)
			return null;
		for(candidate in candidates)
			if(candidate != null && !candidate.endsWith('/') && Paths.fileExists('images/$candidate.png', AssetType.IMAGE))
				return candidate;
		return null;
	}

	static function loadImageSprite(imageKey:String):FlxSprite
	{
		var sprite:FlxSprite = new FlxSprite();
		var graphic = imageKey != null && Paths.fileExists('images/$imageKey.png', AssetType.IMAGE)
			? Paths.image(imageKey, null, false) : null;
		if(graphic != null)
			sprite.loadGraphic(graphic);
		else
			sprite.makeGraphic(64, 64, HaxeUITheme.PURPLE_DARK);
		return sprite;
	}

	static function getCharacterHealthIcon(character:String):String
	{
		if(character == null || character.trim().length < 1)
			return '';
		try
		{
			var path:String = GameCharacter.getCharacterPath(character);
			var data:Dynamic = path != null ? GameCharacter.getCharacterData(path) : null;
			var icon:Dynamic = data != null ? Reflect.field(data, 'healthicon') : null;
			if(icon != null && Std.string(icon).trim().length > 0)
				return Std.string(icon).trim();
		}
		catch(e:Dynamic) {}
		return character.trim();
	}

	static function hasHealthIcon(character:String):Bool
	{
		return findImageKey([
			'game/icons/$character/icon',
			'game/icons/$character',
			'game/icons/icon-$character'
		]) != null;
	}

	static function fitIcon(sprite:FlxSprite, maxWidth:Float, maxHeight:Float):Void
	{
		if(sprite == null)
			return;
		var displayWidth:Float = sprite.width;
		var displayHeight:Float = sprite.height;
		if(Std.isOfType(sprite, HealthIcon))
		{
			var healthIcon:HealthIcon = cast sprite;
			displayWidth = healthIcon.getIconDisplayWidth();
			displayHeight = healthIcon.getIconDisplayHeight();
		}
		if(displayWidth <= 0 || displayHeight <= 0)
			return;
		var ratio:Float = Math.min(maxWidth / displayWidth, maxHeight / displayHeight);
		if(!Math.isFinite(ratio) || ratio <= 0)
			return;
		sprite.scale.set(sprite.scale.x * ratio, sprite.scale.y * ratio);
		sprite.updateHitbox();
	}

	static function centerIcon(sprite:FlxSprite, x:Float, y:Float):Void
	{
		if(Std.isOfType(sprite, HealthIcon))
		{
			var healthIcon:HealthIcon = cast sprite;
			healthIcon.centerIconOn(x, y);
		}
		else
			sprite.setPosition(x - sprite.width * 0.5, y - sprite.height * 0.5);
	}

	override function destroy():Void
	{
		callback = null;
		panel = null;
		icon = null;
		label = null;
		super.destroy();
	}
}

private typedef VisualScrollEntry =
{
	var member:FlxObject;
	var baseY:Float;
	var height:Float;
}

private typedef CameraFilterState =
{
	var camera:FlxCamera;
	var filters:Array<BitmapFilter>;
	var blur:BlurFilter;
}
