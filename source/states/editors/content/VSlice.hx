package states.editors.content;

import backend.Song;
import backend.Difficulty;
import backend.StageData;

import flixel.math.FlxMath;
import flixel.util.FlxSort;

using StringTools;

// Chart
typedef VSliceChart =
{
	var scrollSpeed:Dynamic;	// Map<String, Float>
	var events:Array<VSliceEvent>;
	var notes:Dynamic;			// Map<String, Array<VSliceNote>>
	var generatedBy:String;
	var version:String;
}

typedef VSliceNote =
{
	var t:Float;					// Strum time
	var d:Int;						// Note data
	@:optional var l:Null<Float>;	// Sustain Length
	@:optional var k:String;		// Note type
}

typedef VSliceEvent =
{
	var t:Float;	//Strum time
	var e:String;	//Event name
	var v:Dynamic;	//Values
}

// Metadata
typedef VSliceMetadata = 
{
	var songName:String;
	var artist:String;
	var charter:String;
	var playData:VSlicePlayData;

	var timeFormat:String;
	var timeChanges:Array<VSliceTimeChange>;
	var generatedBy:String;
	var version:String;
}

typedef VSlicePlayData =
{
	var difficulties:Array<String>;
	var characters:VSliceCharacters;
	var noteStyle:String;
	var stage:String;
}

typedef VSliceCharacters =
{
	var player:String;
	var girlfriend:String;
	var opponent:String;
}

typedef VSliceTimeChange =
{
	var t:Float;
	var bpm:Float;
}

typedef PsychEventChart = {
	var events:Array<Dynamic>;
	var format:String;
}

// Package
typedef VSlicePackage =
{
	var chart:VSliceChart;
	var metadata:VSliceMetadata;
}

typedef PsychPackage =
{
	var difficulties:Map<String, SwagSong>;
	var events:PsychEventChart;
}

class VSlice
{
	public static final metadataVersion = '2.2.3';
	public static final chartVersion = '2.0.0';
	public static function convertToPsych(chart:VSliceChart, metadata:VSliceMetadata):PsychPackage
	{
		var songDifficulties:Map<String, SwagSong> = [];
		var timeChanges:Array<VSliceTimeChange> = normalizeTimeChanges(metadata.timeChanges);
		var songBpm:Float = readFloat(timeChanges[0], ['bpm'], 100);
		var stage:String = mapVSliceStage(readString(metadata.playData, ['stage'], 'stage'));
		var stageZoom:Float = StageData.getStageFile(stage).defaultZoom;
		if(Math.isNaN(stageZoom) || stageZoom <= 0)
			stageZoom = StageData.dummy().defaultZoom;
		var difficulties:Array<String> = getDifficulties(chart, metadata);
		var lastNoteTime:Float = 0;
		var notesMap:Map<String, Array<Dynamic>> = [];
		for (diff in difficulties)
		{
			var notes:Array<Dynamic> = getNotesForDifficulty(chart.notes, diff);
			notes.sort(sortByTime);

			notesMap.set(diff, notes);

			for (note in notes)
			{
				var noteEnd:Float = readFloat(note, ['t', 'time'], 0) + Math.max(0, readFloat(note, ['l', 'length'], 0));
				if(noteEnd > lastNoteTime)
					lastNoteTime = noteEnd;
			}
		}

		var focusCameraEvents:Array<Dynamic> = [];
		var allEvents:Array<Dynamic> = chart.events != null ? chart.events.copy() : [];
		allEvents.sort(sortByTime);
		for (event in allEvents)
		{
			var eventTime:Float = readFloat(event, ['t', 'time'], 0);
			if(eventTime > lastNoteTime)
				lastNoteTime = eventTime;
			if(isFocusCameraEvent(event))
				focusCameraEvents.push(event);
		}

		var baseSections:Array<SwagSection> = [];
		var sectionTimes:Array<Float> = [];
		var lastBpm:Float = songBpm;
		var time:Float = 0;
		var focusEventNum:Int = 0;
		var lastFocusTarget:String = 'dad';
		if(lastNoteTime <= 0)
			lastNoteTime = sectionLength(songBpm);

		while (time <= lastNoteTime + 0.001 || baseSections.length < 1)
		{
			var bpm:Float = getBpmAt(time, timeChanges, songBpm);
			while(focusEventNum < focusCameraEvents.length && readFloat(focusCameraEvents[focusEventNum], ['t', 'time'], 0) <= time + 1)
			{
				var focusTarget:String = focusEventTarget(focusCameraEvents[focusEventNum]);
				if(focusTarget != null)
					lastFocusTarget = focusTarget;
				focusEventNum++;
			}

			sectionTimes.push(time);

			var sec:SwagSection = emptySection();
			sec.mustHitSection = lastFocusTarget == 'bf';
			sec.gfSection = false;
			if(lastBpm != bpm)
			{
				sec.changeBPM = true;
				sec.bpm = bpm;
				lastBpm = bpm;
			}
			baseSections.push(sec);
			time += sectionLength(bpm);
		}
		//trace('sections: ${baseSections.length}, max time: $time, note: $lastNoteTime');

		// create sections based on how much time there is until the last note
		for (diff in difficulties)
		{
			var scrollSpeed:Float = getScrollSpeed(chart.scrollSpeed, diff);
			var notes:Array<Dynamic> = notesMap.get(diff);

			var sectionData:Array<SwagSection> = [];
			for (section in baseSections) //clone sections
			{
				var sec:SwagSection = emptySection();
				sec.mustHitSection = section.mustHitSection;
				sec.gfSection = section.gfSection;
				if(Reflect.hasField(section, 'changeBPM'))
				{
					sec.changeBPM = section.changeBPM;
					sec.bpm = section.bpm;
				}
				sectionData.push(sec);
			}

			var noteSec:Int = 0;
			var time:Float = 0;
			for (note in notes)
			{
				var noteTime:Float = readFloat(note, ['t', 'time'], 0);
				while(noteSec + 1 < sectionTimes.length && sectionTimes[noteSec + 1] <= noteTime)
					noteSec++;

				var noteData:Int = readInt(note, ['d', 'data'], 0);
				var psychNote:Array<Dynamic> = [noteTime, wrapLane(noteData), Math.max(0, readFloat(note, ['l', 'length'], 0))];
				var noteKind:String = readString(note, ['k', 'kind'], '');
				if(noteKind.length > 0 && noteKind != 'normal') psychNote.push(noteKind);

				if(sectionData[noteSec] != null)
					sectionData[noteSec].sectionNotes.push(psychNote);
			}

			var swagSong:SwagSong = {
				song: metadata.songName,
				notes: sectionData,
				events: [],
				bpm: songBpm,
				needsVoices: true, //There's no value on V-Slice to identify if there are vocals as it checks automatically
				speed: scrollSpeed,
				offset: 0,
			
				player1: readString(metadata.playData.characters, ['player'], 'bf'),
				player2: readString(metadata.playData.characters, ['opponent'], 'dad'),
				gfVersion: readString(metadata.playData.characters, ['girlfriend'], 'gf'),
				stage: stage,
				format: 'psych_v1_convert'
			}

			Reflect.setField(swagSong, 'artist', metadata.artist);
			Reflect.setField(swagSong, 'charter', metadata.charter);
			Reflect.setField(swagSong, 'generatedBy', 'Psych Engine v${MainMenuState.psychEngineVersion} - Chart Editor V-Slice Importer');
			songDifficulties.set(diff, swagSong);
		}
		var pack:PsychPackage = {difficulties: songDifficulties, events: null};

		var fileEvents:Array<Dynamic> = [];
		if(allEvents.length > 0)
		{
			for (num => event in allEvents)
			{
				var fields:Array<Dynamic> = convertVSliceEvent(event, stageZoom);
				if(fields != null && fields.length > 0)
					addPsychEvent(fileEvents, readFloat(event, ['t', 'time'], 0), fields);
			}
			fileEvents.sort(sortByTime);
			for (_ => swagSong in songDifficulties)
				swagSong.events = clonePsychEvents(fileEvents);
		}
		return pack;
	}

	static function addPsychEvent(events:Array<Dynamic>, time:Float, fields:Array<Dynamic>):Void
	{
		for(event in events)
		{
			if(event != null && Math.abs(readFloat(event, ['t', 'time'], -999999) - time) < 0.001)
			{
				if(event[1] == null)
					event[1] = [];
				cast(event[1], Array<Dynamic>).push(fields);
				return;
			}
		}
		events.push([time, [fields]]);
	}

	static function clonePsychEvents(events:Array<Dynamic>):Array<Dynamic>
	{
		var cloned:Array<Dynamic> = [];
		if(events == null)
			return cloned;

		for(event in events)
		{
			var subEvents:Array<Dynamic> = [];
			if(event != null && event[1] != null)
			{
				for(subEvent in cast(event[1], Array<Dynamic>))
				{
					if(Std.isOfType(subEvent, Array))
						subEvents.push(cast(subEvent, Array<Dynamic>).copy());
					else
						subEvents.push(subEvent);
				}
			}
			cloned.push([event != null ? event[0] : 0, subEvents]);
		}
		return cloned;
	}

	static function normalizeTimeChanges(timeChanges:Array<VSliceTimeChange>):Array<VSliceTimeChange>
	{
		var list:Array<VSliceTimeChange> = timeChanges != null ? timeChanges.copy() : [];
		if(list.length < 1)
			list.push({t: 0, bpm: 100});
		list.sort(sortByTime);
		if(Math.isNaN(readFloat(list[0], ['bpm'], Math.NaN)))
			list[0].bpm = 100;
		return list;
	}

	static function getDifficulties(chart:VSliceChart, metadata:VSliceMetadata):Array<String>
	{
		var diffs:Array<String> = [];
		if(metadata.playData != null && metadata.playData.difficulties != null)
			for(diff in metadata.playData.difficulties)
				pushDifficulty(diffs, diff);

		for(diff in getDynamicKeys(chart.notes))
			pushDifficulty(diffs, diff);

		if(diffs.length < 1)
			diffs.push(Paths.formatToSongPath(Difficulty.getDefault()));
		return diffs;
	}

	static function pushDifficulty(diffs:Array<String>, diff:String):Void
	{
		if(diff == null)
			return;
		diff = Paths.formatToSongPath(diff);
		if(diff.length > 0 && !diffs.contains(diff))
			diffs.push(diff);
	}

	static function getNotesForDifficulty(notesData:Dynamic, diff:String):Array<Dynamic>
	{
		var raw:Dynamic = getFieldLoose(notesData, diff);
		if(raw == null && diff != 'normal')
			raw = getFieldLoose(notesData, 'normal');
		if(raw == null || !Std.isOfType(raw, Array))
			return [];
		return cast raw;
	}

	static function getScrollSpeed(scrollSpeedData:Dynamic, diff:String):Float
	{
		var value:Dynamic = getFieldLoose(scrollSpeedData, diff);
		if(value == null)
			value = getFieldLoose(scrollSpeedData, 'default');
		var speed:Float = parseFloat(value, 1);
		return Math.isNaN(speed) || speed <= 0 ? 1 : speed;
	}

	static function getBpmAt(time:Float, timeChanges:Array<VSliceTimeChange>, fallback:Float):Float
	{
		var bpm:Float = fallback;
		for(change in timeChanges)
		{
			if(readFloat(change, ['t', 'time'], 0) > time)
				break;
			bpm = readFloat(change, ['bpm'], bpm);
		}
		return Math.isNaN(bpm) || bpm <= 0 ? fallback : bpm;
	}

	static function sectionLength(bpm:Float):Float
	{
		if(Math.isNaN(bpm) || bpm <= 0)
			bpm = 100;
		return Conductor.calculateCrochet(bpm) * 4;
	}

	static function isFocusCameraEvent(event:Dynamic):Bool
		return readString(event, ['e', 'eventKind'], '').toLowerCase() == 'focuscamera';

	static function focusEventTarget(event:Dynamic):String
	{
		var value:Dynamic = Reflect.field(event, 'v');
		return focusTargetFromValue(value);
	}

	static function focusTargetFromValue(value:Dynamic):String
	{
		var charValue:Dynamic = getFieldLoose(value, 'char');
		if(charValue == null)
			charValue = value;

		switch(Std.string(charValue ?? '').toLowerCase().trim())
		{
			case '0' | 'bf' | 'boyfriend' | 'player':
				return 'bf';
			case '1' | 'dad' | 'opponent':
				return 'dad';
			case '2' | 'gf' | 'girlfriend':
				return 'gf';
			case '-1' | 'position' | 'pos':
				return 'position';
		}
		return null;
	}

	static function convertVSliceEvent(event:Dynamic, stageZoom:Float):Array<Dynamic>
	{
		var eventName:String = readString(event, ['e', 'eventKind'], '').trim();
		var value:Dynamic = Reflect.field(event, 'v');
		var compact:String = eventName.toLowerCase().replace(' ', '');

		switch(compact)
		{
			case 'focuscamera':
				var target:String = focusTargetFromValue(value);
				if(target == null) target = 'bf';
				var x:String = eventFloatString(value, ['x'], 0);
				var y:String = eventFloatString(value, ['y'], 0);
				var duration:String = eventFloatString(value, ['duration'], 4);
				var ease:String = normalizeVSliceEase(readString(value, ['ease'], 'CLASSIC'), readString(value, ['easeDir'], ''));
				if(ease.toLowerCase().trim() == 'classic')
					duration = '0';
				return ['Focus Camera', '$target, $x, $y', '$ease, $duration'];

			case 'zoomcamera':
				var zoom:Float = eventFloat(value, ['zoom'], 1);
				var duration:String = eventFloatString(value, ['duration'], 4);
				var ease:String = normalizeVSliceEase(readString(value, ['ease'], 'linear'), readString(value, ['easeDir'], 'InOut'));
				if(ease.toLowerCase().trim() == 'classic')
					duration = '0';
				var mode:String = readString(value, ['mode'], 'direct').toLowerCase().trim();
				if(mode == 'stage')
					zoom *= stageZoom;
				var psychMode:String = switch(mode)
				{
					case 'relative' | 'add' | 'mr': 'mr';
					case 'subtract' | 'sub' | 'lss': 'lss';
					default: 'nll';
				}
				return ['Camera Zoom', '${formatFloat(zoom)}, $duration', '$ease, $psychMode'];

			case 'setcamerabop':
				var intensity:Float = eventFloat(value, ['intensity'], 1);
				var rate:String = eventFloatString(value, ['rate'], 4);
				var offset:String = eventFloatString(value, ['offset'], 0);
				return [
					'Camera Module Bop',
					'$rate, beat, $offset',
					'${formatFloat(0.015 * intensity)}, ${formatFloat(0.03 * intensity)}'
				];

			case 'playanimation':
				return [
					'Play Animation',
					readString(value, ['anim', 'animation'], 'idle'),
					readString(value, ['target'], 'boyfriend'),
					readString(value, ['force'], 'false')
				];

			case 'sethealthicon':
				return [
					'Set Health Icon',
					readString(value, ['char', 'target'], '0'),
					readString(value, ['id', 'icon'], ''),
					eventFloatString(value, ['scale'], 1),
					readString(value, ['flipX'], 'false'),
					readString(value, ['isPixel'], 'false'),
					eventFloatString(value, ['offsetX'], 0),
					eventFloatString(value, ['offsetY'], 0)
				];
		}

		var fields:Array<Dynamic> = eventValueFields(value);
		while(fields.length < 2) fields.push('');
		fields.insert(0, eventName);
		return fields;
	}

	static function eventFloatString(value:Dynamic, fields:Array<String>, fallback:Float):String
		return formatFloat(eventFloat(value, fields, fallback));

	static function eventFloat(value:Dynamic, fields:Array<String>, fallback:Float):Float
	{
		var raw:Dynamic = getFirstField(value, fields);
		if(raw == null && isScalar(value))
			raw = value;

		var parsed:Float = parseFloat(raw, fallback);
		if(Math.isNaN(parsed))
			parsed = fallback;
		return parsed;
	}

	static function formatFloat(value:Float):String
	{
		if(Math.isNaN(value))
			return '0';
		var rounded:Float = Math.round(value * 1000000) / 1000000;
		return Std.string(rounded);
	}

	static function isScalar(value:Dynamic):Bool
	{
		return switch(Type.typeof(value))
		{
			case TObject:
				false;
			case TClass(Array):
				false;
			default:
				value != null;
		}
	}

	static function normalizeVSliceEase(ease:String, easeDir:String):String
	{
		if(ease == null || ease.trim().length < 1)
			return 'linear';

		var trimmed:String = ease.trim();
		var lower:String = trimmed.toLowerCase();
		switch(lower)
		{
			case 'classic':
				return 'classic';
			case 'instant':
				return 'instant';
			case 'linear':
				return 'linear';
		}

		var dir:String = easeDir == null ? '' : easeDir.trim();
		if(dir.length < 1 || lower.endsWith('in') || lower.endsWith('out') || lower.endsWith('inout'))
			return trimmed;
		return trimmed + dir;
	}

	static function wrapLane(lane:Int):Int
	{
		lane %= 8;
		if(lane < 0) lane += 8;
		return lane;
	}

	static function eventValueFields(value:Dynamic):Array<Dynamic>
	{
		var fields:Array<Dynamic> = [];
		if(value == null)
			return fields;

		switch(Type.typeof(value))
		{
			case TObject:
				for (field in Reflect.fields(value))
				{
					fields.push(Std.string(Reflect.field(value, field)));
					if(fields.length == 2) break;
				}
			case TClass(String):
				fields.push(value);
			case TClass(Array):
				var arr:Array<Dynamic> = cast value;
				for (item in arr)
				{
					fields.push(Std.string(item));
					if(fields.length == 2) break;
				}
			default:
				fields.push(Std.string(value));
		}
		return fields;
	}

	static function mapVSliceStage(stage:String):String
	{
		return switch(stage)
		{
			case 'mainStage': 'stage';
			case 'spookyMansion': 'spooky';
			case 'phillyTrain': 'philly';
			case 'limoRide': 'limo';
			case 'mallXmas': 'mall';
			case 'tankmanBattlefield': 'tank';
			default: stage;
		}
	}

	static function readFloat(source:Dynamic, fields:Array<String>, fallback:Float):Float
	{
		if(Std.isOfType(source, Array))
			return parseFloat(cast(source, Array<Dynamic>)[0], fallback);
		return parseFloat(getFirstField(source, fields), fallback);
	}

	static function readInt(source:Dynamic, fields:Array<String>, fallback:Int):Int
	{
		var parsed:Int = Std.parseInt(Std.string(getFirstField(source, fields) ?? ''));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	static function readString(source:Dynamic, fields:Array<String>, fallback:String):String
	{
		var value:Dynamic = getFirstField(source, fields);
		return value == null ? fallback : Std.string(value);
	}

	static function parseFloat(value:Dynamic, fallback:Float):Float
	{
		var parsed:Float = Std.parseFloat(Std.string(value ?? ''));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	static function getFirstField(source:Dynamic, fields:Array<String>):Dynamic
	{
		for(field in fields)
		{
			var value:Dynamic = getFieldLoose(source, field);
			if(value != null)
				return value;
		}
		return null;
	}

	static function getFieldLoose(source:Dynamic, field:String):Dynamic
	{
		if(source == null || field == null)
			return null;

		switch(Type.typeof(source))
		{
			case TObject:
			case TClass(_):
			default:
				return null;
		}

		if(Reflect.hasField(source, field))
			return Reflect.field(source, field);

		var getter:Dynamic = Reflect.field(source, 'get');
		if(getter != null)
		{
			try
			{
				var value:Dynamic = Reflect.callMethod(source, getter, [field]);
				if(value != null)
					return value;
			}
			catch(e:Dynamic) {}
		}

		var formatted:String = Paths.formatToSongPath(field);
		for(key in Reflect.fields(source))
			if(Paths.formatToSongPath(key) == formatted)
				return Reflect.field(source, key);
		return null;
	}

	static function getDynamicKeys(source:Dynamic):Array<String>
	{
		var keys:Array<String> = [];
		if(source == null)
			return keys;

		var keysMethod:Dynamic = Reflect.field(source, 'keys');
		if(keysMethod != null)
		{
			try
			{
				var iterator:Dynamic = Reflect.callMethod(source, keysMethod, []);
				while(iterator != null && iterator.hasNext())
				{
					var key:String = Std.string(iterator.next());
					if(!keys.contains(key))
						keys.push(key);
				}
			}
			catch(e:Dynamic) {}
		}

		for(key in Reflect.fields(source))
			if(!keys.contains(key))
				keys.push(key);
		return keys;
	}


	public static function export(songData:SwagSong, ?difficultyName:String = null):VSlicePackage
	{
		var events:Array<VSliceEvent> = [];
		if(songData.events != null && songData.events.length > 0) //Add events
		{
			for (event in songData.events)
			{
				var subEvents:Array<Array<Dynamic>> = cast event[1];
				if(subEvents != null && subEvents.length > 0)
					for (lilEvent in subEvents)
						events.push({t: event[0], e: lilEvent[0], v: {value1: lilEvent[1], value2: lilEvent[2]}});
			}
		}

		var notes:Array<VSliceNote> = [];
		var generatedBy:String = 'Psych Engine v${MainMenuState.psychEngineVersion} - Chart Editor V-Slice Exporter';
		var timeChanges:Array<VSliceTimeChange> = [];
		
		var time:Float = 0;
		var bpm:Float = songData.bpm;
		timeChanges.push({t: 0, bpm: bpm}); //so there was first bpm issue (if the song has multiplier bpm) 
		var lastFocusChar:Int = 1;
		if(songData.notes != null)
		{
			for (section in songData.notes)
			{
				// Add notes
				if(section.sectionNotes != null && section.sectionNotes.length > 0)
				{
					for (note in section.sectionNotes)
					{
						var lane:Int = Std.int(note[1] ?? 0);
						var vsliceNote:VSliceNote = {t: note[0], d: wrapLane(lane)};
						if(note[2] > 0)
							vsliceNote.l = note[2];
						if(note[3] != null && note[3].length > 0)
							vsliceNote.k = note[3];
						
						notes.push(vsliceNote);
					}
				}

				// Add camera events to act like the "Must hit section" camera focus
				var beat:Float = Conductor.calculateCrochet(bpm);
				if(section.changeBPM)
				{
					bpm = section.bpm;
					beat = Conductor.calculateCrochet(bpm);
					timeChanges.push({t: time, bpm: bpm});
				}

				var focusChar:Int = section.gfSection == true ? 2 : (section.mustHitSection ? 0 : 1);
				if(lastFocusChar != focusChar)
				{
					events.push({t: time, e: 'FocusCamera', v: {char: focusChar}});
					lastFocusChar = focusChar;
				}

				var rowRound:Int = Math.round(4 * section.sectionBeats);
				time += beat * (rowRound / 4);
			}
		}
		events.sort(sortByTime);
		notes.sort(sortByTime);
		
		//try to find composer despite it not being a value on psych charts
		var composer:String = 'Unknown';
		if(Reflect.hasField(songData, 'artist')) composer = Reflect.field(songData, 'artist');
		else if(Reflect.hasField(songData, 'composer')) composer = Reflect.field(songData, 'composer');
		
		var charter:String = 'Unknown';
		if(Reflect.hasField(songData, 'charter')) charter = Reflect.field(songData, 'charter');

		// Has to add all difficulties or it might crash on V-Slice's Freeplay
		var diffs:Array<String> = [];
		
		var scrollSpeed:Map<String, Float> = [];
		var notesMap:Map<String, Array<VSliceNote>> = [];
		if(difficultyName == null) //Fill all difficulties to attempt to prevent the song from not showing up on Base Game
		{
			diffs = Difficulty.list.copy();
			for (num => diff in diffs)
			{
				diffs[num] = diff = Paths.formatToSongPath(diff);
				scrollSpeed.set(diff, songData.speed);
				notesMap.set(diff, notes.copy());
			}
		}
		else
		{
			var diff:String = difficultyName;
			if(diff == null) diff = Difficulty.getDefault();
			diff = Paths.formatToSongPath(diff);
			
			diffs = [diff];
			scrollSpeed.set(diff, songData.speed);
			notesMap.set(diff, notes.copy());
		}

		// Build package
		var chart:VSliceChart = {
			scrollSpeed: scrollSpeed,
			events: events,
			notes: notesMap,
			generatedBy: generatedBy,
			version: chartVersion //idk what "version" does on V-Slice, but it seems to break without it
		};

		var stage:String = songData.stage;
		switch(stage) //Psych and VSlice use different names for some stages
		{
			case 'stage':
				stage = 'mainStage';
			case 'spooky':
				stage = 'spookyMansion';
			case 'philly':
				stage = 'phillyTrain';
			case 'limo':
				stage = 'limoRide';
			case 'mall':
				stage = 'mallXmas';
			case 'tank':
				stage = 'tankmanBattlefield';
		}
		var metadata:VSliceMetadata = {
			songName: songData.song,
			artist: composer,
			charter: charter,
			playData: {
				difficulties: diffs,
				characters: {
					player: songData.player1,
					girlfriend: songData.gfVersion != null ? songData.gfVersion : '', //there is no problem if gf don't exist with it 
					opponent: songData.player2
				},
				noteStyle: !PlayState.isPixelStage ? 'funkin' : 'pixel',
				stage: stage
			},
			timeFormat: 'ms',
			timeChanges: timeChanges,
			generatedBy: generatedBy,
			version: metadataVersion //idk what "version" does on V-Slice, but it seems to break without it
		};
		return {chart: chart, metadata: metadata};
	}

	static function emptySection():SwagSection
	{
		return {
			sectionNotes: [],
			sectionBeats: 4,
			mustHitSection: true,
			gfSection: false,
		};
	}

	static function sortByTime(Obj1:Dynamic, Obj2:Dynamic):Int
		return FlxSort.byValues(FlxSort.ASCENDING, readFloat(Obj1, ['t', 'time'], 0), readFloat(Obj2, ['t', 'time'], 0));
}
