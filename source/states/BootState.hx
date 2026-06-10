package states;

class BootState extends MusicBeatState
{
	override function create():Void
	{
		#if TOUCH_CONTROLS_ALLOWED
		trace("Loading mobile data");
		MobileData.init();
		#end
		
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		MusicBeatState.loadState(MusicBeatState.buildState('TitleState'));
	}
}
