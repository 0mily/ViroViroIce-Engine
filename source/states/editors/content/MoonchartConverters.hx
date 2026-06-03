package states.editors.content;

import backend.Song;
import backend.Song.SwagSong;
import haxe.Json;
import moonchart.Moonchart;
import moonchart.backend.FormatData.Format;
import moonchart.backend.FormatData.PossibleValue;
import moonchart.backend.FormatDetector;
import moonchart.formats.BasicFormat.DynamicFormat;
import moonchart.formats.fnf.FNFCodename;
import moonchart.formats.fnf.legacy.FNFPsych;
import states.editors.content.VSlice.PsychPackage;
import states.editors.content.VSlice.VSliceChart;
import states.editors.content.VSlice.VSliceMetadata;

#if GLOBAL_SCRIPTS
import psychlua.GlobalScriptHandler;
import psychlua.LuaUtils;
#end

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

typedef MoonchartOpcao =
{
	var format:Format;
	var label:String;
	var extension:String;
	@:optional var nightmareVision:Bool;
	@:optional var sourceOnly:Bool;
}

typedef MoonchartConversionResult =
{
	var formatName:String;
	var dataPath:String;
	@:optional var metaPath:String;
}

class MoonchartConverters
{
	public static final ENGINE_FORMAT:Format = Format.FNF_LEGACY_PSYCH;

	static final supportedFormats:Array<Format> = [
		ENGINE_FORMAT,
		Format.FNF_LEGACY,
		Format.FNF_LEGACY_TROLL,
		Format.FNF_LEGACY_FPS_PLUS,
		Format.FNF_KADE,
		Format.FNF_MARU,
		Format.FNF_CODENAME,
		Format.FNF_VSLICE,
		Format.OSU_MANIA,
		Format.QUAVER,
		Format.STEPMANIA
	];

	static var initialized:Bool = false;

	static function ensureInit():Void
	{
		if(initialized) return;

		Moonchart.init();
		initialized = true;
	}

	public static function getExternalFormats():Array<MoonchartOpcao>
	{
		ensureInit();

		var options:Array<MoonchartOpcao> = [];
		for(format in supportedFormats)
		{
			var data = FormatDetector.getFormatData(format);
			var extension = cleanExtension(data.extension);
			var metaSuffix = needsMetadata(format) ? ' + metadata' : '';
			options.push({
				format: format,
				label: '${getFormatName(format)} (.$extension$metaSuffix)',
				extension: extension
			});
		}
		options.push({
			format: ENGINE_FORMAT,
			label: 'Nightmare Vision (.json)',
			extension: 'json',
			nightmareVision: true,
			sourceOnly: true
		});
		return options;
	}

	public static function needsMetadata(format:Format):Bool
	{
		ensureInit();

		return FormatDetector.getFormatData(format).hasMetaFile == PossibleValue.TRUE;
	}

	public static function getFormatName(format:Format):String
	{
		ensureInit();

		if(format == ENGINE_FORMAT)
			return 'ViroViroIce';

		return FormatDetector.getFormatData(format).name;
	}

	public static function convertEngineToFormat(songData:SwagSong, targetFormat:Format, outputFolder:String, difficulty:String):MoonchartConversionResult
	{
		ensureInit();

		var diff = cleanDifficulty(difficulty);
		var psych = new FNFPsych().fromJson(PsychJsonPrinter.print(songData, ['sectionNotes', 'events']), null, diff);
		var target = FormatDetector.createFormatInstance(targetFormat);
		target.fromFormat(psych, diff);

		var save = target.save(normalizePath(outputFolder));
		if(targetFormat == ENGINE_FORMAT)
			normalizeEngineSave(save);

		return resultFromSave(save, targetFormat);
	}

	public static function convertFileToEngine(sourceFormat:Format, chartPath:String, ?metadataPath:String, outputFolder:String, difficulty:String, ?conversionName:String):MoonchartConversionResult
	{
		ensureInit();

		var diff = cleanDifficulty(difficulty);
		if(sourceFormat == Format.FNF_VSLICE)
			return convertVSliceFileToEngine(chartPath, metadataPath, outputFolder, diff);

		var source:DynamicFormat = loadSourceFormat(sourceFormat, chartPath, metadataPath, diff);

		var psych = new FNFPsych();
		psych.fromFormat(source, diff);

		var save = psych.save(normalizePath(outputFolder));
		normalizeEngineSave(save, conversionName ?? getFormatName(sourceFormat));

		return resultFromSave(save, ENGINE_FORMAT);
	}

	public static function convertNightmareVisionToEngine(chartPath:String, outputFolder:String, difficulty:String):MoonchartConversionResult
	{
		return convertFileToEngine(ENGINE_FORMAT, chartPath, null, outputFolder, difficulty, 'Nightmare Vision');
	}

	static function convertVSliceFileToEngine(chartPath:String, ?metadataPath:String, outputFolder:String, difficulty:String):MoonchartConversionResult
	{
		#if sys
		if(metadataPath == null || metadataPath.length < 1)
			throw 'FNF V-Slice charts need the matching metadata JSON.';

		var chart:VSliceChart = cast Json.parse(File.getContent(normalizePath(chartPath)));
		var metadata:VSliceMetadata = cast Json.parse(File.getContent(normalizePath(metadataPath)));
		var pack:PsychPackage = VSlice.convertToPsych(chart, metadata);
		var songData:SwagSong = pack.difficulties.get(difficulty);

		if(songData == null && difficulty != 'normal')
			songData = pack.difficulties.get('normal');
		if(songData == null)
		{
			for (_ => data in pack.difficulties)
			{
				songData = data;
				break;
			}
		}
		if(songData == null)
			throw 'V-Slice conversion did not produce any chart data.';

		Song.normalizeChart(songData);

		var outputPath:String = normalizePath(outputFolder);
		if(!FileSystem.exists(outputPath))
			FileSystem.createDirectory(outputPath);
		var defaultDiff:String = Paths.formatToSongPath(Difficulty.getDefault());
		var diffPostfix:String = difficulty != defaultDiff ? '-$difficulty' : '';
		var dataPath:String = normalizePath('$outputPath/${Paths.formatToSongPath(songData.song)}$diffPostfix.json');
		File.saveContent(dataPath, PsychJsonPrinter.print(songData, ['sectionNotes', 'events']));

		if(pack.events != null)
		{
			var eventsFolder:String = normalizePath('$outputPath/events');
			if(!FileSystem.exists(eventsFolder))
				FileSystem.createDirectory(eventsFolder);
			File.saveContent('$eventsFolder/events.json', PsychJsonPrinter.print(pack.events, ['events']));
		}

		return {
			formatName: getFormatName(Format.FNF_VSLICE),
			dataPath: dataPath,
			metaPath: null
		}
		#else
		throw 'FNF V-Slice conversion needs sys file access on this target.';
		#end
	}

	static function loadSourceFormat(sourceFormat:Format, chartPath:String, ?metadataPath:String, difficulty:String):DynamicFormat
	{
		var normalizedChartPath:String = normalizePath(chartPath);
		var normalizedMetadataPath:String = normalizeNullablePath(metadataPath);

		if(sourceFormat == Format.FNF_CODENAME)
			return loadCodenameFormat(normalizedChartPath, normalizedMetadataPath, difficulty);

		var source:DynamicFormat = FormatDetector.createFormatInstance(sourceFormat);
		source.fromFile(normalizedChartPath, normalizedMetadataPath, difficulty);
		return source;
	}

	static function loadCodenameFormat(chartPath:String, ?metadataPath:String, difficulty:String):DynamicFormat
	{
		#if sys
		var rawData:String = File.getContent(chartPath);
		var rawMeta:String = metadataPath != null ? File.getContent(metadataPath) : null;
		if(rawMeta == null || rawMeta.length < 1)
		{
			var parsed:Dynamic = Json.parse(rawData);
			var embeddedMeta:Dynamic = Reflect.field(parsed, 'meta');
			if(embeddedMeta != null)
				rawMeta = Json.stringify(embeddedMeta);
		}

		if(rawMeta == null || rawMeta.length < 1)
			throw 'Codename charts need metadata. Pick the metadata JSON or use a chart with embedded "meta" data.';

		return cast new FNFCodename().fromJson(rawData, rawMeta, difficulty);
		#else
		var source:DynamicFormat = FormatDetector.createFormatInstance(Format.FNF_CODENAME);
		source.fromFile(chartPath, metadataPath, difficulty);
		return source;
		#end
	}

	static function normalizeEngineSave(save:Dynamic, ?conversionName:String = 'ViroViroIce'):Dynamic
	{
		#if sys
		if(save != null && save.dataPath != null)
		{
			var dataPath:String = normalizePath(save.dataPath);
			var songData:SwagSong = Song.parseJSON(File.getContent(dataPath), dataPath);
			applyGeneralStateConversionHooks(songData, conversionName, dataPath);
			File.saveContent(dataPath, PsychJsonPrinter.print(songData, ['sectionNotes', 'events']));
			save.dataPath = dataPath;
		}
		#end
		return save;
	}

	static function applyGeneralStateConversionHooks(songData:SwagSong, conversionName:String, dataPath:String):Void
	{
		#if GLOBAL_SCRIPTS
		if(songData == null || songData.events == null)
			return;

		GlobalScriptHandler.refreshScripts(false, true);

		for (event in songData.events)
		{
			if(event == null || event[1] == null)
				continue;

			var pack:Array<Dynamic> = event[1];
			for (subEvent in pack)
			{
				if(subEvent == null || subEvent.length < 1)
					continue;

				while(subEvent.length < 3)
					subEvent.push('');

				var eventName:String = subEvent[0] != null ? Std.string(subEvent[0]) : '';
				var value1:String = subEvent[1] != null ? Std.string(subEvent[1]) : '';
				var value2:String = subEvent[2] != null ? Std.string(subEvent[2]) : '';
				var returned:Dynamic = GlobalScriptHandler.call('onConvertEventValue2', [
					eventName,
					value1,
					value2,
					conversionName,
					dataPath
				], [
					LuaUtils.Function_Stop,
					LuaUtils.Function_StopLua,
					LuaUtils.Function_StopHScript,
					LuaUtils.Function_StopAll
				], true);

				if(returned != null && Std.isOfType(returned, String) && returned != LuaUtils.Function_Continue)
					subEvent[2] = returned;
			}
		}
		#end
	}

	static function resultFromSave(save:Dynamic, format:Format):MoonchartConversionResult
	{
		if(save == null)
			throw 'Moonchart did not return any saved file data.';

		return {
			formatName: getFormatName(format),
			dataPath: normalizePath(save.dataPath),
			metaPath: normalizeNullablePath(save.metaPath)
		}
	}

	static function cleanDifficulty(difficulty:String):String
	{
		if(difficulty == null || difficulty.trim().length < 1)
			difficulty = Difficulty.getString(false);

		return Paths.formatToSongPath(difficulty);
	}

	static function cleanExtension(extension:String):String
	{
		if(extension == null || extension.length < 1)
			return 'json';

		if(extension.contains('::'))
			extension = extension.split('::').pop();

		return extension;
	}

	static function normalizeNullablePath(path:String):String
	{
		return path == null ? null : normalizePath(path);
	}

	static function normalizePath(path:String):String
	{
		return path == null ? null : path.replace('\\', '/');
	}
}
