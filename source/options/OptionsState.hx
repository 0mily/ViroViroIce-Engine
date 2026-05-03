package options;

import states.MainMenuState;
import backend.StageData;

class OptionsState extends ScriptedState
{
	var options:Array<String> = [
		'Note Colors',
		'Controls',
		'Delay and Combo',
		'Graphics',
		'Visuals',
		'Gameplay',
		'VVIE'
		#if TRANSLATIONS_ALLOWED , 'Language' #end
	];
	private static var curSelected:Int = 0;
	public static var onPlayState:Bool = false;
	
	var optionFunctions:Map<String, Void -> Void> = [];
	var grpOptions:FlxTypedGroup<Alphabet>;
	var bg:FlxSprite;

	function refreshShitScript():Void {
		setOnScripts('curSelected', curSelected);
		setOnScripts('selectedOption', options[curSelected]);
		setOnScripts('optionsList', options.copy());
		setOnScripts('optionsGroup', 'grpOptions');
		setOnScripts('bg', 'bg');
	}

	function accept(label:String, idx:Int) {
		var blockedFNF:Bool = (callOnScripts('onSelected', [label, idx], true) == psychlua.LuaUtils.Function_Stop); // https://open.spotify.com/intl-pt/track/26d3VzErjYpE0buTZV6YKZ
		blockedFNF = (blockedFNF || callOnScripts('onAccept', [label, idx], true) == psychlua.LuaUtils.Function_Stop);
		if (!blockedFNF) {
			var func:Void -> Void = optionFunctions[label];
			if (func != null)
				func();
		}
	}

	var selectorLeft:Alphabet;
	var selectorRight:Alphabet;

	override function create() {
		optionFunctions['Note Colors'] = () -> openSubState(new options.NotesColorSubState());
		optionFunctions['Controls'] = () -> openSubState(new options.ControlsSubState());
		optionFunctions['Graphics'] = () -> openSubState(new options.GraphicsSettingsSubState());
		optionFunctions['Visuals'] = () -> openSubState(new options.VisualsSettingsSubState());
		optionFunctions['Gameplay'] = () -> openSubState(new options.GameplaySettingsSubState());
		optionFunctions['Delay and Combo'] = () -> MusicBeatState.switchState(new options.NoteOffsetState());
		optionFunctions['VVIE'] = () -> openSubState(new options.ViroViroOptionsSubState());
		optionFunctions['Language'] = () -> openSubState(new options.LanguageSubState());
		
		rpcDetails = 'Options Menu';
		preCreate();

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = 0xFFea71fd;
		bg.updateHitbox();

		bg.screenCenter();
		add(bg);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		for (num => option in options) {
			var optionText:Alphabet = new Alphabet(0, 0, Language.getPhrase('options_$option', option), true);
			optionText.screenCenter();
			optionText.y += (92 * (num - (options.length / 2))) + 45;
			grpOptions.add(optionText);
		}

		selectorLeft = new Alphabet(0, 0, '>', true);
		add(selectorLeft);
		selectorRight = new Alphabet(0, 0, '<', true);
		add(selectorRight);

		changeSelection();
		ClientPrefs.saveSettings();

		super.create();
		refreshShitScript();
	}

	override function closeSubState()
	{
		super.closeSubState();
		ClientPrefs.saveSettings();
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end
	}

	override function update(elapsed:Float) {
		preUpdate(elapsed);
		
		super.update(elapsed);
		var blockedFNFInput:Bool = (callOnScripts('onInputUpdate', [elapsed], true) == psychlua.LuaUtils.Function_Stop);
		
		if (!blockedFNFInput) {
			if (controls.UI_UP_P)
				changeSelection(-1);
			if (controls.UI_DOWN_P)
				changeSelection(1);

			if (controls.BACK) {
				if (callOnScripts('onBack', true) != psychlua.LuaUtils.Function_Stop) {
					FlxG.sound.play(Paths.sound('cancelMenu'));
					if(onPlayState) {
						StageData.loadDirectory(PlayState.SONG);
						LoadingState.loadAndSwitchState(new PlayState());
						FlxG.sound.music.volume = 0;
					}
					else MusicBeatState.switchState(new MainMenuState());
				}
			} else if (controls.ACCEPT) {
				accept(options[curSelected], curSelected);
			}
		}
		
		postUpdate(elapsed);
	}
	
	function changeSelection(change:Int = 0) {
		var next:Int = FlxMath.wrap(curSelected + change, 0, options.length - 1);
		
		var blockedFNF:Bool = (callOnScripts('onHighlighted', [options[next], next], true) == psychlua.LuaUtils.Function_Stop);
		blockedFNF = (blockedFNF || callOnScripts('onSelectItem', [options[next], next], true) == psychlua.LuaUtils.Function_Stop);
		if (!blockedFNF) {
			if (change != 0)
				FlxG.sound.play(Paths.sound('scrollMenu'));
			
			curSelected = next;
			updateItemsVisibility();
			refreshShitScript();
			callOnScripts('onHighlightedPost', [options[curSelected], curSelected]);
		}
	}
	
	function updateItemsVisibility():Void {
		for (i => item in grpOptions.members) {
			item.targetY = i - curSelected;
			item.alpha = 0.6;
			
			if (item.targetY == 0) {
				item.alpha = 1;
				selectorLeft.x = item.x - 63;
				selectorLeft.y = item.y;
				selectorRight.x = item.x + item.width + 15;
				selectorRight.y = item.y;
			}
		}
	}

	override function destroy()
	{
		ClientPrefs.loadPrefs();
		super.destroy();
	}

	#if LUA_ALLOWED
	public override function implementLua(lua:psychlua.FunkinLua):Void {
		super.implementLua(lua);

		lua.addLocalCallback('addOptionMenu', function(label:String, stateName:String = '', insertAt:Int = -1) {
			if (options.contains(label))
				return false;

			if (insertAt < 0 || insertAt > options.length)
				options.push(label);
			else
				options.insert(insertAt, label);

			if (stateName != null && stateName.trim().length > 0)
				optionFunctions[label] = () -> MusicBeatState.switchState(MusicBeatState.buildState(stateName));

			var optionText:Alphabet = new Alphabet(0, 0, Language.getPhrase('options_$label', label), true);
			optionText.screenCenter();
			grpOptions.insert(insertAt < 0 ? grpOptions.length : insertAt, optionText);
			for (i => item in grpOptions.members) {
				item.screenCenter();
				item.y = (92 * (i - (options.length / 2))) + 45;
			}
			changeSelection();
			refreshShitScript();
			return true;
		});
		lua.addLocalCallback('removeOptionMenu', function(label:String) {
			var idx:Int = options.indexOf(label);
			if (idx < 0)
				return false;

			options.remove(label);
			optionFunctions.remove(label);
			var item = grpOptions.members[idx];
			if (item != null)
				grpOptions.remove(item, true);

			if (options.length > 0)
				curSelected = FlxMath.wrap(curSelected, 0, options.length - 1);
			else
				curSelected = 0;

			for (i => member in grpOptions.members) {
				member.screenCenter();
				member.y = (92 * (i - (options.length / 2))) + 45;
			}
			changeSelection();
			refreshShitScript();
			return true;
		});
		lua.addLocalCallback('setOptionOrder', function(order:Array<String>) {
			if (order == null) return options.copy();

			var insertAt:Int = 0;
			for (label in order) {
				var idx:Int = options.indexOf(label);
				if (idx < 0) continue;

				var value:String = options[idx];
				options.remove(value);
				options.insert(insertAt, value);

				var item = grpOptions.members[idx];
				grpOptions.remove(item, false);
				grpOptions.insert(insertAt, item);
				insertAt++;
			}

			for (i => member in grpOptions.members) {
				member.screenCenter();
				member.y = (92 * (i - (options.length / 2))) + 45;
			}
			changeSelection();
			refreshShitScript();
			return options.copy();
		});
		lua.addLocalCallback('changeOptionsSelection', function(change:Int = 0) {
			changeSelection(change);
			return options[curSelected];
		});
		lua.addLocalCallback('acceptOptionsSelection', function() {
			accept(options[curSelected], curSelected);
			return options[curSelected];
		});
	}
	#end
}
