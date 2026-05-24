package cutscenes;

import backend.Song;
import openfl.utils.Assets;
import states.PlayState;
import cutscenes.DialogueBoxPsych;

typedef DialoguePlusFile = {
	var path:String;
	var extension:String;
}

class DialoguePlus
{
	public static final EXTENSIONS:Array<String> = ['hxc', 'xml', 'json'];

	public static function start(game:PlayState, dialogueFile:String, ?music:String = null):Bool
	{
		if(game == null)
			return false;

		var found:DialoguePlusFile = findDialogueFile(dialogueFile);
		if(found == null)
			return false;

		switch(found.extension)
		{
			case 'hxc':
				#if HSCRIPT_ALLOWED
				return game.startDialoguePlusScript(found.path, dialogueBaseName(dialogueFile), music);
				#else
				FlxG.log.warn('Dialogue Plus HXC is not supported on this platform: ${found.path}');
				return false;
				#end

			case 'xml':
				var parsed:DialogueFile = parseXmlDialogue(found.path);
				if(isValidDialogue(parsed))
				{
					game.startDialogue(parsed, music, true);
					return true;
				}

			case 'json':
				var parsed:DialogueFile = DialogueBoxPsych.parseDialogue(found.path);
				if(isValidDialogue(parsed))
				{
					game.startDialogue(parsed, music);
					return true;
				}
		}
		return false;
	}

	public static function findDialogueFile(dialogueFile:String, ?extensions:Array<String>):DialoguePlusFile
	{
		dialogueFile = normalizeName(dialogueFile);
		if(dialogueFile.length < 1)
			dialogueFile = 'dialogue';

		extensions ??= EXTENSIONS;
		var explicitExtension:String = knownExtension(dialogueFile);
		if(explicitExtension != null && (extensions == EXTENSIONS || extensions.contains(explicitExtension)))
			extensions = [explicitExtension];

		for(ext in extensions)
		{
			ext = normalizeExtension(ext);
			for(path in buildCandidates(dialogueFile, ext))
			{
				if(pathExists(path))
					return {path: path, extension: ext};
			}
		}
		return null;
	}

	public static function parseXmlDialogue(path:String):DialogueFile
	{
		var raw:String = readText(path);
		if(raw == null || raw.trim().length < 1)
			return DialogueBoxPsych.dummy();

		try
		{
			var root:Xml = Xml.parse(raw).firstElement();
			if(root == null)
				return DialogueBoxPsych.dummy();

			var lines:Array<DialogueLine> = [];
			for(node in root.elements())
			{
				var nodeName:String = node.nodeName == null ? '' : node.nodeName.toLowerCase();
				switch(nodeName)
				{
					case 'line' | 'dialogue' | 'dialogueline':
						lines.push(xmlLine(node));
					default:
				}
			}

			return {dialogue: lines};
		}
		catch(e:Dynamic)
		{
			FlxG.log.warn('Dialogue Plus XML parse error ($path): $e');
		}
		return DialogueBoxPsych.dummy();
	}

	public static function normalizeDialogue(data:Dynamic):DialogueFile
	{
		if(data == null)
			return null;

		var rawDialogue:Dynamic = null;
		if(Std.isOfType(data, Array))
			rawDialogue = data;
		else
			rawDialogue = Reflect.field(data, 'dialogue');

		if(rawDialogue == null || !Std.isOfType(rawDialogue, Array))
			return null;

		var rawLines:Array<Dynamic> = cast rawDialogue;
		var lines:Array<DialogueLine> = [];
		for(rawLine in rawLines)
		{
			if(rawLine == null)
				continue;

			if(Std.isOfType(rawLine, String))
			{
				lines.push({
					portrait: 'bf',
					expression: 'talk',
					text: Std.string(rawLine),
					boxState: 'normal',
					speed: 0.05
				});
				continue;
			}

			lines.push({
				portrait: dynamicString(rawLine, ['portrait', 'character', 'char', 'speaker'], 'bf'),
				expression: dynamicString(rawLine, ['expression', 'anim', 'animation'], 'talk'),
				text: dynamicString(rawLine, ['text', 'dialogue', 'value'], ' '),
				boxState: dynamicString(rawLine, ['boxState', 'box', 'state'], 'normal'),
				speed: dynamicFloat(rawLine, ['speed'], 0.05),
				sound: dynamicString(rawLine, ['sound'], null)
			});
		}
		return {dialogue: lines};
	}

	public static inline function isValidDialogue(dialogue:DialogueFile):Bool
		return dialogue != null && dialogue.dialogue != null && dialogue.dialogue.length > 0;

	static function buildCandidates(dialogueFile:String, extension:String):Array<String>
	{
		var candidates:Array<String> = [];
		var base:String = stripKnownExtension(dialogueFile);
		var fileName:String = '$base.$extension';
		var explicitPath:Bool = base.contains('/') || base.contains('\\');
		var songPath:String = getSongPath();

		function add(raw:String):Void
		{
			if(raw == null || raw.trim().length < 1)
				return;

			raw = raw.replace('\\', '/');
			if(!candidates.contains(raw))
				candidates.push(raw);

			var resolved:String = Paths.getPath(raw, TEXT);
			if(resolved != null && !candidates.contains(resolved))
				candidates.push(resolved);
		}

		if(explicitPath)
		{
			add(fileName);
			return candidates;
		}

		#if TRANSLATIONS_ALLOWED
		var language:String = ClientPrefs.data.language;
		if(language != null && language.trim().length > 0)
			add('songs/$songPath/${base}_$language.$extension');
		#end

		add('songs/$songPath/$fileName');

		if(extension == 'json')
		{
			#if TRANSLATIONS_ALLOWED
			var language:String = ClientPrefs.data.language;
			if(language != null && language.trim().length > 0)
				add('data/$songPath/${base}_$language.json');
			#end
			add('data/$songPath/$base.json');
		}

		return candidates;
	}

	static function xmlLine(node:Xml):DialogueLine
	{
		return {
			portrait: xmlAttr(node, ['portrait', 'character', 'char', 'speaker'], 'bf'),
			expression: xmlAttr(node, ['expression', 'anim', 'animation'], 'talk'),
			text: xmlText(node),
			boxState: xmlAttr(node, ['boxState', 'box', 'state'], 'normal'),
			speed: parseFloat(xmlAttr(node, ['speed'], null), 0.05),
			sound: xmlAttr(node, ['sound'], null)
		};
	}

	static function xmlAttr(node:Xml, names:Array<String>, fallback:String):String
	{
		for(name in names)
			if(node.exists(name))
				return node.get(name);
		return fallback;
	}

	static function xmlText(node:Xml):String
	{
		if(node.exists('text'))
			return node.get('text');

		for(child in node.elementsNamed('text'))
		{
			var text:String = collectText(child);
			if(text.trim().length > 0)
				return text;
		}

		var text:String = collectText(node);
		return text.trim().length > 0 ? text : ' ';
	}

	static function collectText(node:Xml):String
	{
		var text:String = '';
		for(child in node)
		{
			switch(child.nodeType)
			{
				case PCData | CData:
					text += child.nodeValue;
				default:
			}
		}
		return text;
	}

	static function dynamicString(source:Dynamic, fields:Array<String>, fallback:String):String
	{
		for(field in fields)
		{
			var value:Dynamic = Reflect.field(source, field);
			if(value != null)
				return Std.string(value);
		}
		return fallback;
	}

	static function dynamicFloat(source:Dynamic, fields:Array<String>, fallback:Float):Float
	{
		for(field in fields)
		{
			var value:Dynamic = Reflect.field(source, field);
			if(value == null)
				continue;

			if(Std.isOfType(value, Int) || Std.isOfType(value, Float))
				return cast value;

			return parseFloat(Std.string(value), fallback);
		}
		return fallback;
	}

	static function parseFloat(value:String, fallback:Float):Float
	{
		if(value == null)
			return fallback;

		var parsed:Float = Std.parseFloat(value);
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	static function getSongPath():String
	{
		var song:String = Song.loadedSongName;
		if((song == null || song.length < 1) && PlayState.SONG != null)
			song = PlayState.SONG.song;
		return Paths.formatToSongPath(song ?? '');
	}

	static function dialogueBaseName(dialogueFile:String):String
	{
		var base:String = stripKnownExtension(normalizeName(dialogueFile));
		var slash:Int = base.lastIndexOf('/');
		if(slash >= 0)
			base = base.substr(slash + 1);
		return base.length > 0 ? base : 'dialogue';
	}

	static function normalizeName(name:String):String
		return name == null ? '' : name.trim().replace('\\', '/');

	static function stripKnownExtension(name:String):String
	{
		var lower:String = name.toLowerCase();
		for(ext in EXTENSIONS)
		{
			var suffix:String = '.$ext';
			if(lower.endsWith(suffix))
				return name.substr(0, name.length - suffix.length);
		}
		return name;
	}

	static function knownExtension(name:String):String
	{
		var lower:String = name.toLowerCase();
		for(ext in EXTENSIONS)
			if(lower.endsWith('.$ext'))
				return ext;
		return null;
	}

	static function normalizeExtension(extension:String):String
	{
		extension = extension == null ? '' : extension.trim().toLowerCase();
		while(extension.startsWith('.'))
			extension = extension.substr(1);
		return extension;
	}

	static function readText(path:String):String
	{
		#if sys
		if(FileSystem.exists(path))
			return File.getContent(path);
		#end
		return Assets.exists(path, TEXT) ? Assets.getText(path) : null;
	}

	static function pathExists(path:String):Bool
	{
		#if sys
		if(FileSystem.exists(path))
			return true;
		#end
		return Assets.exists(path, TEXT);
	}
}
