package states.editors;

import flixel.graphics.FlxGraphic;
import flixel.addons.display.shapes.FlxShapeCircle;
import flixel.math.FlxRect;
import flixel.util.FlxGradient;
import flixel.util.FlxDestroyUtil;

import openfl.net.FileReference;
import openfl.events.Event;
import openfl.events.IOErrorEvent;

import objects.Character;
import objects.HealthIcon;
import objects.Bar;

import states.editors.content.Prompt;

@:bitmap("assets/images/debugger/cursorCross.png")
class GraphicCursorCross extends openfl.display.BitmapData {}

class CharacterEditorState extends ScriptedState implements PsychUIEventHandler.PsychUIEvent
{
	static inline final HEALTH_ICON_PREVIEW_SIZE:Float = 118;
	static inline final HEALTH_ICON_PREVIEW_BUMP:Float = 12;
	static inline final ASSET_PATH_VISIBLE_ROWS:Int = 3;
	static inline final ASSET_PATH_ROW_GAP:Float = 46;
	static inline final ASSET_PATH_START_Y:Float = 30;
	static inline final ASSET_PATH_VIEW_X:Float = 10;
	static inline final ASSET_PATH_VIEW_Y:Float = 12;
	static inline final ASSET_PATH_VIEW_W:Int = 330;
	static inline final ASSET_PATH_VIEW_H:Int = 150;

	var character:Character;
	var ghost:FlxSprite;
	var animateGhost:FlxAnimate;
	var animateGhostImage:String;
	var cameraFollowPointer:FlxSprite;
	var isAnimateSprite:Bool = false;

	var silhouettes:FlxSpriteGroup;
	var dadPosition = FlxPoint.weak();
	var bfPosition = FlxPoint.weak();

	var helpBg:FlxSprite;
	var helpTexts:FlxSpriteGroup;
	var cameraZoomText:FlxText;
	var frameAdvanceText:FlxText;

	var healthBar:Bar;
	var healthIcon:HealthIcon;
	var healthIconPanel:FlxSprite;
	var healthColorPreview:FlxSprite;
	var healthIconPreviewFrame:Int = 0;
	var healthIconPreviewBump:Float = 0;

	var offsetWindowBg:FlxSprite;
	var offsetOpponentButton:PsychUIButton;
	var offsetPlayerButton:PsychUIButton;
	var draggingOffsetWindow:Bool = false;
	var offsetWindowDragPoint:FlxPoint;
	var offsetWindowStart:FlxPoint;
	var offsetTextClipRect:FlxRect;
	var offsetTextScroll:Float = 0;
	var offsetTextViewHeight:Float = 176;
	var offsetScrollTrack:FlxSprite;
	var offsetScrollThumb:FlxSprite;

	var healthIconLabel:FlxText;
	var draggingHealthIconPanel:Bool = false;
	var healthIconPanelDragPoint:FlxPoint;
	var healthIconPanelStart:FlxPoint;

	var copiedOffset:Array<Float> = [0, 0];
	var _char:String = null;
	var _goToPlayState:Bool = true;

	var anims = null;
	var animsTxt:FlxText;
	var curAnim = 0;

	private var camEditor:FlxCamera;
	private var camHUD:FlxCamera;

	var UI_box:PsychUIBox;
	var UI_characterbox:PsychUIBox;

	var unsavedProgress:Bool = false;

	var selectedFormat:FlxTextFormat = new FlxTextFormat(FlxColor.LIME);

	public function new(char:String = null, goToPlayState:Bool = true)
	{
		this._char = char;
		this._goToPlayState = goToPlayState;
		if (PlayState.SONG == null) goToPlayState = false;
		if (this._char == null) this._char = Character.DEFAULT_CHARACTER;

		super();
	}

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		FlxG.sound.music.stop();
		camEditor = initPsychCamera();

		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);

		loadBG();
		
		preCreate();

		silhouettes = new FlxSpriteGroup();
		add(silhouettes);

		var dad:FlxSprite = new FlxSprite(dadPosition.x, dadPosition.y).loadGraphic(Paths.image('editors/silhouetteDad'));
		dad.antialiasing = ClientPrefs.data.antialiasing;
		dad.active = false;
		dad.offset.set(-4, 1);
		silhouettes.add(dad);

		var boyfriend:FlxSprite = new FlxSprite(bfPosition.x, bfPosition.y + 350).loadGraphic(Paths.image('editors/silhouetteBF'));
		boyfriend.antialiasing = ClientPrefs.data.antialiasing;
		boyfriend.active = false;
		boyfriend.offset.set(-6, 2);
		silhouettes.add(boyfriend);

		silhouettes.alpha = 0.25;

		ghost = new FlxSprite();
		ghost.visible = false;
		ghost.alpha = ghostAlpha;
		add(ghost);
		
		animsTxt = new FlxText(10, 32, 400, '');
		animsTxt.setFormat(null, 16, FlxColor.WHITE, LEFT, OUTLINE_FAST, FlxColor.BLACK);
		animsTxt.scrollFactor.set();
		animsTxt.borderSize = 1;
		animsTxt.cameras = [camHUD];

		addCharacter();

		cameraFollowPointer = new FlxSprite().loadGraphic(FlxGraphic.fromClass(GraphicCursorCross));
		cameraFollowPointer.setGraphicSize(40, 40);
		cameraFollowPointer.updateHitbox();

		healthBar = new Bar(30, FlxG.height - 75);
		healthBar.scrollFactor.set();
		healthBar.cameras = [camHUD];
		healthBar.visible = false;

		healthIcon = new HealthIcon(character.healthIcon, false, false);
		healthIcon.cameras = [camHUD];

		add(cameraFollowPointer);
		addOffsetWindow();
		addHealthIconPanel();

		var tipText:FlxText = new FlxText(FlxG.width - 300, FlxG.height - 24, 300, "Press F1 for Help", 20);
		tipText.cameras = [camHUD];
		tipText.setFormat(null, 16, FlxColor.WHITE, RIGHT, OUTLINE_FAST, FlxColor.BLACK);
		tipText.borderColor = FlxColor.BLACK;
		tipText.scrollFactor.set();
		tipText.borderSize = 1;
		tipText.active = false;
		add(tipText);

		cameraZoomText = new FlxText(0, 50, 200, 'Zoom: 1x');
		cameraZoomText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		cameraZoomText.scrollFactor.set();
		cameraZoomText.borderSize = 1;
		cameraZoomText.screenCenter(X);
		cameraZoomText.cameras = [camHUD];
		add(cameraZoomText);

		frameAdvanceText = new FlxText(0, 75, 350, '');
		frameAdvanceText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
		frameAdvanceText.scrollFactor.set();
		frameAdvanceText.borderSize = 1;
		frameAdvanceText.screenCenter(X);
		frameAdvanceText.cameras = [camHUD];
		add(frameAdvanceText);

		addHelpScreen();
		FlxG.mouse.visible = true;
		FlxG.camera.zoom = 1;

		makeUIMenu();

		updatePointerPos();
		updateHealthBar();
		character.finishAnimation();

		if(ClientPrefs.data.cacheOnGPU) Paths.clearUnusedMemory();

		super.create();
	}

	function addHelpScreen()
	{
		var str:Array<String> = ["CAMERA",
		"E/Q - Camera Zoom In/Out",
		"J/K/L/I - Move Camera",
		"R - Reset Camera Zoom",
		"",
		"CHARACTER",
		"Ctrl + R - Reset Current Offset",
		"Ctrl + C - Copy Current Offset",
		"Ctrl + V - Paste Copied Offset on Current Animation",
		"Ctrl + Z - Undo Last Paste or Reset",
		"W/S - Previous/Next Animation",
		"Space - Replay Animation",
		"Arrow Keys/Mouse & Right Click - Move Offset",
		"A/D - Frame Advance (Back/Forward)",
		"",
		"OTHER",
		"F12 - Toggle Silhouettes",
		"Hold Shift - Move Offsets 10x faster and Camera 4x faster",
		"Hold Control - Move camera 4x slower"];

		helpBg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		helpBg.scale.set(FlxG.width, FlxG.height);
		helpBg.updateHitbox();
		helpBg.alpha = 0.6;
		helpBg.cameras = [camHUD];
		helpBg.active = helpBg.visible = false;
		add(helpBg);

		helpTexts = new FlxSpriteGroup();
		helpTexts.cameras = [camHUD];
		for (i => txt in str)
		{
			if(txt.length < 1) continue;

			var helpText:FlxText = new FlxText(0, 0, 600, txt, 16);
			helpText.setFormat(null, 16, FlxColor.WHITE, CENTER, OUTLINE_FAST, FlxColor.BLACK);
			helpText.borderColor = FlxColor.BLACK;
			helpText.scrollFactor.set();
			helpText.borderSize = 1;
			helpText.screenCenter();
			add(helpText);
			helpText.y += ((i - str.length/2) * 32) + 16;
			helpText.active = false;
			helpTexts.add(helpText);
		}
		helpTexts.active = helpTexts.visible = false;
		add(helpTexts);
	}

	function addOffsetWindow():Void
	{
		offsetWindowBg = new FlxSprite(10, 36);
		HaxeUITheme.drawRoundedBox(offsetWindowBg, 250, 238, HaxeUITheme.BG, 0.92);
		offsetWindowBg.scrollFactor.set();
		offsetWindowBg.cameras = [camHUD];
		add(offsetWindowBg);

		offsetOpponentButton = new PsychUIButton(offsetWindowBg.x + 2, offsetWindowBg.y + 2, 'Opponent', function() setOffsetWindowMode(false), 122, 18);
		offsetPlayerButton = new PsychUIButton(offsetWindowBg.x + 126, offsetWindowBg.y + 2, 'Playable', function() setOffsetWindowMode(true), 122, 18);
		for (button in [offsetOpponentButton, offsetPlayerButton])
		{
			button.scrollFactor.set();
			button.cameras = [camHUD];
			add(button);
		}

		offsetScrollTrack = new FlxSprite(offsetWindowBg.x + offsetWindowBg.width - 10, offsetWindowBg.y + 56).makeGraphic(3, Std.int(offsetTextViewHeight), 0x66FFFFFF);
		offsetScrollTrack.scrollFactor.set();
		offsetScrollTrack.cameras = [camHUD];
		add(offsetScrollTrack);

		offsetScrollThumb = new FlxSprite(offsetScrollTrack.x - 1, offsetScrollTrack.y).makeGraphic(5, 24, FlxColor.WHITE);
		offsetScrollThumb.alpha = 0.75;
		offsetScrollThumb.scrollFactor.set();
		offsetScrollThumb.cameras = [camHUD];
		add(offsetScrollThumb);

		offsetTextClipRect = new FlxRect();
		animsTxt.fieldWidth = offsetWindowBg.width - 36;
		animsTxt.clipRect = offsetTextClipRect;
		add(animsTxt);
		refreshOffsetModeButtons();
		updateOffsetTextLayout(true);
		setOffsetWindowAlpha(0.58);
	}

	function getOffsetTextMaxScroll():Float
	{
		if(animsTxt == null) return 0;
		return Math.max(0, animsTxt.textField.textHeight + 8 - offsetTextViewHeight);
	}

	function updateOffsetTextLayout(force:Bool = false):Void
	{
		if(offsetWindowBg == null || animsTxt == null || offsetTextClipRect == null) return;

		var viewX:Float = offsetWindowBg.x + 18;
		var viewY:Float = offsetWindowBg.y + 56;
		var viewW:Float = offsetWindowBg.width - 38;
		offsetTextScroll = FlxMath.bound(offsetTextScroll, 0, getOffsetTextMaxScroll());
		animsTxt.setPosition(viewX, viewY - offsetTextScroll);
		animsTxt.fieldWidth = viewW;
		offsetTextClipRect.set(0, offsetTextScroll, viewW, offsetTextViewHeight);
		animsTxt.clipRect = offsetTextClipRect;

		if(offsetScrollTrack != null)
		{
			offsetScrollTrack.setPosition(offsetWindowBg.x + offsetWindowBg.width - 12, viewY);
			offsetScrollTrack.visible = getOffsetTextMaxScroll() > 0;
		}
		if(offsetScrollThumb != null)
		{
			var maxScroll:Float = getOffsetTextMaxScroll();
			offsetScrollThumb.visible = maxScroll > 0;
			if(maxScroll > 0)
			{
				var contentHeight:Float = maxScroll + offsetTextViewHeight;
				var thumbHeight:Int = Std.int(FlxMath.bound(offsetTextViewHeight * (offsetTextViewHeight / contentHeight), 18, offsetTextViewHeight));
				offsetScrollThumb.makeGraphic(5, thumbHeight, FlxColor.WHITE);
				offsetScrollThumb.alpha = 0.75;
				offsetScrollThumb.setPosition(offsetScrollTrack.x - 1, offsetScrollTrack.y + (offsetTextViewHeight - thumbHeight) * (offsetTextScroll / maxScroll));
			}
		}
	}

	function setOffsetWindowAlpha(value:Float):Void
	{
		if(offsetWindowBg != null) offsetWindowBg.alpha = value * 0.92;
		if(offsetOpponentButton != null) offsetOpponentButton.alpha = value;
		if(offsetPlayerButton != null) offsetPlayerButton.alpha = value;
		if(animsTxt != null) animsTxt.alpha = value;
		if(offsetScrollTrack != null) offsetScrollTrack.alpha = value * 0.6;
		if(offsetScrollThumb != null) offsetScrollThumb.alpha = value * 0.75;
	}

	function moveOffsetWindow(dx:Float, dy:Float):Void
	{
		if(offsetWindowBg == null) return;
		offsetWindowBg.x += dx;
		offsetWindowBg.y += dy;
		offsetOpponentButton.x += dx;
		offsetOpponentButton.y += dy;
		offsetPlayerButton.x += dx;
		offsetPlayerButton.y += dy;
		if(offsetScrollTrack != null)
		{
			offsetScrollTrack.x += dx;
			offsetScrollTrack.y += dy;
		}
		if(offsetScrollThumb != null)
		{
			offsetScrollThumb.x += dx;
			offsetScrollThumb.y += dy;
		}
		updateOffsetTextLayout();
	}

	function refreshOffsetModeButtons():Void
	{
		if(offsetOpponentButton == null || offsetPlayerButton == null || character == null) return;

		offsetOpponentButton.normalStyle.bgColor = !character.isPlayer ? HaxeUITheme.PURPLE_DARK : HaxeUITheme.PANEL;
		offsetPlayerButton.normalStyle.bgColor = character.isPlayer ? HaxeUITheme.PURPLE_DARK : HaxeUITheme.PANEL;
		offsetOpponentButton.forceCheckNext = true;
		offsetPlayerButton.forceCheckNext = true;
	}

	function storeCurrentOffsetForMode():Void
	{
		var curAnimData = (anims != null && curAnim < anims.length) ? anims[curAnim] : null;
		if (curAnimData == null || character == null) return;

		if (character.isPlayer)
		{
			if (curAnimData.offsets_player == null) curAnimData.offsets_player = [0, 0];
			curAnimData.offsets_player[0] = Std.int(character.offset.x);
			curAnimData.offsets_player[1] = Std.int(character.offset.y);
		}
		else
		{
			if (curAnimData.offsets == null) curAnimData.offsets = [0, 0];
			curAnimData.offsets[0] = Std.int(character.offset.x);
			curAnimData.offsets[1] = Std.int(character.offset.y);
		}
	}

	function setOffsetWindowMode(isPlayer:Bool):Void
	{
		if(character == null || character.isPlayer == isPlayer) return;

		var curAnimData = (anims != null && curAnim < anims.length) ? anims[curAnim] : null;
		storeCurrentOffsetForMode();
		character.isPlayer = isPlayer;
		character.flipX = (character.originalFlipX != character.isPlayer);
		character.reloadAnimationsForCurrentSide();
		character.refreshOffsets();

		if (curAnimData != null && character.hasAnimation(curAnimData.anim))
			character.playAnim(curAnimData.anim, true);

		updateCharacterPositions();
		updatePointerPos(false);
		updateText();
		reloadCurrentAnimationInputs();
		refreshOffsetModeButtons();
		unsavedProgress = true;
	}

	function updateOffsetWindowDrag(elapsed:Float):Void
	{
		if(offsetWindowBg == null) return;

		var over:Bool = FlxG.mouse.visible && FlxG.mouse.overlaps(offsetWindowBg, camHUD);
		var mouse:FlxPoint = FlxG.mouse.getViewPosition(camHUD);
		if(over && FlxG.mouse.wheel != 0)
		{
			offsetTextScroll = FlxMath.bound(offsetTextScroll - FlxG.mouse.wheel * 28, 0, getOffsetTextMaxScroll());
			updateOffsetTextLayout();
		}

		if(FlxG.mouse.justPressed && over && mouse.y <= offsetWindowBg.y + 24)
		{
			draggingOffsetWindow = true;
			offsetWindowDragPoint = FlxPoint.get(mouse.x, mouse.y);
			offsetWindowStart = FlxPoint.get(offsetWindowBg.x, offsetWindowBg.y);
		}

		if(draggingOffsetWindow)
		{
			if(FlxG.mouse.pressed)
			{
				var targetX:Float = offsetWindowStart.x - (offsetWindowDragPoint.x - mouse.x);
				var targetY:Float = offsetWindowStart.y - (offsetWindowDragPoint.y - mouse.y);
				moveOffsetWindow(targetX - offsetWindowBg.x, targetY - offsetWindowBg.y);
			}
			else
			{
				draggingOffsetWindow = false;
				offsetWindowDragPoint = FlxDestroyUtil.put(offsetWindowDragPoint);
				offsetWindowStart = FlxDestroyUtil.put(offsetWindowStart);
			}
		}

		setOffsetWindowAlpha((draggingOffsetWindow || over) ? 1 : 0.58);
	}

	function addHealthIconPanel():Void
	{
		var panelX:Float = 17;
		var panelY:Float = FlxG.height - 216;
		healthIconPanel = new FlxSprite(panelX, panelY);
		HaxeUITheme.drawRoundedBox(healthIconPanel, 226, 194, HaxeUITheme.BG, 0.94);
		healthIconPanel.scrollFactor.set();
		healthIconPanel.cameras = [camHUD];
		add(healthIconPanel);

		healthIconLabel = new FlxText(panelX + 20, panelY + 12, 160, 'Health icon name:', 8);
		healthIconLabel.scrollFactor.set();
		healthIconLabel.cameras = [camHUD];
		add(healthIconLabel);

		healthIconInputText = new PsychUIInputText(panelX + 20, panelY + 30, 172, character.healthIcon, 8);
		healthIconInputText.scrollFactor.set();
		healthIconInputText.cameras = [camHUD];
		add(healthIconInputText);

		healthIcon.autoAdjustOffset = false;
		healthIcon.scrollFactor.set();
		healthIcon.cameras = [camHUD];
		add(healthIcon);

		healthColorPreview = new FlxSprite(panelX + 18, panelY + 162).makeGraphic(190, 16, FlxColor.WHITE);
		healthColorPreview.scrollFactor.set();
		healthColorPreview.cameras = [camHUD];
		add(healthColorPreview);
		layoutHealthIconPanel();
	}

	function layoutHealthIconPanel():Void
	{
		if(healthIconPanel == null) return;

		healthIconLabel.setPosition(healthIconPanel.x + 20, healthIconPanel.y + 12);
		healthIconInputText.setPosition(healthIconPanel.x + 20, healthIconPanel.y + 30);
		var previewSize:Int = Math.round(HEALTH_ICON_PREVIEW_SIZE + HEALTH_ICON_PREVIEW_BUMP * healthIconPreviewBump);
		healthIcon.setGraphicSize(previewSize, previewSize);
		centerHealthIconInPanel();
		healthIcon.setIconFrame(healthIconPreviewFrame);
		healthColorPreview.setPosition(healthIconPanel.x + 18, healthIconPanel.y + 162);
	}

	function centerHealthIconInPanel():Void
	{
		if(healthIcon == null || healthIconPanel == null)
			return;

		var targetCenterX:Float = healthIconPanel.x + healthIconPanel.width / 2;
		var targetCenterY:Float = healthIconPanel.y + 110;
		healthIcon.centerIconOn(targetCenterX, targetCenterY);
	}

	function moveHealthIconPanel(dx:Float, dy:Float):Void
	{
		if(healthIconPanel == null) return;
		healthIconPanel.x += dx;
		healthIconPanel.y += dy;
		layoutHealthIconPanel();
	}

	function updateHealthIconPanelInput(elapsed:Float):Void
	{
		if(healthIconPanel == null) return;

		var over:Bool = FlxG.mouse.visible && FlxG.mouse.overlaps(healthIconPanel, camHUD);
		var mouse:FlxPoint = FlxG.mouse.getViewPosition(camHUD);
		if(FlxG.mouse.justPressed && over && mouse.y <= healthIconPanel.y + 26)
		{
			draggingHealthIconPanel = true;
			healthIconPanelDragPoint = FlxPoint.get(mouse.x, mouse.y);
			healthIconPanelStart = FlxPoint.get(healthIconPanel.x, healthIconPanel.y);
		}

		if(draggingHealthIconPanel)
		{
			if(FlxG.mouse.pressed)
			{
				var targetX:Float = healthIconPanelStart.x - (healthIconPanelDragPoint.x - mouse.x);
				var targetY:Float = healthIconPanelStart.y - (healthIconPanelDragPoint.y - mouse.y);
				moveHealthIconPanel(targetX - healthIconPanel.x, targetY - healthIconPanel.y);
			}
			else
			{
				draggingHealthIconPanel = false;
				healthIconPanelDragPoint = FlxDestroyUtil.put(healthIconPanelDragPoint);
				healthIconPanelStart = FlxDestroyUtil.put(healthIconPanelStart);
			}
		}

		if(healthIconPreviewBump > 0)
		{
			healthIconPreviewBump = Math.max(0, healthIconPreviewBump - elapsed * 5.5);
			layoutHealthIconPanel();
		}

		var alpha:Float = (draggingHealthIconPanel || over) ? 1 : 0.82;
		healthIconPanel.alpha = alpha;
		healthIconLabel.alpha = alpha;
		healthIconInputText.alpha = alpha;
		healthIcon.alpha = alpha;
		healthColorPreview.alpha = alpha;

		if(!draggingHealthIconPanel && healthIcon != null && FlxG.mouse.justPressed && FlxG.mouse.overlaps(healthIcon, camHUD) && healthIcon.getIconFrameCount() > 1)
		{
			healthIconPreviewFrame = healthIconPreviewFrame == 0 ? 1 : 0;
			healthIconPreviewBump = 1;
			healthIcon.setIconFrame(healthIconPreviewFrame);
			layoutHealthIconPanel();
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.45);
		}
		else if(!draggingHealthIconPanel && healthColorPreview != null && FlxG.mouse.justPressed && FlxG.mouse.overlaps(healthColorPreview, camHUD))
			openHealthColorPicker();
	}

	function openHealthColorPicker():Void
	{
		var current:FlxColor = FlxColor.fromRGB(character.healthColorArray[0], character.healthColorArray[1], character.healthColorArray[2]);
		var dominant:FlxColor = FlxColor.fromInt(CoolUtil.dominantColor(healthIcon));
		openSubState(new CharacterHealthColorPicker(current, [FlxColor.RED, FlxColor.GREEN, dominant], function(color:FlxColor)
		{
			character.healthColorArray[0] = color.red;
			character.healthColorArray[1] = color.green;
			character.healthColorArray[2] = color.blue;
			updateHealthBar();
			unsavedProgress = true;
		}));
	}

	function clearGhostSprites()
	{
		if(ghost != null)
		{
			ghost.visible = false;
			ghost.makeGraphic(1, 1, FlxColor.TRANSPARENT);
			ghost.alpha = ghostAlpha;
		}

		if(animateGhost != null)
		{
			remove(animateGhost, true);
			animateGhost = FlxDestroyUtil.destroy(animateGhost);
		}
		animateGhostImage = null;
	}

	function addCharacter(reload:Bool = false)
	{
		var pos:Int = -1;
		var wasPlayer:Null<Bool> = null;
		if(character != null)
		{
			wasPlayer = character.isPlayer;
			pos = members.indexOf(character);
			clearGhostSprites();
			remove(character, true);
			character = FlxDestroyUtil.destroy(character);
		}

		var isPlayer = (reload && wasPlayer != null ? wasPlayer == true : !predictCharacterIsNotPlayer(_char));
		character = new Character(0, 0, _char, isPlayer);
		character.debugMode = true;
		character.MissingCharacter = false;

		if(pos > -1) insert(pos, character);
		else add(character);
		updateCharacterPositions();
		reloadAnimList();
		if(healthBar != null && healthIcon != null) updateHealthBar();
	}

	function makeUIMenu()
	{
		UI_box = new PsychUIBox(FlxG.width - 275, 25, 250, 120, ['Ghost', 'Settings']);
		UI_box.scrollFactor.set();
		UI_box.cameras = [camHUD];

		UI_characterbox = new PsychUIBox(UI_box.x - 100, UI_box.y + UI_box.height + 10, 350, 408, ['Animations', 'Character']);
		UI_characterbox.scrollFactor.set();
		UI_characterbox.cameras = [camHUD];
		UI_characterbox.fitSelectedTabContent = true;
		UI_characterbox.minFitHeight = 280;
		UI_characterbox.maxFitHeight = 520;
		add(UI_characterbox);
		add(UI_box);

		addGhostUI();
		addSettingsUI();
		addAnimationsUI();
		addCharacterUI();

		UI_box.selectedName = 'Settings';
		UI_characterbox.selectedName = 'Character';
	}

	var ghostAlpha:Float = 0.6;
	function addGhostUI()
	{
		var tab_group = UI_box.getTab('Ghost').menu;

		//var hideGhostButton:PsychUIButton = null;
		var makeGhostButton:PsychUIButton = new PsychUIButton(25, 15, "Make Ghost", function() {
			var anim = anims[curAnim];
			if(!character.isAnimationNull())
			{
				var myAnim = anims[curAnim];
				if(!character.isAnimateAtlas)
				{
					ghost.loadGraphic(character.graphic);
					ghost.frames.frames = character.frames.frames;
					ghost.animation.copyFrom(character.animation);
					ghost.animation.play(character.animation.curAnim.name, true, false, character.animation.curAnim.curFrame);
					ghost.animation.pause();
				}
				else if(myAnim != null) //This is VERY unoptimized and bad, I hope to find a better replacement that loads only a specific frame as bitmap in the future.
				{
					if(animateGhost == null) //If I created the animateGhost on create() and you didn't load an atlas, it would crash the game on destroy, so we create it here
					{
						animateGhost = new FlxAnimate(ghost.x, ghost.y);
						animateGhost.showPivot = false;
						insert(members.indexOf(ghost), animateGhost);
						animateGhost.active = false;
					}

					if(animateGhost == null || animateGhostImage != character.imageFile)
						Paths.loadAnimateAtlas(animateGhost, character.imageFile);
					
					animateGhost.addAtlasAnimation('anim', character.getCurrentAnimationSymbol(myAnim), character.getCurrentAnimationIndices(myAnim), 0, false);

					animateGhost.anim.play('anim', true, false, character.atlas.getAtlasCurFrame());
					animateGhost.anim.pause();

					animateGhostImage = character.imageFile;
				}
				
				var spr:FlxSprite = !character.isAnimateAtlas ? ghost : animateGhost;
				if(spr != null)
				{
					spr.setPosition(character.x, character.y);
					spr.antialiasing = character.antialiasing;
					spr.flipX = character.flipX;
					spr.alpha = ghostAlpha;

					spr.scale.set(character.scale.x, character.scale.y);
					spr.updateHitbox();

					spr.offset.set(character.offset.x, character.offset.y);
					spr.visible = true;

					var otherSpr:FlxSprite = (spr == animateGhost) ? ghost : animateGhost;
					if(otherSpr != null) otherSpr.visible = false;
				}
				/*hideGhostButton.active = true;
				hideGhostButton.alpha = 1;*/
				trace('created ghost image');
			}
		});

		/*hideGhostButton = new PsychUIButton(20 + makeGhostButton.width, makeGhostButton.y, "Hide Ghost", function() {
			ghost.visible = false;
			hideGhostButton.active = false;
			hideGhostButton.alpha = 0.6;
		});
		hideGhostButton.active = false;
		hideGhostButton.alpha = 0.6;*/

		var highlightGhost:PsychUICheckBox = new PsychUICheckBox(20 + makeGhostButton.x + makeGhostButton.width, makeGhostButton.y, "Highlight Ghost", 100);
		highlightGhost.onClick = function()
		{
			var value = highlightGhost.checked ? 125 : 0;
			ghost.colorTransform.redOffset = value;
			ghost.colorTransform.greenOffset = value;
			ghost.colorTransform.blueOffset = value;
			if(animateGhost != null)
			{
				animateGhost.colorTransform.redOffset = value;
				animateGhost.colorTransform.greenOffset = value;
				animateGhost.colorTransform.blueOffset = value;
			}
		};

		var ghostAlphaSlider:PsychUISlider = new PsychUISlider(15, makeGhostButton.y + 25, function(v:Float)
		{
			ghostAlpha = v;
			ghost.alpha = ghostAlpha;
			if(animateGhost != null) animateGhost.alpha = ghostAlpha;

		}, ghostAlpha, 0, 1);
		ghostAlphaSlider.label = 'Opacity:';

		tab_group.add(makeGhostButton);
		//tab_group.add(hideGhostButton);
		tab_group.add(highlightGhost);
		tab_group.add(ghostAlphaSlider);
	}

	var charDropDown:PsychUIDropDownMenu;
	function addSettingsUI()
	{
		var tab_group = UI_box.getTab('Settings').menu;

		var reloadCharacter:PsychUIButton = new PsychUIButton(140, 20, "Reload Char", function()
		{
			Character.clearCharacterCache(_char);
			addCharacter(true);
			updatePointerPos();
			reloadCharacterOptions();
			reloadCharacterDropDown();
		});

		var templateCharacter:PsychUIButton = new PsychUIButton(140, 50, "Load Template", function()
		{
			final _template:CharacterFile =
			{
				animations: [ // Mudei pq era mt especifico ser do BF o template
					newAnim('idle', 'idle'),
					newAnim('singLEFT', 'left'),
					newAnim('singDOWN', 'down'),
					newAnim('singUP', 'up'),
					newAnim('singRIGHT', 'right')
				],
				no_antialiasing: false,
				flip_x: false,
				healthicon: 'face',
				image: 'characters/BFMix2',
				sing_duration: 4,
				scale: 1,
				healthbar_colors: [161, 161, 161],
				camera_position: [0, 0],
				position: [0, 0],
				vocals_file: null,
				vslice_sustains: false
			};

			character.loadCharacterFile(_template);
			character.MissingCharacter = false;
			character.color = FlxColor.WHITE;
			character.alpha = 1;
			reloadAnimList();
			reloadCharacterOptions();
			updateCharacterPositions();
			updatePointerPos();
			reloadCharacterDropDown();
			updateHealthBar();
		});
		templateCharacter.normalStyle.bgColor = FlxColor.RED;
		templateCharacter.normalStyle.textColor = FlxColor.WHITE;

		/*var templateCharacterCool:PsychUIButton = new PsychUIButton(140, 80, "Load Awesome Template", function()
		{
			final _templateCool:CharacterFile =
			{
				animations: [ // Template mas maneiro
					newAnim('idle', 'idle'),
					newAnim('singLEFT', 'left'),
					newAnim('singDOWN', 'down'),
					newAnim('singUP', 'up'),
					newAnim('singRIGHT', 'right'),
					newAnim('singLEFT-alt', 'left-alt'),
					newAnim('singDOWN-alt', 'down-alt'),
					newAnim('singUP-alt', 'up-alt'),
					newAnim('singRIGHT-alt', 'right-miss'),
					newAnim('singLEFT-MISS', 'left-miss'),
					newAnim('singDOWN-MISS', 'down-miss'),
					newAnim('singUP-MISS', 'up-miss'),
					newAnim('singRIGHT-MISS', 'right-miss')
				],
				no_antialiasing: false,
				flip_x: false,
				healthicon: 'face',
				image: 'characters/BFMix2',
				sing_duration: 4,
				scale: 1,
				healthbar_colors: [161, 161, 161],
				camera_position: [0, 0],
				position: [0, 0],
				vocals_file: null,
				vslice_sustains: false
			};

			character.loadCharacterFile(_templateCool);
			character.MissingCharacter = false;
			character.color = FlxColor.WHITE;
			character.alpha = 1;
			reloadAnimList();
			reloadCharacterOptions();
			updateCharacterPositions();
			updatePointerPos();
			reloadCharacterDropDown();
			updateHealthBar();
		});
		templateCharacterCool.normalStyle.bgColor = FlxColor.RED;
		templateCharacterCool.normalStyle.textColor = FlxColor.WHITE;*/


		charDropDown = new PsychUIDropDownMenu(10, 30, [''], function(index:Int, intended:String)
		{
			if(intended == null || intended.length < 1) return;

			if (Character.getCharacterPath(intended) != null)
			{
				_char = intended;
				addCharacter();
				reloadCharacterOptions();
				reloadCharacterDropDown();
				updatePointerPos();
			}
			else
			{
				reloadCharacterDropDown();
				FlxG.sound.play(Paths.sound('cancelMenu'));
			}
		});
		reloadCharacterDropDown();
		charDropDown.selectedLabel = _char;

		tab_group.add(new FlxText(charDropDown.x, charDropDown.y - 18, 80, 'Character:'));
		tab_group.add(reloadCharacter);
		tab_group.add(templateCharacter);
		tab_group.add(charDropDown);
	}

	var animationDropDown:PsychUIDropDownMenu;
	var animationInputText:PsychUIInputText;
	var animationNameInputText:PsychUIInputText;
	var animationIndicesInputText:PsychUIInputText;
	var animationFramerate:PsychUINumericStepper;
	var animationLoopCheckBox:PsychUICheckBox;

	function formatAnimIndices(indices:Array<Int>):String
		return (indices != null && indices.length > 0) ? indices.join(',') : '';

	function reloadCurrentAnimationInputs():Void
	{
		if(character == null || animationInputText == null || curAnim < 0 || curAnim >= character.animationsArray.length) return;

		var anim:AnimArray = character.animationsArray[curAnim];
		animationInputText.text = anim.anim;
		animationNameInputText.text = character.getCurrentAnimationSymbol(anim);
		animationLoopCheckBox.checked = anim.loop;
		animationFramerate.value = anim.fps;
		animationIndicesInputText.text = formatAnimIndices(character.getCurrentAnimationIndices(anim));
	}

	function addAnimationsUI()
	{
		var tab_group = UI_characterbox.getTab('Animations').menu;

		animationInputText = new PsychUIInputText(15, 85, 80, '', 8);
		animationNameInputText = new PsychUIInputText(animationInputText.x, animationInputText.y + 35, 150, '', 8);
		animationIndicesInputText = new PsychUIInputText(animationNameInputText.x, animationNameInputText.y + 40, 250, '', 8);
		animationFramerate = new PsychUINumericStepper(animationInputText.x + 170, animationInputText.y, 1, 24, 0, 240, 0);
		animationLoopCheckBox = new PsychUICheckBox(animationNameInputText.x + 170, animationNameInputText.y - 1, "Should it Loop?", 100);

		animationDropDown = new PsychUIDropDownMenu(15, animationInputText.y - 55, [''], function(selectedAnimation:Int, pressed:String) {
			var anim:AnimArray = character.animationsArray[selectedAnimation];
			animationInputText.text = anim.anim;
			animationNameInputText.text = character.getCurrentAnimationSymbol(anim);
			animationLoopCheckBox.checked = anim.loop;
			animationFramerate.value = anim.fps;
			animationIndicesInputText.text = formatAnimIndices(character.getCurrentAnimationIndices(anim));
		});

		var addUpdateButton:PsychUIButton = new PsychUIButton(70, animationIndicesInputText.y + 60, "Add/Update", function() {
			var indicesText:String = animationIndicesInputText.text.trim();
			var indices:Array<Int> = [];
			if(indicesText.length > 0)
			{
				var indicesStr:Array<String> = animationIndicesInputText.text.trim().split(',');
				if(indicesStr.length > 0)
				{
					for (ind in indicesStr)
					{
						if(ind.contains('-'))
						{
							var splitIndices:Array<String> = ind.split('-');
							var indexStart:Int = Std.parseInt(splitIndices[0]);
							if(Math.isNaN(indexStart) || indexStart < 0) indexStart = 0;
	
							var indexEnd:Int = Std.parseInt(splitIndices[1]);
							if(Math.isNaN(indexEnd) || indexEnd < indexStart) indexEnd = indexStart;
	
							for (index in indexStart...indexEnd+1)
								indices.push(index);
						}
						else
						{
							var index:Int = Std.parseInt(ind);
							if(!Math.isNaN(index) && index > -1)
								indices.push(index);
						}
					}
				}
			}

			var lastAnim:String = (character.animationsArray[curAnim] != null) ? character.animationsArray[curAnim].anim : '';
			var lastOffsets:Array<Int> = [0, 0];
			var lastOffsetsPlayer:Null<Array<Int>> = null;
			var lastName:String = animationNameInputText.text;
			var lastNamePlayer:Null<String> = null;
			var lastNameOpponent:Null<String> = null;
			var lastIndices:Array<Int> = indices;
			var lastIndicesPlayer:Null<Array<Int>> = null;
			var lastIndicesOpponent:Null<Array<Int>> = null;
			var foundExisting:Bool = false;
			for (anim in character.animationsArray)
				if(animationInputText.text == anim.anim) {
					foundExisting = true;
					lastOffsets = anim.offsets;
					lastOffsetsPlayer = anim.offsets_player;
					lastName = anim.name;
					lastNamePlayer = anim.name_player;
					lastNameOpponent = anim.name_opponent;
					lastIndices = anim.indices;
					lastIndicesPlayer = anim.indices_player;
					lastIndicesOpponent = anim.indices_opponent;
					if(character.hasAnimation(animationInputText.text))
					{
						if(!character.isAnimateAtlas) character.animation.remove(animationInputText.text);
						else character.atlas.anim.remove(animationInputText.text);
					}
					character.animationsArray.remove(anim);
				}

			var addedAnim:AnimArray = newAnim(animationInputText.text, lastName);
			addedAnim.fps = Math.round(animationFramerate.value);
			addedAnim.loop = animationLoopCheckBox.checked;
			addedAnim.indices = lastIndices;
			addedAnim.offsets = lastOffsets;
			addedAnim.offsets_player = lastOffsetsPlayer;
			addedAnim.name_player = lastNamePlayer;
			addedAnim.name_opponent = lastNameOpponent;
			addedAnim.indices_player = lastIndicesPlayer;
			addedAnim.indices_opponent = lastIndicesOpponent;

			if(character.isPlayer)
			{
				addedAnim.name_player = animationNameInputText.text;
				addedAnim.indices_player = indices;
				if(!foundExisting)
				{
					addedAnim.name = animationNameInputText.text;
					addedAnim.indices = indices;
				}
			}
			else
			{
				addedAnim.name_opponent = animationNameInputText.text;
				addedAnim.indices_opponent = indices;
				if(!foundExisting)
				{
					addedAnim.name = animationNameInputText.text;
					addedAnim.indices = indices;
				}
			}

			addAnimation(addedAnim.anim, character.getCurrentAnimationSymbol(addedAnim), addedAnim.fps, addedAnim.loop, character.getCurrentAnimationIndices(addedAnim));
			character.animationsArray.push(addedAnim);

			reloadAnimList();
			@:arrayAccess curAnim = Std.int(Math.max(0, character.animationsArray.indexOf(addedAnim)));
			character.playAnim(addedAnim.anim, true);
			trace('Added/Updated animation: ' + animationInputText.text);
		});

		var removeButton:PsychUIButton = new PsychUIButton(180, animationIndicesInputText.y + 60, "Remove", function() {
			for (anim in character.animationsArray)
				if(animationInputText.text == anim.anim)
				{
					var resetAnim:Bool = false;
					if(anim.anim == character.getAnimationName()) resetAnim = true;
					if(character.hasAnimation(anim.anim))
					{
						if(!character.isAnimateAtlas) character.animation.remove(anim.anim);
						else character.atlas.anim.remove(anim.anim);
						character.animOffsets.remove(anim.anim);
						character.animationsArray.remove(anim);
					}

					if(resetAnim && character.animationsArray.length > 0) {
						curAnim = FlxMath.wrap(curAnim, 0, anims.length-1);
						character.playAnim(anims[curAnim].anim, true);
					}
					reloadAnimList();
					trace('Removed animation: ' + animationInputText.text);
					break;
				}
		});
		reloadAnimList();
		animationDropDown.selectedLabel = anims[0] != null ? anims[0].anim : '';

		tab_group.add(new FlxText(animationDropDown.x, animationDropDown.y - 18, 100, 'Animations:'));
		tab_group.add(new FlxText(animationInputText.x, animationInputText.y - 18, 100, 'Animation name:'));
		tab_group.add(new FlxText(animationFramerate.x, animationFramerate.y - 18, 100, 'Framerate:'));
		tab_group.add(new FlxText(animationNameInputText.x, animationNameInputText.y - 18, 150, 'Animation Symbol Name/Tag:'));
		tab_group.add(new FlxText(animationIndicesInputText.x, animationIndicesInputText.y - 18, 170, 'ADVANCED - Animation Indices:'));

		tab_group.add(animationInputText);
		tab_group.add(animationNameInputText);
		tab_group.add(animationIndicesInputText);
		tab_group.add(animationFramerate);
		tab_group.add(animationLoopCheckBox);
		tab_group.add(addUpdateButton);
		tab_group.add(removeButton);
		tab_group.add(animationDropDown);
	}

	var imageInputText:PsychUIInputText;
	var healthIconInputText:PsychUIInputText;
	var vocalsInputText:PsychUIInputText;
	var assetPathInputs:Array<PsychUIInputText> = [];
	var assetPathLabels:Array<FlxText> = [];
	var assetPathReloadButtons:Array<PsychUIButton> = [];
	var assetPathRemoveButtons:Array<PsychUIButton> = [];
	var assetPathMask:FlxSprite;
	var assetPathScrollTrack:FlxSprite;
	var assetPathScrollThumb:FlxSprite;
	var assetPathFirstVisible:Int = 0;
	var addAssetPathButton:PsychUIButton;
	var characterTabGroup:FlxSpriteGroup;
	var vocalsLabel:FlxText;
	var singDurationLabel:FlxText;
	var scaleLabel:FlxText;
	var characterPositionLabel:FlxText;
	var cameraPositionLabel:FlxText;
	var healthColorLabel:FlxText;
	var saveCharacterButton:PsychUIButton;

	var singDurationStepper:PsychUINumericStepper;
	var scaleStepper:PsychUINumericStepper;
	var positionXStepper:PsychUINumericStepper;
	var positionYStepper:PsychUINumericStepper;
	var positionCameraXStepper:PsychUINumericStepper;
	var positionCameraYStepper:PsychUINumericStepper;

	var flipXCheckBox:PsychUICheckBox;
	var noAntialiasingCheckBox:PsychUICheckBox;
	var vsliceSustainCheckBox:PsychUICheckBox;

	var healthColorStepperR:PsychUINumericStepper;
	var healthColorStepperG:PsychUINumericStepper;
	var healthColorStepperB:PsychUINumericStepper;

	function addAssetPathRow(?value:String = ''):Void
	{
		if(characterTabGroup == null) return;

		var input:PsychUIInputText = new PsychUIInputText(15, 30, 200, value, 8);
		var label:FlxText = new FlxText(15, input.y - 18, 110, 'Asset path:');
		var reloadButton:PsychUIButton = new PsychUIButton(input.x + 210, input.y - 3, 'Reload Image', function()
		{
			syncImageFromAssetInputs();
			reloadCharacterImage();
		});
		var removeButton:PsychUIButton = new PsychUIButton(input.x + 300, input.y - 3, '-', function()
		{
			removeAssetPathRow(input);
		}, 24);

		assetPathInputs.push(input);
		assetPathLabels.push(label);
		assetPathReloadButtons.push(reloadButton);
		assetPathRemoveButtons.push(removeButton);

		characterTabGroup.add(label);
		characterTabGroup.add(input);
		characterTabGroup.add(reloadButton);
		characterTabGroup.add(removeButton);
		if(imageInputText == null) imageInputText = input;
		layoutCharacterTabControls();
	}

	function removeAssetPathRow(input:PsychUIInputText, markUnsaved:Bool = true):Void
	{
		var index:Int = assetPathInputs.indexOf(input);
		if(index < 0 || assetPathInputs.length < 2) return;

		removeAssetPathMember(assetPathLabels[index]);
		removeAssetPathMember(assetPathInputs[index]);
		removeAssetPathMember(assetPathReloadButtons[index]);
		removeAssetPathMember(assetPathRemoveButtons[index]);

		assetPathLabels.splice(index, 1);
		assetPathInputs.splice(index, 1);
		assetPathReloadButtons.splice(index, 1);
		assetPathRemoveButtons.splice(index, 1);
		imageInputText = assetPathInputs[0];
		assetPathFirstVisible = Std.int(FlxMath.bound(assetPathFirstVisible, 0, getAssetPathMaxFirstVisible()));
		if(markUnsaved) syncImageFromAssetInputs();
		layoutCharacterTabControls();
		if(markUnsaved) unsavedProgress = true;
	}

	function removeAssetPathMember(member:FlxSprite):Void
	{
		if(member == null) return;
		characterTabGroup.remove(member, true);
		member.destroy();
	}

	function syncAssetPathRowsFromCharacter():Void
	{
		if(characterTabGroup == null) return;

		var paths:Array<String> = character.imageFile != null ? character.imageFile.split(',') : [''];
		if(paths.length < 1) paths = [''];
		var targetRows:Int = Std.int(Math.max(1, paths.length));
		while(assetPathInputs.length < targetRows)
			addAssetPathRow('');
		while(assetPathInputs.length > targetRows)
			removeAssetPathRow(assetPathInputs[assetPathInputs.length - 1], false);

		for(i in 0...assetPathInputs.length)
			assetPathInputs[i].text = i < paths.length ? paths[i].trim() : '';

		imageInputText = assetPathInputs[0];
		assetPathFirstVisible = Std.int(FlxMath.bound(assetPathFirstVisible, 0, getAssetPathMaxFirstVisible()));
		layoutCharacterTabControls();
	}

	function syncImageFromAssetInputs():Void
	{
		var paths:Array<String> = [];
		for(input in assetPathInputs)
		{
			var path:String = input.text.trim();
			if(path.length > 0 && !paths.contains(path))
				paths.push(path);
		}
		if(paths.length < 1 && imageInputText != null)
			paths.push(imageInputText.text.trim());
		character.imageFile = paths.join(',');
	}

	function setCharacterTabControlPosition(member:Dynamic, localX:Float, localY:Float):Void
	{
		if(member == null) return;
		var baseX:Float = characterTabGroup != null ? characterTabGroup.x : 0;
		var baseY:Float = characterTabGroup != null ? characterTabGroup.y : 0;
		member.setPosition(baseX + localX, baseY + localY);
	}

	function getAssetPathMaxFirstVisible():Int
		return Std.int(Math.max(0, assetPathInputs.length - ASSET_PATH_VISIBLE_ROWS));

	function setAssetPathFirstVisible(value:Int):Void
	{
		assetPathFirstVisible = Std.int(FlxMath.bound(value, 0, getAssetPathMaxFirstVisible()));
		layoutCharacterTabControls();
	}

	function updateAssetPathScrollInput():Void
	{
		if(assetPathMask == null || assetPathInputs == null || assetPathInputs.length <= ASSET_PATH_VISIBLE_ROWS)
			return;
		if(UI_characterbox == null || UI_characterbox.selectedName != 'Character')
			return;
		if(FlxG.mouse.wheel != 0 && FlxG.mouse.overlaps(assetPathMask, camHUD))
			setAssetPathFirstVisible(assetPathFirstVisible - FlxG.mouse.wheel);
	}

	function setAssetPathMemberVisible(member:Dynamic, value:Bool):Void
	{
		if(member == null) return;
		member.visible = value;
		member.active = value;
	}

	function layoutCharacterTabControls():Void
	{
		if(assetPathInputs == null || assetPathInputs.length < 1) return;

		assetPathFirstVisible = Std.int(FlxMath.bound(assetPathFirstVisible, 0, getAssetPathMaxFirstVisible()));
		if(assetPathMask != null)
		{
			setCharacterTabControlPosition(assetPathMask, ASSET_PATH_VIEW_X, ASSET_PATH_VIEW_Y);
			HaxeUITheme.drawRoundedBox(assetPathMask, ASSET_PATH_VIEW_W, ASSET_PATH_VIEW_H, HaxeUITheme.PANEL, 0.55);
		}
		for(i in 0...assetPathInputs.length)
		{
			var visibleIndex:Int = i - assetPathFirstVisible;
			var visible:Bool = visibleIndex >= 0 && visibleIndex < ASSET_PATH_VISIBLE_ROWS;
			var y:Float = ASSET_PATH_START_Y + ASSET_PATH_ROW_GAP * visibleIndex;
			assetPathLabels[i].text = i == 0 ? 'Asset path:' : 'Asset path ${i + 1}:';
			setCharacterTabControlPosition(assetPathLabels[i], 15, y - 18);
			setCharacterTabControlPosition(assetPathInputs[i], 15, y);
			setCharacterTabControlPosition(assetPathReloadButtons[i], 225, y - 3);
			setCharacterTabControlPosition(assetPathRemoveButtons[i], 315, y - 3);
			setAssetPathMemberVisible(assetPathLabels[i], visible);
			setAssetPathMemberVisible(assetPathInputs[i], visible);
			setAssetPathMemberVisible(assetPathReloadButtons[i], visible);
			setAssetPathMemberVisible(assetPathRemoveButtons[i], visible && assetPathInputs.length > 1);
		}

		var maxFirstVisible:Int = getAssetPathMaxFirstVisible();
		var showScroll:Bool = maxFirstVisible > 0;
		if(assetPathScrollTrack != null)
		{
			setCharacterTabControlPosition(assetPathScrollTrack, ASSET_PATH_VIEW_X + ASSET_PATH_VIEW_W + 3, ASSET_PATH_VIEW_Y + 10);
			assetPathScrollTrack.visible = showScroll;
		}
		if(assetPathScrollThumb != null)
		{
			assetPathScrollThumb.visible = showScroll;
			if(showScroll)
			{
				var trackHeight:Float = ASSET_PATH_VIEW_H - 20;
				var thumbHeight:Int = Std.int(FlxMath.bound(trackHeight * (ASSET_PATH_VISIBLE_ROWS / assetPathInputs.length), 18, trackHeight));
				assetPathScrollThumb.makeGraphic(5, thumbHeight, FlxColor.WHITE);
				assetPathScrollThumb.alpha = 0.75;
				setCharacterTabControlPosition(assetPathScrollThumb, ASSET_PATH_VIEW_X + ASSET_PATH_VIEW_W + 2, ASSET_PATH_VIEW_Y + 10 + (trackHeight - thumbHeight) * (assetPathFirstVisible / maxFirstVisible));
			}
		}

		var afterAssetsY:Float = ASSET_PATH_VIEW_Y + ASSET_PATH_VIEW_H + 18;
		if(addAssetPathButton != null)
			setCharacterTabControlPosition(addAssetPathButton, 162, ASSET_PATH_VIEW_Y + ASSET_PATH_VIEW_H + 2);

		var vocalsY:Float = afterAssetsY + 4;
		var singY:Float = vocalsY + 48;
		var scaleY:Float = singY + 46;
		var healthY:Float = scaleY + 56;
		var checkX:Float = 108;
		var stepX:Float = 190;
		var stepGap:Float = 78;

		if(vocalsInputText != null) setCharacterTabControlPosition(vocalsInputText, 15, vocalsY);
		if(singDurationStepper != null) setCharacterTabControlPosition(singDurationStepper, 15, singY);
		if(scaleStepper != null) setCharacterTabControlPosition(scaleStepper, 15, scaleY);
		if(flipXCheckBox != null) setCharacterTabControlPosition(flipXCheckBox, checkX, singY);
		if(vsliceSustainCheckBox != null) setCharacterTabControlPosition(vsliceSustainCheckBox, checkX, singY + 28);
		if(noAntialiasingCheckBox != null) setCharacterTabControlPosition(noAntialiasingCheckBox, checkX, singY + 56);
		if(positionXStepper != null) setCharacterTabControlPosition(positionXStepper, stepX, singY);
		if(positionYStepper != null) setCharacterTabControlPosition(positionYStepper, stepX + stepGap, singY);
		if(positionCameraXStepper != null) setCharacterTabControlPosition(positionCameraXStepper, stepX, singY + 48);
		if(positionCameraYStepper != null) setCharacterTabControlPosition(positionCameraYStepper, stepX + stepGap, singY + 48);
		if(healthColorStepperR != null) setCharacterTabControlPosition(healthColorStepperR, 15, healthY);
		if(healthColorStepperG != null) setCharacterTabControlPosition(healthColorStepperG, 86, healthY);
		if(healthColorStepperB != null) setCharacterTabControlPosition(healthColorStepperB, 157, healthY);
		if(saveCharacterButton != null) setCharacterTabControlPosition(saveCharacterButton, 248, healthY - 2);
		if(vocalsLabel != null) setCharacterTabControlPosition(vocalsLabel, 15, vocalsY - 18);
		if(singDurationLabel != null) setCharacterTabControlPosition(singDurationLabel, 15, singY - 18);
		if(scaleLabel != null) setCharacterTabControlPosition(scaleLabel, 15, scaleY - 18);
		if(characterPositionLabel != null) setCharacterTabControlPosition(characterPositionLabel, stepX, singY - 18);
		if(cameraPositionLabel != null) setCharacterTabControlPosition(cameraPositionLabel, stepX, singY + 30);
		if(healthColorLabel != null) setCharacterTabControlPosition(healthColorLabel, 15, healthY - 18);
	}

	function addCharacterUI()
	{
		var tab_group = UI_characterbox.getTab('Character').menu;
		characterTabGroup = tab_group;

		assetPathMask = new FlxSprite(ASSET_PATH_VIEW_X, ASSET_PATH_VIEW_Y).makeGraphic(ASSET_PATH_VIEW_W, ASSET_PATH_VIEW_H, FlxColor.BLACK);
		tab_group.add(assetPathMask);
		addAssetPathRow(character.imageFile != null ? character.imageFile.split(',')[0] : '');

		assetPathScrollTrack = new FlxSprite().makeGraphic(3, ASSET_PATH_VIEW_H - 20, 0x66FFFFFF);
		assetPathScrollTrack.alpha = 0.6;
		assetPathScrollThumb = new FlxSprite().makeGraphic(5, 24, FlxColor.WHITE);
		assetPathScrollThumb.alpha = 0.75;
		tab_group.add(assetPathScrollTrack);
		tab_group.add(assetPathScrollThumb);

		addAssetPathButton = new PsychUIButton(162, 64, '+', function()
		{
			addAssetPathRow('');
			assetPathFirstVisible = getAssetPathMaxFirstVisible();
			layoutCharacterTabControls();
			unsavedProgress = true;
		}, 24);

		vocalsInputText = new PsychUIInputText(15, 120, 75, character.vocalsFile != null ? character.vocalsFile : '', 8);

		singDurationStepper = new PsychUINumericStepper(15, vocalsInputText.y + 45, 0.1, character.singDuration, 0, 999, 1);

		scaleStepper = new PsychUINumericStepper(15, singDurationStepper.y + 40, 0.1, character.jsonScale, 0.05, 10, 2);

		flipXCheckBox = new PsychUICheckBox(singDurationStepper.x + 80, singDurationStepper.y, "Flip X", 50);
		flipXCheckBox.checked = character.flipX;
		if(character.isPlayer) flipXCheckBox.checked = !flipXCheckBox.checked;
		flipXCheckBox.onClick = function() {
			character.originalFlipX = !character.originalFlipX;
			character.flipX = (character.originalFlipX != character.isPlayer);
		};

		vsliceSustainCheckBox = new PsychUICheckBox(15, singDurationStepper.y + 28, "Vslice Holds", 90);
		vsliceSustainCheckBox.checked = character.vSliceSustains;
		vsliceSustainCheckBox.onClick = function() {
			character.vSliceSustains = vsliceSustainCheckBox.checked;
			unsavedProgress = true;
		};

		noAntialiasingCheckBox = new PsychUICheckBox(flipXCheckBox.x, flipXCheckBox.y + 40, "No Antialiasing", 80);
		noAntialiasingCheckBox.checked = character.noAntialiasing;
		noAntialiasingCheckBox.onClick = function() {
			character.antialiasing = false;
			if(!noAntialiasingCheckBox.checked && ClientPrefs.data.antialiasing) {
				character.antialiasing = true;
			}
			character.noAntialiasing = noAntialiasingCheckBox.checked;
		};

		positionXStepper = new PsychUINumericStepper(flipXCheckBox.x + 110, flipXCheckBox.y, 10, character.positionArray[0], -9000, 9000, 0, 48);
		positionYStepper = new PsychUINumericStepper(positionXStepper.x + 70, positionXStepper.y, 10, character.positionArray[1], -9000, 9000, 0, 48);

		positionCameraXStepper = new PsychUINumericStepper(positionXStepper.x, positionXStepper.y + 40, 10, character.cameraPosition[0], -9000, 9000, 0, 48);
		positionCameraYStepper = new PsychUINumericStepper(positionYStepper.x, positionYStepper.y + 40, 10, character.cameraPosition[1], -9000, 9000, 0, 48);

		saveCharacterButton = new PsychUIButton(250, noAntialiasingCheckBox.y + 48, "Save Character", function() {
			saveCharacter();
		});

		healthColorStepperR = new PsychUINumericStepper(singDurationStepper.x, saveCharacterButton.y, 20, character.healthColorArray[0], 0, 255, 0, 46);
		healthColorStepperG = new PsychUINumericStepper(singDurationStepper.x + 65, saveCharacterButton.y, 20, character.healthColorArray[1], 0, 255, 0, 46);
		healthColorStepperB = new PsychUINumericStepper(singDurationStepper.x + 130, saveCharacterButton.y, 20, character.healthColorArray[2], 0, 255, 0, 46);

		vocalsLabel = new FlxText(15, vocalsInputText.y - 18, 100, 'Vocals File Postfix:');
		singDurationLabel = new FlxText(15, singDurationStepper.y - 18, 120, 'Sing Animation length:');
		scaleLabel = new FlxText(15, scaleStepper.y - 18, 100, 'Scale:');
		characterPositionLabel = new FlxText(positionXStepper.x, positionXStepper.y - 18, 100, 'Character X/Y:');
		cameraPositionLabel = new FlxText(positionCameraXStepper.x, positionCameraXStepper.y - 18, 100, 'Camera X/Y:');
		healthColorLabel = new FlxText(healthColorStepperR.x, healthColorStepperR.y - 18, 100, 'Health Bar R/G/B:');
		tab_group.add(vocalsLabel);
		tab_group.add(singDurationLabel);
		tab_group.add(scaleLabel);
		tab_group.add(characterPositionLabel);
		tab_group.add(cameraPositionLabel);
		tab_group.add(healthColorLabel);
		tab_group.add(addAssetPathButton);
		tab_group.add(vocalsInputText);
		tab_group.add(singDurationStepper);
		tab_group.add(scaleStepper);
		tab_group.add(flipXCheckBox);
		tab_group.add(vsliceSustainCheckBox);
		tab_group.add(noAntialiasingCheckBox);
		tab_group.add(positionXStepper);
		tab_group.add(positionYStepper);
		tab_group.add(positionCameraXStepper);
		tab_group.add(positionCameraYStepper);
		tab_group.add(healthColorStepperR);
		tab_group.add(healthColorStepperG);
		tab_group.add(healthColorStepperB);
		tab_group.add(saveCharacterButton);
		syncAssetPathRowsFromCharacter();
		layoutCharacterTabControls();
	}

	public function UIEvent(id:String, sender:Dynamic) {
		//trace(id, sender);
		if(id == PsychUICheckBox.CLICK_EVENT)
			unsavedProgress = true;

		if(id == PsychUIInputText.CHANGE_EVENT)
		{
			if(sender == healthIconInputText) {
				var lastIcon = healthIcon.getCharacter();
				healthIcon.changeIcon(healthIconInputText.text, false);
				if(lastIcon != healthIcon.getCharacter())
				{
					healthIconPreviewFrame = 0;
					healthIconPreviewBump = 0;
				}
				layoutHealthIconPanel();
				character.healthIcon = healthIconInputText.text;
				if(lastIcon != healthIcon.getCharacter()) updatePresence();
				unsavedProgress = true;
			}
			else if(sender == vocalsInputText)
			{
				character.vocalsFile = vocalsInputText.text;
				unsavedProgress = true;
			}
			else if(Std.isOfType(sender, PsychUIInputText) && assetPathInputs.contains(cast sender))
			{
				syncImageFromAssetInputs();
				unsavedProgress = true;
			}
		}
		else if(id == PsychUINumericStepper.CHANGE_EVENT)
		{
			if (sender == scaleStepper)
			{
				reloadCharacterImage();
				character.jsonScale = sender.value;
				character.scale.set(character.jsonScale, character.jsonScale);
				character.updateHitbox();
				updatePointerPos(false);
				unsavedProgress = true;
			}
			else if(sender == positionXStepper)
			{
				character.positionArray[0] = positionXStepper.value;
				updateCharacterPositions();
				unsavedProgress = true;
			}
			else if(sender == positionYStepper)
			{
				character.positionArray[1] = positionYStepper.value;
				updateCharacterPositions();
				unsavedProgress = true;
			}
			else if(sender == singDurationStepper)
			{
				character.singDuration = singDurationStepper.value;
				unsavedProgress = true;
			}
			else if(sender == positionCameraXStepper)
			{
				character.cameraPosition[0] = positionCameraXStepper.value;
				updatePointerPos();
				unsavedProgress = true;
			}
			else if(sender == positionCameraYStepper)
			{
				character.cameraPosition[1] = positionCameraYStepper.value;
				updatePointerPos();
				unsavedProgress = true;
			}
			else if(sender == healthColorStepperR)
			{
				character.healthColorArray[0] = Math.round(healthColorStepperR.value);
				updateHealthBar();
				unsavedProgress = true;
			}
			else if(sender == healthColorStepperG)
			{
				character.healthColorArray[1] = Math.round(healthColorStepperG.value);
				updateHealthBar();
				unsavedProgress = true;
			}
			else if(sender == healthColorStepperB)
			{
				character.healthColorArray[2] = Math.round(healthColorStepperB.value);
				updateHealthBar();
				unsavedProgress = true;
			}
		}
	}

	function reloadCharacterImage()
	{
		if(assetPathInputs != null && assetPathInputs.length > 0)
			syncImageFromAssetInputs();

		var lastAnim:String = character.getAnimationName();
		var anims:Array<AnimArray> = character.animationsArray.copy();

		clearGhostSprites();
		character.atlas = FlxDestroyUtil.destroy(character.atlas);
		character.isAnimateAtlas = false;
		character.animation.destroyAnimations();
		character.color = FlxColor.WHITE;
		character.alpha = 1;

		if(Paths.isAnimateAtlas(character.imageFile))
		{
			character.atlas = new FlxAnimate();
			character.atlas.showPivot = false;
			try
			{
				Paths.loadAnimateAtlas(character.atlas, character.imageFile);
			}
			catch(e:Dynamic)
			{
				FlxG.log.warn('Could not load atlas ${character.imageFile}: $e');
			}
			character.isAnimateAtlas = true;
		}
		else
		{
			character.frames = Paths.getMultiAtlas(character.imageFile.split(','));
		}

		for (anim in anims) {
			var animAnim:String = '' + anim.anim;
			var animName:String = character.getCurrentAnimationSymbol(anim);
			var animFps:Int = anim.fps;
			var animLoop:Bool = !!anim.loop; //Bruh
			var animIndices:Array<Int> = character.getCurrentAnimationIndices(anim);
			addAnimation(animAnim, animName, animFps, animLoop, animIndices);
		}
		character.refreshOffsets();

		if(anims.length > 0)
		{
			if(lastAnim != '') character.playAnim(lastAnim, true);
			else character.dance();
		}
	}

	function reloadCharacterOptions() {
		if(UI_characterbox == null) return;

		syncAssetPathRowsFromCharacter();
		if(healthIconInputText != null) healthIconInputText.text = character.healthIcon;
		if(vocalsInputText != null) vocalsInputText.text = character.vocalsFile != null ? character.vocalsFile : '';
		if(singDurationStepper != null) singDurationStepper.value = character.singDuration;
		if(scaleStepper != null) scaleStepper.value = character.jsonScale;
		if(flipXCheckBox != null) flipXCheckBox.checked = character.originalFlipX;
		if(vsliceSustainCheckBox != null) vsliceSustainCheckBox.checked = character.vSliceSustains;
		if(noAntialiasingCheckBox != null) noAntialiasingCheckBox.checked = character.noAntialiasing;
		if(positionXStepper != null) positionXStepper.value = character.positionArray[0];
		if(positionYStepper != null) positionYStepper.value = character.positionArray[1];
		if(positionCameraXStepper != null) positionCameraXStepper.value = character.cameraPosition[0];
		if(positionCameraYStepper != null) positionCameraYStepper.value = character.cameraPosition[1];
		reloadAnimationDropDown();
		updateHealthBar();
	}

	var holdingArrowsTime:Float = 0;
	var holdingArrowsElapsed:Float = 0;
	var holdingFrameTime:Float = 0;
	var holdingFrameElapsed:Float = 0;
	var undoOffsets:Array<Float> = null;
	override function update(elapsed:Float)
	{
		preUpdate(elapsed);
		
		super.update(elapsed);
		updateOffsetWindowDrag(elapsed);
		updateHealthIconPanelInput(elapsed);
		updateAssetPathScrollInput();

		if(PsychUIInputText.focusOn != null)
		{
			ClientPrefs.toggleVolumeKeys(false);
			return;
		}
		ClientPrefs.toggleVolumeKeys(true);

		var shiftMult:Float = 1;
		var ctrlMult:Float = 1;
		var shiftMultBig:Float = 1;
		if(FlxG.keys.pressed.SHIFT)
		{
			shiftMult = 4;
			shiftMultBig = 10;
		}
		if(FlxG.keys.pressed.CONTROL) ctrlMult = 0.25;

		// CAMERA CONTROLS
		if (FlxG.keys.pressed.J) FlxG.camera.scroll.x -= elapsed * 500 * shiftMult * ctrlMult;
		if (FlxG.keys.pressed.K) FlxG.camera.scroll.y += elapsed * 500 * shiftMult * ctrlMult;
		if (FlxG.keys.pressed.L) FlxG.camera.scroll.x += elapsed * 500 * shiftMult * ctrlMult;
		if (FlxG.keys.pressed.I) FlxG.camera.scroll.y -= elapsed * 500 * shiftMult * ctrlMult;

		var lastZoom = FlxG.camera.zoom;
		if(FlxG.keys.justPressed.R && !FlxG.keys.pressed.CONTROL) FlxG.camera.zoom = 1;
		else if (FlxG.keys.pressed.E && FlxG.camera.zoom < 3) {
			FlxG.camera.zoom += elapsed * FlxG.camera.zoom * shiftMult * ctrlMult;
			if(FlxG.camera.zoom > 3) FlxG.camera.zoom = 3;
		}
		else if (FlxG.keys.pressed.Q && FlxG.camera.zoom > 0.1) {
			FlxG.camera.zoom -= elapsed * FlxG.camera.zoom * shiftMult * ctrlMult;
			if(FlxG.camera.zoom < 0.1) FlxG.camera.zoom = 0.1;
		}

		if(lastZoom != FlxG.camera.zoom) cameraZoomText.text = 'Zoom: ' + FlxMath.roundDecimal(FlxG.camera.zoom, 2) + 'x';

		// CHARACTER CONTROLS
		var changedAnim:Bool = false;
		if(anims.length > 1)
		{
			if(FlxG.keys.justPressed.W && (changedAnim = true)) curAnim--;
			else if(FlxG.keys.justPressed.S && (changedAnim = true)) curAnim++;
			
			if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(animsTxt, camHUD)) {
				var p:Float = FlxMath.remapToRange(FlxG.mouse.getWorldPosition(camHUD).y, animsTxt.y, animsTxt.y + animsTxt.textField.textHeight, 0, anims.length);
				var animIndex:Int = Std.int(Math.min(p, anims.length - 1));
				if (curAnim != animIndex) {
					curAnim = animIndex;
					changedAnim = true;
				}
			}
			
			if(changedAnim)
			{
				undoOffsets = null;
				curAnim = FlxMath.wrap(curAnim, 0, anims.length-1);
				character.playAnim(anims[curAnim].anim, true);
				updateText();
			}
		}

		var changedOffset = false;
		var moveKeysP = [FlxG.keys.justPressed.LEFT, FlxG.keys.justPressed.RIGHT, FlxG.keys.justPressed.UP, FlxG.keys.justPressed.DOWN];
		var moveKeys = [FlxG.keys.pressed.LEFT, FlxG.keys.pressed.RIGHT, FlxG.keys.pressed.UP, FlxG.keys.pressed.DOWN];
		if(moveKeysP.contains(true))
		{
			character.offset.x += ((moveKeysP[0] ? 1 : 0) - (moveKeysP[1] ? 1 : 0)) * shiftMultBig;
			character.offset.y += ((moveKeysP[2] ? 1 : 0) - (moveKeysP[3] ? 1 : 0)) * shiftMultBig;
			changedOffset = true;
		}

		if(moveKeys.contains(true))
		{
			holdingArrowsTime += elapsed;
			if(holdingArrowsTime > 0.6)
			{
				holdingArrowsElapsed += elapsed;
				while(holdingArrowsElapsed > (1/60))
				{
					character.offset.x += ((moveKeys[0] ? 1 : 0) - (moveKeys[1] ? 1 : 0)) * shiftMultBig;
					character.offset.y += ((moveKeys[2] ? 1 : 0) - (moveKeys[3] ? 1 : 0)) * shiftMultBig;
					holdingArrowsElapsed -= (1/60);
					changedOffset = true;
				}
			}
		}
		else holdingArrowsTime = 0;

		if(FlxG.mouse.pressedRight && (FlxG.mouse.deltaViewX != 0 || FlxG.mouse.deltaViewY != 0))
		{
			character.offset.x -= FlxG.mouse.deltaViewX;
			character.offset.y -= FlxG.mouse.deltaViewY;
			changedOffset = true;
		}

		if(FlxG.keys.pressed.CONTROL)
		{
			if(FlxG.keys.justPressed.C)
			{
				copiedOffset[0] = character.offset.x;
				copiedOffset[1] = character.offset.y;
				changedOffset = true;
			}
			else if(FlxG.keys.justPressed.V)
			{
				undoOffsets = [character.offset.x, character.offset.y];
				character.offset.x = copiedOffset[0];
				character.offset.y = copiedOffset[1];
				changedOffset = true;
			}
			else if(FlxG.keys.justPressed.R)
			{
				undoOffsets = [character.offset.x, character.offset.y];
				character.offset.set(0, 0);
				changedOffset = true;
			}
			else if(FlxG.keys.justPressed.Z && undoOffsets != null)
			{
				character.offset.x = undoOffsets[0];
				character.offset.y = undoOffsets[1];
				changedOffset = true;
			}
		}

		var anim = anims[curAnim];
		if(changedOffset && anim != null)
		{
			// salva :thumbs1up:
			if (character.isPlayer)
			{
				if (anim.offsets_player == null) anim.offsets_player = [0, 0];
				anim.offsets_player[0] = Std.int(character.offset.x);
				anim.offsets_player[1] = Std.int(character.offset.y);
			}
			else
			{
				if (anim.offsets == null) anim.offsets = [0, 0];
				anim.offsets[0] = Std.int(character.offset.x);
				anim.offsets[1] = Std.int(character.offset.y);
			}

			character.addOffset(anim.anim, character.offset.x, character.offset.y);
			updateText();
		}

		var txt = 'ERROR: No Animation Found';
		var clr = FlxColor.RED;
		if(!character.isAnimationNull())
		{
			if(FlxG.keys.pressed.A || FlxG.keys.pressed.D)
			{
				holdingFrameTime += elapsed;
				if(holdingFrameTime > 0.5) holdingFrameElapsed += elapsed;
			}
			else holdingFrameTime = 0;

			if(FlxG.keys.justPressed.SPACE)
				character.playAnim(character.getAnimationName(), true);

			var frames:Int = -1;
			var length:Int = -1;
			if(!character.isAnimateAtlas && character.animation.curAnim != null)
			{
				frames = character.animation.curAnim.curFrame;
				length = character.animation.curAnim.numFrames;
			}
			else if(character.isAnimateAtlas && character.atlas.anim != null)
			{
				frames = character.atlas.getAtlasCurFrame();
				length = character.atlas.getAtlasLength();
			}

			if(length > 0)
			{
				if(FlxG.keys.justPressed.A || FlxG.keys.justPressed.D || holdingFrameTime > 0.5)
				{
					var isLeft = false;
					if((holdingFrameTime > 0.5 && FlxG.keys.pressed.A) || FlxG.keys.justPressed.A) isLeft = true;
					character.animPaused = true;
	
					if(holdingFrameTime <= 0.5 || holdingFrameElapsed > 0.1)
					{
						frames = FlxMath.wrap(frames + Std.int(isLeft ? -shiftMult : shiftMult), 0, length-1);
						if(!character.isAnimateAtlas) character.animation.curAnim.curFrame = frames;
						else character.atlas.setAtlasCurFrame(frames);
						holdingFrameElapsed -= 0.1;
					}
				}
	
				txt = 'Frames: ( $frames / ${length-1} )';
				//if(character.animation.curAnim.paused) txt += ' - PAUSED';
				clr = FlxColor.WHITE;
			}
		}
		if(txt != frameAdvanceText.text) frameAdvanceText.text = txt;
		frameAdvanceText.color = clr;

		// OTHER CONTROLS
		if(FlxG.keys.justPressed.F12)
			silhouettes.visible = !silhouettes.visible;

		if(FlxG.keys.justPressed.F1 || (helpBg.visible && FlxG.keys.justPressed.ESCAPE))
		{
			helpBg.visible = !helpBg.visible;
			helpTexts.visible = helpBg.visible;
		}
		else if(FlxG.keys.justPressed.ESCAPE)
		{
			if(!_goToPlayState)
			{
				if(!unsavedProgress)
				{
					MusicBeatState.switchState(new states.MainMenuState(true));
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
				}
				else openSubState(new ExitConfirmationPrompt());
			}
			else
			{
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(new PlayState());
			}
			return;
		}
		
		postUpdate(elapsed);
	}

	final assetFolder = 'week1';  //load from assets/week1/
	inline function loadBG()
	{
		var lastLoaded = Paths.currentLevel;
		Paths.currentLevel = assetFolder;

		/////////////
		// bg data //
		/////////////
		#if !BASE_GAME_FILES
		camEditor.bgColor = 0xFF666666;
		#else
		var bg:BGSprite = new BGSprite('stageback', -600, -200, 0.9, 0.9);
		add(bg);

		var stageFront:BGSprite = new BGSprite('stagefront', -650, 600, 0.9, 0.9);
		stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
		stageFront.updateHitbox();
		add(stageFront);
		#end

		dadPosition.set(100, 100);
		bfPosition.set(770, 100);
		/////////////

		Paths.currentLevel = lastLoaded;
	}

	inline function updatePointerPos(?snap:Bool = true)
	{
		if(character == null || cameraFollowPointer == null) return;

		var offX:Float = 0;
		var offY:Float = 0;
		if(!character.isPlayer)
		{
			offX = character.getMidpoint().x + 150 + character.cameraPosition[0];
			offY = character.getMidpoint().y - 100 + character.cameraPosition[1];
		}
		else
		{
			offX = character.getMidpoint().x - 100 - character.cameraPosition[0];
			offY = character.getMidpoint().y - 100 + character.cameraPosition[1];
		}
		cameraFollowPointer.setPosition(offX, offY);

		if(snap)
		{
			FlxG.camera.scroll.x = cameraFollowPointer.getMidpoint().x - FlxG.width/2;
			FlxG.camera.scroll.y = cameraFollowPointer.getMidpoint().y - FlxG.height/2;
		}
	}

	inline function updateHealthBar()
	{
		var color:FlxColor = FlxColor.fromRGB(character.healthColorArray[0], character.healthColorArray[1], character.healthColorArray[2]);
		if(healthColorStepperR != null) healthColorStepperR.value = character.healthColorArray[0];
		if(healthColorStepperG != null) healthColorStepperG.value = character.healthColorArray[1];
		if(healthColorStepperB != null) healthColorStepperB.value = character.healthColorArray[2];
		if(healthBar != null) healthBar.leftBar.color = healthBar.rightBar.color = color;
		if(healthColorPreview != null) healthColorPreview.color = color;
		if(healthIcon != null)
		{
			var lastIcon:String = healthIcon.getCharacter();
			healthIcon.changeIcon(character.healthIcon, false);
			if(lastIcon != healthIcon.getCharacter())
			{
				healthIconPreviewFrame = 0;
				healthIconPreviewBump = 0;
			}
			layoutHealthIconPanel();
		}
		updatePresence();
	}
	
	override function updatePresence() {
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Character Editor", "Character: " + _char, healthIcon.getCharacter());
		#end
	}

	inline function reloadAnimList()
	{
		anims = character.animationsArray;
		if(anims.length > 0) character.playAnim(anims[0].anim, true);
		curAnim = 0;

		updateText();
		if(animationDropDown != null) reloadAnimationDropDown();
	}

	inline function updateText()
	{
		animsTxt.removeFormat(selectedFormat);

		var intendText:String = '';
		var burroSuffix:String = character.isPlayer ? ' [P]' /*Player*/ : ' [O]'; /*Oponente*/
		for (num => anim in anims)
		{
			if(num > 0) intendText += '\n';

			var curOffsets:Array<Int> = (character.isPlayer && anim.offsets_player != null) ? anim.offsets_player : anim.offsets;

			if(num == curAnim)
			{
				var n:Int = intendText.length;
				intendText += anim.anim + burroSuffix + ": " + curOffsets;
				animsTxt.addFormat(selectedFormat, n, intendText.length);
			}
			else intendText += anim.anim + ": " + curOffsets;
		}
		animsTxt.text = intendText;
		updateOffsetTextLayout();
	}

	inline function updateCharacterPositions()
	{
		if((character != null && !character.isPlayer) || (character == null && predictCharacterIsNotPlayer(_char))) character.setPosition(dadPosition.x, dadPosition.y);
		else character.setPosition(bfPosition.x, bfPosition.y);

		character.x += character.positionArray[0];
		character.y += character.positionArray[1];
		updatePointerPos(false);
	}

	inline function predictCharacterIsNotPlayer(name:String)
	{
		return (name != 'bf' && !name.startsWith('bf-') && !name.endsWith('-player') && !name.endsWith('-playable') && !name.endsWith('-dead')) ||
				name.endsWith('-opponent') || name.startsWith('gf-') || name.endsWith('-gf') || name == 'gf';
	}

	function addAnimation(anim:String, name:String, fps:Float, loop:Bool, indices:Array<Int>)
	{
		if(!character.isAnimateAtlas)
		{
			if(indices != null && indices.length > 0)
				character.animation.addByIndices(anim, name, indices, "", fps, loop);
			else
				character.animation.addByPrefix(anim, name, fps, loop);
		}
		else
		{
			character.atlas.addAtlasAnimation(anim, name, indices, fps, loop);
		}

		if(!character.hasAnimation(anim))
			character.addOffset(anim, 0, 0);
	}

	inline function newAnim(anim:String, name:String):AnimArray
	{
		return {
			offsets: [0, 0],
			loop: false,
			fps: 24,
			anim: anim,
			indices: [],
			name: name
		};
	}

	var characterList:Array<String> = [];
	function reloadCharacterDropDown() {
		characterList = Mods.mergeAllTextsNamed('data/characterList.txt');
		Character.appendCharacterFileList(characterList);

		if(characterList.length < 1) characterList.push('');
		charDropDown.list = characterList;
		charDropDown.selectedLabel = _char;
	}

	function reloadAnimationDropDown() {
		var animList:Array<String> = [];
		for (anim in anims) animList.push(anim.anim);
		if(animList.length < 1) animList.push('NO ANIMATIONS'); //Prevents crash

		animationDropDown.list = animList;
	}

	// save
	var _file:FileReference;
	function onSaveComplete(_):Void
	{
		if(_file == null) return;
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		Character.clearCharacterCache();
		unsavedProgress = false;
		reloadCharacterDropDown();
		FlxG.log.notice("Successfully saved file.");
	}

	/**
		* Called when the save file dialog is cancelled.
		*/
	function onSaveCancel(_):Void
	{
		if(_file == null) return;
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
		* Called if there is an error while saving the gameplay recording.
		*/
	function onSaveError(_):Void
	{
		if(_file == null) return;
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving file");
	}

	function xmlEscape(value:String):String
	{
		if(value == null) return '';
		return value.replace('&', '&amp;').replace('"', '&quot;').replace('<', '&lt;').replace('>', '&gt;');
	}

	function xmlBool(value:Bool):String
		return value ? 'true' : 'false';

	function xmlNumber(value:Float):String
		return Std.string(FlxMath.roundDecimal(value, 4));

	function xmlColor():String
	{
		var color:FlxColor = FlxColor.fromRGB(character.healthColorArray[0], character.healthColorArray[1], character.healthColorArray[2]);
		return '#' + color.toHexString(false, false);
	}

	function buildCharacterXml():String
	{
		var assets:Array<String> = character.imageFile != null ? character.imageFile.split(',') : [];
		var cleanedAssets:Array<String> = [];
		for(asset in assets)
		{
			var trimmed:String = asset.trim();
			if(trimmed.length > 0 && !cleanedAssets.contains(trimmed))
				cleanedAssets.push(trimmed);
		}
		if(cleanedAssets.length < 1)
			cleanedAssets.push('characters/bf');

		var output:StringBuf = new StringBuf();
		output.add('<?xml version="1.0" encoding="utf-8"?>\n');
		output.add('<character assetPath="${xmlEscape(cleanedAssets[0])}" icon="${xmlEscape(character.healthIcon)}" scale="${xmlNumber(character.jsonScale)}" ');
		output.add('singDuration="${xmlNumber(character.singDuration)}" x="${xmlNumber(character.positionArray[0])}" y="${xmlNumber(character.positionArray[1])}" ');
		output.add('cameraX="${xmlNumber(character.cameraPosition[0])}" cameraY="${xmlNumber(character.cameraPosition[1])}" ');
		output.add('flipX="${xmlBool(character.originalFlipX)}" noAntialiasing="${xmlBool(character.noAntialiasing)}" ');
		output.add('healthColor="${xmlColor()}" vocalsFile="${xmlEscape(character.vocalsFile)}" vsliceHolds="${xmlBool(character.vSliceSustains)}">\n');

		output.add('\t<assets>\n');
		for(asset in cleanedAssets)
			output.add('\t\t<asset path="${xmlEscape(asset)}"/>\n');
		output.add('\t</assets>\n');

		output.add('\t<animations>\n');
		for(anim in character.animationsArray)
		{
			if(anim == null || anim.anim == null || anim.name == null) continue;
			var offsets:Array<Int> = (anim.offsets != null && anim.offsets.length > 1) ? anim.offsets : [0, 0];
			var playerOffsets:Array<Int> = (anim.offsets_player != null && anim.offsets_player.length > 1) ? anim.offsets_player : offsets;
			output.add('\t\t<anim id="${xmlEscape(anim.anim)}" symbol="${xmlEscape(anim.name)}" fps="${anim.fps}" loop="${xmlBool(anim.loop)}" ');
			if(anim.name_opponent != null && anim.name_opponent.length > 0)
				output.add('opponentSymbol="${xmlEscape(anim.name_opponent)}" ');
			if(anim.name_player != null && anim.name_player.length > 0)
				output.add('playerSymbol="${xmlEscape(anim.name_player)}" ');
			output.add('x="${offsets[0]}" y="${offsets[1]}" playerX="${playerOffsets[0]}" playerY="${playerOffsets[1]}"');
			if(anim.indices != null && anim.indices.length > 0)
				output.add(' indices="${anim.indices.join(',')}"');
			if(anim.indices_opponent != null && anim.indices_opponent.length > 0)
				output.add(' opponentIndices="${anim.indices_opponent.join(',')}"');
			if(anim.indices_player != null && anim.indices_player.length > 0)
				output.add(' playerIndices="${anim.indices_player.join(',')}"');
			output.add('/>\n');
		}
		output.add('\t</animations>\n');
		output.add('</character>\n');
		return output.toString();
	}

	function saveCharacter() {
		if(_file != null) return;
		if(assetPathInputs != null && assetPathInputs.length > 0)
			syncImageFromAssetInputs();
		storeCurrentOffsetForMode();

		var data:String = buildCharacterXml();

		if (data.length > 0)
		{
			_file = new FileReference();
			_file.addEventListener(#if desktop Event.SELECT #else Event.COMPLETE #end, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data, '$_char.xml');
		}
	}
}

class CharacterHealthColorPicker extends MusicBeatSubstate
{
	var originalColor:FlxColor;
	var selectedColor:FlxColor;
	var presets:Array<FlxColor>;
	var callback:FlxColor->Void;

	var bg:FlxSprite;
	var panel:FlxSprite;
	var colorWheel:FlxSprite;
	var colorWheelSelector:FlxShapeCircle;
	var colorGradient:FlxSprite;
	var colorGradientSelector:FlxSprite;
	var colorPreview:FlxSprite;
	var colorHexText:FlxText;
	var holdingColorPicker:FlxSprite;
	var storedPickerColor:FlxColor = FlxColor.WHITE;
	var presetSprites:Array<FlxSprite> = [];

	public function new(color:FlxColor, presets:Array<FlxColor>, callback:FlxColor->Void)
	{
		originalColor = color;
		selectedColor = color;
		this.presets = presets;
		this.callback = callback;
		super();
	}

	override function create()
	{
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.55;
		bg.scrollFactor.set();
		bg.cameras = cameras;
		add(bg);

		panel = new FlxSprite();
		HaxeUITheme.drawRoundedBox(panel, 300, 246, HaxeUITheme.BG, 0.96);
		panel.screenCenter();
		panel.scrollFactor.set();
		panel.cameras = cameras;
		add(panel);

		var title:FlxText = new FlxText(panel.x, panel.y + 14, panel.width, 'Health Bar Color', 14);
		title.alignment = CENTER;
		title.scrollFactor.set();
		title.cameras = cameras;
		add(title);

		colorGradient = FlxGradient.createGradientFlxSprite(18, 118, [FlxColor.WHITE, FlxColor.BLACK]);
		colorGradient.setPosition(panel.x + 24, panel.y + 48);
		colorGradient.scrollFactor.set();
		colorGradient.cameras = cameras;
		add(colorGradient);

		colorGradientSelector = new FlxSprite(colorGradient.x - 4, colorGradient.y).makeGraphic(26, 6, FlxColor.WHITE);
		colorGradientSelector.offset.y = 3;
		colorGradientSelector.scrollFactor.set();
		colorGradientSelector.cameras = cameras;
		add(colorGradientSelector);

		colorWheel = new FlxSprite(panel.x + 54, panel.y + 48).loadGraphic(Paths.image('noteColorMenu/colorWheel'));
		colorWheel.setGraphicSize(118, 118);
		colorWheel.updateHitbox();
		colorWheel.scrollFactor.set();
		colorWheel.cameras = cameras;
		add(colorWheel);

		colorWheelSelector = new FlxShapeCircle(0, 0, 5, {thickness: 0}, FlxColor.WHITE);
		colorWheelSelector.offset.set(5, 5);
		colorWheelSelector.alpha = 0.72;
		colorWheelSelector.scrollFactor.set();
		colorWheelSelector.cameras = cameras;
		add(colorWheelSelector);

		colorPreview = new FlxSprite(panel.x + 194, panel.y + 50).makeGraphic(58, 42, FlxColor.WHITE);
		colorPreview.scrollFactor.set();
		colorPreview.cameras = cameras;
		add(colorPreview);

		colorHexText = new FlxText(panel.x + 184, panel.y + 98, 78, '#FFFFFF', 12);
		colorHexText.alignment = CENTER;
		colorHexText.scrollFactor.set();
		colorHexText.cameras = cameras;
		add(colorHexText);

		var swatchY:Float = panel.y + 132;
		for(i in 0...presets.length)
		{
			var swatch:FlxSprite = new FlxSprite(panel.x + 190 + i * 28, swatchY).makeGraphic(24, 20, FlxColor.WHITE);
			swatch.color = presets[i];
			swatch.scrollFactor.set();
			swatch.cameras = cameras;
			presetSprites.push(swatch);
			add(swatch);
		}

		var okButton:PsychUIButton = new PsychUIButton(panel.x + 74, panel.y + 202, 'OK', function() close(), 70);
		okButton.cameras = cameras;
		add(okButton);

		var cancelButton:PsychUIButton = new PsychUIButton(panel.x + 156, panel.y + 202, 'Cancel', function()
		{
			setColor(originalColor);
			close();
		}, 70);
		cancelButton.cameras = cameras;
		add(cancelButton);

		updateColorPicker();
		super.create();
	}

	function setColor(color:FlxColor):Void
	{
		selectedColor = color;
		if(callback != null) callback(selectedColor);
		updateColorPicker();
	}

	function updateColorPicker(?specific:Null<FlxColor>):Void
	{
		if(colorWheel == null) return;

		var wheelColor:FlxColor = specific == null ? selectedColor : specific;
		colorPreview.color = selectedColor;
		colorHexText.text = '#' + selectedColor.toHexString(false, false);
		colorWheel.color = FlxColor.fromHSB(0, 0, selectedColor.brightness);

		colorWheelSelector.setPosition(colorWheel.x + colorWheel.width / 2, colorWheel.y + colorWheel.height / 2);
		if(wheelColor.brightness != 0)
		{
			var hueWrap:Float = wheelColor.hue * Math.PI / 180;
			colorWheelSelector.x += Math.sin(hueWrap) * colorWheel.width / 2 * wheelColor.saturation;
			colorWheelSelector.y -= Math.cos(hueWrap) * colorWheel.height / 2 * wheelColor.saturation;
		}
		colorGradientSelector.y = colorGradient.y + colorGradient.height * (1 - selectedColor.brightness);
	}

	function updateColorPickerInput():Void
	{
		if(holdingColorPicker == null) return;

		var mouse:FlxPoint = FlxG.mouse.getViewPosition(cameras[0]);
		if(holdingColorPicker == colorGradient)
		{
			var newBrightness:Float = 1 - FlxMath.bound((mouse.y - colorGradient.y) / colorGradient.height, 0, 1);
			if(storedPickerColor.brightness == 0)
				setColor(FlxColor.fromRGBFloat(newBrightness, newBrightness, newBrightness));
			else
				setColor(FlxColor.fromHSB(storedPickerColor.hue, storedPickerColor.saturation, newBrightness));
			updateColorPicker(storedPickerColor);
		}
		else if(holdingColorPicker == colorWheel)
		{
			var center:FlxPoint = FlxPoint.get(colorWheel.x + colorWheel.width / 2, colorWheel.y + colorWheel.height / 2);
			var cX:Float = (center.x - mouse.x) / colorWheel.width * 2;
			var cY:Float = (center.y - mouse.y) / colorWheel.height * 2;
			var hue:Float = FlxMath.wrap(FlxMath.wrap(Std.int(mouse.degreesTo(center)), 0, 360) - 90, 0, 360);
			var sat:Float = FlxMath.bound(Math.sqrt(cX * cX + cY * cY), 0, 1);
			if(sat != 0)
				setColor(FlxColor.fromHSB(hue, sat, storedPickerColor.brightness));
			else
				setColor(FlxColor.fromRGBFloat(storedPickerColor.brightness, storedPickerColor.brightness, storedPickerColor.brightness));
			center.put();
		}
		mouse.put();
	}

	function mouseOverSprite(sprite:FlxSprite):Bool
		return sprite != null && FlxG.mouse.overlaps(sprite, cameras[0]);

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(FlxG.keys.justPressed.ESCAPE)
		{
			setColor(originalColor);
			close();
			return;
		}

		if(FlxG.mouse.justPressed)
		{
			for(i in 0...presetSprites.length)
			{
				if(mouseOverSprite(presetSprites[i]))
				{
					setColor(presets[i]);
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.45);
					return;
				}
			}

			if(mouseOverSprite(colorWheel))
				holdingColorPicker = colorWheel;
			else if(mouseOverSprite(colorGradient))
				holdingColorPicker = colorGradient;
			else
				holdingColorPicker = null;

			if(holdingColorPicker != null)
			{
				storedPickerColor = selectedColor;
				updateColorPickerInput();
			}
		}
		else if(holdingColorPicker != null)
		{
			if(FlxG.mouse.justReleased)
			{
				holdingColorPicker = null;
				storedPickerColor = selectedColor;
				updateColorPicker();
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.45);
			}
			else if(FlxG.mouse.pressed && (FlxG.mouse.justMoved || FlxG.mouse.deltaViewX != 0 || FlxG.mouse.deltaViewY != 0))
				updateColorPickerInput();
		}
	}
}
