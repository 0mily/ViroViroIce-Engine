package states;

class BootState extends MusicBeatState
{
	override function create():Void
	{
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		MusicBeatState.loadState(MusicBeatState.buildState('TitleState'));
	}
}
