#if LUA_ALLOWED
package psychlua;

import backend.Difficulty;
import backend.Highscore;
import backend.Mods;
import backend.Paths;
import backend.Song;
import backend.StageData;
import backend.WeekData;
import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.Json;
import states.FreeplayState;
import states.LoadingState;
import states.PlayState;
import states.StoryMenuState;
import substates.ResetScoreSubState;
import options.GameplayChangersSubState;

/**
 * Small Freeplay bridge for custom-state Lua menus.
 *
 * The important rule here is: data stays in addons/contents through Mods/Paths.
 * Lua can own the menu, while Haxe only exposes safe engine operations that were
 * previously locked inside the compiled FreeplayState.
 */
class FreeplayLuaFunctions
{
	static var previewEndTimer:FlxTimer = null;
	static var previewSongKey:String = '';
	static inline final PREVIEW_FADE_IN_DURATION:Float = 0.5;

	public static function implement():Void
	{
		FunkinLua.registerFunction('formatSongPath', function(value:String) {
			return Paths.formatToSongPath(value ?? '');
		});

		FunkinLua.registerFunction('getMouseWheel', function() {
			return FlxG.mouse.wheel;
		});

		FunkinLua.registerFunction('controlJustPressed', function(name:String) {
			return readControl(name, 'justPressed');
		});

		FunkinLua.registerFunction('controlPressed', function(name:String) {
			return readControl(name, 'pressed');
		});

		FunkinLua.registerFunction('controlJustReleased', function(name:String) {
			return readControl(name, 'justReleased');
		});

		FunkinLua.registerFunction('getFreeplaySongs', function(includeLocked:Bool = false) {
			return collectFreeplaySongs(includeLocked);
		});

		FunkinLua.registerFunction('reloadFreeplaySongs', function(includeLocked:Bool = false) {
			return collectFreeplaySongs(includeLocked);
		});

		FunkinLua.registerFunction('getFreeplayWeekDifficulties', function(weekIndex:Int) {
			var week = getWeekByIndex(weekIndex);
			if (week == null) return [];

			var ctx = saveContext();
			var diffs:Array<String> = [];
			try
			{
				applyWeekContext(week, weekIndex);
				diffs = Difficulty.list.copy();
			}
			catch(e:Dynamic) {}
			restoreContext(ctx);
			return diffs;
		});

		FunkinLua.registerFunction('getFreeplayDifficultyIndex', function(weekIndex:Int, diffName:String) {
			var week = getWeekByIndex(weekIndex);
			if (week == null) return 0;

			var ctx = saveContext();
			var index:Int = 0;
			try
			{
				applyWeekContext(week, weekIndex);
				var wanted:String = Paths.formatToSongPath(diffName ?? Difficulty.getDefault());
				for (i in 0...Difficulty.list.length)
				{
					if (Paths.formatToSongPath(Difficulty.list[i]) == wanted)
					{
						index = i;
						break;
					}
				}
			}
			catch(e:Dynamic) {}
			restoreContext(ctx);
			return index;
		});

		FunkinLua.registerFunction('getFreeplayScore', function(songName:String, weekIndex:Int, difficultyIndex:Int = 0) {
			return getFreeplayScore(songName, weekIndex, difficultyIndex);
		});

		FunkinLua.registerFunction('getFreeplayMetadata', function(songName:String, weekIndex:Int = -1) {
			var ctx = saveContext();
			try
			{
				var week = getWeekByIndex(weekIndex);
				if (week != null) applyWeekContext(week, weekIndex);
				var meta = readSongMetadata(songName);
				restoreContext(ctx);
				return meta;
			}
			catch(e:Dynamic)
			{
				restoreContext(ctx);
			}
			return {};
		});

		FunkinLua.registerFunction('setFreeplaySongContext', function(weekIndex:Int) {
			var week = getWeekByIndex(weekIndex);
			if (week == null) return false;

			applyWeekContext(week, weekIndex);
			return true;
		});

		FunkinLua.registerFunction('playFreeplayPreview', function(songName:String, weekIndex:Int, difficultyIndex:Int = 0, volume:Float = 0.7, startSeconds:Float = 0, endSeconds:Float = 0) {
			return playPreview(songName, weekIndex, difficultyIndex, volume, startSeconds, endSeconds);
		});

		FunkinLua.registerFunction('stopFreeplayPreview', function(restoreMenuMusic:Bool = true, fadeOut:Float = 0.25) {
			stopPreview(restoreMenuMusic, fadeOut);
			return true;
		});

		FunkinLua.registerFunction('loadFreeplaySong', function(songName:String, weekIndex:Int, difficultyIndex:Int = 0) {
			return loadFreeplaySong(songName, weekIndex, difficultyIndex);
		});

		FunkinLua.registerFunction('openFreeplayResetScore', function(songName:String, weekIndex:Int, difficultyIndex:Int = 0, character:String = 'face') {
			var week = getWeekByIndex(weekIndex);
			if (week != null)
				applyWeekContext(week, weekIndex);

			FlxG.state.persistentUpdate = false;
			FlxG.state.openSubState(new ResetScoreSubState(songName, difficultyIndex, character));
			return true;
		});

		FunkinLua.registerFunction('openFreeplayGameplayChangers', function() {
			FlxG.state.persistentUpdate = false;
			FlxG.state.openSubState(new GameplayChangersSubState());
			return true;
		});

		FunkinLua.registerFunction('isFreeplayFavorite', function(songName:String, weekFile:String = '') {
			return isFavorite(songName, weekFile);
		});

		FunkinLua.registerFunction('toggleFreeplayFavorite', function(songName:String, weekFile:String = '') {
			return toggleFavorite(songName, weekFile);
		});
	}

	static function readControl(name:String, mode:String):Bool
	{
		name = (name ?? '').trim();
		if (name.length < 1 || backend.Controls.instance == null)
			return false;

		switch(mode)
		{
			case 'pressed':
				return backend.Controls.instance.pressed(name.toLowerCase());
			case 'justReleased':
				return backend.Controls.instance.justReleased(name.toLowerCase());
			default:
				return backend.Controls.instance.justPressed(name.toLowerCase());
		}
	}

	static function saveContext():Dynamic
	{
		return {
			mod: Mods.currentModDirectory,
			pack: Mods.currentPackageDirectory,
			levelName: WeekData.currentLevelName,
			storyWeek: PlayState.storyWeek,
			storyWeekData: PlayState.storyWeekData,
			storyDifficulty: PlayState.storyDifficulty,
			diffs: Difficulty.list.copy()
		};
	}

	static function restoreContext(ctx:Dynamic):Void
	{
		if (ctx == null) return;
		Mods.currentModDirectory = ctx.mod ?? '';
		Mods.currentPackageDirectory = ctx.pack ?? '';
		WeekData.currentLevelName = ctx.levelName ?? '';
		PlayState.storyWeek = ctx.storyWeek;
		PlayState.storyWeekData = ctx.storyWeekData;
		PlayState.storyDifficulty = ctx.storyDifficulty;
		var diffs:Array<String> = cast (ctx.diffs ?? []);
		Difficulty.copyFrom(diffs);
	}

	static function applyWeekContext(week:WeekData, weekIndex:Int):Void
	{
		WeekData.setDirectoryFromWeek(week);
		PlayState.storyWeek = weekIndex;
		PlayState.storyWeekData = week;
		Difficulty.loadFromWeek(week);
		if (Difficulty.list == null || Difficulty.list.length < 1)
			Difficulty.resetList();
	}

	static function getWeekByIndex(weekIndex:Int):WeekData
	{
		if (weekIndex < 0)
			return null;

		if (WeekData.weeksList == null || WeekData.weeksList.length <= weekIndex)
			WeekData.reloadWeekFiles(false);

		if (WeekData.weeksList == null || weekIndex >= WeekData.weeksList.length)
			return null;

		return WeekData.weeksLoaded.get(WeekData.weeksList[weekIndex]);
	}

	static function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		if (leWeek == null) return true;
		return (!leWeek.startUnlocked
			&& leWeek.weekBefore != null
			&& leWeek.weekBefore.length > 0
			&& (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	static function collectFreeplaySongs(includeLocked:Bool = false):Array<Dynamic>
	{
		var ctx = saveContext();
		var songs:Array<Dynamic> = [];

		WeekData.reloadWeekFiles(false);
		for (weekIndex in 0...WeekData.weeksList.length)
		{
			var weekFile:String = WeekData.weeksList[weekIndex];
			var week:WeekData = WeekData.weeksLoaded.get(weekFile);
			if (week == null)
				continue;

			var locked:Bool = weekIsLocked(weekFile);
			if (locked && !includeLocked)
				continue;

			applyWeekContext(week, weekIndex);
			var diffs:Array<String> = Difficulty.list.copy();

			for (songIndex in 0...week.songs.length)
			{
				var rawSong:Dynamic = week.songs[songIndex];
				var songName:String = Std.string(rawSong[0]);
				var character:String = Std.string(rawSong[1]);
				var colors:Array<Int> = normalizeColorArray(rawSong[2]);
				var meta:Dynamic = readSongMetadata(songName);

				songs.push({
					songName: songName,
					displayName: displayNameFromMeta(meta, songName),
					songId: Paths.formatToSongPath(songName),
					songIndex: songIndex,
					weekIndex: weekIndex,
					weekFile: weekFile,
					weekName: week.weekName,
					storyName: week.storyName,
					levelName: week.weekName,
					character: character,
					icon: character,
					color: colorInt(colors),
					colorHex: StringTools.hex(colorInt(colors) & 0xFFFFFF, 6),
					colorRGB: colors,
					difficulties: diffs.copy(),
					folder: week.folder ?? '',
					packageFolder: week.packageFolder ?? '',
					locked: locked,
					favorite: isFavorite(songName, weekFile),
					metadata: meta
				});
			}
		}

		restoreContext(ctx);
		return songs;
	}

	static function normalizeColorArray(value:Dynamic):Array<Int>
	{
		var fallback:Array<Int> = [146, 113, 253];
		if (value == null || !Std.isOfType(value, Array))
			return fallback;

		var raw:Array<Dynamic> = cast value;
		if (raw.length < 3)
			return fallback;

		return [
			clampColor(Std.parseInt(Std.string(raw[0]))),
			clampColor(Std.parseInt(Std.string(raw[1]))),
			clampColor(Std.parseInt(Std.string(raw[2])))
		];
	}

	static inline function clampColor(value:Null<Int>):Int
		return Std.int(FlxMath.bound(value ?? 0, 0, 255));

	static inline function colorInt(colors:Array<Int>):Int
		return FlxColor.fromRGB(colors[0], colors[1], colors[2]);

	static function displayNameFromMeta(meta:Dynamic, fallback:String):String
	{
		if (meta != null)
		{
			for (field in ['displayName', 'name', 'songName'])
			{
				var value:Dynamic = Reflect.field(meta, field);
				if (value != null && Std.string(value).trim().length > 0)
					return Std.string(value);
			}
		}
		return fallback;
	}

	static function readSongMetadata(songName:String):Dynamic
	{
		var formatted:String = Paths.formatToSongPath(songName ?? '');
		if (formatted.length < 1)
			return {};

		for (path in [
			'data/$formatted/metadata.json',
			'songs/$formatted/metadata.json',
			'$formatted/song/metadata.json'
		])
		{
			var raw:String = Paths.getTextFromFile(path);
			if (raw == null || raw.trim().length < 1)
				continue;

			try
			{
				return Json.parse(raw);
			}
			catch(e:Dynamic)
			{
				FunkinLua.luaTrace('getFreeplayMetadata: failed to parse $path: $e', false, false, WARN);
			}
		}
		return {};
	}

	static function getFreeplayScore(songName:String, weekIndex:Int, difficultyIndex:Int):Dynamic
	{
		var week = getWeekByIndex(weekIndex);
		if (week == null)
			return {score: 0, rating: 0};

		var ctx = saveContext();
		var ret:Dynamic = {score: 0, rating: 0};
		try
		{
			applyWeekContext(week, weekIndex);
			difficultyIndex = Std.int(FlxMath.bound(difficultyIndex, 0, Math.max(0, Difficulty.list.length - 1)));
			ret = {
				score: Highscore.getScore(songName, difficultyIndex),
				rating: Highscore.getRating(songName, difficultyIndex)
			};
		}
		catch(e:Dynamic) {}
		restoreContext(ctx);
		return ret;
	}

	static function playPreview(songName:String, weekIndex:Int, difficultyIndex:Int, volume:Float, startSeconds:Float, endSeconds:Float):Dynamic
	{
		var week = getWeekByIndex(weekIndex);
		if (week == null)
			return {ok: false, error: 'Week index $weekIndex was not found.'};

		try
		{
			applyWeekContext(week, weekIndex);
			difficultyIndex = Std.int(FlxMath.bound(difficultyIndex, 0, Math.max(0, Difficulty.list.length - 1)));

			var songLowercase:String = Paths.formatToSongPath(songName);
			var chartName:String = Highscore.formatSong(songLowercase, difficultyIndex);
			Song.loadFromJson(chartName, songLowercase);

			var newKey:String = '${Mods.getAssetContextKey()}::$songLowercase::$difficultyIndex';
			if (FlxG.sound.music != null && previewSongKey == newKey)
				return {ok: true, reused: true};

			stopPreview(false, 0);
			previewSongKey = newKey;
			FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0, true);
			if (FlxG.sound.music != null)
			{
				FlxG.sound.music.time = Math.max(0, startSeconds) * 1000;
				FlxG.sound.music.fadeIn(PREVIEW_FADE_IN_DURATION, 0, volume);
			}

			if (endSeconds > startSeconds)
			{
				previewEndTimer = new FlxTimer().start(endSeconds - startSeconds, function(_) {
					if (FlxG.sound.music != null && previewSongKey == newKey)
					{
						FlxG.sound.music.time = Math.max(0, startSeconds) * 1000;
						FlxG.sound.music.fadeIn(PREVIEW_FADE_IN_DURATION, 0, volume);
					}
				}, 0);
			}

			return {ok: true};
		}
		catch(e:Dynamic)
		{
			return {ok: false, error: Std.string(e)};
		}
	}

	static function stopPreview(restoreMenuMusic:Bool, fadeOut:Float):Void
	{
		if (previewEndTimer != null)
		{
			previewEndTimer.cancel();
			previewEndTimer.destroy();
			previewEndTimer = null;
		}

		previewSongKey = '';
		FreeplayState.destroyFreeplayVocals();

		if (FlxG.sound.music != null)
		{
			if (fadeOut > 0)
			{
				FlxTween.cancelTweensOf(FlxG.sound.music);
				FlxG.sound.music.fadeOut(fadeOut, 0, function(_) {
					if (restoreMenuMusic)
						FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7, true);
					else if (FlxG.sound.music != null)
						FlxG.sound.music.stop();
				});
			}
			else
			{
				FlxG.sound.music.stop();
				if (restoreMenuMusic)
					FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7, true);
			}
		}
		else if (restoreMenuMusic)
		{
			FlxG.sound.playMusic(Paths.music('freakyMenu'), 0.7, true);
		}
	}

	static function loadFreeplaySong(songName:String, weekIndex:Int, difficultyIndex:Int):Dynamic
	{
		var week = getWeekByIndex(weekIndex);
		if (week == null)
			return {ok: false, error: 'Week index $weekIndex was not found.'};

		try
		{
			stopPreview(false, 0);
			applyWeekContext(week, weekIndex);
			difficultyIndex = Std.int(FlxMath.bound(difficultyIndex, 0, Math.max(0, Difficulty.list.length - 1)));

			var songLowercase:String = Paths.formatToSongPath(songName);
			var chartName:String = Highscore.formatSong(songLowercase, difficultyIndex);
			Song.loadFromJson(chartName, songLowercase);
			if (PlayState.SONG == null)
				throw 'Song parsing failed for $songName.';

			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = difficultyIndex;

			var directory = StageData.forceNextDirectory;
			LoadingState.loadNextDirectory();
			StageData.forceNextDirectory = directory;

			@:privateAccess
			if (PlayState._lastLoadedModDirectory != Mods.getAssetContextKey())
				Paths.freeGraphicsFromMemory();

			LoadingState.prepareToSong();
			LoadingState.loadAndSwitchState(new PlayState());
			#if !SHOW_LOADING_SCREEN
			if (FlxG.sound.music != null)
				FlxG.sound.music.stop();
			#end
			return {ok: true};
		}
		catch(e:Dynamic)
		{
			return {ok: false, error: Std.string(e)};
		}
	}

	static function favoriteKey(songName:String, weekFile:String):String
		return Paths.formatToSongPath(songName ?? '') + '@' + (weekFile ?? '');

	static function favoriteList():Array<String>
	{
		var list:Dynamic = Reflect.field(FlxG.save.data, 'vsliceFreeplayFavorites');
		if (list == null || !Std.isOfType(list, Array))
		{
			list = [];
			Reflect.setField(FlxG.save.data, 'vsliceFreeplayFavorites', list);
		}
		return cast list;
	}

	static function isFavorite(songName:String, weekFile:String):Bool
		return favoriteList().contains(favoriteKey(songName, weekFile));

	static function toggleFavorite(songName:String, weekFile:String):Bool
	{
		var key:String = favoriteKey(songName, weekFile);
		var list:Array<String> = favoriteList();
		var active:Bool = !list.contains(key);
		if (active)
			list.push(key);
		else
			list.remove(key);

		Reflect.setField(FlxG.save.data, 'vsliceFreeplayFavorites', list);
		FlxG.save.flush();
		return active;
	}
}
#end
