package backend;

import flixel.util.FlxSave;
import states.StoryMenuState;

class Highscore
{
	public static var weekScores:Map<String, Int> = [];
	public static var songScores:Map<String, Int> = [];
	public static var songRating:Map<String, Float> = [];

	public static function resetSong(song:String, diff:Int = 0):Void
	{
		var daSong:String = formatHighscoreKey(song, diff);
		setScore(daSong, 0);
		setRating(daSong, 0);
	}

	public static function resetWeek(week:String, diff:Int = 0):Void
	{
		var daWeek:String = formatHighscoreKey(week, diff);
		setWeekScore(daWeek, 0);
	}

	public static function saveScore(song:String, score:Int = 0, ?diff:Int = 0, ?rating:Float = -1):Void
	{
		if(song == null) return;
		var daSong:String = formatHighscoreKey(song, diff);

		if (songScores.exists(daSong))
		{
			if (songScores.get(daSong) < score)
				setScore(daSong, score);
		}
		else
			setScore(daSong, score);

		if(rating >= 0 && (!songRating.exists(daSong) || songRating.get(daSong) < rating))
			setRating(daSong, rating);
	}

	public static function saveWeekScore(week:String, score:Int = 0, ?diff:Int = 0):Void
	{
		if(week == null) return;
		var daWeek:String = formatHighscoreKey(week, diff);

		if (weekScores.exists(daWeek))
		{
			if (weekScores.get(daWeek) < score)
				setWeekScore(daWeek, score);
		}
		else setWeekScore(daWeek, score);
	}

	/**
	 * YOU SHOULD FORMAT SONG WITH formatSong() BEFORE TOSSING IN SONG VARIABLE
	 */
	static function setScore(song:String, score:Int):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		songScores.set(song, score);
		FlxG.save.data.songScores = songScores;
		FlxG.save.flush();
	}
	static function setWeekScore(week:String, score:Int):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		weekScores.set(week, score);
		FlxG.save.data.weekScores = weekScores;
		FlxG.save.flush();
	}

	static function setRating(song:String, rating:Float):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		songRating.set(song, rating);
		FlxG.save.data.songRating = songRating;
		FlxG.save.flush();
	}

	public static function formatSong(song:String, diff:Int):String
	{
		return Difficulty.getFilePath(diff);
	}

	static function formatHighscoreKey(name:String, diff:Int):String // finally bruh
	{
		var formattedName:String = Paths.formatToSongPath(name);
		var formattedDifficulty:String = Difficulty.getFilePath(diff);
		if(formattedDifficulty == null || formattedDifficulty.length < 1)
			formattedDifficulty = Paths.formatToSongPath(Difficulty.getDefault());

		return '$formattedName::$formattedDifficulty';
	}

	public static function getScore(song:String, diff:Int):Int
	{
		var daSong:String = formatHighscoreKey(song, diff);
		if (!songScores.exists(daSong))
			return 0;

		return songScores.get(daSong);
	}

	public static function getRating(song:String, diff:Int):Float
	{
		var daSong:String = formatHighscoreKey(song, diff);
		if (!songRating.exists(daSong))
			return 0;

		return songRating.get(daSong);
	}

	public static function getWeekScore(week:String, diff:Int):Int
	{
		var daWeek:String = formatHighscoreKey(week, diff);
		if (!weekScores.exists(daWeek))
			return 0;

		return weekScores.get(daWeek);
	}

	public static function load():Void {
		weekScores = (FlxG.save.data.weekScores ?? weekScores);
		songScores = (FlxG.save.data.songScores ?? songScores);
		songRating = (FlxG.save.data.songRating ?? songRating);
		StoryMenuState.weekCompleted = (FlxG.save.data.weekCompleted ?? StoryMenuState.weekCompleted);
	}
	public static function saveScores():Void {
		FlxG.save.data.weekCompleted = StoryMenuState.weekCompleted;
		FlxG.save.data.weekScores = weekScores;
		FlxG.save.data.songScores = songScores;
		FlxG.save.data.songRating = songRating;
	}
}
