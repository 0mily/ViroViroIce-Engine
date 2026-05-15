package backend;

import haxe.Json;
import lime.utils.Assets;

import objects.Note;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;
	var offset:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var format:String;

	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;
	
	@:optional var disableNoteRGB:Bool;

	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;
	@:optional var cameraMove:CameraMoveData;
}

typedef CameraMoveData =
{
	var enabled:Bool;
	var intensity:Float;
	var speed:Float;
	var offset:Float;
}

typedef SwagSection =
{
	var sectionNotes:Array<Dynamic>;
	var sectionBeats:Int;
	var mustHitSection:Bool;
	@:optional var altAnim:Bool;
	@:optional var gfSection:Bool;
	@:optional var bpm:Float;
	@:optional var changeBPM:Bool;
}

class Song
{
	public static inline final VIRO_FORMAT:String = 'viroviroice_v1';
	public static inline final CAMERA_FOCUS_EVENT:String = 'Focus Camera';

	public var song:String;
	public var notes:Array<SwagSection>;
	public var events:Array<Dynamic>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var arrowSkin:String;
	public var splashSkin:String;
	public var gameOverChar:String;
	public var gameOverSound:String;
	public var gameOverLoop:String;
	public var gameOverEnd:String;
	public var disableNoteRGB:Bool = false;
	public var speed:Float = 1;
	public var stage:String;
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	public var format:String = VIRO_FORMAT;
	public var cameraMove:CameraMoveData;

	public static function convert(songJson:Dynamic) // converte chart irado
	{
		if(songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			if(Reflect.hasField(songJson, 'player3')) Reflect.deleteField(songJson, 'player3');
		}

		if(songJson.events == null)
			songJson.events = [];

		var sectionsData:Array<Dynamic> = songJson.notes;
		if(sectionsData == null) return;

		for (section in sectionsData)
		{
			if(section.sectionNotes == null)
				section.sectionNotes = [];

			if(section.mustHitSection == null)
				section.mustHitSection = true;

			if(section.sectionBeats == null)
				section.sectionBeats = section.lengthInSteps != null ? Std.int(section.lengthInSteps / 4) : 4;

			var i:Int = 0;
			var notes:Array<Dynamic> = section.sectionNotes;
			var len:Int = notes.length;
			while(i < len)
			{
				var note:Array<Dynamic> = notes[i];
				if(note[1] < 0)
				{
					songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
					notes.remove(note);
					len = notes.length;
				}
				else i++;
			}

			var beats:Int = Std.int(section.sectionBeats ?? 4);
			section.sectionBeats = beats;
			if (Reflect.hasField(section, 'lengthInSteps')) Reflect.deleteField(section, 'lengthInSteps');

			for (note in notes)
			{
				var gottaHitNote:Bool = (note[1] < 4) ? section.mustHitSection : !section.mustHitSection;
				note[1] = (note[1] % 4) + (gottaHitNote ? 0 : 4);

				if(note[3] != null && !Std.isOfType(note[3], String))
					note[3] = Note.defaultNoteTypes[note[3]]; //compatibility with Week 7 and 0.1-0.3 psych charts
			}
		}
	}

	public static function isPsychLikeFormat(?format:String):Bool
	{
		if(format == null || format.length < 1) return false;
		return format.startsWith('psych_v1') || format.startsWith(VIRO_FORMAT);
	}

	public static function normalizeChart(songJson:Dynamic):Void
	{
		if(songJson == null) return;

		if(songJson.events == null)
			songJson.events = [];
		ensureCameraMoveData(songJson);
		if(songJson.notes == null)
			return;

		normalizeSections(songJson);
		normalizeCameraEvents(songJson);
		songJson.format = VIRO_FORMAT;
	}

	static function normalizeSections(songJson:Dynamic):Void
	{
		var sectionsData:Array<Dynamic> = songJson.notes;
		if(sectionsData == null) return;

		for (section in sectionsData)
		{
			if(section.sectionNotes == null)
				section.sectionNotes = [];
			if(section.mustHitSection == null)
				section.mustHitSection = true;
			if(section.gfSection == null)
				section.gfSection = false;
			if(section.altAnim == null)
				section.altAnim = false;
			if(section.changeBPM == null)
				section.changeBPM = false;
			if(section.sectionBeats == null)
				section.sectionBeats = section.lengthInSteps != null ? Std.int(section.lengthInSteps / 4) : 4;
		}
	}

	static function normalizeCameraEvents(songJson:Dynamic):Void
	{
		var events:Array<Dynamic> = songJson.events;
		var hasFocusEvent:Bool = false;

		if(events != null)
		{
			for (event in events)
			{
				if(event == null || event[1] == null) continue;
				var pack:Array<Dynamic> = event[1];
				for (subEvent in pack)
				{
					if(subEvent == null || subEvent.length < 1) continue;

					var normalized = normalizeFocusEvent(subEvent);
					if(normalized != null)
					{
						subEvent[0] = CAMERA_FOCUS_EVENT;
						subEvent[1] = normalized[0];
						subEvent[2] = normalized[1];
						hasFocusEvent = true;
					}
				}
			}
		}

		if(!hasFocusEvent)
			addSectionCameraEvents(songJson);

		sortEvents(songJson.events);
	}

	public static function ensureCameraMoveData(songJson:Dynamic):CameraMoveData
	{
		if(songJson == null) return null;

		var data:Dynamic = songJson.cameraMove;
		if(data == null)
		{
			data = {};
			songJson.cameraMove = data;
		}

		data.enabled = parseBool(data.enabled, false);
		data.intensity = parseFloat(data.intensity, 1);
		data.speed = parseFloat(data.speed, 1);
		data.offset = parseFloat(data.offset, 30);

		if(data.speed < 0) data.speed = 0;
		if(data.offset < 0) data.offset = 0;

		return cast data;
	}

	public static function hasEventsNamed(songJson:Dynamic, eventName:String):Bool
	{
		if(songJson == null)
			return false;
		return eventArrayHasEvent(songJson.events, eventName);
	}

	public static function eventArrayHasEvent(events:Array<Dynamic>, eventName:String):Bool
	{
		if(events == null)
			return false;

		for (event in events)
		{
			if(event == null || event[1] == null) continue;
			var pack:Array<Dynamic> = event[1];
			for (subEvent in pack)
			{
				if(subEvent == null || subEvent.length < 1) continue;
				if(subEventMatchesName(cast subEvent, eventName))
					return true;
			}
		}
		return false;
	}

	public static function removeEventsByName(songJson:Dynamic, eventName:String):Void
	{
		if(songJson == null)
			return;
		removeEventsFromArray(songJson.events, eventName);
	}

	public static function removeEventsFromArray(events:Array<Dynamic>, eventName:String):Void
	{
		if(events == null)
			return;

		var i:Int = events.length - 1;
		while(i >= 0)
		{
			var event:Array<Dynamic> = events[i];
			if(event != null && event[1] != null)
			{
				var pack:Array<Dynamic> = event[1];
				var j:Int = pack.length - 1;
				while(j >= 0)
				{
					var subEvent:Array<Dynamic> = cast pack[j];
					if(subEvent != null && subEventMatchesName(subEvent, eventName))
						pack.remove(subEvent);
					j--;
				}

				if(pack.length < 1)
					events.remove(event);
			}
			i--;
		}
		sortEvents(events);
	}

	static function normalizeFocusEvent(event:Array<Dynamic>):Array<String>
	{
		var name:String = Std.string(event[0] ?? '').trim();
		var compact:String = name.toLowerCase().replace(' ', '');

		switch(compact)
		{
			case 'focuscamera' | 'changefocus' | 'changefocuscamera':
				return buildFocusValues(event[1], event[2]);

			case 'fnf_must_hit_section':
				var mustHit:Bool = parseBool(event[1], false);
				return [mustHit ? 'bf, 0, 0' : 'dad, 0, 0', 'classic, 0'];

			case 'cameramovement':
				var target:String = switch(parseInt(event[1], 0))
				{
					case 1: 'bf';
					case 2: 'gf';
					default: 'dad';
				}
				return ['$target, 0, 0', 'classic, 0'];
		}

		return null;
	}

	static function subEventMatchesName(event:Array<Dynamic>, eventName:String):Bool
	{
		if(event == null || event.length < 1)
			return false;

		var expected:String = Std.string(eventName ?? '').toLowerCase().replace(' ', '').trim();
		var actual:String = Std.string(event[0] ?? '').toLowerCase().replace(' ', '').trim();
		if(actual == expected)
			return true;

		return expected == CAMERA_FOCUS_EVENT.toLowerCase().replace(' ', '') && normalizeFocusEvent(event) != null;
	}

	static function buildFocusValues(value1:Dynamic, value2:Dynamic):Array<String>
	{
		var targetData:Array<String> = splitValues(value1);
		var easeData:Array<String> = splitValues(value2);

		var target:String = targetData[0] ?? 'dad';
		var x:String = targetData[1] ?? '0';
		var y:String = targetData[2] ?? '0';
		var ease:String = easeData[0] ?? targetData[3] ?? 'classic';
		var steps:String = easeData[1] ?? targetData[4] ?? '0';

		return ['$target, $x, $y', '$ease, $steps'];
	}

	static function splitValues(value:Dynamic):Array<String>
	{
		if(value == null) return [];

		var raw:String = Std.string(value);
		var values:Array<String> = raw.split(',');
		for (i in 0...values.length)
			values[i] = values[i].trim();

		return values;
	}

	static function addSectionCameraEvents(songJson:Dynamic):Void
	{
		var sectionsData:Array<Dynamic> = songJson.notes;
		if(sectionsData == null) return;

		var bpm:Float = parseFloat(songJson.bpm, 100);
		var time:Float = 0;
		var lastTarget:String = null;

		for (section in sectionsData)
		{
			if(section.changeBPM == true && section.bpm != null)
				bpm = parseFloat(section.bpm, bpm);

			var target:String = section.gfSection == true ? 'gf' : (section.mustHitSection == true ? 'bf' : 'dad');
			if(target != lastTarget)
			{
				addEvent(songJson.events, time, CAMERA_FOCUS_EVENT, '$target, 0, 0', 'classic, 0');
				lastTarget = target;
			}

			var beats:Float = parseFloat(section.sectionBeats, 4);
			if(beats <= 0) beats = 4;
			time += (60 / bpm) * 1000 * beats;
		}
	}

	static function addEvent(events:Array<Dynamic>, time:Float, name:String, value1:String, value2:String):Void
	{
		for (event in events)
		{
			if(event != null && Math.abs(parseFloat(event[0], -999999) - time) < 0.001)
			{
				if(event[1] == null) event[1] = [];
				var pack:Array<Dynamic> = event[1];
				pack.insert(0, [name, value1, value2]);
				return;
			}
		}

		events.push([time, [[name, value1, value2]]]);
	}

	static function sortEvents(events:Array<Dynamic>):Void
	{
		if(events == null) return;
		events.sort((a:Dynamic, b:Dynamic) -> {
			var aTime:Float = parseFloat(a[0], 0);
			var bTime:Float = parseFloat(b[0], 0);
			return aTime < bTime ? -1 : (aTime > bTime ? 1 : 0);
		});
	}

	static function parseBool(value:Dynamic, fallback:Bool):Bool
	{
		if(value == null) return fallback;
		if(Std.isOfType(value, Bool)) return value;

		switch(Std.string(value).toLowerCase().trim())
		{
			case 'true' | '1' | 'bf' | 'boyfriend' | 'player':
				return true;
			case 'false' | '0' | 'dad' | 'opponent':
				return false;
		}
		return fallback;
	}

	static function parseInt(value:Dynamic, fallback:Int):Int
	{
		var parsed:Int = Std.parseInt(Std.string(value ?? ''));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	static function parseFloat(value:Dynamic, fallback:Float):Float
	{
		var parsed:Float = Std.parseFloat(Std.string(value ?? ''));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	public static var chartPath:String;
	public static var loadedSongName:String;
	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		if(folder == null) folder = jsonInput;
		PlayState.SONG = getChart(jsonInput, folder);
		loadedSongName = folder;
		chartPath = _lastPath;
		#if windows
		chartPath = chartPath.replace('/', '\\');
		#end
		StageData.loadDirectory(PlayState.SONG);
		return PlayState.SONG;
	}

	static var _lastPath:String;
	public static function getChart(jsonInput:String, ?folder:String, ?subfolder:String = 'chart'):SwagSong
	{
		if(folder == null) folder = jsonInput;
		var rawData:String = null;
		
		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);
		_lastPath = Paths.json('$formattedFolder/$subfolder/$formattedSong');
		#if MODS_ALLOWED
		if(FileSystem.exists(_lastPath))
			rawData = Paths.getTextFromFile(_lastPath);
		else
		#end
		if (Assets.exists(_lastPath))
			rawData = Assets.getText(_lastPath);

		return rawData != null ? parseJSON(rawData, jsonInput) : null;
	}

	public static function parseJSON(rawData:String, ?nameForError:String = null, ?convertTo:String = 'psych_v1'):SwagSong
	{
		var songJson:SwagSong = cast Json.parse(rawData);
		if(Reflect.hasField(songJson, 'song'))
		{
			var subSong:SwagSong = Reflect.field(songJson, 'song');
			if(subSong != null && Type.typeof(subSong) == TObject)
				songJson = subSong;
		}

		if(convertTo != null && convertTo.length > 0)
		{
			var fmt:String = songJson.format;
			if(fmt == null) fmt = songJson.format = 'unknown';

			switch(convertTo)
			{
				case 'psych_v1':
					if(!isPsychLikeFormat(fmt)) //Convert to Psych 1.0 format
					{
						trace('converting chart $nameForError with format $fmt to psych_v1 format...');
						songJson.format = 'psych_v1_convert';
						convert(songJson);
					}
			}
			normalizeChart(songJson);
		}
		return songJson;
	}
}
