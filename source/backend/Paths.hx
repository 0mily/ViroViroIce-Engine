package backend;

import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxRect;
import flixel.system.FlxAssets;

import openfl.display.BitmapData;
import openfl.display3D.textures.RectangleTexture;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.system.System;
import openfl.geom.Rectangle;

import lime.utils.Assets;
import flash.media.Sound;

import haxe.Json;
import haxe.io.Path as HaxePath;

import animate.FlxAnimateFrames;
import animate.FlxAnimateFrames.SpritemapInput;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

#if ADDONS_ALLOWED
import backend.Mods;
#end

typedef AudioFolderCandidate = {
	var folder:String;
	var matchKey:String;
}

@:access(openfl.display.BitmapData)
class Paths
{
	#if html5
	inline public static var SOUND_EXT = "mp3";
	public static final SOUND_EXTENSIONS:Array<String> = ["mp3"];
	#else
	inline public static var SOUND_EXT = "ogg";
	public static final SOUND_EXTENSIONS:Array<String> = ["ogg"];
	#end
	inline public static var VIDEO_EXT = "mp4";

	public static function excludeAsset(key:String) {
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static var dumpExclusions:Array<String> = [
		'assets/shared/music/menus/mainMenu/music.$SOUND_EXT',
		'assets/shared/music/menus/MainMenu/music.$SOUND_EXT'
	];
	// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory()
	{
		var protectedGfx:Array<FlxGraphic> = collectLiveGraphics();
		// clear non local assets in the tracked assets list
		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && !protectedGfx.contains(currentTrackedAssets.get(key)))
			{
				destroyGraphic(currentTrackedAssets.get(key)); // get rid of the graphic
				currentTrackedAssets.remove(key); // and remove the key from local cache map
			}
		}

		// run the garbage collector for good measure lmfao
		System.gc();
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = [];

	@:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
	public static function clearStoredMemory()
	{
		var protectedGfx:Array<FlxGraphic> = collectLiveGraphics();
		// clear anything not in the tracked assets list
		for (key in FlxG.bitmap._cache.keys())
		{
			var graphic:FlxGraphic = FlxG.bitmap.get(key);
			if (!currentTrackedAssets.exists(key) && !isProtectedCachedGraphic(key, graphic, protectedGfx))
				destroyGraphic(graphic);
		}

		// clear all sounds that are cached
		for (key => asset in currentTrackedSounds)
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && asset != null)
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}
		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = [];
		#if !html5 openfl.Assets.cache.clear("songs"); #end
	}

	static function collectLiveGraphics():Array<FlxGraphic>
	{
		var protectedGfx:Array<FlxGraphic> = [];
		function checkForGraphics(spr:Dynamic, depth:Int = 0):Void
		{
			if(spr == null || depth > 32)
				return;

			try
			{
				var gfx:FlxGraphic = Reflect.getProperty(spr, 'graphic');
				if(gfx != null && !protectedGfx.contains(gfx))
					protectedGfx.push(gfx);
			}
			catch(e:Dynamic) {}

			try
			{
				var grp:Array<Dynamic> = Reflect.getProperty(spr, 'members');
				if(grp != null)
					for (member in grp)
						checkForGraphics(member, depth + 1);
			}
			catch(e:Dynamic) {}
		}

		if(FlxG.state != null)
		{
			checkForGraphics(FlxG.state);
			if(FlxG.state.subState != null)
				checkForGraphics(FlxG.state.subState);
		}
		return protectedGfx;
	}

	static function isProtectedCachedGraphic(key:String, graphic:FlxGraphic, protectedGfx:Array<FlxGraphic>):Bool
	{
		if(graphic == null || protectedGfx.contains(graphic))
			return true;
		if(key == null)
			return true;

		var normalized:String = StringTools.replace(key, '\\', '/');
		return StringTools.startsWith(normalized, 'flixel/')
			|| StringTools.startsWith(normalized, 'openfl/')
			|| StringTools.startsWith(normalized, 'assets/flixel/');
	}

	public static function freeGraphicsFromMemory()
	{
		var protectedGfx:Array<FlxGraphic> = collectLiveGraphics();

		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!dumpExclusions.contains(key))
			{
				var graphic:FlxGraphic = currentTrackedAssets.get(key);
				if(!protectedGfx.contains(graphic))
				{
					destroyGraphic(graphic); // get rid of the graphic
					currentTrackedAssets.remove(key); // and remove the key from local cache map
					//trace('deleted $key');
				}
			}
		}
	}

	inline static function destroyGraphic(graphic:FlxGraphic)
	{
		// free some gpu memory
		if (graphic != null && graphic.bitmap != null && graphic.bitmap.__texture != null)
			graphic.bitmap.__texture.dispose();
		FlxG.bitmap.remove(graphic);
	}

	static public var currentLevel:String;
	static public function setCurrentLevel(name:String)
		currentLevel = name.toLowerCase();

	public static function getPath(file:String, ?type:AssetType = TEXT, ?parentfolder:String, ?modsAllowed:Bool = true):String
	{
		#if ADDONS_ALLOWED
		if(modsAllowed)
		{
			var customFile:String = file;
			if (parentfolder != null) customFile = '$parentfolder/$file';

			var modded:String = modFolders(customFile);
			if(FileSystem.exists(modded)) return modded;
		}
		#end

		if (parentfolder != null)
			return getFolderPath(file, parentfolder);

		if (currentLevel != null && currentLevel != 'shared')
		{
			var levelPath = getFolderPath(file, currentLevel);
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}
		
		if (#if sys FileSystem.exists(file) #else OpenFlAssets.exists(file) #end) return file;
		
		return getSharedPath(file);
	}

	inline static public function getFolderPath(file:String, folder = "shared")
		return 'assets/$folder/$file';

	inline public static function getSharedPath(file:String = '')
		return 'assets/shared/$file';

	inline static public function txt(key:String, ?folder:String)
		return getPath('data/$key.txt', TEXT, folder, true);

	inline static public function xml(key:String, ?folder:String)
		return getPath('data/$key.xml', TEXT, folder, true);

	inline static public function json(key:String, ?folder:String)
		return getPath('songs/$key.json', TEXT, folder, true);

	inline static public function shaderFragment(key:String, ?folder:String)
		return getPath('shaders/$key.frag', TEXT, folder, true);

	inline static public function shaderVertex(key:String, ?folder:String)
		return getPath('shaders/$key.vert', TEXT, folder, true);

	inline static public function lua(key:String, ?folder:String)
		return getPath('$key.lua', TEXT, folder, true);

	static public function video(key:String)
	{
		#if ADDONS_ALLOWED
		var file:String = modsVideo(key);
		if(FileSystem.exists(file)) return file;
		#end
		return 'assets/videos/$key.$VIDEO_EXT';
	}

	inline static public function sound(key:String, ?modsAllowed:Bool = true):Sound
		return returnSound('sounds/$key', null, modsAllowed);

	inline static public function music(key:String, ?modsAllowed:Bool = true):Sound
		return returnSound('music/$key', null, modsAllowed);

	inline static public function uiSound(key:String, ?modsAllowed:Bool = true):Sound
		return sound('general/$key', modsAllowed);

	inline static public function gameSound(key:String, ?modsAllowed:Bool = true):Sound
		return sound('game/$key', modsAllowed);

	inline static public function editorSound(key:String, ?modsAllowed:Bool = true):Sound
		return sound('editors/$key', modsAllowed);

	inline static public function chartEditorSound(key:String, ?modsAllowed:Bool = true):Sound
		return editorSound('charting/$key', modsAllowed);

	inline static public function hitsound(?modsAllowed:Bool = true):Sound
		return gameSound('hitsound', modsAllowed);

	inline static public function missnote(index:Int, ?modsAllowed:Bool = true):Sound
		return gameSound('missnotes/missnote$index', modsAllowed);

	inline static public function missnoteRandom(?modsAllowed:Bool = true):Sound
		return missnote(FlxG.random.int(1, 3), modsAllowed);

	inline static public function countdownSound(uiName:String, soundName:String, ?modsAllowed:Bool = true):Sound
		return gameSound('countdown/${normalizeAudioVariant(uiName, "default")}/${normalizeSoundLeaf(soundName, "intro1")}', modsAllowed);

	inline static public function dialogueSound(uiName:String, soundName:String, ?modsAllowed:Bool = true):Sound
		return gameSound('dialogue/${normalizeAudioVariant(uiName, "default")}/${normalizeSoundLeaf(soundName, "dialogue")}', modsAllowed);

	inline static public function menuMusic(menuName:String, ?track:String = 'music', ?modsAllowed:Bool = true):Sound
		return music('menus/${resolveMenuFolderName(menuName, modsAllowed)}/${normalizeSoundLeaf(track, "music")}', modsAllowed);

	inline static public function editorMusic(editorName:String, ?track:String = 'music', ?modsAllowed:Bool = true):Sound
		return music('editors/${normalizePathPart(editorName, "chartingEditor")}/${normalizeSoundLeaf(track, "music")}', modsAllowed);

	public static function pauseMusic(pauseMusicName:String, ?characterName:String = 'default', ?uiName:String = null, ?track:String = 'music', ?modsAllowed:Bool = true):Sound
	{
		var musicName:String = formatToSongPath(normalizePathPart(pauseMusicName, 'breakfast'));
		var character:String = normalizeAudioCharacter(characterName);
		var ui:String = normalizeAudioVariant(uiName, null);
		var trackName:String = normalizeSoundLeaf(track, 'music');

		var candidates:Array<String> = [];
		addAudioCharacterMusicCandidates(candidates, 'music/game/pause/$musicName', character, ui, trackName, modsAllowed);
		return returnSound(findExistingSoundKey(candidates, null, modsAllowed), null, modsAllowed);
	}

	public static function gameOverSound(soundName:String, ?characterName:String = 'default', ?modsAllowed:Bool = true, ?beepOnNull:Bool = true, ?includeGeneric:Bool = true):Sound
	{
		var sound:String = normalizeSoundLeaf(soundName, 'fnf_loss_sfx');
		var character:String = normalizeGameOverAudioCharacter(characterName);

		var candidates:Array<String> = [];
		if(character != 'default')
		{
			candidates.push('sounds/game/gameover/$character/$sound');
			candidates.push('sounds/gameover/$character/$sound');
		}
		if(includeGeneric)
		{
			candidates.push('sounds/game/gameover/$sound');
			candidates.push('sounds/gameover/$sound');
			candidates.push('sounds/$sound');
		}
		return returnSound(findExistingSoundKey(candidates, null, modsAllowed), null, modsAllowed, beepOnNull);
	}

	public static function gameOverMusic(characterName:String, uiName:String, ?track:String = 'music', ?modsAllowed:Bool = true, ?beepOnNull:Bool = true):Sound
	{
		var character:String = normalizeGameOverAudioCharacter(characterName);
		var ui:String = normalizeAudioVariant(uiName, null);
		var trackNames:Array<String> = gameOverTrackCandidates(track);

		var candidates:Array<String> = [];
		for(trackName in trackNames)
			for(root in gameOverMusicRoots())
				addAudioCharacterMusicCandidates(candidates, root, character, ui, trackName, modsAllowed);
		return returnSound(findExistingSoundKey(candidates, null, modsAllowed), null, modsAllowed, beepOnNull);
	}

	public static function gameOverScriptFolders(characterName:String, uiName:String, ?modsAllowed:Bool = true):Array<String>
	{
		var character:String = normalizeGameOverAudioCharacter(characterName);
		var ui:String = normalizeAudioVariant(uiName, null);

		var folders:Array<String> = ['music/game/gameover/scripts'];
		for(root in gameOverMusicRoots())
		{
			var characterFolders:Array<String> = audioCharacterScriptFolders(root, character, ui, modsAllowed);
			characterFolders.reverse();
			for(folder in characterFolders)
				addUniqueString(folders, folder);
		}
		return folders;
	}

	public static function pauseScriptFolders(pauseMusicName:String, characterName:String, uiName:String, ?modsAllowed:Bool = true):Array<String>
	{
		var musicName:String = formatToSongPath(normalizePathPart(pauseMusicName, 'breakfast'));
		var character:String = normalizeAudioCharacter(characterName);
		var ui:String = normalizeAudioVariant(uiName, null);
		var root:String = 'music/game/pause/$musicName';
		var folders:Array<String> = ['music/game/pause/scripts', '$root/scripts'];
		var characterFolders:Array<String> = audioCharacterScriptFolders(root, character, ui, modsAllowed);
		characterFolders.reverse();
		for(folder in characterFolders)
			addUniqueString(folders, folder);
		return folders;
	}

	inline static public function inst(song:String, ?modsAllowed:Bool = true):Sound
    	return returnSound('${formatToSongPath(song)}/song/Inst', 'songs', modsAllowed);

	static public function voices(song:String, postfix:String = null, ?modsAllowed:Bool = true):Sound
	{
		var songKey:String = '${formatToSongPath(song)}/song/Voices';
		if(postfix == null || postfix.trim().length < 1)
			return returnSound(songKey, 'songs', modsAllowed, false);

		var candidates:Array<String> = [];
		addVoicePostfixCandidates(candidates, songKey, postfix);
		return returnSound(findExistingSoundKey(candidates, 'songs', modsAllowed), 'songs', modsAllowed, false);
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?modsAllowed:Bool = true)
		return sound(key + FlxG.random.int(min, max), modsAllowed);

	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];
	static public function image(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxGraphic
	{
		key = Language.getFileTranslation('images/$key') + '.png';
		var bitmap:BitmapData = null;
		if (currentTrackedAssets.exists(key))
		{
			localTrackedAssets.push(key);
			return currentTrackedAssets.get(key);
		}
		return cacheBitmap(key, parentFolder, bitmap, allowGPU);
	}

	public static function cacheBitmap(key:String, ?parentFolder:String = null, ?bitmap:BitmapData, ?allowGPU:Bool = true):FlxGraphic
	{
		if (bitmap == null)
		{
			var file:String = getPath(key, IMAGE, parentFolder, true);
			#if (ADDONS_ALLOWED && sys)
			if (FileSystem.exists(file))
				bitmap = BitmapData.fromFile(file);
			else #end if (OpenFlAssets.exists(file, IMAGE))
				bitmap = OpenFlAssets.getBitmapData(file);

			if (bitmap == null)
			{
				trace('Bitmap not found: $file | key: $key');
				return null;
			}
		}

		if (allowGPU && ClientPrefs.data.cacheOnGPU && bitmap.image != null)
		{
			bitmap.lock();
			if (bitmap.__texture == null)
			{
				bitmap.image.premultiplied = true;
				bitmap.getTexture(FlxG.stage.context3D);
			}
			bitmap.getSurface();
			bitmap.disposeImage();
			bitmap.image.data = null;
			bitmap.image = null;
			bitmap.readable = true;
		}

		var graph:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, key);
		graph.persist = true;
		graph.destroyOnNoUse = false;

		currentTrackedAssets.set(key, graph);
		localTrackedAssets.push(key);
		return graph;
	}

	inline static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		#if sys
		if (FileSystem.exists(key))
			return File.getContent(key);
		#end

		var path:String = getPath(key, TEXT, null, !ignoreMods);
		#if sys
		return (FileSystem.exists(path)) ? File.getContent(path) : null;
		#else
		return (OpenFlAssets.exists(path, TEXT)) ? Assets.getText(path) : null;
		#end
	}

	inline static public function font(key:String, embedded:Bool = true)
	{
		var folderKey:String = Language.getFileTranslation('fonts/$key');
		#if (ADDONS_ALLOWED && sys)
		var file:String = modFolders(folderKey);
		if (FileSystem.exists(file)) return file;
		#end
		if (OpenFlAssets.exists('assets/$folderKey')) return OpenFlAssets.getFont('assets/$folderKey').fontName;
		return 'assets/$folderKey';
	}

	public static function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?parentFolder:String = null)
{
	#if ADDONS_ALLOWED
	if(!ignoreMods)
	{
		var modKey:String = key;
		if(parentFolder != null) modKey = '$parentFolder/$key';

		if (FileSystem.exists(modFolders(modKey)) || (Mods.rootAddonsAllowed() && FileSystem.exists(mods(modKey))))
			return true;
	}
	#end

	return OpenFlAssets.exists(getPath(key, type, parentFolder, false), type);
}

	static public function getAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var useMod = false;
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);

		var myXml:Dynamic = getPath('images/$key.xml', TEXT, parentFolder, true);
		if(OpenFlAssets.exists(myXml) #if ADDONS_ALLOWED || (FileSystem.exists(myXml) && (useMod = true)) #end )
		{
			#if ADDONS_ALLOWED
			return FlxAtlasFrames.fromSparrow(imageLoaded, (useMod ? getTextFromFile(myXml) : myXml));
			#else
			return FlxAtlasFrames.fromSparrow(imageLoaded, myXml);
			#end
		}
		else
		{
			var myJson:Dynamic = getPath('images/$key.json', TEXT, parentFolder, true);
			if(OpenFlAssets.exists(myJson) #if ADDONS_ALLOWED || (FileSystem.exists(myJson) && (useMod = true)) #end )
			{
				#if ADDONS_ALLOWED
				return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, (useMod ? getTextFromFile(myJson) : myJson));
				#else
				return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, myJson);
				#end
			}
		}
		return getPackerAtlas(key, parentFolder);
	}
	
	static public function getMultiAtlas(keys:Array<String>, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var cleanedKeys:Array<String> = [];
		for (key in keys)
		{
			if (key == null) continue;
			key = key.trim();
			if (key.length > 0 && !cleanedKeys.contains(key))
				cleanedKeys.push(key);
		}

		if(cleanedKeys.length < 1)
			cleanedKeys.push('characters/bf');

		var parentFrames:FlxAtlasFrames = null;
		for (key in cleanedKeys)
		{
			var frames:FlxAtlasFrames = null;
			try
			{
				frames = Paths.getAtlas(key, parentFolder, allowGPU);
			}
			catch(e:Dynamic)
			{
				FlxG.log.warn('Could not load atlas $key: $e');
			}
			if(frames == null)
				continue;

			if(parentFrames == null)
			{
				parentFrames = new FlxAtlasFrames(frames.parent);
				parentFrames.addAtlas(frames, true);
			}
			else
				parentFrames.addAtlas(frames, true);
		}
		return parentFrames != null ? parentFrames : Paths.getAtlas('characters/bf', parentFolder, allowGPU);
	}

	inline static public function getSparrowAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		#if (ADDONS_ALLOWED && sys)
		var xmlExists:Bool = false;

		var xml:String = modsXml(key);
		if(FileSystem.exists(xml)) xmlExists = true;
		
		return FlxAtlasFrames.fromSparrow(imageLoaded, (xmlExists ? getTextFromFile(xml) : getPath(Language.getFileTranslation('images/$key') + '.xml', TEXT, parentFolder)));
		#else
		return FlxAtlasFrames.fromSparrow(imageLoaded, getPath(Language.getFileTranslation('images/$key') + '.xml', TEXT, parentFolder));
		#end
	}

	inline static public function getPackerAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		#if (ADDONS_ALLOWED && sys)
		var txtExists:Bool = false;
		
		var txt:String = modsTxt(key);
		if(FileSystem.exists(txt)) txtExists = true;

		return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, (txtExists ? getTextFromFile(txt) : getPath(Language.getFileTranslation('images/$key') + '.txt', TEXT, parentFolder)));
		#else
		return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, getPath(Language.getFileTranslation('images/$key') + '.txt', TEXT, parentFolder));
		#end
	}

	inline static public function getAsepriteAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		#if (ADDONS_ALLOWED && sys)
		var jsonExists:Bool = false;

		var json:String = modsImagesJson(key);
		if(FileSystem.exists(json)) jsonExists = true;

		return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, (jsonExists ? getTextFromFile(json) : getPath(Language.getFileTranslation('images/$key') + '.json', TEXT, parentFolder)));
		#else
		return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, getPath(Language.getFileTranslation('images/$key') + '.json', TEXT, parentFolder));
		#end
	}

	static function normalizePathPart(value:String, fallback:String):String
	{
		if(value == null)
			return fallback;

		value = value.trim().replace('\\', '/');
		while(value.startsWith('/')) value = value.substr(1);
		while(value.endsWith('/')) value = value.substr(0, value.length - 1);
		return value.length > 0 ? value : fallback;
	}

	static function normalizeSoundLeaf(value:String, fallback:String):String
	{
		value = normalizePathPart(value, fallback);
		var lower:String = value.toLowerCase();
		for(ext in SOUND_EXTENSIONS)
		{
			var suffix:String = '.$ext';
			if(lower.endsWith(suffix))
				return value.substr(0, value.length - suffix.length);
		}
		return value;
	}

	static function normalizeAudioVariant(value:String, fallback:String):String
	{
		if(value == null)
			return fallback;

		var variant:String = formatToSongPath(value);
		if(variant.length < 1 || variant == 'normal')
			return fallback;
		if(variant == 'pixel' || variant.endsWith('-pixel'))
			return 'pixel';
		return variant;
	}

	static function normalizeAudioCharacter(value:String):String
	{
		var character:String = formatToSongPath(normalizePathPart(value, 'default'));
		return character.length > 0 ? character : 'default';
	}

	static function normalizeGameOverAudioCharacter(value:String):String
	{
		return normalizeAudioCharacter(value);
	}

	static function gameOverMusicRoots():Array<String>
	{
		return ['music/game/gameover'];
	}

	static function gameOverTrackCandidates(track:String):Array<String>
	{
		var trackName:String = normalizeSoundLeaf(track, 'music');
		var tracks:Array<String> = [];
		addUniqueString(tracks, trackName);

		var normalized:String = formatToSongPath(trackName);
		if(normalized.endsWith('-pixel'))
			normalized = normalized.substr(0, normalized.length - '-pixel'.length);

		switch(normalized)
		{
			case 'gameover' | 'game-over':
				addUniqueString(tracks, 'music');
			case 'gameoverend' | 'game-over-end' | 'gameover-end':
				addUniqueString(tracks, 'music-end');
			case 'gameoverendalt' | 'game-over-end-alt' | 'gameover-end-alt':
				addUniqueString(tracks, 'music-end-alt');
			default:
		}
		return tracks;
	}

	static function resolveMenuFolderName(menuName:String, ?modsAllowed:Bool = true):String
	{
		var fallback:String = normalizePathPart(menuName, 'mainMenu');
		var wanted:String = formatToSongPath(fallback);

		for(folder in collectAudioFolderNames('music/menus', modsAllowed))
			if(formatToSongPath(folder) == wanted)
				return folder;
		return fallback;
	}

	static function addUniqueString(list:Array<String>, value:String):Void
	{
		if(value != null && value.length > 0 && !list.contains(value))
			list.push(value);
	}

	static function addVoicePostfixCandidates(candidates:Array<String>, songKey:String, postfix:String):Void
	{
		var raw:String = normalizeSoundLeaf(postfix, '').trim();
		if(raw.length < 1)
			return;

		addUniqueString(candidates, '$songKey-$raw');
		addUniqueString(candidates, '$songKey-${raw.toLowerCase()}');

		var normalized:String = formatToSongPath(raw);
		addUniqueString(candidates, '$songKey-$normalized');

		switch(normalized)
		{
			case 'player' | 'p1' | 'bf' | 'boyfriend':
				addUniqueString(candidates, '$songKey-Player');
				addUniqueString(candidates, '$songKey-player');
				addUniqueString(candidates, '$songKey-p1'); // god, write "-Player" and "-Opponent" is SO tiring.
			case 'opponent' | 'opp' | 'dad':
				addUniqueString(candidates, '$songKey-Opponent');
				addUniqueString(candidates, '$songKey-opponent');
				addUniqueString(candidates, '$songKey-opp');
				addUniqueString(candidates, '$songKey-p2');
			default:
		}
	}

	static function addUniqueAudioFolderCandidate(list:Array<AudioFolderCandidate>, folder:String, matchKey:String):Void
	{
		if(folder == null || matchKey == null || matchKey.length < 1)
			return;

		for(candidate in list)
			if(candidate.folder == folder && candidate.matchKey == matchKey)
				return;
		list.push({folder: folder, matchKey: matchKey});
	}

	static function collectAudioFolderNames(root:String, ?modsAllowed:Bool = true):Array<String>
	{
		var folders:Array<String> = [];

		#if sys
		var roots:Array<String> = [getSharedPath(root)];
		#if ADDONS_ALLOWED
		if(modsAllowed)
			roots = Mods.directoriesWithFile(getSharedPath(), root, true);
		#end

		for(rootPath in roots)
		{
			if(rootPath == null || !FileSystem.exists(rootPath) || !FileSystem.isDirectory(rootPath))
				continue;

			for(folder in FileSystem.readDirectory(rootPath))
			{
				var path:String = '$rootPath/$folder';
				if(FileSystem.exists(path) && FileSystem.isDirectory(path))
					addUniqueString(folders, folder);
			}
		}
		#else
		var prefix:String = 'assets/shared/$root/';
		for(asset in OpenFlAssets.list(SOUND))
		{
			if(!asset.startsWith(prefix))
				continue;

			var rest:String = asset.substr(prefix.length);
			var slash:Int = rest.indexOf('/');
			if(slash > 0)
				addUniqueString(folders, rest.substr(0, slash));
		}
		#end

		return folders;
	}

	static function collectAudioSubfolderNames(root:String, folder:String, ?modsAllowed:Bool = true):Array<String>
		return collectAudioFolderNames('$root/$folder', modsAllowed);

	static function audioFolderHasSubfolder(root:String, folder:String, subfolder:String, ?modsAllowed:Bool = true):Bool
	{
		if(subfolder == null || subfolder.length < 1 || subfolder == 'default')
			return false;

		var wanted:String = formatToSongPath(subfolder);
		for(candidate in collectAudioSubfolderNames(root, folder, modsAllowed))
			if(formatToSongPath(candidate) == wanted)
				return true;
		return false;
	}

	static function detectCharacterUiFromFolder(root:String, folder:String, character:String, matchKey:String, ?modsAllowed:Bool = true):String
	{
		if(character == null || matchKey == null || !character.startsWith(matchKey + '-'))
			return null;

		var suffix:String = character.substr(matchKey.length + 1);
		if(audioFolderHasSubfolder(root, folder, suffix, modsAllowed))
			return suffix;
		return null;
	}

	static function audioCharacterFolderCandidates(root:String, character:String, ui:String, ?modsAllowed:Bool = true):Array<AudioFolderCandidate>
	{
		var folders:Array<String> = collectAudioFolderNames(root, modsAllowed);
		addUniqueString(folders, 'default');

		var candidates:Array<AudioFolderCandidate> = [];

		for(folder in folders)
		{
			var folderKey:String = normalizeAudioCharacter(folder);
			if(folderKey == 'default')
				continue;

			if(character.startsWith(folderKey))
				addUniqueAudioFolderCandidate(candidates, folder, folderKey);
		}

		candidates.sort(function(a:AudioFolderCandidate, b:AudioFolderCandidate)
		{
			var aExact:Bool = (a.matchKey == character);
			var bExact:Bool = (b.matchKey == character);
			if(aExact != bExact)
				return aExact ? -1 : 1;
			if(a.matchKey.length != b.matchKey.length)
				return b.matchKey.length - a.matchKey.length;
			return Reflect.compare(a.folder.toLowerCase(), b.folder.toLowerCase());
		});

		candidates.push({folder: 'default', matchKey: 'default'});
		return candidates;
	}

	static function addAudioCharacterMusicCandidates(candidates:Array<String>, root:String, character:String, ui:String, track:String, ?modsAllowed:Bool = true):Void
	{
		for(candidate in audioCharacterFolderCandidates(root, character, ui, modsAllowed))
		{
			var effectiveUi:String = ui;
			if(effectiveUi == null || effectiveUi == 'default')
				effectiveUi = detectCharacterUiFromFolder(root, candidate.folder, character, candidate.matchKey, modsAllowed);

			if(effectiveUi != null && effectiveUi != 'default')
				addUniqueString(candidates, '$root/${candidate.folder}/$effectiveUi/$track');
			addUniqueString(candidates, '$root/${candidate.folder}/$track');
		}
	}

	static function audioCharacterScriptFolders(root:String, character:String, ui:String, ?modsAllowed:Bool = true):Array<String>
	{
		var folders:Array<String> = [];
		for(candidate in audioCharacterFolderCandidates(root, character, ui, modsAllowed))
		{
			var effectiveUi:String = ui;
			if(effectiveUi == null || effectiveUi == 'default')
				effectiveUi = detectCharacterUiFromFolder(root, candidate.folder, character, candidate.matchKey, modsAllowed);

			if(effectiveUi != null && effectiveUi != 'default')
				addUniqueString(folders, '$root/${candidate.folder}/$effectiveUi/scripts');
			addUniqueString(folders, '$root/${candidate.folder}/scripts');
		}
		return folders;
	}

	static function findExistingSoundKey(candidates:Array<String>, ?path:String = null, ?modsAllowed:Bool = true):String
	{
		for(candidate in candidates)
			if(soundKeyExists(candidate, path, modsAllowed))
				return candidate;
		return candidates.length > 0 ? candidates[0] : null;
	}

	public static function soundKeyExists(key:String, ?path:String, ?modsAllowed:Bool = true):Bool
		return resolveSoundFile(key, path, modsAllowed) != null;

	inline static public function formatToSongPath(path:String) {
		final invalidChars = ~/[~&;:<>#\s]/g;
		final hideChars = ~/[.,'"%?!]/g;

		return hideChars.replace(invalidChars.replace(path, '-'), '').trim().toLowerCase();
	}

	public static var currentTrackedSounds:Map<String, Sound> = [];
	static function resolveSoundFile(key:String, ?path:String, ?modsAllowed:Bool = true):String
	{
		for(ext in SOUND_EXTENSIONS)
		{
			var file:String = getPath(Language.getFileTranslation(key) + '.$ext', SOUND, path, modsAllowed);
			#if (ADDONS_ALLOWED && sys)
			if(FileSystem.exists(file))
				return file;
			#else
			if(OpenFlAssets.exists(file, SOUND))
				return file;
			#end
		}
		return null;
	}

	public static function returnSound(key:String, ?path:String, ?modsAllowed:Bool = true, ?beepOnNull:Bool = true)
	{
		var file:String = resolveSoundFile(key, path, modsAllowed);

		//trace('precaching sound: $file');
		if(file == null)
		{
			if(beepOnNull)
			{
				trace('SOUND NOT FOUND: $key, PATH: $path');
				FlxG.log.error('SOUND NOT FOUND: $key, PATH: $path');
				return FlxAssets.getSoundAddExtension('flixel/sounds/beep');
			}
			return null;
		}

		if(file != null && !currentTrackedSounds.exists(file))
		{
			#if (ADDONS_ALLOWED && sys)
			if(FileSystem.exists(file))
				currentTrackedSounds.set(file, Sound.fromFile(file));
			#else
			if(OpenFlAssets.exists(file, SOUND))
				currentTrackedSounds.set(file, OpenFlAssets.getSound(file));
			#end
			else if(beepOnNull)
			{
				trace('SOUND NOT FOUND: $key, PATH: $path');
				FlxG.log.error('SOUND NOT FOUND: $key, PATH: $path');
				return FlxAssets.getSoundAddExtension('flixel/sounds/beep');
			}
		}
		localTrackedAssets.push(file);
		return currentTrackedSounds.get(file);
	}

	#if ADDONS_ALLOWED
	inline static public function mods(key:String = '')
		return #if mobile StorageSystem.getDirectory() + #end Mods.resolveModPath(key);

	inline static public function contents(key:String = '')
		return #if mobile StorageSystem.getDirectory() + #end Mods.resolveContentPath(key);

	inline static public function modsJson(key:String)
		return modFolders('data/' + key + '.json');

	inline static public function modsVideo(key:String)
		return modFolders('videos/' + key + '.' + VIDEO_EXT);

	inline static public function modsSounds(path:String, key:String)
		return modFolders(path + '/' + key + '.' + SOUND_EXT);

	inline static public function modsImages(key:String)
		return modFolders('images/' + key + '.png');

	inline static public function modsXml(key:String)
		return modFolders('images/' + key + '.xml');

	inline static public function modsTxt(key:String)
		return modFolders('images/' + key + '.txt');

	inline static public function modsImagesJson(key:String)
		return modFolders('images/' + key + '.json');

	static public function modFolders(key:String)
	{
		key = key.replace('\\', '/');
		if ((key.startsWith('contents/') || key.startsWith('addons/')) && FileSystem.exists(#if mobile StorageSystem.getDirectory() + #end key))
			return #if mobile StorageSystem.getDirectory() + #end key;

		if(Mods.packageSupportsKey(key) && Mods.isCurrentPackageActive())
		{
			var fileToCheck:String = mods(Mods.currentPackageDirectory + '/' + key);
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;
		}

		for(mod in Mods.getActiveModDirectories())
		{
			var fileToCheck:String = mods(mod + '/' + key);
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;
		}

		for(packageFolder in Mods.getPackageSearchDirectories(key, false, true))
		{
			var fileToCheck:String = mods(packageFolder + '/' + key);
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;
		}

		if(Mods.rootAddonsAllowed())
		{
			var rootFile:String = mods(key);
			if(FileSystem.exists(rootFile))
				return rootFile;
		}
		return #if mobile StorageSystem.getDirectory() + #end Mods.rootAddonsAllowed() ? mods(key) : '__disabled_addons__/' + key;
	}
	#end

	static function normalizeAtlasKey(imageKey:String):String
	{
		if(imageKey == null) return '';

		imageKey = imageKey.replace('\\', '/').trim();
		var slashIndex:Int = imageKey.indexOf('/');
		var colonIndex:Int = imageKey.indexOf(':');
		if(colonIndex >= 0 && (slashIndex < 0 || colonIndex < slashIndex))
			imageKey = imageKey.substr(colonIndex + 1);
		if(imageKey.startsWith('images/'))
			imageKey = imageKey.substr('images/'.length);
		while(imageKey.length > 0 && imageKey.startsWith('/'))
			imageKey = imageKey.substr(1);
		while(imageKey.length > 0 && (imageKey.endsWith('/') || imageKey.endsWith('\\')))
			imageKey = imageKey.substr(0, imageKey.length - 1);

		return imageKey;
	}

	static function splitAtlasKeys(imageKey:String):Array<String>
	{
		var keys:Array<String> = [];
		if(imageKey == null) return keys;

		for(rawKey in imageKey.split(','))
		{
			var key:String = normalizeAtlasKey(rawKey);
			if(key.length > 0 && !keys.contains(key))
				keys.push(key);
		}
		return keys;
	}

	static function isSingleAnimateAtlas(imageKey:String):Bool
	{
		imageKey = normalizeAtlasKey(imageKey);
		if(imageKey.length < 1) return false;
		return getTextFromFile('images/$imageKey/Animation.json') != null;
	}

	public static function isAnimateAtlas(imageKey:String):Bool
	{
		var keys:Array<String> = splitAtlasKeys(imageKey);
		if(keys.length < 1) return false;

		for(key in keys)
			if(isSingleAnimateAtlas(key))
				return true;
		return false;
	}

	public static function loadAnimateAtlas(spr:FlxAnimate, folderOrImg:Dynamic, spriteJson:Dynamic = null, animationJson:Dynamic = null)
	{
		if(spr == null) return;
		#if !flash
		@:privateAccess spr._renderTexture = FlxDestroyUtil.destroy(spr._renderTexture);
		#end
		@:privateAccess spr._renderTextureDirty = true;
		spr.useRenderTexture = true;

		if(Std.isOfType(folderOrImg, String))
		{
			var originalPath:String = normalizeAtlasKey(Std.string(folderOrImg));
			var atlasKeys:Array<String> = splitAtlasKeys(originalPath);
			if(atlasKeys.length > 1 && spriteJson == null && animationJson == null)
			{
				loadMultiAnimateAtlas(spr, atlasKeys);
				return;
			}

			if(spriteJson == null)
			{
				var folderPath:String = getAnimateAtlasFolderPath(originalPath);
				if(folderPath != null)
				{
					spr.frames = FlxAnimateFrames.fromAnimate(folderPath, null, null, originalPath, false, {cacheOnLoad: true});
					return;
				}
			}

			animationJson = getAnimateAtlasText(animationJson);
			if(animationJson == null)
				animationJson = getTextFromFile('images/$originalPath/Animation.json');

			if(spriteJson == null)
			{
				var spriteMaps:Array<SpritemapInput> = getAnimateAtlasSpriteMaps(originalPath);
				if(spriteMaps.length > 0)
				{
					spr.frames = FlxAnimateFrames.fromAnimate(Std.string(animationJson), spriteMaps, null, originalPath, false, {cacheOnLoad: true});
					return;
				}
			}
			else
			{
				spriteJson = getAnimateAtlasText(spriteJson);
				var imageKey:String = getAnimateAtlasImageKey(originalPath, spriteJson, 'spritemap');
				folderOrImg = image(fileExists('images/$imageKey.png', IMAGE) ? imageKey : originalPath);
			}
		}
		else
		{
			spriteJson = getAnimateAtlasText(spriteJson);
			animationJson = getAnimateAtlasText(animationJson);
		}

		if(animationJson == null || spriteJson == null || folderOrImg == null) return;
		var inputs:Array<SpritemapInput> = [{source: folderOrImg, json: Std.string(spriteJson)}];
		spr.frames = FlxAnimateFrames.fromAnimate(Std.string(animationJson), inputs, null, null, true, {cacheOnLoad: true});
	}

	static function loadMultiAnimateAtlas(spr:FlxAnimate, keys:Array<String>):Void
	{
		var atlasList:Array<FlxAtlasFrames> = [];
		for(key in keys)
		{
			var frames:FlxAtlasFrames = getFramesForMultiAnimateAtlas(key);
			if(frames != null)
				atlasList.push(frames);
		}

		if(atlasList.length > 0)
		{
			var combined:FlxAtlasFrames = FlxAnimateFrames.combineAtlas(atlasList);
			if(combined != null)
				spr.frames = combined;
		}
	}

	static function getFramesForMultiAnimateAtlas(key:String):FlxAtlasFrames
	{
		key = normalizeAtlasKey(key);
		if(key.length < 1) return null;

		if(isSingleAnimateAtlas(key))
		{
			var temp:FlxAnimate = new FlxAnimate();
			loadAnimateAtlas(temp, key);
			return cast temp.frames;
		}

		try
		{
			return getAtlas(key);
		}
		catch(e:Dynamic)
		{
			FlxG.log.warn('Could not load atlas $key: $e');
			return null;
		}
	}

	static function getAnimateAtlasFolderPath(imageKey:String):String
	{
		imageKey = normalizeAtlasKey(imageKey);
		var animationFile:String = getPath('images/$imageKey/Animation.json', TEXT, null, true);
		#if sys
		if(FileSystem.exists(animationFile)) return HaxePath.directory(animationFile);
		#end

		return OpenFlAssets.exists(animationFile, TEXT) ? HaxePath.directory(animationFile) : null;
	}

	static function getAnimateAtlasText(data:Dynamic):String
	{
		if(data == null) return null;
		if(!Std.isOfType(data, String)) return Json.stringify(data);

		var str:String = Std.string(data);
		var trimmed:String = str.trim();
		if(trimmed.startsWith('{') || trimmed.startsWith('[') || trimmed.startsWith('<')) return str;

		var text:String = getTextFromFile(str);
		return text != null ? text : str;
	}

	static function getAnimateAtlasSpriteMaps(folder:String):Array<SpritemapInput>
	{
		folder = normalizeAtlasKey(folder);
		var spriteMaps:Array<SpritemapInput> = [];
		addAnimateAtlasSpriteMap(spriteMaps, folder, 'spritemap');

		var index:Int = 1;
		while(index < 1000)
		{
			var name:String = 'spritemap$index';
			if(!addAnimateAtlasSpriteMap(spriteMaps, folder, name)) break;
			index++;
		}

		return spriteMaps;
	}

	static function addAnimateAtlasSpriteMap(spriteMaps:Array<SpritemapInput>, folder:String, name:String):Bool
	{
		var spriteJson:String = getTextFromFile('images/$folder/$name.json');
		if(spriteJson == null) return false;

		spriteMaps.push({
			json: spriteJson,
			source: image(getAnimateAtlasImageKey(folder, spriteJson, name))
		});
		return true;
	}

	static function getAnimateAtlasImageKey(folder:String, spriteJson:Dynamic, fallback:String):String
	{
		var imageName:String = fallback;
		try
		{
			var parsed:Dynamic = Std.isOfType(spriteJson, String) ? Json.parse(Std.string(spriteJson)) : spriteJson;
			var meta:Dynamic = Reflect.field(parsed, 'meta');
			var metaImage:Dynamic = meta != null ? Reflect.field(meta, 'image') : null;
			if(metaImage != null) imageName = Std.string(metaImage);
		}
		catch(e:Dynamic) {}

		imageName = StringTools.replace(imageName, '\\', '/');
		if(imageName.contains('/')) imageName = imageName.substr(imageName.lastIndexOf('/') + 1);
		if(StringTools.endsWith(imageName.toLowerCase(), '.png')) imageName = imageName.substr(0, imageName.length - 4);

		return '$folder/$imageName';
	}
}
