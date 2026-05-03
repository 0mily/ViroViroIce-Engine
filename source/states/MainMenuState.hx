package states;

import flixel.FlxObject;
import flixel.effects.FlxFlicker;
import flixel.graphics.frames.FlxFrame;
import lime.app.Application;
import backend.Highscore;
import states.editors.MasterEditorMenu;
import options.OptionsState;

using Lambda;

enum abstract MainMenuColumn(String) to String {
	var LEFT = 'left';
	var CENTER = 'center';
	var RIGHT = 'right';
}

class MainMenuState extends ScriptedState
{
	public static var psychEngineVersion:String = '0.0.5';
	public static var modVersion = '0.1.6';
	public static var curSelected:Int = 0;
	public static var curColumn:MainMenuColumn = CENTER;
	var allowMouse:Bool = true; //Turn this off to block mouse movement in menus

	var menuItems:FlxTypedSpriteGroup<MenuItem>;
	var selectedItem:MenuItem = null;
	var itemYPadding:Float = 25;
	var itemSpacing:Float = 140;
	var rightItem:MenuItem;
	var leftItem:MenuItem;
	var psychVer:FlxText;
	var emiVer:FlxText;

	//Centered/Text options
	var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		#if MODS_ALLOWED 'mods', #end
		'credits',
		'options'
	];
	var menuFunctions:Map<String, MenuItem -> Void> = [];

	var rightOption:String = #if ACHIEVEMENTS_ALLOWED 'achievements' #else null #end;
	var leftOption:String = null;
	
	var bg:FlxSprite;
	var magenta:FlxSprite;
	var camFollow:FlxObject;
	
	var justEntered:Bool = true;

	static var showOutdatedWarning:Bool = true;
	var openDebugMenu:Bool = false;
	public function new(debug:Bool = false) {
		super();
		openDebugMenu = debug;
	}
	override function create() {
		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();
		
		rpcDetails = 'In the Menus';

		persistentUpdate = persistentDraw = true;
		
		preCreate();
		
		bg = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		add(camFollow = new FlxObject(0, 0, 1, 1));
		FlxG.camera.follow(camFollow, null, .2);

		magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		magenta.antialiasing = ClientPrefs.data.antialiasing;
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.color = 0xFFfd719b;
		add(magenta);

		menuItems = new FlxTypedSpriteGroup();
		menuFunctions['story_mode'] ??= (item:MenuItem) -> MusicBeatState.switchState(new StoryMenuState());
		menuFunctions['freeplay'] ??= (item:MenuItem) -> MusicBeatState.switchState(new FreeplayState());
		menuFunctions['mods'] ??= (item:MenuItem) -> MusicBeatState.switchState(new ModsMenuState());
		menuFunctions['credits'] ??= (item:MenuItem) -> MusicBeatState.switchState(new CreditsState());
		menuFunctions['options'] ??= (item:MenuItem) -> {
			MusicBeatState.switchState(new OptionsState());
			OptionsState.onPlayState = false;
			if (PlayState.SONG != null) {
				PlayState.SONG.arrowSkin = null;
				PlayState.SONG.splashSkin = null;
				PlayState.stageUI = 'normal';
			}
		};
		#if ACHIEVEMENTS_ALLOWED menuFunctions['achievements'] ??= (item:MenuItem) -> MusicBeatState.switchState(new AchievementsMenuState()); #end
		
		for (option in optionShit)
			addMenuItem(option);

		emiVer = new FlxText(12, FlxG.height - 24, 0, 'Built on Psych Engine Mint $psychEngineVersion', 11);
		emiVer.scrollFactor.set();
		emiVer.setFormat(Paths.font("vcr.ttf"), 15, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(emiVer);
		psychVer = new FlxText(12, FlxG.height - 40, 0, 'ViroViroIce $modVersion', 12);
		psychVer.scrollFactor.set();
		psychVer.setFormat(Paths.font("vcr.ttf"), 15, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(psychVer);

		#if ACHIEVEMENTS_ALLOWED
		// Unlocks "Freaky on a Friday Night" achievement if it's a Friday and between 18:00 PM and 23:59 PM
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
			Achievements.unlock('friday_night_play');

		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end
		
		subStateClosed.add((sub:flixel.FlxSubState) -> {
			if (sub is CustomFadeTransition) return;
			
			fade(true);
			pause(false);
		});
		subStateOpened.add((sub:flixel.FlxSubState) -> pause(true));
		if (openDebugMenu) {
			openSubState(new MasterEditorMenu(true));
			FlxTransitionableState.skipNextTransOut = true;
		}

		#if CHECK_FOR_UPDATES
		if (showOutdatedWarning && ClientPrefs.data.checkForUpdates && substates.OutdatedSubState.updateVersion > modVersion) {
			persistentUpdate = false;
			showOutdatedWarning = false;
			openSubState(new substates.OutdatedSubState());
		}
		#end
		
		if (rightOption != null)
			rightItem = addMenuItem(rightOption, null, RIGHT);
		if (leftOption != null)
			leftItem = addMenuItem(leftOption, null, LEFT);
		
		add(menuItems);
		
		super.create();
		
		changeItem(true);
		refreshShitScript();
		FlxG.camera.snapToTarget();
	}

	function refreshShitScript():Void {
		var curItem:MenuItem = switch (curColumn) {
			case LEFT: leftItem;
			case CENTER: (menuItems != null && menuItems.length > 0) ? menuItems.members[curSelected] : null;
			case RIGHT: rightItem;
		}

		setOnScripts('curSelected', curSelected);
		setOnScripts('curColumn', curColumn);
		setOnScripts('selectedItemName', curItem?.name);
		setOnScripts('menuItemNames', [for (item in menuItems.members) if (item != null) item.name]);
		setOnScripts('menuItemsGroup', 'menuItems');
		setOnScripts('bg', 'bg');
		setOnScripts('magenta', 'magenta');
		setOnScripts('camFollow', 'camFollow');
		setOnScripts('EngineVerTxt', 'emiVer');
		setOnScripts('FNFVerTxt', 'psychVer');
		setOnScripts('storymode', 'story_mode');
		setOnScripts('freeplay', 'freeplay');
		setOnScripts('mods', 'mods');
		setOnScripts('options', 'options');
		setOnScripts('credits', 'credits');
		setOnScripts('awards', 'achievements');
	}
	
	function pause(yea:Bool):Void {
		if (justEntered && !openDebugMenu)
			yea = false;
		
		FlxG.mouse.visible = !yea;
		selectedSomethin = yea;
		justEntered = false;
	}

	function addMenuItem(name:String, ?onAccept:MenuItem -> Void, column:MainMenuColumn = CENTER):MenuItem {
		var item:MenuItem = new MenuItem(0, 0, name, onAccept ?? menuFunctions[name]);
		item.column = column;
		
		switch (column) {
			case CENTER:
				menuItems.add(item);
				positionMenuItems();
				
			case LEFT:
				if (leftItem != null) {
					trace('left slot already occupied by ${leftItem.name}!');
					return item;
				}
				
				item.setPosition(50, FlxG.height - item.height - 50);
				leftItem = item;
				add(item);
				updateYScroll();
				
			case RIGHT:
				if (rightItem != null) {
					trace('right slot already occupied by ${rightItem.name}!');
					return item;
				}
				
				item.setPosition(FlxG.width - item.width - 50, FlxG.height - item.height - 50);
				rightItem = item;
				add(item);
				updateYScroll();
		}
		
		return item;
	}

	function getMenuItemByName(name:String, ?column:MainMenuColumn):MenuItem {
		if (name == null) return null;

		if (column == null || column == CENTER)
			for (item in menuItems.members)
				if (item != null && item.name == name)
					return item;

		if ((column == null || column == LEFT) && leftItem != null && leftItem.name == name)
			return leftItem;
		if ((column == null || column == RIGHT) && rightItem != null && rightItem.name == name)
			return rightItem;
		return null;
	}

	function removeMenuItemByName(name:String, destroy:Bool = true):Bool {
		var item = getMenuItemByName(name);
		if (item == null)
			return false;

		if (item == leftItem) {
			remove(leftItem, destroy);
			if (destroy) leftItem.destroy();
			leftItem = null;
		} else if (item == rightItem) {
			remove(rightItem, destroy);
			if (destroy) rightItem.destroy();
			rightItem = null;
		} else {
			menuItems.remove(item, destroy);
			if (destroy) item.destroy();
			if (menuItems.length > 0)
				curSelected = FlxMath.wrap(curSelected, 0, menuItems.length - 1);
			else
				curSelected = 0;

			if (selectedItem == item)
				selectedItem = null;
			positionMenuItems();
		}

		updateYScroll();
		refreshShitScript();
		return true;
	}

	function reorderMenuItems(order:Array<String>):Array<String> {
		if (order == null)
			return [for (item in menuItems.members) if (item != null) item.name];

		var insertAt:Int = 0;
		for (name in order) {
			var item = getMenuItemByName(name, CENTER);
			if (item == null)
				continue;

			menuItems.remove(item, false);
			menuItems.insert(insertAt, item);
			insertAt++;
		}

		positionMenuItems();
		refreshShitScript();
		return [for (item in menuItems.members) if (item != null) item.name];
	}
	
	function positionMenuItems():Void {
		for (i => item in menuItems.members) {
			item.setPosition(0, i * itemSpacing + (FlxG.height - menuItems.length * itemSpacing) * .5);
			item.screenCenter(X);
		}
		
		updateYScroll();
	}
	
	function getAllMenuItems():Array<MenuItem> {
		var items:Array<MenuItem> = [];
		
		for (item in menuItems) items.push(item);
		if (leftItem != null) items.push(leftItem);
		if (rightItem != null) items.push(rightItem);
		
		return items;
	}
	
	function updateYScroll():Void {
		var itemYScroll:Float = Math.min(1, Math.max(menuItems.height - FlxG.height + itemYPadding, 0) / FlxG.height * .35 + .25);
		menuItems?.scrollFactor.set(.04, itemYScroll);
		
		var yScroll:Float = (.7 / menuItems.length);
		leftItem?.scrollFactor.set(0, yScroll * .25);
		rightItem?.scrollFactor.set(0, yScroll * .25);
		
		bg.scrollFactor.set(0, yScroll * .75);
		magenta.scrollFactor.copyFrom(bg.scrollFactor);
	}
	
	var selectedSomethin:Bool = false;
	
	var timeNotMoving:Float = 0;
	override function update(elapsed:Float)
	{
		preUpdate(elapsed);
		
		if (FlxG.sound.music == null)
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.8);
		else if (FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);

		var blockedFNFInput:Bool = (callOnScripts('onInputUpdate', [elapsed], true) == psychlua.LuaUtils.Function_Stop);

		if (!selectedSomethin && !blockedFNFInput)
		{
			if (controls.UI_UP_P)
				changeItem(-1);

			if (controls.UI_DOWN_P)
				changeItem(1);

			var allowMouse:Bool = allowMouse;
			if (allowMouse && (FlxG.mouse.deltaViewX != 0 || FlxG.mouse.deltaViewY != 0 || FlxG.mouse.justPressed)) {
				FlxG.mouse.visible = true;
				allowMouse = false;
				timeNotMoving = 0;

				var selectedItem:FlxSprite;
				switch(curColumn) {
					case LEFT:
						selectedItem = leftItem;
					case CENTER:
						selectedItem = menuItems.members[curSelected];
					case RIGHT:
						selectedItem = rightItem;
				}

				if (rightItem != null && FlxG.mouse.overlaps(rightItem)) {
					allowMouse = true;
					if (selectedItem != rightItem)
						changeItem(RIGHT);
				} else if (leftItem != null && FlxG.mouse.overlaps(leftItem)) {
					allowMouse = true;
					if (selectedItem != leftItem)
						changeItem(LEFT);
				} else {
					var dist:Float = -1;
					var distItem:Int = -1;
					for (i => memb in menuItems.members) {
						if (memb.column != CENTER) continue;
						
						if (FlxG.mouse.overlaps(memb)) {
							var distance:Float = Math.sqrt(Math.pow(memb.getGraphicMidpoint().x - FlxG.mouse.viewX, 2) + Math.pow(memb.getGraphicMidpoint().y - FlxG.mouse.viewY, 2));
							if (dist < 0 || distance < dist) {
								dist = distance;
								distItem = i;
								allowMouse = true;
							}
						}
					}

					if (distItem != -1 && selectedItem != menuItems.members[distItem])
						changeItem(distItem - curSelected);
				}
			} else {
				timeNotMoving += elapsed;
				if (timeNotMoving > 2)
					FlxG.mouse.visible = false;
			}

			switch(curColumn) {
				case LEFT:
					if (controls.UI_RIGHT_P)
						changeItem(CENTER);
					
				case CENTER:
					if (controls.UI_RIGHT_P && rightItem != null) {
						changeItem(RIGHT);
					} else if (controls.UI_LEFT_P && leftItem != null) {
						changeItem(LEFT);
					}

				case RIGHT:
					if (controls.UI_LEFT_P)
						changeItem(CENTER);
			}

			if (controls.BACK) {
				if (callOnScripts('onBack', true) != psychlua.LuaUtils.Function_Stop) {
					FlxG.sound.play(Paths.sound('cancelMenu'));
					MusicBeatState.switchState(new TitleState());
				}
			}

			if (controls.ACCEPT || (FlxG.mouse.justPressed && allowMouse)) {
				var item:MenuItem = switch(curColumn) {
					case LEFT: leftItem;
					case CENTER: menuItems.members[curSelected];
					case RIGHT: rightItem;
				}
				
				var blockedFNF:Bool = (callOnScriptsExt('onSelected', [item.name, curSelected, curColumn], [item, curSelected, curColumn], true) == psychlua.LuaUtils.Function_Stop);
				blockedFNF = (blockedFNF || callOnScriptsExt('onAccept', [curSelected], [item, curSelected], true) == psychlua.LuaUtils.Function_Stop);
				if (!blockedFNF) {
					FlxG.sound.play(Paths.sound('confirmMenu'));
					selectedSomethin = true;
					FlxG.mouse.visible = false;
					
					if (ClientPrefs.data.flashing)
						FlxFlicker.flicker(magenta, 1.1, 0.15, false);
					
					FlxFlicker.flicker(item, 1, 0.06, false, false, (flick:FlxFlicker) -> {
						if (item.onAccept != null) {
							item.onAccept(item);
						} else {
							trace('Menu Item "${item.name}" doesn\'t do anything');
							selectedSomethin = false;
							item.visible = true;
							
							fade(true, item);
						}
					});
					
					fade(false, item);
				}
			}
			if (controls.justPressed('debug_1')) {
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				openSubState(new MasterEditorMenu());
			}
		}

		super.update(elapsed);
		
		postUpdate(elapsed);
	}
	
	function fade(fadeIn:Bool = false, ?ignore:MenuItem):Void {
		for (item in getAllMenuItems()) {
			if (item == ignore)
				continue;
			
			if (fadeIn)
				item.visible = true;
			FlxTween.cancelTweensOf(item);
			FlxTween.tween(item, {alpha: fadeIn ? 1 : 0}, 0.4, {ease: FlxEase.quadOut});
		}
	}

	function changeItem(change:Int = 0, column:MainMenuColumn = CENTER, forced:Bool = false)
	{
		var oldColumn:MainMenuColumn = curColumn;
		var oldSelected:Int = curSelected;
		
		if (column == CENTER)
			curSelected = FlxMath.wrap(curSelected + change, 0, menuItems.length - 1);
		
		if (change != 0) {
			curColumn = CENTER;
		} else {
			curColumn = column;
		}

		var newSelectedItem:MenuItem;
		switch(curColumn) {
			case LEFT:
				newSelectedItem = leftItem;
			case CENTER:
				newSelectedItem = menuItems.members[curSelected];
			case RIGHT:
				newSelectedItem = rightItem;
		}
		
		var blockedFNF:Bool = false;
		if (!forced) {
			blockedFNF = (callOnScriptsExt('onHighlighted', [newSelectedItem.name, curSelected, curColumn], [newSelectedItem, curSelected, curColumn], true) == psychlua.LuaUtils.Function_Stop);
			blockedFNF = (blockedFNF || callOnScriptsExt('onSelectItem', [curSelected], [selectedItem, curSelected], true) == psychlua.LuaUtils.Function_Stop);
		}

		if (forced || !blockedFNF) {
			if (selectedItem != null)
				selectedItem.selected = false;
			newSelectedItem.selected = true;
			selectedItem = newSelectedItem;
			
			if (change != 0 || curColumn != oldColumn)
				FlxG.sound.play(Paths.sound('scrollMenu'));
			
			if (leftItem != null) {
				FlxTween.cancelTweensOf(leftItem.scrollFactor, ['x']);
				FlxTween.tween(leftItem.scrollFactor, {x: (column == LEFT ? .08 : .01)}, .2, {ease: FlxEase.quartOut});
			}
			if (rightItem != null) {
				FlxTween.cancelTweensOf(rightItem.scrollFactor, ['x']);
				FlxTween.tween(rightItem.scrollFactor, {x: (column == RIGHT ? .08 : .01)}, .2, {ease: FlxEase.quartOut});
			}
			
			if (column == CENTER)
				camFollow.y = selectedItem.getGraphicMidpoint().y;
			camFollow.x = selectedItem.getGraphicMidpoint().x;
			
			refreshShitScript();
			callOnScriptsExt('onHighlightedPost', [selectedItem.name, curSelected, curColumn], [selectedItem, curSelected, curColumn]);
			callOnScriptsExt('onSelectItemPost', [curSelected], [selectedItem, curSelected]);
		} else {
			curColumn = oldColumn;
			curSelected = oldSelected;
		}
	}

	#if LUA_ALLOWED
	public override function implementLua(lua:psychlua.FunkinLua):Void {
		super.implementLua(lua);

		lua.addLocalCallback('addItemMenu', function(item:String, imagePath:String = '', fps:Float = 24, column:String = 'center', insertAt:Int = -1) {
			switch (column.toLowerCase()) {
				case 'left':
					if (leftItem != null) return false;
					addMenuItem(item, menuFunctions[item], LEFT);
					if (imagePath != null && imagePath.trim().length > 0)
						leftItem.loadSprite(item, imagePath, fps);

				case 'right':
					if (rightItem != null) return false;
					addMenuItem(item, menuFunctions[item], RIGHT);
					if (imagePath != null && imagePath.trim().length > 0)
						rightItem.loadSprite(item, imagePath, fps);

				default:
					var added = addMenuItem(item, menuFunctions[item], CENTER);
					if (imagePath != null && imagePath.trim().length > 0)
						added.loadSprite(item, imagePath, fps);
					if (insertAt >= 0) {
						menuItems.remove(added, false);
						menuItems.insert(Std.int(Math.min(insertAt, menuItems.length)), added);
						positionMenuItems();
					}
			}

			refreshShitScript();
			return true;
		});
		lua.addLocalCallback('removeItemMenu', function(item:String) {
			return removeMenuItemByName(item);
		});
		lua.addLocalCallback('setItemOrder', function(order:Array<String>) {
			return reorderMenuItems(order);
		});
		lua.addLocalCallback('hasBeatenSong', function(songName:String) {
			for (i in 0...Std.int(Math.max(Difficulty.defaultList.length, 1)))
				if (Highscore.getScore(songName, i) > 0)
					return true;
			return false;
		});
		lua.addLocalCallback('hasBeatenWeek', function(week:String) {
			return StoryMenuState.weekCompleted.exists(week) && StoryMenuState.weekCompleted.get(week);
		});
		lua.addLocalCallback('changeMainMenuSelection', function(change:Int = 0, column:String = 'center') {
			var selectedColumn:MainMenuColumn = switch (column.toLowerCase()) {
				case 'left': LEFT;
				case 'right': RIGHT;
				default: CENTER;
			};
			changeItem(change, selectedColumn);
			return selectedItem?.name;
		});
		lua.addLocalCallback('acceptMainMenuSelection', function() {
			var item:MenuItem = switch(curColumn) {
				case LEFT: leftItem;
				case CENTER: menuItems.members[curSelected];
				case RIGHT: rightItem;
			}
			if (item != null && item.onAccept != null)
				item.onAccept(item);
			return item?.name;
		});
	}
	#end
}

class MenuItem extends FlxSprite {
	public var name:String;
	public var column:MainMenuColumn;
	public var onAccept:MenuItem -> Void = null;
	public var selected(default, set):Bool = false;
	
	public function new(x:Float = 0, y:Float = 0, name:String = '', ?onAccept:MenuItem -> Void) {
		this.onAccept = onAccept;
		this.name = name;
		super(x, y);
		
		loadSprite(name);
		
		antialiasing = ClientPrefs.data.antialiasing;
	}
	
	function getPrefix(candidates:Array<String>, fallback:String):String {
		for (candidate in candidates) {
			var found:Array<FlxFrame> = [];
			@:privateAccess animation.findByPrefix(found, candidate);
			if (found.length > 0)
				return candidate;
		}
		return fallback;
	}

	public function loadSprite(name:String, imagePath:String = '', fps:Float = 24) {
		var atlas:String = (imagePath != null && imagePath.trim().length > 0) ? imagePath : 'mainmenu/menu_$name';
		frames = Paths.getSparrowAtlas(atlas);
		animation.destroyAnimations();

		var idlePrefix:String = getPrefix(['$name idle', '${name}_idle', name], '$name idle');
		var selectedPrefix:String = getPrefix(['$name selected', '${name}_selected', '$name press', idlePrefix], '$name selected');
		animation.addByPrefix('idle', idlePrefix, Std.int(fps), true);
		animation.addByPrefix('selected', selectedPrefix, Std.int(fps), true);
		animation.play('idle');
		updateHitbox();
		
		selected = selected;
	}
	
	function set_selected(yea:Bool):Bool {
		animation.play(yea ? 'selected' : 'idle');
		centerOffsets();
		
		return selected = yea;
	}
}
