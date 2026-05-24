package cutscenes;

import cutscenes.DialogueBoxPsych.DialogueFile;
import cutscenes.DialogueBoxPsych.DialogueLine;
import cutscenes.DialoguePlus.DialoguePlusFile;
import states.PlayState;

class DialoguePlusRuntime
{
	public var game(default, null):PlayState;
	public var dialogueName(default, null):String;
	public var dialogueMusic(default, null):String;
	public var dialoguePath:String;
	public var loadedXmlPath:String;

	var dialogueFile:DialogueFile = {dialogue: []};

	public var psychDialogue(get, never):DialogueBoxPsych;
	public var box(get, never):Dynamic;
	public var text(get, never):Dynamic;
	public var background(get, never):Dynamic;
	public var skipText(get, never):Dynamic;
	public var characters(get, never):Dynamic;

	var pendingDialogueVisible:Null<Bool> = null;
	var pendingBoxVisible:Null<Bool> = null;
	var pendingTextVisible:Null<Bool> = null;
	var pendingBackgroundVisible:Null<Bool> = null;
	var pendingSkipTextVisible:Null<Bool> = null;
	var pendingCanContinue:Null<Bool> = null;
	var pendingCanSkip:Null<Bool> = null;

	public function new(game:PlayState, dialogueName:String = 'dialogue', ?dialogueMusic:String = null, ?dialoguePath:String = null)
	{
		this.game = game;
		this.dialogueName = dialogueName;
		this.dialogueMusic = dialogueMusic;
		this.dialoguePath = dialoguePath;
	}

	public function loadXml(name:String = 'dialogue', append:Bool = false):Bool
	{
		var found:DialoguePlusFile = DialoguePlus.findDialogueFile(name, ['xml']);
		if(found == null)
		{
			FlxG.log.warn('Dialogue Plus XML not found: $name');
			return false;
		}

		var parsed:DialogueFile = DialoguePlus.parseXmlDialogue(found.path);
		if(!DialoguePlus.isValidDialogue(parsed))
		{
			FlxG.log.warn('Dialogue Plus XML is empty or invalid: ${found.path}');
			return false;
		}

		loadedXmlPath = found.path;
		return addLines(parsed, append);
	}

	public function addLine(portrait:String = 'bf', text:String = ' ', expression:String = 'talk', boxState:String = 'normal', speed:Float = 0.05, sound:String = 'dialogue'):DialogueLine
	{
		var line:DialogueLine = {
			portrait: portrait,
			expression: expression,
			text: text,
			boxState: boxState,
			speed: speed,
			sound: sound
		};
		dialogueFile.dialogue.push(line);
		return line;
	}

	public function addLines(data:Dynamic, append:Bool = true):Bool
	{
		var parsed:DialogueFile = DialoguePlus.normalizeDialogue(data);
		if(!DialoguePlus.isValidDialogue(parsed))
			return false;

		if(!append)
			clearLines();

		for(line in parsed.dialogue)
			dialogueFile.dialogue.push(line);
		return true;
	}

	public function setDialogueFile(data:Dynamic):Bool
		return addLines(data, false);

	public function clearLines():Void
		dialogueFile.dialogue.resize(0);

	public function getDialogueFile():DialogueFile
		return dialogueFile;

	public function hasLines():Bool
		return DialoguePlus.isValidDialogue(dialogueFile);

	public function onLine(lineNumber:Int, index:Int, curLine:DialogueLine):Void
	{
		callScript('onLine', [lineNumber, index, curLine, this]);
		applySettings();
	}

	public function stopDialogueMusic(fadeTime:Float = 0):Bool
	{
		var music = FlxG.sound.music;
		if(music == null)
			return false;

		if(fadeTime > 0)
			music.fadeOut(fadeTime, 0, (_) -> music.stop());
		else
			music.stop();
		return true;
	}

	public function playDialogueMusic(name:String, volume:Float = 1, loop:Bool = true, fadeTime:Float = 0):Bool
	{
		if(name == null || name.trim().length < 1)
			return false;

		FlxG.sound.playMusic(Paths.music(name), fadeTime > 0 ? 0 : volume, loop);
		if(fadeTime > 0 && FlxG.sound.music != null)
			FlxG.sound.music.fadeIn(fadeTime, 0, volume);
		return true;
	}

	public function setCanContinue(value:Bool):Bool
	{
		pendingCanContinue = value;
		if(game != null && game.psychDialogue != null)
			game.psychDialogue.canContinue = value;
		return value;
	}

	public function setCanSkip(value:Bool):Bool
	{
		pendingCanSkip = value;
		if(game != null && game.psychDialogue != null)
			game.psychDialogue.canSkip = value;
		return value;
	}

	public function setDialogueVisible(value:Bool):Bool
	{
		pendingDialogueVisible = value;
		if(game != null && game.psychDialogue != null)
			game.psychDialogue.visible = value;
		return value;
	}

	public function setBoxVisible(value:Bool):Bool
	{
		pendingBoxVisible = value;
		if(game != null && game.psychDialogue != null)
			game.psychDialogue.setBoxVisible(value);
		return value;
	}

	public function setTextVisible(value:Bool):Bool
	{
		pendingTextVisible = value;
		if(game != null && game.psychDialogue != null)
			game.psychDialogue.setTextVisible(value);
		return value;
	}

	public function setBackgroundVisible(value:Bool):Bool
	{
		pendingBackgroundVisible = value;
		if(game != null && game.psychDialogue != null)
			game.psychDialogue.setBackgroundVisible(value);
		return value;
	}

	public function setSkipTextVisible(value:Bool):Bool
	{
		pendingSkipTextVisible = value;
		if(game != null && game.psychDialogue != null)
			game.psychDialogue.setSkipTextVisible(value);
		return value;
	}

	public function applySettings():Void
	{
		if(game == null || game.psychDialogue == null)
			return;

		if(pendingDialogueVisible != null)
			game.psychDialogue.visible = pendingDialogueVisible;
		if(pendingBoxVisible != null)
			game.psychDialogue.setBoxVisible(pendingBoxVisible);
		if(pendingTextVisible != null)
			game.psychDialogue.setTextVisible(pendingTextVisible);
		if(pendingBackgroundVisible != null)
			game.psychDialogue.setBackgroundVisible(pendingBackgroundVisible);
		if(pendingSkipTextVisible != null)
			game.psychDialogue.setSkipTextVisible(pendingSkipTextVisible);
		if(pendingCanContinue != null)
			game.psychDialogue.canContinue = pendingCanContinue;
		if(pendingCanSkip != null)
			game.psychDialogue.canSkip = pendingCanSkip;
	}

	public function dialogueTimer(time:Float, callback:Dynamic):FlxTimer
	{
		return new FlxTimer().start(time, (_) -> {
			if(Reflect.isFunction(callback))
				Reflect.callMethod(null, callback, []);
		});
	}

	function callScript(name:String, args:Array<Dynamic>):Dynamic
	{
		#if HSCRIPT_ALLOWED
		if(game != null && game.dialoguePlusScript != null && !game.dialoguePlusScript.closed && game.dialoguePlusScript.exists(name))
		{
			var call = game.dialoguePlusScript.call(name, args);
			return call != null ? call.returnValue : null;
		}
		#end
		return null;
	}

	function get_psychDialogue():DialogueBoxPsych
		return game != null ? game.psychDialogue : null;

	function get_box():Dynamic
		return psychDialogue != null ? psychDialogue.box : null;

	function get_text():Dynamic
		return psychDialogue != null ? psychDialogue.daText : null;

	function get_background():Dynamic
		return psychDialogue != null ? psychDialogue.bgFade : null;

	function get_skipText():Dynamic
		return psychDialogue != null ? psychDialogue.skipText : null;

	function get_characters():Dynamic
		return psychDialogue != null ? psychDialogue.arrayCharacters : null;
}
