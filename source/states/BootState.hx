package states;

class BootState extends MusicBeatState
{
	override function create():Void
	{
		ClientPrefs.preloadContentSelection();
		#if ADDONS_ALLOWED
		Mods.loadTopMod();
		Mods.pushGlobalMods();
		#end

		#if (TOUCH_CONTROLS_ALLOWED && mobile)
		trace("Loading mobile data");
		MobileData.init();
		#end
		
		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;
		MusicBeatState.loadState(MusicBeatState.buildState('TitleState'));
	}
}
