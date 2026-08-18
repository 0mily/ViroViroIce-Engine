package backend;

import lime.utils.Assets;
import openfl.utils.Assets as OpenFlAssets;
import haxe.Json;
import backend.lists.ListLoader;
import backend.lists.ListLoader.ListKind;

typedef WeekFile =
{
	// Level variables
	var songs:Array<Dynamic>;
	var weekCharacters:Array<String>;
	var weekBackground:String;
	var weekBefore:String;
	var storyName:String;
	var weekName:String;
	var startUnlocked:Bool;
	var hiddenUntilUnlocked:Bool;
	var hideStoryMode:Bool;
	var hideFreeplay:Bool;
	var difficulties:String;
}

private typedef WeekSource =
{
	var root:String;
	var modFolder:String;
	var packageFolder:String;
}

class WeekData {
	public static inline var LEVELS_PATH:String = 'data/levels/';
	public static inline var LEVEL_LIST:String = LEVELS_PATH + 'levelList.txt';

	public static var weeksLoaded:Map<String, WeekData> = new Map<String, WeekData>();
	public static var weeksList:Array<String> = [];
	public static var currentLevelName:String = '';
	public var folder:String = '';
	public var packageFolder:String = '';

	// Level variables
	public var songs:Array<Dynamic>;
	public var weekCharacters:Array<String>;
	public var weekBackground:String;
	public var weekBefore:String;
	public var storyName:String;
	public var weekName:String;
	public var startUnlocked:Bool;
	public var hiddenUntilUnlocked:Bool;
	public var hideStoryMode:Bool;
	public var hideFreeplay:Bool;
	public var difficulties:String;

	public var fileName:String;

	public static function createWeekFile():WeekFile {
		var weekFile:WeekFile = {
			songs: [["Bopeebo", "face", [146, 113, 253]], ["Fresh", "face", [146, 113, 253]], ["Dad Battle", "face", [146, 113, 253]]],
			#if BASE_GAME_FILES
			weekCharacters: ['dad', 'bf', 'gf'],
			#else
			weekCharacters: ['bf', 'bf', 'gf'],
			#end
			weekBackground: 'stage',
			weekBefore: 'tutorial',
			storyName: 'Your New Level',
			weekName: 'Custom Level',
			startUnlocked: true,
			hiddenUntilUnlocked: false,
			hideStoryMode: false,
			hideFreeplay: false,
			difficulties: ''
		};
		return weekFile;
	}

	// HELP: Is there any way to convert a WeekFile to WeekData without having to put all variables there manually? I'm kind of a noob in haxe lmao
	public function new(weekFile:WeekFile, fileName:String) {
		// here ya go - MiguelItsOut
		var fields:Array<String> = Reflect.fields(#if js js.lib.Object.getPrototypeOf(this) #else this #end); //fix crash on html5
		for (field in Reflect.fields(weekFile)) {
			if (fields.contains(field))
				Reflect.setProperty(this, field, Reflect.getProperty(weekFile, field));
		}

		this.fileName = fileName;
	}

	public static function reloadWeekFiles(isStoryMode:Null<Bool> = false)
	{
		weeksList = [];
		weeksLoaded.clear();
		var sources:Array<WeekSource> = [];
		var addSource = function(root:String, modFolder:String = '', packageFolder:String = ''):Void
		{
			if(root == null || root.trim().length < 1)
				return;
			root = root.replace('\\', '/');
			if(!root.endsWith('/'))
				root += '/';
			for(source in sources)
				if(source.root == root)
					return;
			sources.push({root: root, modFolder: modFolder, packageFolder: packageFolder});
		};

		#if ADDONS_ALLOWED
		for(addon in Mods.getEnabledAddonMods())
			addSource(Paths.mods(addon + '/'), addon);

		if(Mods.rootAddonsAllowed())
			addSource(Paths.mods());

		// and then the content turns into peak assets
		for(contentLayer in Mods.getContentModDirectories())
			addSource(Paths.mods(contentLayer + '/'), contentLayer);
		#end
		addSource(Paths.getSharedPath());

		var levelNames:Array<String> = [];
		var addLevelName = function(name:String):Void
		{
			if(name == null)
				return;
			name = name.trim();
			if(name.length > 0 && !levelNames.contains(name))
				levelNames.push(name);
		};

		var scriptedLevelList:Array<String> = ListLoader.names(ListLoader.load(LEVEL, FlxG.state));
		for(level in scriptedLevelList)
			addLevelName(level);

		var discoverySources:Array<WeekSource> = sources.copy();
		discoverySources.reverse();
		for(source in discoverySources)
		{
			var directory:String = source.root + LEVELS_PATH;
			if(!FileSystem.exists(directory) || !FileSystem.isDirectory(directory))
				continue;

			var listPath:String = directory + 'levelList.txt';
			if(FileSystem.exists(listPath))
				for(level in CoolUtil.coolTextFile(listPath))
					addLevelName(level);

			var files:Array<String> = FileSystem.readDirectory(directory);
			files.sort(function(a:String, b:String) return Reflect.compare(a.toLowerCase(), b.toLowerCase()));
			for(file in files)
			{
				var path:String = haxe.io.Path.join([directory, file]);
				if(!FileSystem.isDirectory(path) && file.toLowerCase().endsWith('.xml'))
					addLevelName(file.substr(0, file.length - 4));
			}
		}

		for(levelName in levelNames)
		{
			for(source in sources)
			{
				var path:String = source.root + LEVELS_PATH + levelName + '.xml';
				if(!FileSystem.exists(path))
					continue;

				addWeek(levelName, path, isStoryMode, source.modFolder, source.packageFolder);
				break;
			}
		}
	}

	private static function addWeek(weekToCheck:String, path:String, ?isStoryMode:Null<Bool>, ?modFolder:String, ?packageFolder:String)
	{
		if(weeksLoaded.exists(weekToCheck))
			return;

		var week:WeekFile = getWeekFile(path);
		if(week == null)
			return;

		var weekFile:WeekData = new WeekData(week, weekToCheck);
		weekFile.folder = modFolder ?? '';
		weekFile.packageFolder = packageFolder ?? '';
		if(isStoryMode == null || (isStoryMode && !weekFile.hideStoryMode) || (!isStoryMode && !weekFile.hideFreeplay))
		{
			weeksLoaded.set(weekToCheck, weekFile);
			weeksList.push(weekToCheck);
		}
	}

	public static function getWeekFile(path:String):WeekFile {
		var raw:String = null;
		#if ADDONS_ALLOWED
		if(FileSystem.exists(path)) {
			raw = Paths.getTextFromFile(path);
		}
		#else
		if(OpenFlAssets.exists(path)) {
			raw = Assets.getText(path);
		}
		#end

		return parseWeekFile(raw, path);
	}

	public static function parseWeekFile(raw:String, ?path:String, allowJson:Bool = false):WeekFile {
		if(raw == null) return null;
		var trimmed:String = raw.trim();
		if(trimmed.length > 0 && trimmed.charCodeAt(0) == 0xFEFF)
			trimmed = trimmed.substr(1).trim();
		if(trimmed.length < 1) return null;

		var lowerPath:String = path == null ? '' : path.toLowerCase();
		try
		{
			if(lowerPath.endsWith('.xml') || trimmed.startsWith('<'))
				return parseLevelXml(trimmed);

			if(allowJson && (lowerPath.endsWith('.json') || trimmed.startsWith('{')))
				return normalizeWeekFile(cast tjson.TJSON.parse(raw));
		}
		catch(e:Dynamic)
		{
			trace('Error parsing level file "$path": $e');
		}
		return null;
	}

	static function parseLevelXml(raw:String):WeekFile {
		var root:Xml = Xml.parse(raw).firstElement();
		if(root == null) return null;

		var weekFile:WeekFile = createWeekFile();
		weekFile.storyName = xmlAttr(root, ['storyName', 'story', 'name', 'displayName'], weekFile.storyName);
		weekFile.weekName = xmlAttr(root, ['weekName', 'levelName', 'title'], weekFile.weekName);
		weekFile.weekBackground = xmlAttr(root, ['weekBackground', 'background', 'asset'], weekFile.weekBackground);
		weekFile.weekBefore = xmlAttr(root, ['weekBefore', 'before', 'unlockAfter', 'requires'], weekFile.weekBefore);
		weekFile.difficulties = xmlAttr(root, ['difficulties', 'difficultyList'], weekFile.difficulties);
		weekFile.startUnlocked = xmlBool(root, ['startUnlocked', 'unlocked'], weekFile.startUnlocked);
		weekFile.hiddenUntilUnlocked = xmlBool(root, ['hiddenUntilUnlocked', 'hiddenUntilUnlock'], weekFile.hiddenUntilUnlocked);
		weekFile.hideStoryMode = xmlBool(root, ['hideStoryMode', 'hideStory'], weekFile.hideStoryMode);
		weekFile.hideFreeplay = xmlBool(root, ['hideFreeplay'], weekFile.hideFreeplay);

		var characters:Array<String> = parseStringList(xmlAttr(root, ['weekCharacters', 'characters'], null));
		var characterNode:Xml = firstChild(root, ['characters', 'weekcharacters']);
		if(characterNode != null)
		{
			var opponent:String = xmlAttr(characterNode, ['opponent', 'dad', 'enemy'], null);
			var boyfriend:String = xmlAttr(characterNode, ['boyfriend', 'bf', 'player'], null);
			var girlfriend:String = xmlAttr(characterNode, ['girlfriend', 'gf'], null);
			if(opponent != null) characters[0] = opponent;
			if(boyfriend != null) characters[1] = boyfriend;
			if(girlfriend != null) characters[2] = girlfriend;
		}
		while(characters.length < 3)
			characters.push(weekFile.weekCharacters[characters.length]);
		weekFile.weekCharacters = [characters[0], characters[1], characters[2]];

		var songs:Array<Dynamic> = [];
		var songsNode:Xml = firstChild(root, ['songs', 'tracks']);
		var songsParent:Xml = songsNode != null ? songsNode : root;
		for(songNode in songsParent.elements())
		{
			var nodeName:String = songNode.nodeName.toLowerCase();
			if(nodeName != 'song' && nodeName != 'track') continue;

			var songName:String = xmlAttr(songNode, ['name', 'id', 'song'], xmlText(songNode));
			if(songName == null || songName.trim().length < 1) continue;

			var icon:String = xmlAttr(songNode, ['icon', 'character', 'freeplayIcon'], 'face');
			var color:Array<Int> = parseXmlColor(songNode, [146, 113, 253]);
			songs.push([songName, icon, color]);
		}

		if(songs.length < 1)
		{
			for(songName in parseStringList(xmlAttr(root, ['songs', 'songList', 'tracks'], null)))
				songs.push([songName, 'face', [146, 113, 253]]);
		}
		if(songs.length > 0)
			weekFile.songs = songs;

		return normalizeWeekFile(weekFile);
	}

	static function normalizeWeekFile(data:Dynamic):WeekFile {
		var defaults:WeekFile = createWeekFile();
		if(data == null) return defaults;

		if((!Reflect.hasField(data, 'storyName') || Reflect.field(data, 'storyName') == null) && Reflect.hasField(data, 'name'))
			Reflect.setField(data, 'storyName', Reflect.field(data, 'name'));
		if((!Reflect.hasField(data, 'weekName') || Reflect.field(data, 'weekName') == null) && Reflect.hasField(data, 'name'))
			Reflect.setField(data, 'weekName', Reflect.field(data, 'name'));
		if((!Reflect.hasField(data, 'weekBackground') || Reflect.field(data, 'weekBackground') == null) && Reflect.hasField(data, 'background'))
			Reflect.setField(data, 'weekBackground', Reflect.field(data, 'background'));

		for(field in Reflect.fields(defaults))
		{
			if(!Reflect.hasField(data, field) || Reflect.field(data, field) == null)
				Reflect.setField(data, field, Reflect.field(defaults, field));
		}

		if(data.weekCharacters == null || data.weekCharacters.length < 3)
		{
			var chars:Array<String> = cast (data.weekCharacters ?? []);
			while(chars.length < 3)
				chars.push(defaults.weekCharacters[chars.length]);
			data.weekCharacters = chars;
		}

		if(data.songs == null || data.songs.length < 1)
			data.songs = defaults.songs;

		var normalizedSongs:Array<Dynamic> = [];
		for(rawSong in (data.songs:Array<Dynamic>))
		{
			var song:Array<Dynamic> = [];
			if(Std.isOfType(rawSong, Array))
				song = cast rawSong;
			else
				song = [Std.string(rawSong), 'face', [146, 113, 253]];

			while(song.length < 3)
				song.push(song.length == 1 ? 'face' : [146, 113, 253]);
			if(song[2] == null || song[2].length < 3)
				song[2] = [146, 113, 253];
			normalizedSongs.push(song);
		}
		data.songs = normalizedSongs;
		return cast data;
	}

	static function xmlAttr(node:Xml, names:Array<String>, fallback:String):String {
		if(node == null) return fallback;
		for(name in names)
		{
			if(node.exists(name))
			{
				var value:String = node.get(name);
				if(value != null)
					return value.trim();
			}
		}
		return fallback;
	}

	static function xmlBool(node:Xml, names:Array<String>, fallback:Bool):Bool {
		var value:String = xmlAttr(node, names, null);
		if(value == null) return fallback;
		switch(value.trim().toLowerCase())
		{
			case 'true' | '1' | 'yes' | 'y' | 'on':
				return true;
			case 'false' | '0' | 'no' | 'n' | 'off':
				return false;
		}
		return fallback;
	}

	static function firstChild(node:Xml, names:Array<String>):Xml {
		if(node == null) return null;
		for(child in node.elements())
			if(names.contains(child.nodeName.toLowerCase()))
				return child;
		return null;
	}

	static function xmlText(node:Xml):String {
		if(node == null) return '';
		var text:String = '';
		for(child in node)
		{
			if(child.nodeType == Xml.PCData || child.nodeType == Xml.CData)
				text += child.nodeValue;
		}
		return text.trim();
	}

	static function parseStringList(value:String):Array<String> {
		var list:Array<String> = [];
		if(value == null) return list;
		for(item in value.split(','))
		{
			item = item.trim();
			if(item.length > 0)
				list.push(item);
		}
		return list;
	}

	static function parseXmlColor(node:Xml, fallback:Array<Int>):Array<Int> {
		var color:String = xmlAttr(node, ['color', 'rgb'], null);
		if(color != null)
		{
			color = color.trim();
			if(color.startsWith('#')) color = color.substr(1);
			if(color.indexOf(',') >= 0)
			{
				var parts:Array<String> = color.split(',');
				if(parts.length >= 3)
				{
					var r:Null<Int> = Std.parseInt(parts[0].trim());
					var g:Null<Int> = Std.parseInt(parts[1].trim());
					var b:Null<Int> = Std.parseInt(parts[2].trim());
					if(r != null && g != null && b != null)
						return [r, g, b];
				}
			}
			else if(color.length == 6)
			{
				var parsed:Null<Int> = Std.parseInt('0x$color');
				if(parsed != null)
					return [(parsed >> 16) & 0xFF, (parsed >> 8) & 0xFF, parsed & 0xFF];
			}
		}

		var r:Null<Int> = Std.parseInt(xmlAttr(node, ['r', 'red'], null));
		var g:Null<Int> = Std.parseInt(xmlAttr(node, ['g', 'green'], null));
		var b:Null<Int> = Std.parseInt(xmlAttr(node, ['b', 'blue'], null));
		if(r != null && g != null && b != null)
			return [r, g, b];
		return fallback;
	}

	public static function buildLevelXml(weekFile:WeekFile):String {
		weekFile = normalizeWeekFile(weekFile);
		var xml:StringBuf = new StringBuf();
		xml.add('<?xml version="1.0" encoding="utf-8"?>\n');
		xml.add('<level');
		xml.add(' storyName="${escapeXml(weekFile.storyName)}"');
		xml.add(' weekName="${escapeXml(weekFile.weekName)}"');
		xml.add(' background="${escapeXml(weekFile.weekBackground)}"');
		xml.add(' unlockAfter="${escapeXml(weekFile.weekBefore)}"');
		xml.add(' startUnlocked="${weekFile.startUnlocked}"');
		xml.add(' hiddenUntilUnlocked="${weekFile.hiddenUntilUnlocked}"');
		xml.add(' hideStoryMode="${weekFile.hideStoryMode}"');
		xml.add(' hideFreeplay="${weekFile.hideFreeplay}"');
		xml.add(' difficulties="${escapeXml(weekFile.difficulties)}"');
		xml.add('>\n');
		xml.add('\t<characters opponent="${escapeXml(weekFile.weekCharacters[0])}" boyfriend="${escapeXml(weekFile.weekCharacters[1])}" girlfriend="${escapeXml(weekFile.weekCharacters[2])}"/>\n');
		xml.add('\t<songs>\n');
		for(song in weekFile.songs)
		{
			var name:String = Std.string(song[0]);
			var icon:String = Std.string(song[1]);
			var color:Array<Int> = song[2];
			if(color == null || color.length < 3) color = [146, 113, 253];
			xml.add('\t\t<song name="${escapeXml(name)}" icon="${escapeXml(icon)}" color="${formatColor(color)}"/>\n');
		}
		xml.add('\t</songs>\n');
		xml.add('</level>\n');
		return xml.toString();
	}

	static function escapeXml(value:Dynamic):String {
		if(value == null) return '';
		return StringTools.htmlEscape(Std.string(value), true);
	}

	static function formatColor(color:Array<Int>):String {
		var rgb:Int = ((color[0] & 0xFF) << 16) | ((color[1] & 0xFF) << 8) | (color[2] & 0xFF);
		return '#' + StringTools.hex(rgb, 6);
	}

	//   FUNCTIONS YOU WILL PROBABLY NEVER NEED TO USE

	//To use on PlayState.hx or Highscore stuff
	public static function getWeekFileName():String {
		if(weeksList.length < 1 || PlayState.storyWeek < 0 || PlayState.storyWeek >= weeksList.length)
			return currentLevelName;
		return weeksList[PlayState.storyWeek];
	}

	//Used on LoadingState, nothing really too relevant
	public static function getCurrentWeek():WeekData {
		if(weeksList.length < 1 || PlayState.storyWeek < 0 || PlayState.storyWeek >= weeksList.length)
			return PlayState.storyWeekData;
		return weeksLoaded.get(weeksList[PlayState.storyWeek]);
	}

	public static function setDirectoryFromWeek(?data:WeekData = null) {
		Mods.currentModDirectory = '';
		Mods.currentPackageDirectory = '';
		currentLevelName = '';
		if(data != null && data.folder != null && data.folder.length > 0) {
			Mods.currentModDirectory = data.folder;
			Mods.currentPackageDirectory = data.packageFolder ?? '';
		}
		if(data != null)
			currentLevelName = data.fileName;
	}
}
