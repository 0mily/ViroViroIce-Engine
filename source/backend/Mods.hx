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

class Mods
{
	static public var currentModDirectory:String = '';
	static public var currentPackageDirectory:String = '';
	public static inline var PACKAGE_MOD_FOLDER:String = 'packageMod';
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

	inline public static function pushGlobalMods() // prob a better way to do this but idc
	{
		globalMods = [];
		globalPackageMods = [];
		for(packageFolder in getRootPackageDirectories())
			if(!globalPackageMods.contains(packageFolder))
				globalPackageMods.push(packageFolder);

		for (mod in parseList().enabled) {
			var pack:Dynamic = getPack(mod);
			if (pack != null && pack.runsGlobally) globalMods.push(mod);

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

			if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			{
				var folder:String = Paths.mods(Mods.currentModDirectory + '/' + fileToFind);
				if(FileSystem.exists(folder)) addFolder(folder);
			}

			for(packageFolder in getPackageSearchDirectories(fileToFind, false, true))
			{
				var folder:String = Paths.mods(packageFolder + '/' + fileToFind);
				if(FileSystem.exists(folder)) addFolder(folder);
			}

			var folder:String = Paths.mods(fileToFind);
			if(FileSystem.exists(folder)) addFolder(folder);

			for(mod in Mods.getGlobalMods())
			{
				folder = Paths.mods(mod + '/' + fileToFind);
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
				var rawJson:String = Paths.getTextFromFile(path);
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

		var folders:Array<String> = [];
		if (currentModDirectory != null && currentModDirectory.length > 0)
			folders.push(currentModDirectory);
		for (mod in getGlobalMods())
			if (!folders.contains(mod))
				folders.push(mod);

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
				var rawJson:String = Paths.getTextFromFile(jsonPath);
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
				var rawXml:String = Paths.getTextFromFile(xmlPath);
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

		if (currentModDirectory != null && currentModDirectory.trim().length > 0)
		{
			for(packageFolder in getPackageDirectories(currentModDirectory))
				if (packageFolder != currentPackageDirectory)
					addPackage(packageFolder);
		}

		if (includeGlobals)
		{
			for(packageFolder in getRootPackageDirectories())
				if (packageFolder != currentPackageDirectory)
					addPackage(packageFolder);

			for(packageFolder in getGlobalPackageMods())
				if (packageFolder != currentPackageDirectory)
					addPackage(packageFolder);

			for(mod in getGlobalMods())
			{
				for(packageFolder in getPackageDirectories(mod))
					if (packageFolder != currentPackageDirectory)
						addPackage(packageFolder);
			}
		}
		#end

		return list;
	}

	public static var updatedOnState:Bool = false;
	inline public static function parseList():ModsList {
		var list:ModsList = {enabled: [], disabled: [], all: [], available: []};

		#if MODS_ALLOWED
		#if sys if (FileSystem.exists('modsList.txt')) {
			try {
				for (mod in CoolUtil.coolTextFile('modsList.txt')) {
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

				FileSystem.deleteFile('modsList.txt');
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

		File.saveContent('modsList.txt', content);
		#end

		updatedOnState = true;
		#end
	}

	private static function directoryIsMod(dir:String):Bool {
		if (dir.trim().length == 0 || ignoreModFolders.contains(dir.toLowerCase())) return false;

		dir = Paths.mods(dir);

		if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) {
			if (FileSystem.exists('$dir/.notamod'))
				return false;

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
		var list:ModsList = Mods.parseList();

		for (mod in list.available) {
			if (list.enabled.contains(mod)) {
				Mods.currentModDirectory = mod;
				return;
			}
		}
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
