package backend;

import openfl.utils.Assets;

import haxe.Json;

#if sys
import sys.FileSystem;
import sys.io.File;
#end
// uhm ok, como eu começo

using StringTools;

typedef ModsList = {
	enabled:Array<String>,
	disabled:Array<String>,
	available:Array<String>,
	all:Array<String>
};

typedef PackageModData = {
	@:optional var global:Bool;
	@:optional var name:String;
	@:optional var description:String;
};

typedef ContentAddonsData = {
	@:optional var allowAddons:Bool;
	@:optional var addonPrefix:String;
};

typedef ContentData = {
	@:optional var name:String;
	@:optional var description:String;
	@:optional var version:String;
	@:optional var author:String;
	@:optional var discordRPC:String;
	@:optional var icon:String;
	@:optional var addons:ContentAddonsData;
};

class Mods
{
	public static inline var ADDONS_FOLDER:String = 'addons';
	public static inline var CONTENTS_FOLDER:String = 'contents';
	static inline var ADDONS_LIST_FILE:String = 'addonsList.txt';
	static inline var LEGACY_MODS_LIST_FILE:String = 'modsList.txt';

	static public var selectedContentDirectory:String = '';
	static public var currentModDirectory:String = '';
	static public var currentPackageDirectory:String = '';
	public static inline var PACKAGE_MOD_FOLDER:String = 'packageMod';
	static var contentDirectoriesCache:Array<String> = null;
	static var contentDataCache:Map<String, ContentData> = new Map();
	public static final PACKAGE_MOD_FOLDERS:Array<String> = ['packageMod', 'packageMods'];
	public static final ignoreModFolders:Array<String> = [
		'characters',
		'data',
		'songs',
		'music',
		'sounds',
		'shaders',
		'videos',
		'images',
		'stages',
		'weeks',
		'fonts',
		'achievements',
		'packagemod',
		'packagemods'
	];
	static final packageContentFolders:Array<String> = [
		'images',
		'songs',
		'sounds'
	];

	public static var globalMods:Array<String> = [];
	public static var globalPackageMods:Array<String> = [];

	inline public static function getGlobalMods()
		return globalMods;

	inline public static function getGlobalPackageMods()
		return globalPackageMods;

	public static function normalizeFolderKey(path:String):String
	{
		if (path == null)
			return '';
		path = path.replace('\\', '/').trim();
		while (path.startsWith('/'))
			path = path.substr(1);
		return path;
	}

	public static function clearContentCaches():Void
	{
		contentDirectoriesCache = null;
		contentDataCache = new Map();
	}

	public static function resolveModPath(key:String = ''):String
	{
		key = normalizeFolderKey(key);
		if (key.length < 1)
			return '$ADDONS_FOLDER/';
		if (key == ADDONS_FOLDER || key.startsWith('$ADDONS_FOLDER/'))
			return key;
		if (key == CONTENTS_FOLDER || key.startsWith('$CONTENTS_FOLDER/'))
			return key;
		return '$ADDONS_FOLDER/$key';
	}

	public static function resolveContentPath(key:String = ''):String
	{
		key = normalizeFolderKey(key);
		return key.length < 1 ? '$CONTENTS_FOLDER/' : '$CONTENTS_FOLDER/$key';
	}

	inline public static function contentRootDirectory(content:String):String
		return '$CONTENTS_FOLDER/${normalizeFolderKey(content)}';

	inline public static function contentModDirectory(content:String, modFolder:String):String
		return contentRootDirectory(content) + '/' + normalizeFolderKey(modFolder);

	public static function getSelectedContentDirectory():String
	{
		syncSelectedContentFromPrefs();
		return selectedContentDirectory;
	}

	static function syncSelectedContentFromPrefs():Void
	{
		var selected:String = ClientPrefs.selectedContent ?? selectedContentDirectory ?? '';
		selected = normalizeFolderKey(selected);
		if (selected.length > 0 && !getContentDirectories().contains(selected))
			selected = '';

		selectedContentDirectory = selected;
		ClientPrefs.selectedContent = selected;
	}

	public static function selectContent(?folder:String):Bool
	{
		folder = normalizeFolderKey(folder ?? '');
		if (folder.length > 0 && !getContentDirectories().contains(folder))
		{
			clearContentCaches();
			if (!getContentDirectories().contains(folder))
				return false;
		}

		selectedContentDirectory = folder;
		ClientPrefs.selectedContent = folder;
		ClientPrefs.pendingSelectedContent = '';
		ClientPrefs.contentBootStatus = '';
		ClientPrefs.saveContentSelectionState();

		loadTopMod();
		pushGlobalMods();
		return true;
	}

	public static function queueContentSelection(?folder:String):Bool
		return selectContent(folder);

	public static function confirmContentBoot():Void
	{
		ClientPrefs.pendingSelectedContent = '';
		ClientPrefs.contentBootStatus = '';
		ClientPrefs.saveContentSelectionState();
	}

	public static function clearSelectedContent():Void
	{
		selectedContentDirectory = '';
		ClientPrefs.selectedContent = '';
		ClientPrefs.pendingSelectedContent = '';
		ClientPrefs.contentBootStatus = '';
		ClientPrefs.saveContentSelectionState();
	}

	inline public static function hasSelectedContent():Bool
		return getSelectedContentDirectory().length > 0;

	public static function getSelectedContentData():ContentData
		return getContentData(getSelectedContentDirectory());

	public static function addonsAllowedForCurrentContent():Bool
	{
		var content:String = getSelectedContentDirectory();
		if (content.length < 1)
			return true;

		var data:ContentData = getContentData(content);
		if (data == null || data.addons == null)
			return false;
		return data.addons.allowAddons == true;
	}

	public static function getCurrentAddonPrefix():String
	{
		if (!addonsAllowedForCurrentContent())
			return null;

		var data:ContentData = getSelectedContentData();
		if (data == null || data.addons == null || data.addons.addonPrefix == null)
			return '';
		return data.addons.addonPrefix.trim();
	}

	public static function rootAddonsAllowed():Bool
	{
		var content:String = getSelectedContentDirectory();
		if (content.length < 1)
			return true;

		var prefix:String = getCurrentAddonPrefix();
		return prefix != null && prefix.length < 1;
	}

	public static function addonAllowedForCurrentContent(folder:String):Bool
	{
		folder = normalizeFolderKey(folder);
		var content:String = getSelectedContentDirectory();
		if (content.length < 1)
			return true;
		if (!addonsAllowedForCurrentContent())
			return false;

		var prefix:String = getCurrentAddonPrefix();
		if (prefix == null || prefix.length < 1)
			return true;
		return folder.startsWith(prefix);
	}

	inline public static function pushGlobalMods() // prob a better way to do this but idc
	{
		globalMods = [];
		globalPackageMods = [];
		var contentMods:Array<String> = getContentModDirectories();
		var primaryContentMod:String = contentMods.length > 0 ? contentMods[0] : '';

		for (mod in contentMods)
		{
			if (mod != primaryContentMod && !globalMods.contains(mod))
				globalMods.push(mod);

			for(packageFolder in getPackageDirectories(mod))
			{
				var packagePack:PackageModData = getPackagePack(packageFolder);
				if(packagePack != null && packagePack.global == true && !globalPackageMods.contains(packageFolder))
					globalPackageMods.push(packageFolder);
			}
		}

		if (rootAddonsAllowed())
		{
			for(packageFolder in getRootPackageDirectories())
				if(!globalPackageMods.contains(packageFolder))
					globalPackageMods.push(packageFolder);
		}

		for (mod in getEnabledAddonMods(parseList())) {
			var pack:Dynamic = getPack(mod);
			if (pack != null && pack.runsGlobally && !globalMods.contains(mod)) globalMods.push(mod);

			for(packageFolder in getPackageDirectories(mod))
			{
				var packagePack:PackageModData = getPackagePack(packageFolder);
				if(packagePack != null && packagePack.global == true && !globalPackageMods.contains(packageFolder))
					globalPackageMods.push(packageFolder);
			}
		}
		return globalMods;
	}

	inline public static function clearPackageDirectory():Void
		currentPackageDirectory = '';

	inline public static function isCurrentPackageActive():Bool
		return currentPackageDirectory != null && currentPackageDirectory.trim().length > 0;

	inline public static function getAssetContextKey():String
	{
		var mod:String = currentModDirectory ?? '';
		var pack:String = currentPackageDirectory ?? '';
		return pack.length > 0 ? '$mod::$pack' : mod;
	}

	inline public static function packageDirectory(mod:String, packageName:String = '', ?rootFolder:String):String
	{
		mod = mod == null ? '' : mod.trim();
		packageName = packageName == null ? '' : packageName.trim();
		rootFolder = rootFolder == null || rootFolder.trim().length < 1 ? PACKAGE_MOD_FOLDER : rootFolder.trim();

		if (mod.length < 1)
			return rootFolder + (packageName.length > 0 ? '/$packageName' : '');
		return '$mod/$rootFolder' + (packageName.length > 0 ? '/$packageName' : '');
	}

	inline public static function getModDirectories():Array<String>
	{
		var list:Array<String> = [];
		
		#if MODS_ALLOWED
		var modsFolder:String = Paths.mods();

		if (FileSystem.exists(modsFolder)) {
			for (folder in FileSystem.readDirectory(modsFolder)) {
				if (directoryIsMod(folder))
					list.push(folder);
			}
		}
		#end
		
		return list;
	}

	public static function getContentDirectories():Array<String>
	{
		if (contentDirectoriesCache != null)
			return contentDirectoriesCache.copy();

		var list:Array<String> = [];

		#if MODS_ALLOWED
		var contentsFolder:String = Paths.contents();
		if (FileSystem.exists(contentsFolder))
		{
			for (folder in FileSystem.readDirectory(contentsFolder))
			{
				var absolute:String = Paths.contents(folder);
				if (FileSystem.exists(absolute) && FileSystem.isDirectory(absolute) && directoryIsContent(folder))
					list.push(folder);
			}
		}
		list.sort(Reflect.compare);
		#end

		contentDirectoriesCache = list;
		return list.copy();
	}

	static function directoryIsContent(folder:String):Bool
	{
		#if MODS_ALLOWED
		folder = normalizeFolderKey(folder);
		if (folder.length < 1)
			return false;

		var dir:String = Paths.contents(folder);
		if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir))
			return false;

		return FileSystem.exists('$dir/data.json') || FileSystem.exists('$dir/data.xml');
		#else
		return false;
		#end
	}

	public static function getContentModDirectories(?content:String):Array<String>
	{
		var list:Array<String> = [];

		#if MODS_ALLOWED
		content = normalizeFolderKey(content ?? getSelectedContentDirectory());
		if (content.length < 1 || !directoryIsContent(content))
			return list;

		var rootRelative:String = contentRootDirectory(content);
		var rootAbsolute:String = Paths.mods(rootRelative);
		for (folder in FileSystem.readDirectory(rootAbsolute))
		{
			var relative:String = contentModDirectory(content, folder);
			var absolute:String = Paths.mods(relative);
			if (!FileSystem.exists(absolute) || !FileSystem.isDirectory(absolute))
				continue;

			if (directoryIsMod(relative) && !list.contains(relative))
				list.push(relative);
		}
		list.sort(Reflect.compare);

		if (list.length < 1 && directoryIsMod(rootRelative))
			list.push(rootRelative);
		#end

		return list;
	}

	public static function getEnabledAddonMods(?list:ModsList):Array<String>
	{
		list ??= parseList();
		var enabled:Array<String> = [];

		for (mod in list.enabled)
			if (list.available.contains(mod) && addonAllowedForCurrentContent(mod) && !enabled.contains(mod))
				enabled.push(mod);
		return enabled;
	}

	public static function getGameplayModDirectories(?list:ModsList):Array<String>
	{
		var directories:Array<String> = getContentModDirectories();
		for (mod in getEnabledAddonMods(list))
			if (!directories.contains(mod))
				directories.push(mod);
		return directories;
	}

	public static function getActiveModDirectories():Array<String>
	{
		var directories:Array<String> = [];
		if (currentModDirectory != null && currentModDirectory.trim().length > 0)
			directories.push(currentModDirectory);

		for (mod in getGlobalMods())
			if (mod != null && mod.trim().length > 0 && !directories.contains(mod))
				directories.push(mod);
		return directories;
	}

	public static function getModFolderFromPath(path:String):String
	{
		path = normalizeFolderKey(path);
		for (mod in getGameplayModDirectories())
		{
			var modPath:String = normalizeFolderKey(Paths.mods(mod + '/'));
			if (path.startsWith(modPath))
				return mod;
		}
		return null;
	}

	public static function folderFromDirectoryPath(path:String):String
	{
		path = normalizeFolderKey(path);
		while (path.endsWith('/'))
			path = path.substr(0, path.length - 1);

		var addonRoot:String = normalizeFolderKey(Paths.mods());
		if (path.startsWith(addonRoot))
			return path.substr(addonRoot.length);
		return path;
	}

	static function parseContentBool(value:String, fallback:Bool):Bool
	{
		if (value == null)
			return fallback;
		switch (value.trim().toLowerCase())
		{
			case 'true', '1', 'yes', 'y', 'on': return true;
			case 'false', '0', 'no', 'n', 'off': return false;
		}
		return fallback;
	}

	public static function getContentData(?folder:String):ContentData
	{
		#if MODS_ALLOWED
		folder = normalizeFolderKey(folder);
		if (folder.length < 1)
			return null;
		if (contentDataCache.exists(folder))
			return contentDataCache.get(folder);

		var jsonPath:String = Paths.contents('$folder/data.json');
		if (FileSystem.exists(jsonPath))
		{
			try {
				var rawJson:String = File.getContent(jsonPath);
				if(rawJson != null && rawJson.length > 0)
				{
					var data:ContentData = cast tjson.TJSON.parse(rawJson);
					contentDataCache.set(folder, data);
					return data;
				}
			} catch(e:Dynamic) {
				trace(e);
			}
		}

		var xmlPath:String = Paths.contents('$folder/data.xml');
		if (FileSystem.exists(xmlPath))
		{
			try {
				var rawXml:String = File.getContent(xmlPath);
				if (rawXml != null && rawXml.length > 0)
				{
					var root:Xml = Xml.parse(rawXml).firstElement();
					if (root != null)
					{
						var data:ContentData = {};
						data.name = root.get('name');
						data.description = root.get('description');
						data.version = root.get('version');
						data.author = root.get('author');
						data.discordRPC = root.get('discordRPC');
						data.icon = root.get('icon');
						var addonsNode:Xml = null;
						for (node in root.elementsNamed('addons'))
						{
							addonsNode = node;
							break;
						}
						if (addonsNode != null)
						{
							data.addons = {
								allowAddons: parseContentBool(addonsNode.get('allowAddons'), false),
								addonPrefix: addonsNode.get('addonPrefix') ?? ''
							};
						}
						else if (root.exists('allowAddons') || root.exists('addonPrefix'))
						{
							data.addons = {
								allowAddons: parseContentBool(root.get('allowAddons'), false),
								addonPrefix: root.get('addonPrefix') ?? ''
							};
						}
						contentDataCache.set(folder, data);
						return data;
					}
				}
			} catch(e:Dynamic) {
				trace(e);
			}
		}
		#end
		contentDataCache.set(folder, null);
		return null;
	}
	
	inline public static function mergeAllTextsNamed(path:String, ?defaultDirectory:String = null, allowDuplicates:Bool = false)
	{
		if(defaultDirectory == null) defaultDirectory = Paths.getSharedPath();
		defaultDirectory = defaultDirectory.trim();
		if(!defaultDirectory.endsWith('/')) defaultDirectory += '/';
		if(!defaultDirectory.startsWith('assets/')) defaultDirectory = 'assets/$defaultDirectory';

		var mergedList:Array<String> = [];
		var paths:Array<String> = directoriesWithFile(defaultDirectory, path);

		var defaultPath:String = defaultDirectory + path;
		if(paths.contains(defaultPath))
		{
			paths.remove(defaultPath);
			paths.insert(0, defaultPath);
		}

		for (file in paths)
		{
			var list:Array<String> = CoolUtil.coolTextFile(file);
			for (value in list)
				if((allowDuplicates || !mergedList.contains(value)) && value.length > 0)
					mergedList.push(value);
		}
		return mergedList;
	}

	inline public static function directoriesWithFile(path:String, fileToFind:String, mods:Bool = true)
	{
		//Main folder
		var foldersToCheck:Array<String> = [];
		var addFolder = function(folder:String) {
			if (folder != null && folder.length > 0 && !foldersToCheck.contains(folder))
				foldersToCheck.push(folder);
		};

		#if sys
		if (FileSystem.exists(path + fileToFind))
		#else
		if (Assets.exists(path + fileToFind))
		#end
			addFolder(path + fileToFind);

		if(Paths.currentLevel != null && Paths.currentLevel != path)
		{
			var pth:String = Paths.getFolderPath(fileToFind, Paths.currentLevel);
			if(FileSystem.exists(pth))
				addFolder(pth);
		}

		#if MODS_ALLOWED
		if(mods)
		{
			if(isCurrentPackageActive() && packageSupportsKey(fileToFind))
			{
				var folder:String = Paths.mods(Mods.currentPackageDirectory + '/' + fileToFind);
				if(FileSystem.exists(folder)) addFolder(folder);
			}

			for(mod in getActiveModDirectories())
			{
				var folder:String = Paths.mods(mod + '/' + fileToFind);
				if(FileSystem.exists(folder)) addFolder(folder);
			}

			for(packageFolder in getPackageSearchDirectories(fileToFind, false, true))
			{
				var folder:String = Paths.mods(packageFolder + '/' + fileToFind);
				if(FileSystem.exists(folder)) addFolder(folder);
			}

			if(rootAddonsAllowed())
			{
				var folder:String = Paths.mods(fileToFind);
				if(FileSystem.exists(folder)) addFolder(folder);
			}
		}
		#end
		return foldersToCheck;
	}

	public static function getPack(?folder:String = null):Dynamic
	{
		#if MODS_ALLOWED
		if(folder == null) folder = Mods.currentModDirectory;
		if(folder == null || folder.trim().length < 1)
			return null;

		var path = Paths.mods(folder + '/pack.json');
		if(FileSystem.exists(path)) {
			try {
				#if sys
				var rawJson:String = File.getContent(path);
				#else
				var rawJson:String = Assets.getText(path);
				#end
				if(rawJson != null && rawJson.length > 0) return tjson.TJSON.parse(rawJson);
			} catch(e:Dynamic) {
				trace(e);
			}
		}
		#end
		return null;
	}

	static function normalizeStateName(name:String):String // eu acho que eu cansei
	{
		if (name == null)
			return null;

		name = name.replace('\\', '/').trim();
		if (name.length < 1)
			return null;

		if (name.endsWith('.lua'))
			name = name.substr(0, name.length - 4);
		else if (name.endsWith('.hx'))
			name = name.substr(0, name.length - 3);

		var slash:Int = name.lastIndexOf('/');
		if (slash >= 0)
			name = name.substr(slash + 1);

		var dot:Int = name.lastIndexOf('.');
		if (dot >= 0)
			name = name.substr(dot + 1);

		return name.trim();
	}

	static function normalizeScriptName(name:String):String
	{
		if (name == null)
			return null;

		name = name.replace('\\', '/').trim();
		if (name.length < 1)
			return null;

		if (name.endsWith('.lua'))
			name = name.substr(0, name.length - 4);
		else if (name.endsWith('.hx'))
			name = name.substr(0, name.length - 3);

		return name.trim();
	}

	public static function getStateName(name:String):String
		return normalizeStateName(name);

	public static function getStateScriptName(name:String):String
	{
		var stateName:String = normalizeStateName(name);
		if (stateName == null)
			return null;

		var folders:Array<String> = getActiveModDirectories();

		for (folder in folders)
		{
			var pack:Dynamic = getPack(folder);
			if (pack == null || pack.states == null)
				continue;

			var statesMap:Dynamic = pack.states;
			if (Reflect.hasField(statesMap, stateName))
			{
				var alias:String = normalizeScriptName(Std.string(Reflect.field(statesMap, stateName)));
				if (alias != null && alias.length > 0)
					return alias;
			}
		}
		return null;
	}

	public static function packageSupportsKey(key:String):Bool
	{
		if (key == null)
			return false;

		key = key.replace('\\', '/').toLowerCase().trim();
		if (key.length < 1)
			return false;
		if (key == 'pack.json' || key == 'package.json' || key == 'package.xml')
			return false;
		if (key.startsWith('states/') || key.startsWith('substates/') || key.startsWith('characters/'))
			return false;
		if (key.startsWith('music/') || key.startsWith('stages/') || key.startsWith('weeks/'))
			return false;
		if (key.startsWith('fonts/') || key.startsWith('videos/') || key.startsWith('shaders/'))
			return false;
		if (key.startsWith('data/events/'))
			return false;
		if (key.startsWith('data/states/') || key.startsWith('data/substates/'))
			return false;
		if (key.startsWith('data/scripts/states/') || key.startsWith('data/scripts/substates/'))
			return false;

		return key.startsWith('images/')
			|| key.startsWith('sounds/')
			|| key.startsWith('songs/')
			|| key.startsWith('data/notetypes/')
			|| key.startsWith('data/scripts/');
	}

	public static function getPackageDirectories(?mod:String):Array<String>
	{
		if (mod == null) mod = currentModDirectory;
		if (mod == null || mod.trim().length < 1)
			return [];

		return getPackageDirectoriesFromMod(mod);
	}

	public static function getRootPackageDirectories():Array<String>
		return getPackageDirectoriesFromMod('');

	static function getPackageDirectoriesFromMod(mod:String):Array<String>
	{
		var list:Array<String> = [];

		#if MODS_ALLOWED
		mod = mod == null ? '' : mod.trim();
		for(rootFolder in PACKAGE_MOD_FOLDERS)
		{
			var rootRelative:String = packageDirectory(mod, '', rootFolder);
			var packageRoot:String = Paths.mods(rootRelative);
			if (!FileSystem.exists(packageRoot) || !FileSystem.isDirectory(packageRoot))
				continue;

			if (isPackageFolder(packageRoot) && !list.contains(rootRelative))
				list.push(rootRelative);

			for (folder in FileSystem.readDirectory(packageRoot))
			{
				var relative:String = packageDirectory(mod, folder, rootFolder);
				var absolute:String = Paths.mods(relative);
				if (!FileSystem.exists(absolute) || !FileSystem.isDirectory(absolute))
					continue;

				if (isPackageFolder(absolute) && !list.contains(relative))
					list.push(relative);
			}
		}
		#end

		return list;
	}

	static function isPackageFolder(absolute:String):Bool  // é mais facil fazer com carinho eu acho
	{
		#if MODS_ALLOWED
		if (absolute == null || !FileSystem.exists(absolute) || !FileSystem.isDirectory(absolute))
			return false;

		if (FileSystem.exists(absolute + '/package.json') || FileSystem.exists(absolute + '/package.xml'))
			return true;

		for (folder in packageContentFolders)
			if (FileSystem.exists(absolute + '/' + folder))
				return true;

		if (FileSystem.exists(absolute + '/data/notetypes') || FileSystem.exists(absolute + '/data/scripts'))
			return true;
		#end
		return false;
	}

	public static function getPackagePack(?packageFolder:String):PackageModData
	{
		#if MODS_ALLOWED
		if (packageFolder == null) packageFolder = currentPackageDirectory;
		if (packageFolder == null || packageFolder.trim().length < 1)
			return null;

		var jsonPath:String = Paths.mods(packageFolder + '/package.json');
		if (FileSystem.exists(jsonPath))
		{
			try {
				var rawJson:String = File.getContent(jsonPath);
				if (rawJson != null && rawJson.length > 0)
					return cast tjson.TJSON.parse(rawJson);
			} catch (e:Dynamic) {
				trace(e);
			}
		}

		var xmlPath:String = Paths.mods(packageFolder + '/package.xml');
		if (FileSystem.exists(xmlPath))
		{
			try {
				var rawXml:String = File.getContent(xmlPath);
				if (rawXml != null && rawXml.length > 0)
				{
					var root:Xml = Xml.parse(rawXml).firstElement();
					if (root != null)
					{
						var data:PackageModData = {};
						var globalAttr:String = root.get('global');
						if (globalAttr != null)
							data.global = ['true', '1', 'yes'].contains(globalAttr.toLowerCase());
						data.name = root.get('name');
						data.description = root.get('description');
						return data;
					}
				}
			} catch (e:Dynamic) {
				trace(e);
			}
		}
		#end

		return null;
	}

	public static function getPackageSearchDirectories(key:String, includeCurrent:Bool = true, includeGlobals:Bool = true):Array<String>
	{
		var list:Array<String> = [];
		if (!packageSupportsKey(key))
			return list;

		var addPackage = function(folder:String) {
			if (folder != null && folder.trim().length > 0 && !list.contains(folder))
				list.push(folder);
		};

		#if MODS_ALLOWED
		if (includeCurrent && isCurrentPackageActive())
			addPackage(currentPackageDirectory);

		for(mod in getActiveModDirectories())
		{
			for(packageFolder in getPackageDirectories(mod))
				if (packageFolder != currentPackageDirectory)
					addPackage(packageFolder);
		}

		if (includeGlobals)
		{
			if (rootAddonsAllowed())
			{
				for(packageFolder in getRootPackageDirectories())
					if (packageFolder != currentPackageDirectory)
						addPackage(packageFolder);
			}

			for(packageFolder in getGlobalPackageMods())
				if (packageFolder != currentPackageDirectory)
					addPackage(packageFolder);
		}
		#end

		return list;
	}

	public static var updatedOnState:Bool = false;
	inline public static function parseList():ModsList {
		var list:ModsList = {enabled: [], disabled: [], all: [], available: []};

		#if MODS_ALLOWED
		#if sys
		var listFile:String = FileSystem.exists(ADDONS_LIST_FILE) ? ADDONS_LIST_FILE : LEGACY_MODS_LIST_FILE;
		if (FileSystem.exists(listFile)) {
			try {
				for (mod in CoolUtil.coolTextFile(listFile)) {
					if (mod.trim().length < 1) continue;

					var dat = mod.split('|');
					var folder:String = dat[0];
					var modEnabled:Bool = (dat[1] == '1');

					list.all.push(folder);
					(modEnabled ? list.enabled : list.disabled).push(folder);
					if (directoryIsMod(folder)) list.available.push(folder);

					ClientPrefs.modsEnabled.set(folder, modEnabled);
				}
			} catch(e) {
				trace(e);

				FileSystem.deleteFile(listFile);
			}
		} else #end {
			for (mod => enabled in ClientPrefs.modsEnabled) {
				list.all.push(mod);
				(enabled ? list.enabled : list.disabled).push(mod);
				if (directoryIsMod(mod)) list.available.push(mod);
			}
		}
		#end

		if (!updatedOnState) updateModList(list);

		return list;
	}

	public static function updateModList(?list:ModsList) {
		#if MODS_ALLOWED
		var list:ModsList = (list ?? parseList());

		for (folder in getModDirectories()) {
			if (!list.all.contains(folder) && directoryIsMod(folder)) {
				list.all.push(folder);
				list.enabled.push(folder);
				list.available.push(folder);

				ClientPrefs.modsEnabled.set(folder, true);
			}
		}

		#if sys
		var content:String = '';
		for (mod in list.available)
			content += '$mod|${list.enabled.contains(mod) ? 1 : 0}\n';

		File.saveContent(ADDONS_LIST_FILE, content);
		#end

		updatedOnState = true;
		#end
	}

	private static function directoryIsMod(dir:String):Bool {
		dir = normalizeFolderKey(dir);
		if (dir.length == 0)
			return false;

		var folderName:String = dir;
		var lastSlash:Int = folderName.lastIndexOf('/');
		if (lastSlash >= 0)
			folderName = folderName.substr(lastSlash + 1);
		if (ignoreModFolders.contains(folderName.toLowerCase()))
			return false;

		dir = Paths.mods(dir);

		if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) {
			if (FileSystem.exists('$dir/.notamod'))
				return false;

			if (FileSystem.exists('$dir/pack.json'))
				return true;

			for (sub in ignoreModFolders) {
				if (FileSystem.exists('$dir/$sub'))
					return true;
			}
		}

		return false;
	}

	public static function loadTopMod()
	{
		Mods.currentModDirectory = '';
		Mods.currentPackageDirectory = '';

		#if MODS_ALLOWED
		syncSelectedContentFromPrefs();
		var contentMods:Array<String> = getContentModDirectories();
		if (contentMods.length > 0)
		{
			Mods.currentModDirectory = contentMods[0];
			pushGlobalMods();
			return;
		}

		var list:ModsList = Mods.parseList();

		for (mod in list.available) {
			if (list.enabled.contains(mod) && addonAllowedForCurrentContent(mod)) {
				Mods.currentModDirectory = mod;
				pushGlobalMods();
				return;
			}
		}
		pushGlobalMods();
		#end
	}

	inline public static function modUsesStickerTrans()
	{
		var pack:Dynamic = getPack(Mods.currentModDirectory);
		if (pack != null && pack.enableSticker != null) return pack.enableSticker;
		return false;
	}

	public static function clearStoredWithoutStickers() {
		@:privateAccess
		var cache = FlxG.bitmap._cache;
		for (key => val in cache){
			if(	key.toLowerCase().contains("transitionswag")
				|| key.contains("bg_graphic_")
				|| key == "images/faceSticker.png")
				Paths.currentTrackedAssets.set(key,val);
		}
		Paths.clearStoredMemory();
		cacheStickersToContext();
	}

	public static function cacheStickersToContext() {
		for (key => val in Paths.currentTrackedAssets){
			if(	key.toLowerCase().contains("transitionswag")
				|| key.contains("bg_graphic_")
				|| key == "images/faceSticker.png")
				Paths.localTrackedAssets.push(key);
		}
	}
}
