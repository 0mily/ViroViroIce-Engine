package states.editors.content;

import backend.Mods;
import backend.Paths;
import backend.Song;
import backend.Highscore;
import backend.Difficulty;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import backend.ViroText as FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import states.PlayState;
import states.editors.ChartingState;
import states.editors.content.Prompt.BasePrompt;
import states.LoadingState;
#if sys
import sys.FileSystem;
#end

/*
	i   slept
 */
typedef ChartEditorSongChoice =
{
	var song:String;
	var chart:String;
	var label:String;
	@:optional var source:String;
	@:optional var modDirectory:String;
	@:optional var packageDirectory:String;
}

class CoolNewSongSubState extends BasePrompt
{
	static inline final ROWS:Int = 12;

	var choices:Array<ChartEditorSongChoice> = [];
	var buttons:Array<PsychUIButton> = [];
	var rowTexts:Array<FlxText> = [];
	var sourceTexts:Array<FlxText> = [];
	var scroll:Int = 0;
	var selected:Int = 0;
	var statusText:FlxText;
	var counterText:FlxText;

	var createNew:Void->Void;
	var openSong:ChartEditorSongChoice->Void;

	public function new(?createNew:Void->Void, ?openSong:ChartEditorSongChoice->Void)
	{
		FlxG.mouse.visible = true;
		this.createNew = createNew;
		this.openSong = openSong;
		super(560, 430, 'New Chart', build, tick);
	}

	function build(state:BasePrompt):Void
	{
		choices = findAvailableCharts();

		state.bg.scale.set(1, 1);
		state.bg.x = FlxG.width * 0.5 - 280;
		state.bg.y = FlxG.height * 0.5 - 215;
		HaxeUITheme.drawRoundedBox(state.bg, 560, 430, HaxeUITheme.BG, 0.96, 10, HaxeUITheme.PURPLE_DARK, 3);

		state.titleText.text = 'Chart Editor';
		state.titleText.color = HaxeUITheme.TEXT;
		state.titleText.size = 22;
		state.titleText.y = state.bg.y + 22;
		state.titleText.screenCenter(X);

		var accent:FlxSprite = new FlxSprite(state.bg.x + 18, state.bg.y + 60);
		HaxeUITheme.drawRoundedBox(accent, 524, 4, HaxeUITheme.PURPLE, 1, 4, HaxeUITheme.PURPLE, 0);
		accent.cameras = state.cameras;
		state.add(accent);

		var left:Float = state.bg.x + 24;
		var top:Float = state.bg.y + 82;
		var listX:Float = state.bg.x + 205;
		var listY:Float = top + 52;
		var listW:Int = 330;

		var createBox:FlxSprite = new FlxSprite(left, top);
		HaxeUITheme.drawRoundedBox(createBox, 155, 120, HaxeUITheme.PANEL, 1, 8, HaxeUITheme.OUTLINE, 2);
		createBox.cameras = state.cameras;
		state.add(createBox);

		var createTitle:FlxText = new FlxText(left + 14, top + 14, 126, 'Create New', 14);
		createTitle.color = HaxeUITheme.TEXT;
		createTitle.cameras = state.cameras;
		state.add(createTitle);

		var createBtn:PsychUIButton = new PsychUIButton(left + 14, top + 52, 'Template Chart', function()
		{
			state.close();
			if(createNew != null) createNew();
			else LoadingState.loadAndSwitchState(new ChartingState(), true); // fucker still crashes JUST on template??????????
		}, 126, 26);
		createBtn.normalStyle.bgColor = HaxeUITheme.PURPLE_DARK;
		createBtn.hoverStyle.bgColor = HaxeUITheme.PURPLE;
		createBtn.clickStyle.bgColor = HaxeUITheme.PANEL_LIGHT;
		createBtn.cameras = state.cameras;
		state.add(createBtn);

		var hint:FlxText = new FlxText(left + 14, top + 88, 126, 'Blank starter chart.', 11);
		hint.color = HaxeUITheme.TEXT_MUTED;
		hint.cameras = state.cameras;
		state.add(hint);

		var helpBox:FlxSprite = new FlxSprite(left, top + 142);
		HaxeUITheme.drawRoundedBox(helpBox, 155, 158, HaxeUITheme.PANEL, 0.94, 8, HaxeUITheme.OUTLINE, 2);
		helpBox.cameras = state.cameras;
		state.add(helpBox);

		var helpTitle:FlxText = new FlxText(left + 14, top + 158, 126, 'Controls', 13);
		helpTitle.color = HaxeUITheme.TEXT;
		helpTitle.cameras = state.cameras;
		state.add(helpTitle);

		var help:FlxText = new FlxText(left + 14, top + 184, 126, 'Enter / Click\nopens\n\nEsc closes\nWheel scrolls', 12);
		help.color = HaxeUITheme.TEXT_MUTED;
		help.cameras = state.cameras;
		state.add(help);

		var listBox:FlxSprite = new FlxSprite(listX, top);
		HaxeUITheme.drawRoundedBox(listBox, listW, 300, HaxeUITheme.PANEL, 1, 8, HaxeUITheme.OUTLINE, 2);
		listBox.cameras = state.cameras;
		state.add(listBox);

		var listTitle:FlxText = new FlxText(listX + 14, top + 14, listW - 28, 'Create From Active Song', 14);
		listTitle.color = HaxeUITheme.TEXT;
		listTitle.cameras = state.cameras;
		state.add(listTitle);

		var listSub:FlxText = new FlxText(listX + 14, top + 34, listW - 28, getActiveSourceLabel(), 11);
		listSub.color = HaxeUITheme.TEXT_MUTED;
		listSub.cameras = state.cameras;
		state.add(listSub);

		for(i in 0...ROWS)
		{
			var y:Float = listY + (i * 19);
			var btn:PsychUIButton = new PsychUIButton(listX + 14, y - 3, '', function() {}, listW - 28, 18);
			btn.normalStyle.bgColor = HaxeUITheme.PANEL_BOTTOM;
			btn.hoverStyle.bgColor = HaxeUITheme.PANEL_LIGHT;
			btn.clickStyle.bgColor = HaxeUITheme.PURPLE_DARK;
			btn.cameras = state.cameras;
			state.add(btn);
			buttons.push(btn);

			var row:FlxText = new FlxText(listX + 22, y, 178, '', 12);
			row.color = HaxeUITheme.TEXT;
			row.cameras = state.cameras;
			state.add(row);
			rowTexts.push(row);

			var source:FlxText = new FlxText(listX + 204, y, 108, '', 11);
			source.color = HaxeUITheme.TEXT_MUTED;
			source.alignment = RIGHT;
			source.cameras = state.cameras;
			state.add(source);
			sourceTexts.push(source);
		}

		counterText = new FlxText(listX + 14, state.bg.y + state.bg.height - 46, listW - 28, '', 12);
		counterText.color = HaxeUITheme.TEXT_MUTED;
		counterText.alignment = RIGHT;
		counterText.cameras = state.cameras;
		state.add(counterText);

		statusText = new FlxText(left, state.bg.y + state.bg.height - 46, 350, '', 12);
		statusText.color = choices.length > 0 ? HaxeUITheme.TEXT_MUTED : 0xFFFF8BA7;
		statusText.cameras = state.cameras;
		state.add(statusText);

		refreshRows();
	}

	function tick(state:BasePrompt, elapsed:Float):Void
	{
		if(choices.length < 1) return;

		if(FlxG.mouse.wheel != 0)
		{
			scrollBy(-FlxG.mouse.wheel);
			return;
		}

		if(FlxG.keys.justPressed.UP) selectBy(-1);
		else if(FlxG.keys.justPressed.DOWN) selectBy(1);
		else if(FlxG.keys.justPressed.PAGEUP) selectBy(-ROWS);
		else if(FlxG.keys.justPressed.PAGEDOWN) selectBy(ROWS);
		else if(FlxG.keys.justPressed.ENTER) acceptSelected();
	}

	function refreshRows():Void
	{
		if(choices.length < 1)
		{
			statusText.text = 'No chart found in the active content.';
			counterText.text = '0 songs';
		}
		else
		{
			statusText.text = 'Found ${choices.length} active chart${choices.length == 1 ? '' : 's'}.';
			counterText.text = '${selected + 1}/${choices.length}';
		}

		for(i in 0...ROWS)
		{
			var index:Int = scroll + i;
			var exists:Bool = index >= 0 && index < choices.length;
			buttons[i].visible = rowTexts[i].visible = sourceTexts[i].visible = exists;
			if(!exists) continue;

			var choice = choices[index];
			rowTexts[i].text = choice.label;
			sourceTexts[i].text = choice.source ?? '';
			rowTexts[i].color = index == selected ? FlxColor.WHITE : 0xFFE6DAFF;
			sourceTexts[i].color = index == selected ? 0xFFFFFFFF : HaxeUITheme.TEXT_MUTED;
			buttons[i].normalStyle.bgColor = index == selected ? HaxeUITheme.PURPLE_DARK : HaxeUITheme.PANEL_BOTTOM;
			buttons[i].hoverStyle.bgColor = index == selected ? HaxeUITheme.PURPLE : HaxeUITheme.PANEL_LIGHT;
			var captured = index;
			buttons[i].onClick = function()
			{
				selected = captured;
				acceptSelected();
			};
		}
	}

	function selectBy(amount:Int):Void
	{
		selected = FlxMath.wrap(selected + amount, 0, choices.length - 1);
		if(selected < scroll) scroll = selected;
		if(selected >= scroll + ROWS) scroll = selected - ROWS + 1;
		refreshRows();
	}

	function scrollBy(amount:Int):Void
	{
		var maxScroll:Int = Std.int(Math.max(0, choices.length - ROWS));
		scroll = Std.int(Math.max(0, Math.min(maxScroll, scroll + amount)));
		selected = Std.int(Math.max(scroll, Math.min(scroll + ROWS - 1, selected)));
		refreshRows();
	}

	function acceptSelected():Void
	{
		var choice = choices[selected];
		if(choice == null) return;
		close();
		if(openSong != null) openSong(choice);
		else if(loadChoiceIntoPlayState(choice)) LoadingState.loadAndSwitchState(new ChartingState(), false);
	}

	public static function loadChoiceIntoPlayState(choice:ChartEditorSongChoice):Bool
	{
		if(choice == null) return false;
		#if ADDONS_ALLOWED
		Mods.currentModDirectory = choice.modDirectory ?? '';
		Mods.currentPackageDirectory = choice.packageDirectory ?? '';
		#end
		try
		{
			Song.loadFromJson(choice.chart, choice.song);
			return PlayState.SONG != null;
		}
		catch(e:Dynamic)
		{
			trace('Could not load chart ${choice.label}: $e');
			return false;
		}
	}

	static function findAvailableCharts():Array<ChartEditorSongChoice>
	{
		var list:Array<ChartEditorSongChoice> = [];
		var added:Map<String, Bool> = new Map();

		#if sys
		scanSongRoot(Paths.getSharedPath('songs'), 'Assets', null, null, list, added);

		#if ADDONS_ALLOWED
		var selectedContent:String = Mods.getSelectedContentDirectory();
		if(selectedContent != null && selectedContent.length > 0)
		{
			var root:String = Mods.contentRootDirectory(selectedContent);
			scanSongRoot(Paths.mods('$root/songs'), selectedContent, root, null, list, added);
		}

		if(Mods.rootAddonsAllowed())
			scanSongRoot(Paths.mods('songs'), 'Addons', '', null, list, added);

		for(mod in Mods.getActiveModDirectories())
			scanSongRoot(Paths.mods('$mod/songs'), sourceNameForMod(mod), mod, null, list, added);
		#end
		#end

		list.sort(function(a, b) return Reflect.compare(a.label.toLowerCase(), b.label.toLowerCase()));
		return list;
	}

	static function getActiveSourceLabel():String
	{
		#if ADDONS_ALLOWED
		var selectedContent:String = Mods.getSelectedContentDirectory();
		if(selectedContent != null && selectedContent.length > 0)
			return 'Active content: $selectedContent';
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			return 'Loaded mod: ${Mods.currentModDirectory}';
		#end
		return 'Base game and enabled addons';
	}

	static function sourceNameForMod(mod:String):String
	{
		if(mod == null || mod.length < 1) return 'Addons';
		#if ADDONS_ALLOWED
		var selectedContent:String = Mods.getSelectedContentDirectory();
		if(selectedContent != null && selectedContent.length > 0)
		{
			var root:String = Mods.contentRootDirectory(selectedContent);
			if(mod == root) return selectedContent;
			if(mod.startsWith(root + '/')) return mod.substr(root.length + 1);
		}
		#end
		return mod;
	}

	#if sys
	static function scanSongRoot(root:String, source:String, modDirectory:String, packageDirectory:String, list:Array<ChartEditorSongChoice>, added:Map<String, Bool>):Void
	{
		if(root == null || !FileSystem.exists(root) || !FileSystem.isDirectory(root)) return;

		for(songFolder in FileSystem.readDirectory(root))
		{
			var songPath:String = '$root/$songFolder';
			var chartPath:String = '$songPath/chart';
			if(!FileSystem.exists(chartPath) || !FileSystem.isDirectory(chartPath)) continue;

			var chart:String = preferredChartFile(chartPath);
			if(chart == null) continue;

			var key:String = '${modDirectory ?? 'assets'}::$songFolder::$chart';
			if(added.exists(key)) continue;
			added.set(key, true);

			list.push({
				song: Paths.formatToSongPath(songFolder),
				chart: chart,
				label: songFolder,
				source: source,
				modDirectory: modDirectory,
				packageDirectory: packageDirectory
			});
		}
	}

	static function preferredChartFile(chartPath:String):String
	{
		var files:Array<String> = [];
		for(file in FileSystem.readDirectory(chartPath))
		{
			if(!file.endsWith('.json')) continue;
			var name:String = file.substr(0, file.length - 5);
			if(name == 'events') continue;
			files.push(name);
		}
		if(files.length < 1) return null;

		var preferred:Array<String> = ['normal', 'hard', 'easy'];
		for(name in preferred)
			if(files.contains(name)) return name;

		files.sort(Reflect.compare);
		return files[0];
	}
	#end
}
