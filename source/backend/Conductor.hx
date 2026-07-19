package backend;

import backend.Song;
import objects.Note;

typedef BPMChangeEvent =
{
	var bpm:Float;
	var stepTime:Float;
	var songTime:Float;
	var sectionBeats:Int;
	@:optional var stepCrochet:Float;
}

class Conductor
{
	/**
	 * The current BPM of the music.
	*/
	public static var bpm(default, set):Float = 100;
	/**
	 * The time (in milliseconds) between beats.
	*/
	public static var crochet:Float = ((60 / bpm) * 1000); // beats in milliseconds
	/**
	 * The time (in milliseconds) between steps (1/16th notes).
	*/
	public static var stepCrochet:Float = crochet / 4; // steps in milliseconds
	/**
	 * The time (in milliseconds) of the music.
	*/
	public static var songPosition:Float = 0;
	/**
	 * The time (in milliseconds) to offset the Conductor by.
	*/
	public static var offset:Float = 0;

	//public static var safeFrames:Int = 10;
	/**
	 * The time (in milliseconds) for the note hit window.
	*/
	public static var safeZoneOffset:Float = 0; // is calculated in create(), is safeFrames in milliseconds

	/**
	 * Array containing all BPM changes in the music.
	*/
	public static var bpmChangeMap:Array<BPMChangeEvent> = defaultBPMChangeMap(bpm);

	/**
	 * Judges hit time with the specified ratings.
	 * 
	 * @param 	arr 	A list of `Rating`s to use in judgement.
	 * @param 	diff 	The time deviation (in milliseconds).
	 * 
	 * @return 	A `Rating`.
	*/
	public static function judgeNote(arr:Array<Rating>, diff:Float=0):Rating // die
	{
		var data:Array<Rating> = arr;
		for(i in 0...data.length-1) //skips last window (Shit)
			if (diff <= data[i].hitWindow)
				return data[i];

		return data[data.length - 1];
	}

	/**
	 * Gets the step crotchet at a specified time in the music.
	 * 
	 * @param 	time 			The time (in milliseconds) to get the step crotchet on.
	 * @param 	bpmChangeMap 	A list of BPM changes. If unspecified, the default `bpmChangeMap` is used.
	 * 
	 * @return 	The time (in milliseconds) between steps at the specified time.
	*/
	public static function getStepCrotchetAtTime(time:Float, ?bpmChangeMap:Array<BPMChangeEvent>){
		var lastChange = getBPMFromSeconds(time, bpmChangeMap);
		return lastChange.stepCrochet;
	}
	
	/**
	 * Gets the beat crotchet at a specified time in the music.
	 * 
	 * @param 	time 			The time (in milliseconds) to get the beat crotchet on.
	 * @param 	bpmChangeMap 	A list of BPM changes. If unspecified, the default `bpmChangeMap` is used.
	 * 
	 * @return 	The time (in milliseconds) between beats at the specified time.
	*/
	public static function getCrotchetAtTime(time:Float, ?bpmChangeMap:Array<BPMChangeEvent>){
		return getStepCrotchetAtTime(time, bpmChangeMap) * 4;
	}

	/**
	 * Gets the BPM at a specified time in the music.
	 * 
	 * @param 	time 			The time (in milliseconds) to get the BPM on.
	 * @param 	bpmChangeMap 	A list of BPM changes. If unspecified, the default `bpmChangeMap` is used.
	 * 
	 * @return 	The BPM at the specified time.
	*/
	public static function getBPMFromSeconds(time:Float, ?bpmChangeMap:Array<BPMChangeEvent>){
		bpmChangeMap ??= Conductor.bpmChangeMap;
		
		var lastChange:BPMChangeEvent = null;
		for (change in bpmChangeMap) {
			if (time >= change.songTime || lastChange == null)
				lastChange = change;
		}

		return lastChange;
	}

	/**
	 * Gets the BPM at a specified step in the music.
	 * 
	 * @param 	step 			The step time to get the BPM on.
	 * @param 	bpmChangeMap 	A list of BPM changes. If unspecified, the default `bpmChangeMap` is used.
	 * 
	 * @return 	The BPM at the specified step.
	*/
	public static function getBPMFromStep(step:Float, ?bpmChangeMap:Array<BPMChangeEvent>){
		bpmChangeMap ??= Conductor.bpmChangeMap;
		
		var lastChange:BPMChangeEvent = null;
		for (change in bpmChangeMap) {
			if (change.stepTime <= step || lastChange == null)
				lastChange = change;
		}

		return lastChange;
	}
	
	/**
	 * Converts time in steps to time in milliseconds.
	 * 
	 * @param 	step 			The step time to convert to milliseconds.
	 * @param 	bpmChangeMap 	A list of BPM changes. If unspecified, the default `bpmChangeMap` is used.
	 * 
	 * @return 	Time in milliseconds.
	*/
	public static function stepToSeconds(step:Float, ?bpmChangeMap:Array<BPMChangeEvent>):Float {
		var lastChange = getBPMFromStep(step, bpmChangeMap);
		return lastChange.songTime + ((step - lastChange.stepTime) / (lastChange.bpm / 60) / 4) * 1000; // TODO: make less shit and take BPM into account PROPERLY
	}

	/**
	 * Converts time in beats to time in milliseconds.
	 * 
	 * @param 	beat 			The beat time to convert to milliseconds.
	 * @param 	bpmChangeMap 	A list of BPM changes. If unspecified, the default `bpmChangeMap` is used.
	 * 
	 * @return 	Time in milliseconds.
	*/
	public static function beatToSeconds(beat:Float, ?bpmChangeMap:Array<BPMChangeEvent>):Float {
		return stepToSeconds(beat * 4, bpmChangeMap);
	}

	/**
	 * Converts time in milliseconds to time in steps.
	 * 
	 * @param 	step 			The millisecond time to convert to steps.
	 * @param 	bpmChangeMap 	A list of BPM changes. If unspecified, the default `bpmChangeMap` is used.
	 * 
	 * @return 	Time in steps.
	*/
	public static function getStep(time:Float, ?bpmChangeMap:Array<BPMChangeEvent>){
		var lastChange = getBPMFromSeconds(time, bpmChangeMap);
		return lastChange.stepTime + (time - lastChange.songTime) / lastChange.stepCrochet;
	}

	/**
	 * Converts time in milliseconds to time in steps.
	 * 
	 * @param 	step 			The millisecond time to convert to steps.
	 * @param 	bpmChangeMap 	A list of BPM changes. If unspecified, the default `bpmChangeMap` is used.
	 * 
	 * @return 	Time in steps, rounded to `Int`.
	*/
	public static function getStepRounded(time:Float, ?bpmChangeMap:Array<BPMChangeEvent>):Int {
		return Math.floor(getStep(time, bpmChangeMap));
	}

	/**
	 * Converts time in milliseconds to time in beats.
	 * 
	 * @param 	step 			The millisecond time to convert to beats.
	 * @param 	bpmChangeMap 	A list of BPM changes. If unspecified, the default `bpmChangeMap` is used.
	 * 
	 * @return 	Time in beats.
	*/
	public static function getBeat(time:Float, ?bpmChangeMap:Array<BPMChangeEvent>){
		return (getStep(time, bpmChangeMap) / 4);
	}

	/**
	 * Converts time in milliseconds to time in beats.
	 * 
	 * @param 	step 			The millisecond time to convert to beats.
	 * @param 	bpmChangeMap 	A list of BPM changes. If unspecified, the default `bpmChangeMap` is used.
	 * 
	 * @return 	Time in beats, rounded to `Int`.
	*/
	public static function getBeatRounded(time:Float, ?bpmChangeMap:Array<BPMChangeEvent>):Int {
		return Math.floor(getStep(time, bpmChangeMap) / 4);
	}
	
	/**
	 * Converts time in milliseconds to time in measures.
	 * 
	 * @param 	step 			The millisecond time to convert to measures.
	 * @param 	bpmChangeMap 	A list of BPM changes. If unspecified, the default `bpmChangeMap` is used.
	 * 
	 * @return 	Time in measures.
	*/
	public static function getSection(time:Float, ?bpmChangeMap:Array<BPMChangeEvent>):Float { // psych's conductor is such a brainfuck
		bpmChangeMap ??= Conductor.bpmChangeMap;
		
		var curSectionBeats:Int = bpmChangeMap[0].sectionBeats;
		var curBPM:Float = bpmChangeMap[0].bpm;
		
		var lastSection:Float = 0;
		var lastTime:Float = 0;
		
		for (change in bpmChangeMap) {
			if (change.songTime > time) break;
			
			lastSection += ((change.songTime - lastTime) / calculateCrochet(curBPM) / curSectionBeats);
			lastTime = change.songTime;
			
			curBPM = change.bpm;
			curSectionBeats = change.sectionBeats;
		}
		
		return ((time - lastTime) / calculateCrochet(curBPM) / curSectionBeats + lastSection);
	}
	
	/**
	 * Converts time in milliseconds to time in measures.
	 * 
	 * @param 	step 			The millisecond time to convert to measures.
	 * @param 	bpmChangeMap 	A list of BPM changes. If unspecified, the default `bpmChangeMap` is used.
	 * 
	 * @return 	Time in measures, rounded to `Int`.
	*/
	public static function getSectionRounded(time:Float, ?bpmChangeMap:Array<BPMChangeEvent>):Int {
		return Math.floor(getSection(time, bpmChangeMap));
	}

	/**
	 * Maps BPM changes from chart data.
	 * 
	 * @param 	song	The chart data to map BPM changes from.
	*/
	public static function mapBPMChanges(?song:SwagSong, ?extraEvents:SwagSong) {
		if (song == null) {
			bpmChangeMap = defaultBPMChangeMap(Conductor.bpm);
			return;
		}
		
		var initialBeats:Int = (song.notes[0]?.sectionBeats ?? 4);
		bpmChangeMap = defaultBPMChangeMap(song.bpm, initialBeats);

		var rawChanges:Array<{songTime:Float, bpm:Float, order:Int}> = [];
		var order:Int = 0;
		function collectTempoEvents(container:SwagSong):Void
		{
			if(container?.events == null) return;
			for(event in container.events)
			{
				if(event == null || event.length < 2 || event[1] == null) continue;
				var eventTime:Float = Std.parseFloat(Std.string(event[0]));
				if(Math.isNaN(eventTime)) continue;
				for(subEvent in (cast event[1]:Array<Dynamic>))
				{
					if(subEvent == null || subEvent.length < 2 || !Song.isBPMChangeEventName(Std.string(subEvent[0]))) continue;
					var eventBPM:Float = Std.parseFloat(Std.string(subEvent[1]));
					if(Math.isNaN(eventBPM) || eventBPM <= 0) continue;
					rawChanges.push({songTime: Math.max(0, eventTime), bpm: eventBPM, order: order++});
				}
			}
		}

		collectTempoEvents(song);
		if(extraEvents != song) collectTempoEvents(extraEvents);

		// it will make charts keep working even tho
		if(rawChanges.length < 1)
		{
			var legacyBPM:Float = song.bpm;
			var legacyTime:Float = 0;
			for(section in song.notes)
			{
				if(section.changeBPM == true && section.bpm != null && section.bpm > 0 && section.bpm != legacyBPM)
				{
					legacyBPM = section.bpm;
					rawChanges.push({songTime: legacyTime, bpm: legacyBPM, order: order++});
				}
				legacyTime += calculateCrochet(legacyBPM) * getSectionBeats(song, song.notes.indexOf(section));
			}
		}

		rawChanges.sort(function(a, b)
		{
			if(Math.abs(a.songTime - b.songTime) < 0.0001) return a.order - b.order;
			return a.songTime < b.songTime ? -1 : 1;
		});

		for(raw in rawChanges)
		{
			var last:BPMChangeEvent = bpmChangeMap[bpmChangeMap.length - 1];
			if(Math.abs(raw.songTime - last.songTime) < 0.0001)
			{
				last.bpm = raw.bpm;
				last.stepCrochet = calculateCrochet(raw.bpm) / 4;
				continue;
			}

			var changeStep:Float = last.stepTime + (raw.songTime - last.songTime) / last.stepCrochet;
			bpmChangeMap.push({
				sectionBeats: last.sectionBeats,
				stepTime: changeStep,
				songTime: raw.songTime,
				bpm: raw.bpm,
				stepCrochet: calculateCrochet(raw.bpm) / 4
			});
		}
		trace('Added ${bpmChangeMap.length} BPM changes');
	}
	/**
	 * Clones a list of BPM changes.
	 * 
	 * @param 	bpmChangeMap 	A list of BPM changes. If unspecified, the default `bpmChangeMap` is used.
	 * 
	 * @return 	The cloned BPM change list.
	*/
	public static function copyBPMChanges(?bpmChanges:Array<BPMChangeEvent>):Array<BPMChangeEvent> {
		bpmChanges ??= Conductor.bpmChangeMap;
		
		var newBPMMap:Array<BPMChangeEvent> = [];
		for (change in bpmChanges)
			newBPMMap.push(Reflect.copy(change));
		
		return newBPMMap;
	}
	/**
	 * Generates a BPM change list from starting tempo.
	 * 
	 * @param 	bpm 			The starting BPM of the music.
	 * @param 	sectionBeats 	The starting beats per measure of the music.
	 * 
	 * @return 	A new BPM change list.
	*/
	public static function defaultBPMChangeMap(bpm:Float = 100, sectionBeats:Int = 4):Array<BPMChangeEvent> {
		return [{
			bpm: bpm,
			stepTime: 0,
			songTime: 0,
			sectionBeats: sectionBeats,
			stepCrochet: calculateCrochet(bpm) * .25
		}];
	}
	
	/**
	 * Gets the amount of beats in a measure.
	 * 
	 * @param 	section 	The measure to get the amount of beats on.
	 * 
	 * @return 	Amount of beats in the measure.
	*/
	static function getSectionBeats(song:SwagSong, section:Int)
	{
		var val:Null<Int> = null;
		if(song.notes[section] != null) val = song.notes[section].sectionBeats;
		return val != null ? val : 4;
	}

	/**
	 * Calculates the beat crotchet from BPM.
	 * 
	 * @param 	bpm 	The BPM to calculate the crotchet for.
	 * 
	 * @return 	The time (in milliseconds) between beats.
	*/
	inline public static function calculateCrochet(bpm:Float){
		return (60/bpm)*1000;
	}

	public static function set_bpm(newBPM:Float):Float {
		crochet = calculateCrochet(newBPM);
		stepCrochet = crochet / 4;
		return bpm = newBPM;
	}

	// updates the bpm without rerwringtgn the modified timeline or smr
	public static inline function setCurrentBPM(newBPM:Float):Float
	{
		return set_bpm(newBPM);
	}
}
