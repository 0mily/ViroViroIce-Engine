package psychlua;

#if macro

#if HSCRIPT_ALLOWED
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;

class HScriptMacro {
	static macro function buildInterp():Array<Field> {
		var pos:Position = Context.currentPos();
		var fields:Array<Field> = Context.getBuildFields();
		
		for (field in fields) {
			if (field.name == 'setVar' && field.access != null) // DE-INLINE METHOD
				field.access.remove(Access.AInline);
		}
		
		return fields;
	}
}
#end

#else

import flixel.FlxState;
import flixel.FlxSubState;
import flixel.system.FlxAssets.FlxShader;
import openfl.Lib;
import openfl.utils.Assets;

import states.MainMenuState;

#if LUA_ALLOWED
import psychlua.FunkinLua;
#end

#if HSCRIPT_ALLOWED
import psychlua.LuaUtils;

import crowplexus.iris.Iris;
import crowplexus.iris.IrisConfig;
import crowplexus.iris.ErrorSeverity;
import crowplexus.hscript.Expr.Error as IrisError;
import crowplexus.hscript.Printer;

typedef HScriptInfos = {
	> haxe.PosInfos,
	var ?funcName:String;
	var ?showLine:Null<Bool>;
	#if LUA_ALLOWED
	var ?isLua:Null<Bool>;
	#end
}

class HScript extends Iris {
	public var closed:Bool = false;
	public var filePath:String;
	public var modFolder:String;
	public var returnValue:Dynamic;
	public var parentState:FlxState = null;
	public var characterScriptName:String = null;
	public var characterScriptCharacter:objects.Character = null;
	
	public static var globalStatic(default, never):Map<String, Dynamic> = [];
	public static final SCRIPT_EXTENSIONS:Array<String> = ['.hx', '.hxc', '.hscript'];

	public static function hasScriptExtension(file:String):Bool
	{
		if(file == null)
			return false;

		file = file.toLowerCase();
		for(ext in SCRIPT_EXTENSIONS)
			if(file.endsWith(ext))
				return true;
		return false;
	}

	public static function withoutScriptExtension(file:String):String
	{
		if(file == null)
			return null;

		var lower:String = file.toLowerCase();
		for(ext in SCRIPT_EXTENSIONS)
			if(lower.endsWith(ext))
				return file.substr(0, file.length - ext.length);
		return file;
	}

	public static function withScriptExtensions(file:String):Array<String>
	{
		if(file == null)
			return [];

		var candidates:Array<String> = [];
		var addCandidate = function(path:String)
		{
			if(path != null && path.length > 0 && !candidates.contains(path))
				candidates.push(path);
		};

		addCandidate(file);
		var base:String = withoutScriptExtension(file);
		for(ext in SCRIPT_EXTENSIONS)
			addCandidate(base + ext);
		return candidates;
	}

	#if LUA_ALLOWED
	public var parentLua:FunkinLua;
	public static function initHaxeModule(parent:FunkinLua) {
		if (parent.hscript == null) {
			trace('INIT HAXE INTERP FOR: ${parent.scriptName}');
			parent.hscript = new HScript(parent, null, null, null, parent.parentState);
		}
	}

	public static function initHaxeModuleCode(parent:FunkinLua, code:String, ?varsToBring:Any = null) {
		var hs:HScript = try parent.hscript catch (e) null;
		if (hs == null) {
			trace('initializing haxe interp for: ${parent.scriptName}');
			try {
				parent.hscript = new HScript(parent, code, varsToBring, null, parent.parentState);
			} catch(e:Dynamic) {
				catchError(hs, e, parent.lastCalledFunction);
				parent.hscript = null;
			}
		}
		else
		{
			try {
				hs.scriptCode = code;
				hs.varsToBring = varsToBring;
				hs.parse(true);
				var ret:Dynamic = hs.execute();
				hs.returnValue = ret;
			} catch(e:Dynamic) {
				catchError(hs, e, parent.lastCalledFunction);
				parent.hscript = null;
			}
		}
	}
	#end
	
	public static function init():Void {
		Iris.proxyImports.set('options.GameplayChangersSubstate', options.GameplayChangersSubState); // lol
		Iris.proxyImports.set('funkin.data.ClientPrefs', funkin.data.ClientPrefs);
		Iris.proxyImports.set('funkin.data.Conductor', funkin.data.Conductor);
		Iris.proxyImports.set('funkin.objects.BGSprite', funkin.objects.BGSprite);
		Iris.proxyImports.set('funkin.objects.SnowEmitter', funkin.objects.SnowEmitter);
		Iris.proxyImports.set('funkin.objects.shader.OverlayShader', funkin.objects.shader.OverlayShader);
		Iris.proxyImports.set('funkin.game.shaders.OverlayShader', funkin.objects.shader.OverlayShader);
		Iris.proxyImports.set('funkin.graphics.shaders.SserafimShader', shaders.SserafimShader);
		Iris.proxyImports.set('funkin.utils.AtlasUtil', backend.AtlasUtil);
		//Iris.proxyImports.set('funkin.graphics.FunkinSprite', funkin.graphics.FunkinSprite);
		#if flxanimate
		Iris.proxyImports.set('animate.internal.elements.FlxSpriteElement', animate.internal.elements.FlxSpriteElement);
		#end
		Iris.proxyImports.set('funkin.utils.CameraUtil', funkin.utils.CameraUtil);
		Iris.proxyImports.set('funkin.utils.CoolUtil', funkin.utils.CoolUtil);
		Iris.proxyImports.set('funkin.states.PlayState', states.PlayState);
		Iris.logLevel = (level:ErrorSeverity, x:Dynamic, ?pos:haxe.PosInfos) -> {
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null) newPos.showLine = true;
			var msgInfo:String = (newPos.funcName != null ? '(${newPos.funcName}) - ' : '')  + '${newPos.fileName}:';
			#if LUA_ALLOWED
			if (newPos.isLua == true) {
				msgInfo += 'HScript:';
				newPos.showLine = false;
			}
			#end
			if (newPos.showLine == true) {
				msgInfo += '${newPos.lineNumber}:';
			}
			
			Log.print('$msgInfo $x', errorSeverityToLog(level));
		}
	}
	
	static function errorSeverityToLog(level:ErrorSeverity):LogType {
		return switch (level) {
			case NONE: INFO;
			case WARN: WARN;
			case ERROR: ERROR;
			case FATAL: FATAL;
		}
	}
	
	public var origin:String;
	public var unsafe:Bool = false;
	override public function new(?parent:Dynamic, ?file:String, ?varsToBring:Any = null, ?manualRun:Bool = false, ?state:FlxState) {
		parentState = state ?? FlxG.state;
		
		if (file == null)
			file = '';

		filePath = file;
		if (filePath != null && filePath.length > 0)
		{
			this.origin = filePath;
			#if ADDONS_ALLOWED
			this.modFolder = Mods.getModFolderFromPath(filePath);
			#end
		}
		var scriptThing:String = file;
		var scriptName:String = null;
		if(parent == null && file != null)
		{
			var f:String = file.replace('\\', '/');
			if(f.contains('/') && !f.contains('\n')) {
				scriptThing = Paths.getTextFromFile(f);
				scriptThing = normalizeCompatScript(scriptThing);
				scriptName = f;
			}
		}
		#if LUA_ALLOWED
		if (scriptName == null && parent != null)
			scriptName = parent.scriptName;
		#end
		
		super(scriptThing, new IrisConfig(scriptName, false, false));
		if(scriptName != null && scriptName.length > 0)
			Iris.instances.set(scriptName, this); // idgaf
		var customInterp:CustomInterp = new CustomInterp();
		customInterp.parentInstance = getParent();
		customInterp.showPosOnLog = false;
		this.interp = customInterp;
		#if LUA_ALLOWED
		parentLua = parent;
		if (parent != null)
		{
			this.origin = parent.scriptName;
			this.modFolder = parent.modFolder;
		}
		#end
		preset();
		this.varsToBring = varsToBring;
		if (!manualRun) {
			try {
				var ret:Dynamic = execute();
				returnValue = ret;
			} catch(e:Dynamic) {
				returnValue = null;
				this.destroy();
				throw e;
			}
		}
	}
	
	public static function initFromFile(file:String, ?parent:FlxState, ?base:Class<HScript>) {
		var newScript:HScript = null;
		
		try {
			trace('LOADING HX: $file');
			
			newScript = Type.createInstance(base ?? HScript, [null, file, null, true, parent]);
			newScript.unsafe = true;
			newScript.execute();
			
			newScript.callInitialCallbacks();
			
			newScript.unsafe = false;
		} catch(e:Dynamic) {
			var script:HScript = cast (Iris.instances.get(file), HScript);
			if (Std.isOfType(e, IrisError)) {
				var pos:HScriptInfos = cast {showLine: true, isLua: false, fileName: e.origin, lineNumber: e.line};
				Iris.fatal(Printer.errorToString(e, false), pos);
			} else {
				var pos:HScriptInfos = @:privateAccess { cast script.interp.posInfos(); }
				Iris.fatal(Std.string(e), pos);
			}
			
			script?.destroy();
			newScript = null;
		}
		
		return newScript;
	}

	public static function initFromFileWithVars(file:String, ?parent:FlxState, ?varsToBring:Any = null, ?base:Class<HScript>, ?onCreateInstance:HScript->Void) {
		var newScript:HScript = null;

		try {
			trace('LOADING HX: $file');

			newScript = Type.createInstance(base ?? HScript, [null, file, varsToBring, true, parent]);
			if(onCreateInstance != null)
				onCreateInstance(newScript);
			newScript.unsafe = true;
			newScript.execute();

			newScript.callInitialCallbacks();

			newScript.unsafe = false;
		} catch(e:Dynamic) {
			var script:HScript = cast (Iris.instances.get(file), HScript);
			if (Std.isOfType(e, IrisError)) {
				var pos:HScriptInfos = cast {showLine: true, isLua: false, fileName: e.origin, lineNumber: e.line};
				Iris.fatal(Printer.errorToString(e, false), pos);
			} else if(script != null) {
				var pos:HScriptInfos = @:privateAccess { cast script.interp.posInfos(); }
				Iris.fatal(Std.string(e), pos);
			} else {
				Iris.fatal(Std.string(e), Iris.getDefaultPos(file));
			}

			script?.destroy();
			newScript = null;
		}

		return newScript;
	}

	var varsToBring(default, set):Any = null;
	override function preset() {
		super.preset();
		
		for (define => value in backend.macro.Scripting.Defines.list)
			parser.preprocesorValues.set(define, value);

		if(backend.DeveloperMode.mobileSimulation)
		{
			parser.preprocesorValues.set('mobile', true);
			parser.preprocesorValues.set('TOUCH_CONTROLS_ALLOWED', true);
			parser.preprocesorValues.set('desktop', false);
			parser.preprocesorValues.set('windows', false);
			parser.preprocesorValues.set('linux', false);
			parser.preprocesorValues.set('mac', false);
			parser.preprocesorValues.set('html5', false);
		}
		
		// Some very commonly used classes
		set('Type', Type);
		#if sys
		set('File', File);
		set('FileSystem', FileSystem);
		#end
		set('FlxG', flixel.FlxG);
		set('FlxMath', flixel.math.FlxMath);
		set('FlxSprite', flixel.FlxSprite);
		set('PerspectiveSprite', objects.PerspectiveSprite);
		set('FlxBackdrop', flixel.addons.display.FlxBackdrop);
		set('FlxAxes', {
			X: flixel.util.FlxAxes.X,
			Y: flixel.util.FlxAxes.Y,
			XY: flixel.util.FlxAxes.XY,
			NONE: flixel.util.FlxAxes.NONE
		});
		set('FlxText', flixel.text.FlxText);
		set('FlxCamera', flixel.FlxCamera);
		set('FlxTypedGroup', flixel.group.FlxGroup.FlxTypedGroup);
		set('FlxSpriteGroup', flixel.group.FlxSpriteGroup);
		set('FlxBar', flixel.ui.FlxBar);
		set('PsychCamera', backend.PsychCamera);
		set('FlxTimer', flixel.util.FlxTimer);
		set('FlxTween', flixel.tweens.FlxTween);
		set('FlxEase', flixel.tweens.FlxEase);
		set('FlxColor', CustomFlxColor);
		set('Countdown', backend.BaseStage.Countdown);
		set('PlayState', PlayState);
		set('Paths', Paths);
		set('GameOverSubstate', substates.GameOverSubstate);
		set('gameOver', substates.GameOverSubstate.instance);
		set('gameOverCharacter', substates.GameOverSubstate.characterName);
		set('gameOverMusicCharacter', substates.GameOverSubstate.musicCharacterName);
		set('gameOverMusic', function(kind:String = 'loop', track:String = 'music') {
			substates.GameOverSubstate.setGameOverMusic(kind, track);
		});
		set('PauseSubState', substates.PauseSubState);
		set('pauseSubstate', substates.PauseSubState.instance);
		set('pauseMusicName', substates.PauseSubState.pauseMusicName);
		set('pauseMusicTrack', substates.PauseSubState.pauseTrackName);
		set('pauseMusicCharacter', substates.PauseSubState.musicCharacterName);
		set('pauseMusic', function(name:String = null, track:String = 'music') {
			substates.PauseSubState.setPauseMusic(name, track);
		});
		set('menuMusic', function(menuName:String = 'mainMenu', track:String = 'music') {
			return Paths.menuMusic(menuName, track);
		});
		set('precacheMenuMusic', function(menuName:String = 'mainMenu', track:String = 'music') {
			Paths.menuMusic(menuName, track);
		});
		set('playMenuMusic', function(menuName:String = 'mainMenu', volume:Float = 1, loop:Bool = false, track:String = 'music') {
			FlxG.sound.playMusic(Paths.menuMusic(menuName, track), volume, loop);
		});
		set('VignetteUtil', backend.VignetteUtil);
		set('VVIESpriteHandler', objects.VVIESpriteHandler);
		set('OverlayShader', shaders.OverlayShader);
		set('SserafimShader', shaders.SserafimShader);
		set('GradientUtil', backend.GradientUtil);
		set('AtlasUtil', backend.AtlasUtil);
		set('DialoguePlus', cutscenes.DialoguePlus);
		set('DialoguePlusRuntime', cutscenes.DialoguePlusRuntime);
		set('ResolutionManager', backend.ResolutionManager);
		set('DeveloperMode', backend.DeveloperMode);
		set('milymc', {});
		set('Conductor', Conductor);
		set('ClientPrefs', funkin.data.ClientPrefs);
		set('CustomCursor', backend.CustomCursor);
		set('script_COVERSTARTOffsets', [
			{x: 0.0, y: 0.0},
			{x: 0.0, y: 0.0},
			{x: 0.0, y: 0.0},
			{x: 0.0, y: 0.0}
		]);
		#if ACHIEVEMENTS_ALLOWED
		set('Achievements', Achievements);
		#end
		#if LUA_ALLOWED
		set('FunkinLua', FunkinLua);
		#end
		set('Character', objects.Character);
		set('Alphabet', Alphabet);
		set('Note', objects.Note);
		set('CustomState', CustomState);
		set('CustomSubstate', CustomSubstate);
		set('MusicBeatState', MusicBeatState);
		set('MusicBeatSubstate', MusicBeatSubstate);
		#if (!flash && sys)
		set('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
		set('ErrorHandledRuntimeShader', shaders.ErrorHandledShader.ErrorHandledRuntimeShader);
		set('CodenameRuntimeShader', shaders.CodenameRuntimeShader);
		set('CustomShader', shaders.CustomShader);
		set('addCameraShader', function(camera:FlxCamera, shader:flixel.addons.display.FlxRuntimeShader) {
			if(camera == null || shader == null) return false;
			if(Std.isOfType(shader, shaders.CodenameRuntimeShader))
				shaders.CodenameRuntimeShader.applyCameraUniforms(shader, camera);
			if(camera.filters == null) camera.filters = [];
			camera.filters.push(new openfl.filters.ShaderFilter(shader));
			shaders.ShaderResizeFix.fixCamera(camera);
			return true;
		});
		set('removeCameraShader', function(camera:FlxCamera, shader:flixel.addons.display.FlxRuntimeShader = null) {
			if(camera == null) return false;
			if(shader == null) camera.filters = [];
			else if(camera.filters != null)
				camera.filters = camera.filters.filter(function(filter) {
					return !(Std.isOfType(filter, openfl.filters.ShaderFilter) && cast(filter, openfl.filters.ShaderFilter).shader == shader);
				});
			shaders.ShaderResizeFix.fixCamera(camera);
			return true;
		});
		set('addWindowShader', function(shader:flixel.addons.display.FlxRuntimeShader) {
			if(shader == null) return false;
			if(Std.isOfType(shader, shaders.CodenameRuntimeShader))
				shaders.CodenameRuntimeShader.applyScreenUniforms(shader);
			var filters = Lib.current.filters;
			filters.push(new openfl.filters.ShaderFilter(shader));
			Lib.current.filters = filters;
			shaders.ShaderResizeFix.fixSprite(Lib.current);
			return true;
		});
		set('removeWindowShader', function(shader:flixel.addons.display.FlxRuntimeShader = null) {
			if(shader == null) Lib.current.filters = [];
			else if(Lib.current.filters != null)
				Lib.current.filters = Lib.current.filters.filter(function(filter) {
					return !(Std.isOfType(filter, openfl.filters.ShaderFilter) && cast(filter, openfl.filters.ShaderFilter).shader == shader);
				});
			shaders.ShaderResizeFix.fixSprite(Lib.current);
			return true;
		});
		#end
		set('ShaderFilter', openfl.filters.ShaderFilter);
		set('BlurFilter', openfl.filters.BlurFilter);
		set('BitmapFilterQuality', {
			LOW: openfl.filters.BitmapFilterQuality.LOW,
			MEDIUM: openfl.filters.BitmapFilterQuality.MEDIUM,
			HIGH: openfl.filters.BitmapFilterQuality.HIGH
		});
		set('StringTools', StringTools);
		#if flxanimate
		set('FlxAnimate', FlxAnimate);
		set('FlxSpriteElement', animate.internal.elements.FlxSpriteElement);
		#end
		set('controls', Controls.instance);
		
		if (parentState != null && !(parentState is ScriptedSubState))
			set(ScriptedSubState.getStateName(parentState), Type.getClass(parentState));

		// Functions & Variables
		var variableMap:Map<String, Dynamic> = getVariables();
		
		if (parentState != null) {
			var cls = Type.getClass(parentState);
			var clsName:String = Type.getClassName(cls);
			var stateName:String = clsName.substr(clsName.indexOf('.') + 1);
			
			set('game', parentState);
			set('stage', parentState);
			set(stateName, cls);
		}

		if(PlayState.instance != null) {
			set('camGame', PlayState.instance.camGame);
			set('camHUD', PlayState.instance.camHUD);
			set('camOther', PlayState.instance.camOther);
			set('camPause', PlayState.instance.camOther);
		}
		
		set('global', variableMap);
		set('globalStatic', HScript.globalStatic);
		set('refreshZ', function(?target:Dynamic = null) {
			return refreshZTarget(target, parentState);
		});
		set('startDialoguePlus', function(dialogueFile:String = 'dialogue', ?music:String = null) {
			return PlayState.instance != null ? PlayState.instance.startDialoguePlus(dialogueFile, music) : false;
		});
		set('startXmlDialogue', function(dialogueFile:String = 'dialogue', ?music:String = null) {
			if(PlayState.instance == null)
				return false;

			var found = cutscenes.DialoguePlus.findDialogueFile(dialogueFile, ['xml']);
			if(found == null)
				return false;

			var parsed = cutscenes.DialoguePlus.parseXmlDialogue(found.path);
			if(!cutscenes.DialoguePlus.isValidDialogue(parsed))
				return false;

			PlayState.instance.startDialogue(parsed, music, true);
			return true;
		});
		set('startPsychDialogue', function(dialogueFile:String = 'dialogue', ?music:String = null) {
			if(PlayState.instance == null)
				return false;

			var found = cutscenes.DialoguePlus.findDialogueFile(dialogueFile, ['json']);
			if(found == null)
				return false;

			var parsed = cutscenes.DialogueBoxPsych.parseDialogue(found.path);
			if(!cutscenes.DialoguePlus.isValidDialogue(parsed))
				return false;

			PlayState.instance.startDialogue(parsed, music);
			return true;
		});
		set('finishDialoguePlus', function(callFinish:Bool = true) {
			if(PlayState.instance == null)
				return false;
			PlayState.instance.finishDialoguePlusCutscene(callFinish);
			return true;
		});
		set('addCamera', function(tag:String, bgColor:String = '00000000', x:Float = 0, y:Float = 0, width:Int = -1, height:Int = -1, zoom:Float = 1, front:Bool = false) {
			return PlayState.instance != null ? PlayState.instance.addCamera(tag, bgColor, x, y, width, height, zoom, front) : null;
		});
		set('removeCamera', function(tag:String, destroy:Bool = true) {
			return PlayState.instance != null && PlayState.instance.removeCamera(tag, destroy);
		});
		set('setMainCamera', function(tag:String) {
			return PlayState.instance != null && PlayState.instance.setMainCamera(tag);
		});
		set('setCameraOrder', function(tag:String, index:Int) {
			return PlayState.instance != null && PlayState.instance.setCameraOrder(tag, index);
		});
		set('setCameraAngle', function(camera:String, angle:Float) {
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if(cam != null)
				cam.angle = angle;
			return angle;
		});
		set('addCameraAngle', function(camera:String, angle:Float) {
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if(cam != null)
				cam.angle += angle;
			return cam != null ? cam.angle : 0;
		});
		set('getCameraAngle', function(camera:String) {
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			return cam != null ? cam.angle : 0;
		});
		set('setCameraRotateSprite', function(camera:String, rotateSprite:Bool = false) {
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if(Std.isOfType(cam, backend.PsychCamera))
			{
				cast(cam, backend.PsychCamera).rotateSprite = rotateSprite;
				return true;
			}
			return false;
		});
		set('changeRes', function(width:Int, height:Int, resizable:Bool = true) return backend.ResolutionManager.changeRes(width, height, resizable));
		set('ChangeRes', function(width:Int, height:Int, resizable:Bool = true) return backend.ResolutionManager.changeRes(width, height, resizable));
		set('resetRes', function() return backend.ResolutionManager.reset());
		set('ResetRes', function() return backend.ResolutionManager.reset());
		set('tweenRes', function(width:Int, height:Int, duration:Float = 1, ease:String = 'linear', resizable:Bool = true)
			return backend.ResolutionManager.tweenRes(width, height, duration, LuaUtils.getTweenEaseByString(ease), resizable));
		set('TweenRes', function(width:Int, height:Int, duration:Float = 1, ease:String = 'linear', resizable:Bool = true)
			return backend.ResolutionManager.tweenRes(width, height, duration, LuaUtils.getTweenEaseByString(ease), resizable));
		set('tweenResFrom', function(fromWidth:Int, fromHeight:Int, toWidth:Int, toHeight:Int, duration:Float = 1, ease:String = 'linear', resizable:Bool = true)
			return backend.ResolutionManager.tweenResFrom(fromWidth, fromHeight, toWidth, toHeight, duration, LuaUtils.getTweenEaseByString(ease), resizable));
		set('cancelTweenRes', function() backend.ResolutionManager.cancelTweenRes());
		set('preloadVideo', function(name:String) return LoadingState.preloadVideo(name) != null);
		set('precacheVideo', function(name:String) return LoadingState.preloadVideo(name) != null);
		set('getSongPosition', function() return Conductor.songPosition);
		set('setSongTime', function(time:Float, offset:Bool = true, clearPastNotes:Bool = true) {
			if(PlayState.instance == null)
				return false;
			PlayState.instance.setSongTime(time, offset);
			if(clearPastNotes)
				PlayState.instance.clearNotesBefore(Conductor.songPosition);
			return true;
		});
		set('createChar', function(name:String, x:Float = 0, y:Float = 0, noteType:String = '', isPlayer:Bool = false, offsetSide:String = null) {
			return PlayState.instance != null ? PlayState.instance.createChar(name, x, y, noteType, isPlayer, offsetSide) : null;
		});
		set('createCharacter', function(name:String, x:Float = 0, y:Float = 0, noteType:String = '', isPlayer:Bool = false, offsetSide:String = null) {
			return PlayState.instance != null ? PlayState.instance.createChar(name, x, y, noteType, isPlayer, offsetSide) : null;
		});
		set('getCharacterTag', function(name:String) {
			return PlayState.instance != null ? PlayState.instance.getExtraCharacterTag(name) : null;
		});
		set('getCharacterX', function(type:String) {
			if(PlayState.instance == null) return 0.0;
			var group = PlayState.instance.getCharacterGroupByName(type);
			return group != null ? group.x : 0.0;
		});
		set('getCharacterY', function(type:String) {
			if(PlayState.instance == null) return 0.0;
			var group = PlayState.instance.getCharacterGroupByName(type);
			return group != null ? group.y : 0.0;
		});
		set('setCharacterX', function(type:String, value:Float) {
			if(PlayState.instance == null) return;
			var group = PlayState.instance.getCharacterGroupByName(type);
			if(group != null) group.x = value;
		});
		set('setCharacterY', function(type:String, value:Float) {
			if(PlayState.instance == null) return;
			var group = PlayState.instance.getCharacterGroupByName(type);
			if(group != null) group.y = value;
		});
		set('cameraSetTarget', function(target:String) {
			PlayState.instance?.changeFocus(target);
		});
		set('changeFocus', function(target:String, x:Float = 0, y:Float = 0, ease:String = 'classic', steps:Float = 0) {
			PlayState.instance?.changeFocus(target, x, y, ease, steps);
		});
		set('ChangeFocus', function(target:String, x:Float = 0, y:Float = 0, ease:String = 'classic', steps:Float = 0) {
			PlayState.instance?.changeFocus(target, x, y, ease, steps);
		});
		set('cameraZoom', function(zoom:Float, steps:Float = 0, ease:String = 'classic', type:String = 'nll') {
			return PlayState.instance != null ? PlayState.instance.applyCameraZoom(zoom, steps, ease, type) : 0.0;
		});
		set('CameraZoom', function(zoom:Float, steps:Float = 0, ease:String = 'classic', type:String = 'nll') {
			return PlayState.instance != null ? PlayState.instance.applyCameraZoom(zoom, steps, ease, type) : 0.0;
		});
		set('cameraZoomEvent', function(value1:String = '', value2:String = '') {
			return PlayState.instance != null ? PlayState.instance.applyCameraZoomEvent(value1, value2) : 0.0;
		});
		set('changeIcon', function(icon:String, side:Int = 0) {
			return PlayState.instance != null && PlayState.instance.changeHealthIcon(icon, side);
		});
		set('ChangeIcon', function(icon:String, side:Int = 0) {
			return PlayState.instance != null && PlayState.instance.changeHealthIcon(icon, side);
		});
		set('setIconFrame', function(side:Int = 0, frame:Int = 0) {
			return PlayState.instance != null && PlayState.instance.setIconFrame(side, frame);
		});
		set('addIcon', function(frame:Int = 0, ?side:Null<Int> = null) {
			if(PlayState.instance == null) return false;
			if(side == null)
				return PlayState.instance.setIconFrame(0, frame) && PlayState.instance.setIconFrame(1, frame);
			return PlayState.instance.setIconFrame(side, frame);
		});
		set('AddIcon', function(frame:Int = 0, ?side:Null<Int> = null) {
			if(PlayState.instance == null) return false;
			if(side == null)
				return PlayState.instance.setIconFrame(0, frame) && PlayState.instance.setIconFrame(1, frame);
			return PlayState.instance.setIconFrame(side, frame);
		});
		var scriptVariables = function():Map<String, Dynamic> {
			var vars:Map<String, Dynamic> = variableMap;
			if(vars == null && FlxG.state != null)
				vars = FlxG.state.extraData;
			return vars;
		};
		var targetInstance = function():Dynamic {
			return CustomSubstate.instance != null ? CustomSubstate.instance : LuaUtils.getTargetInstance();
		};
		var getObject = function(name:String):Dynamic {
			if(name == null)
				return null;
			return LuaUtils.getObjectDirectly(name);
		};
		var getOrderContainer = function(?group:String = null):Dynamic {
			if(group != null)
				return getObject(group);
			return targetInstance();
		};
		var getOrderMembers = function(container:Dynamic):Array<Dynamic> {
			if(container == null)
				return null;
			if(Type.typeof(container).match(TClass(Array)))
				return cast container;

			var members:Dynamic = Reflect.getProperty(container, 'members');
			return members != null ? cast members : null;
		};
		var findOrderContainerFor:Dynamic = null;
		findOrderContainerFor = function(object:FlxBasic, root:Dynamic, depth:Int = 0):Dynamic {
			if(object == null || root == null || depth > 16)
				return null;

			var members:Array<Dynamic> = getOrderMembers(root);
			if(members == null)
				return null;
			if(members.indexOf(object) >= 0)
				return root;

			for(member in members)
			{
				if(member == null || member == root || member == object)
					continue;

				var found:Dynamic = findOrderContainerFor(object, member, depth + 1);
				if(found != null)
					return found;
			}
			return null;
		};
		var removeFromOrderContainer = function(container:Dynamic, object:FlxBasic):Void {
			if(container == null || object == null)
				return;

			if(Type.typeof(container).match(TClass(Array)))
				container.remove(object);
			else if(Reflect.isFunction(Reflect.field(container, 'remove')))
				container.remove(object, true);
			else
				getOrderMembers(container)?.remove(object);
		};
		var insertIntoOrderContainer = function(container:Dynamic, index:Int, object:FlxBasic):Void {
			if(container == null || object == null)
				return;

			var members:Array<Dynamic> = getOrderMembers(container);
			if(members == null)
				return;

			if(index < 0) index = 0;
			if(index > members.length) index = members.length;
			if(Reflect.isFunction(Reflect.field(container, 'insert')))
				container.insert(index, object);
			else
				members.insert(index, object);
		};
		var moveObjectRelative = function(obj:String, target:String, behind:Bool = true, ?group:String = null):Bool {
			var leObj:FlxBasic = cast getObject(obj);
			var targetObj:FlxBasic = cast getObject(target);
			var root:Dynamic = getOrderContainer(group);

			if(leObj == null || targetObj == null || root == null)
				return false;

			var targetContainer:Dynamic = group != null ? root : findOrderContainerFor(targetObj, root);
			var sourceContainer:Dynamic = group != null ? root : findOrderContainerFor(leObj, root);
			if(targetContainer == null)
				return false;

			var members:Array<Dynamic> = getOrderMembers(targetContainer);
			if(members == null)
				return false;

			var targetIndex:Int = members.indexOf(targetObj);
			if(targetIndex < 0)
				return false;

			var oldIndex:Int = (sourceContainer == targetContainer) ? members.indexOf(leObj) : -1;
			if(oldIndex >= 0 && oldIndex < targetIndex)
				targetIndex--;

			if(sourceContainer != null)
				removeFromOrderContainer(sourceContainer, leObj);

			insertIntoOrderContainer(targetContainer, behind ? targetIndex : targetIndex + 1, leObj);
			return true;
		};
		var makeLuaSprite = function(tag:String, image:String = null, x:Float = 0, y:Float = 0) {
			if(tag == null)
				return null;
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var spr:ModchartSprite = new ModchartSprite(x, y);
			if(image != null && image.length > 0)
				spr.loadGraphic(Paths.image(image));
			scriptVariables()?.set(tag, spr);
			spr.active = true;
			return spr;
		};
		var makeAnimatedLuaSprite = function(tag:String, image:String = null, x:Float = 0, y:Float = 0, spriteType:String = 'auto') {
			if(tag == null)
				return null;
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var spr:ModchartSprite = new ModchartSprite(x, y);
			if(image != null && image.length > 0)
				LuaUtils.loadFrames(spr, image, spriteType);
			scriptVariables()?.set(tag, spr);
			spr.active = true;
			return spr;
		};
		var makePerspectiveSprite = function(tag:String, image:String = null, bottomX:Float = 0, bottomY:Float = 0, topX:Float = 0, topY:Float = 0) {
			if(tag == null)
				return null;
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var spr:objects.PerspectiveSprite = new objects.PerspectiveSprite();
			if(image != null && image.length > 0)
				spr.loadGraphic(Paths.image(image));
			spr.setPositions(bottomX, bottomY, topX, topY);
			scriptVariables()?.set(tag, spr);
			spr.active = true;
			return spr;
		};
		var getPerspectiveSprite = function(objName:String):objects.PerspectiveSprite {
			var obj:Dynamic = getObject(objName);
			return Std.isOfType(obj, objects.PerspectiveSprite) ? cast obj : null;
		};
		var addInstance = function(objectName:String, inFront:Bool = false) {
			var obj:Dynamic = getObject(objectName);
			var instance:Dynamic = targetInstance();
			if(obj == null || instance == null || instance.add == null)
				return false;

			if(inFront)
			{
				instance.add(obj);
				return true;
			}

			var gameover = substates.GameOverSubstate.instance;
			var addToGameover:Bool = ((instance == PlayState.instance && PlayState.instance.isDead) || instance == gameover);
			if(instance != PlayState.instance || addToGameover)
			{
				if(addToGameover && gameover != null)
					gameover.insert(gameover.members.indexOf(gameover.boyfriend), obj);
				else
					instance.insert(0, obj);
			}
			else
			{
				var pos:Int = instance.members.indexOf(LuaUtils.getLowestCharacterGroup());
				if(pos < 0) pos = 0;
				instance.insert(pos, obj);
			}
			return true;
		};
		var addAnimByPrefix = function(objName:String, name:String, prefix:String, framerate:Float = 24, loop:Bool = true) {
			var obj:Dynamic = getObject(objName);
			if(obj == null)
				return false;

			if(obj.animation != null)
			{
				obj.animation.addByPrefix(name, prefix, framerate, loop);
				if(obj.animation.curAnim == null)
				{
					if(obj.playAnim != null) obj.playAnim(name, true);
					else obj.animation.play(name, true);
				}
				return true;
			}
			if(obj.anim != null)
			{
				obj.anim.addByPrefix(name, prefix, framerate, loop);
				if(obj.hasActiveAtlasAnimation == null || !obj.hasActiveAtlasAnimation())
				{
					if(obj.playAnim != null) obj.playAnim(name, true);
					else obj.anim.play(name, true);
				}
				return true;
			}
			return false;
		};
		var getShaderObject = function(name:String):FlxShader {
			var obj:Dynamic = getObject(name);
			if(Std.isOfType(obj, FlxShader))
				return cast obj;
			if(Std.isOfType(obj, FlxSprite))
			{
				var spr:FlxSprite = cast obj;
				if(spr.shader != null && Std.isOfType(spr.shader, FlxShader))
					return cast spr.shader;
			}
			#if flxanimate
			var atlas:Dynamic = backend.AtlasUtil.getAtlas(obj);
			if(atlas != null)
			{
				var shader:Dynamic = Reflect.getProperty(atlas, 'shader');
				if(Std.isOfType(shader, FlxShader))
					return cast shader;
			}
			#end
			return null;
		};
		set('getObject', getObject);
		set('getObjectDirectly', getObject);
		#if flxanimate
		var getAtlasFallbackTarget = function():Dynamic {
			return characterScriptCharacter;
		};
		var getAtlasObjectArgument = function(value:Dynamic):Dynamic {
			if(value == null)
				return null;
			if(Std.isOfType(value, String))
				return getObject(Std.string(value));
			return value;
		};
		var getAtlasTarget = function(objName:Dynamic):Dynamic {
			if(objName == null || (Std.isOfType(objName, String) && Std.string(objName).length < 1))
				return getAtlasFallbackTarget();
			var obj:Dynamic = getAtlasObjectArgument(objName);
			return obj != null ? obj : getAtlasFallbackTarget();
		};
		var atlasArgIsObject = function(objName:Dynamic):Bool {
			return getAtlasObjectArgument(objName) != null;
		};
		set('getAtlasDefaultSymbol', function(objName:Dynamic = null) return backend.AtlasUtil.getDefaultSymbol(getAtlasTarget(objName)));
		set('getAtlasSymbols', function(objName:Dynamic = null) return backend.AtlasUtil.listSymbols(getAtlasTarget(objName)));
		set('listAtlasSymbols', function(objName:Dynamic = null) return backend.AtlasUtil.listSymbols(getAtlasTarget(objName)));
		var addAtlasSpriteElementFunc = function(atlasOrSpriteName:Dynamic, spriteOrKeyword:Dynamic, keyword:String = null, insertIndex:Int = -1, symbolKeyword:String = null, exact:Bool = false, elementActive:Bool = true) {
			var explicitTarget:Bool = atlasArgIsObject(atlasOrSpriteName) && keyword != null;
			var atlasTarget:Dynamic = explicitTarget ? getAtlasObjectArgument(atlasOrSpriteName) : getAtlasFallbackTarget();
			var sprite:Dynamic = explicitTarget ? getAtlasObjectArgument(spriteOrKeyword) : getAtlasObjectArgument(atlasOrSpriteName);
			var frameKeyword:String = explicitTarget ? keyword : Std.string(spriteOrKeyword);
			return backend.AtlasUtil.addSpriteElement(atlasTarget, sprite, frameKeyword, insertIndex, symbolKeyword, exact, elementActive);
		};
		set('addAtlasSpriteElement', addAtlasSpriteElementFunc);
		set('addSpriteToAtlasFrames', addAtlasSpriteElementFunc);
		set('addAtlasSpriteToFrames', addAtlasSpriteElementFunc);
		var setAtlasLayerVisibleFunc = function(objOrLayer:Dynamic, layerKeyword:String = null, visible:Bool = true, symbolKeyword:String = null, exact:Bool = false) {
			var explicitTarget:Bool = atlasArgIsObject(objOrLayer) && layerKeyword != null;
			var target:Dynamic = explicitTarget ? getAtlasObjectArgument(objOrLayer) : getAtlasFallbackTarget();
			var layer:String = explicitTarget ? layerKeyword : Std.string(objOrLayer);
			var symbol:String = explicitTarget ? symbolKeyword : layerKeyword;
			return backend.AtlasUtil.setLayerVisible(target, layer, visible, symbol, exact);
		};
		set('setAtlasLayerVisible', setAtlasLayerVisibleFunc);
		set('setAtlasLayersVisible', setAtlasLayerVisibleFunc);
		set('hideAtlasLayer', function(objOrLayer:Dynamic, layerKeyword:String = null, symbolKeyword:String = null, exact:Bool = false) {
			var explicitTarget:Bool = atlasArgIsObject(objOrLayer) && layerKeyword != null;
			return explicitTarget ? setAtlasLayerVisibleFunc(objOrLayer, layerKeyword, false, symbolKeyword, exact) : setAtlasLayerVisibleFunc(objOrLayer, null, false, layerKeyword, exact);
		});
		set('showAtlasLayer', function(objOrLayer:Dynamic, layerKeyword:String = null, symbolKeyword:String = null, exact:Bool = false) {
			var explicitTarget:Bool = atlasArgIsObject(objOrLayer) && layerKeyword != null;
			return explicitTarget ? setAtlasLayerVisibleFunc(objOrLayer, layerKeyword, true, symbolKeyword, exact) : setAtlasLayerVisibleFunc(objOrLayer, null, true, layerKeyword, exact);
		});
		var setAtlasElementVisibleFunc = function(objOrKeyword:Dynamic, keyword:String = null, visible:Bool = true, exact:Bool = false) {
			var explicitTarget:Bool = atlasArgIsObject(objOrKeyword) && keyword != null;
			var target:Dynamic = explicitTarget ? getAtlasObjectArgument(objOrKeyword) : getAtlasFallbackTarget();
			var elementKeyword:String = explicitTarget ? keyword : Std.string(objOrKeyword);
			return backend.AtlasUtil.setElementVisible(target, elementKeyword, visible, exact);
		};
		set('setAtlasElementVisible', setAtlasElementVisibleFunc);
		set('setAtlasElementsVisible', setAtlasElementVisibleFunc);
		set('hideAtlasElement', function(objOrKeyword:Dynamic, keyword:String = null, exact:Bool = false)
			return setAtlasElementVisibleFunc(objOrKeyword, keyword, false, exact));
		set('showAtlasElement', function(objOrKeyword:Dynamic, keyword:String = null, exact:Bool = false)
			return setAtlasElementVisibleFunc(objOrKeyword, keyword, true, exact));
		set('syncAtlasFrameToSongPosition', function(objName:Dynamic = null, framerate:Float = 24, frameOffset:Int = -1)
			return backend.AtlasUtil.syncFrameToSongPosition(getAtlasTarget(objName), framerate, frameOffset));
		set('syncAtlasFrameToSong', function(objName:Dynamic = null, framerate:Float = 24, frameOffset:Int = -1)
			return backend.AtlasUtil.syncFrameToSongPosition(getAtlasTarget(objName), framerate, frameOffset));
		set('setAtlasFrame', function(objName:Dynamic = null, frame:Int = 0)
			return backend.AtlasUtil.setFrame(getAtlasTarget(objName), frame));
		set('setAtlasCurFrame', function(objName:Dynamic = null, frame:Int = 0)
			return backend.AtlasUtil.setFrame(getAtlasTarget(objName), frame));
		set('getAtlasFrame', function(objName:Dynamic = null)
			return backend.AtlasUtil.getFrame(getAtlasTarget(objName)));
		set('getAtlasCurFrame', function(objName:Dynamic = null)
			return backend.AtlasUtil.getFrame(getAtlasTarget(objName)));
		#end
		set('makeSserafimShader', function(tag:String, isCharacter:Bool = false) {
			if(tag == null) return null;
			tag = tag.replace('.', '');
			var shader = new shaders.SserafimShader(isCharacter);
			scriptVariables()?.set(tag, shader);
			return shader;
		});
		set('setObjectShaderObject', function(objName:String, shaderName:String)
			return backend.AtlasUtil.setShader(getObject(objName), getShaderObject(shaderName)));
		set('copyObjectShader', function(sourceName:String, targetName:String)
			return backend.AtlasUtil.copyShader(getObject(sourceName), getObject(targetName)));
		set('setSserafimShader', function(objName:String, shaderOrIsCharacter:Dynamic = false) {
			var shader:shaders.SserafimShader = null;
			if(Std.isOfType(shaderOrIsCharacter, String))
			{
				var existing = getShaderObject(Std.string(shaderOrIsCharacter));
				if(Std.isOfType(existing, shaders.SserafimShader))
					shader = cast existing;
			}
			else
				shader = new shaders.SserafimShader(shaderOrIsCharacter == true);
			return shader != null && backend.AtlasUtil.setShader(getObject(objName), shader);
		});
		set('getObjectOrder', function(obj:String, ?group:String = null) {
			var leObj:FlxBasic = cast getObject(obj);
			var root:Dynamic = getOrderContainer(group);
			var container:Dynamic = group != null ? root : findOrderContainerFor(leObj, root);
			var members:Array<Dynamic> = getOrderMembers(container);
			return members != null ? members.indexOf(leObj) : -1;
		});
		set('setObjectOrder', function(obj:String, position:Int, ?group:String = null) {
			var leObj:FlxBasic = cast getObject(obj);
			var root:Dynamic = getOrderContainer(group);
			var sourceContainer:Dynamic = group != null ? root : findOrderContainerFor(leObj, root);
			var targetContainer:Dynamic = sourceContainer ?? root;
			if(leObj == null || targetContainer == null)
				return false;

			if(sourceContainer != null)
				removeFromOrderContainer(sourceContainer, leObj);
			insertIntoOrderContainer(targetContainer, position, leObj);
			return true;
		});
		set('setObjectBehind', function(obj:String, target:String, ?group:String = null)
			return moveObjectRelative(obj, target, true, group));
		set('setObjectInFront', function(obj:String, target:String, ?group:String = null)
			return moveObjectRelative(obj, target, false, group));
		set('getProperty', function(variable:String, allowMaps:Bool = false)
			return LuaUtils.getPropertyLoop(variable, allowMaps, parentState ?? FlxG.state));
		set('setProperty', function(variable:String, value:Dynamic, allowMaps:Bool = false)
			return LuaUtils.setPropertyLoop(variable, value, allowMaps, parentState ?? FlxG.state));
		set('getPropertyFromClass', function(classVar:String, variable:String, allowMaps:Bool = false)
			return LuaUtils.getPropertyLoop(variable, allowMaps, Type.resolveClass(classVar)));
		set('setPropertyFromClass', function(classVar:String, variable:String, value:Dynamic, allowMaps:Bool = false)
			return LuaUtils.setPropertyLoop(variable, value, allowMaps, Type.resolveClass(classVar)));
		set('makeLuaSprite', makeLuaSprite);
		set('makeSprite', makeLuaSprite);
		set('createSprite', makeLuaSprite);
		set('makeAnimatedLuaSprite', makeAnimatedLuaSprite);
		set('makeAnimatedSprite', makeAnimatedLuaSprite);
		set('createAnimatedSprite', makeAnimatedLuaSprite);
		set('makePerspectiveSprite', makePerspectiveSprite);
		set('createPerspectiveSprite', makePerspectiveSprite);
		set('makeLuaPerspectiveSprite', makePerspectiveSprite);
		set('setPerspectivePositions', function(objName:String, bottomX:Float, bottomY:Float, topX:Float, topY:Float) {
			var spr = getPerspectiveSprite(objName);
			if(spr == null)
				return false;
			spr.setPositions(bottomX, bottomY, topX, topY);
			return true;
		});
		set('setPerspectiveWidths', function(objName:String, bottomWidth:Float, topWidth:Float) {
			var spr = getPerspectiveSprite(objName);
			if(spr == null)
				return false;
			spr.setWidths(bottomWidth, topWidth);
			return true;
		});
		set('setPerspectiveScrollFactors', function(objName:String, bottomX:Float, bottomY:Float, topX:Float, topY:Float) {
			var spr = getPerspectiveSprite(objName);
			if(spr == null)
				return false;
			spr.setScrollFactors(bottomX, bottomY, topX, topY);
			return true;
		});
		set('updatePerspectiveSprite', function(objName:String, camera:Dynamic = 'game') {
			var spr = getPerspectiveSprite(objName);
			if(spr == null)
				return false;
			var cam:FlxCamera = Std.isOfType(camera, FlxCamera) ? cast camera : LuaUtils.cameraFromString(Std.string(camera));
			spr.updateSkew(cam);
			return true;
		});
		set('updatePerspectiveSkew', function(objName:String, camera:Dynamic = 'game') {
			var spr = getPerspectiveSprite(objName);
			if(spr == null)
				return false;
			var cam:FlxCamera = Std.isOfType(camera, FlxCamera) ? cast camera : LuaUtils.cameraFromString(Std.string(camera));
			spr.updateSkew(cam);
			return true;
		});
		set('loadGraphic', function(variable:String, image:String, gridX:Int = 0, gridY:Int = 0) {
			var obj:Dynamic = getObject(variable);
			if(obj == null || image == null || image.length < 1)
				return false;
			obj.loadGraphic(Paths.image(image), (gridX != 0 || gridY != 0), gridX, gridY);
			return true;
		});
		set('loadFrames', function(variable:String, image:String, spriteType:String = 'auto') {
			var obj:FlxSprite = cast getObject(variable);
			if(obj == null || image == null || image.length < 1)
				return false;
			LuaUtils.loadFrames(obj, image, spriteType);
			return true;
		});
		set('setTileObject', TileFunctions.setTileObject);
		set('setTiledObject', TileFunctions.setTileObject);
		set('makeTileObject', TileFunctions.makeTileObject);
		set('makeTiledLuaSprite', TileFunctions.makeTileObject);
		set('makeAnimatedTileObject', TileFunctions.makeAnimatedTileObject);
		set('makeAnimatedTiledLuaSprite', TileFunctions.makeAnimatedTileObject);
		set('copyTileObject', TileFunctions.copyTileObject);
		set('setTileVelocity', TileFunctions.setTileVelocity);
		set('setTileMotion', TileFunctions.setTileMotion);
		set('setTileAxes', TileFunctions.setTileAxes);
		set('removeTileObject', TileFunctions.removeTileObject);
		set('addGridBackdrop', TileFunctions.addGridBackdrop);
		set('setBackdropVelocity', TileFunctions.setTileVelocity);
		set('removeBackdrop', TileFunctions.removeTileObject);
		set('makeGraphic', function(objName:String, width:Int = 256, height:Int = 256, color:String = 'FFFFFF') {
			var spr:FlxSprite = cast getObject(objName);
			if(spr == null)
				return false;
			spr.makeGraphic(width, height, CoolUtil.colorFromString(color));
			return true;
		});
		set('makeGradient', function(objName:String, width:Int = 256, height:Int = 256, colors:Dynamic = null, ?alphas:Dynamic = null, rotation:Int = 90,
			chunkSize:Int = 1, interpolate:Bool = true) {
			return backend.GradientUtil.applyToSprite(cast getObject(objName), width, height, colors, alphas, rotation, chunkSize, interpolate);
		});
		set('applyGradient', get('makeGradient'));
		var makeGradientSpriteFunc = function(tag:String, width:Int = 256, height:Int = 256, colors:Dynamic = null, ?alphas:Dynamic = null, ?x:Float = 0,
			?y:Float = 0, rotation:Int = 90, chunkSize:Int = 1, interpolate:Bool = true) {
			if(tag == null)
				return null;
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			backend.GradientUtil.applyToSprite(leSprite, width, height, colors, alphas, rotation, chunkSize, interpolate);
			variableMap?.set(tag, leSprite);
			leSprite.active = true;
			return leSprite;
		};
		set('makeLuaGradient', makeGradientSpriteFunc); // meio sacanagem mas ehh?
		set('makeGradientSprite', makeGradientSpriteFunc);
		set('createGradientSprite', makeGradientSpriteFunc);
		set('setGradientStop', function(objName:String, index:Int, ?color:Dynamic = null, ?alpha:Dynamic = null) {
			return backend.GradientUtil.setStop(cast getObject(objName), index, color, alpha);
		});
		var tweenGradientFunc = function(tag:String, objName:String, colors:Dynamic = null, ?alphas:Dynamic = null, duration:Float = 1, ?ease:String = 'linear') {
			var obj:FlxSprite = cast getObject(objName);
			if(obj == null)
				return null;

			var tweenTag:String = LuaUtils.formatVariable('tween_$tag');
			LuaUtils.cancelTween(tag);
			var tween:FlxTween = backend.GradientUtil.tweenSprite(obj, colors, alphas, duration, LuaUtils.getTweenEaseByString(ease), function(twn:FlxTween) {
				variableMap?.remove(tweenTag);
			});
			variableMap?.set(tweenTag, tween);
			return tween;
		};
		set('tweenGradient', tweenGradientFunc);
		set('doTweenGradient', tweenGradientFunc);
		var tweenGradientAlphaFunc = function(tag:String, objName:String, alphas:Dynamic = null, duration:Float = 1, ?ease:String = 'linear') {
			var obj:FlxSprite = cast getObject(objName);
			if(obj == null)
				return null;

			var tweenTag:String = LuaUtils.formatVariable('tween_$tag');
			LuaUtils.cancelTween(tag);
			var tween:FlxTween = backend.GradientUtil.tweenSpriteAlpha(obj, alphas, duration, LuaUtils.getTweenEaseByString(ease), function(twn:FlxTween) {
				variableMap?.remove(tweenTag);
			});
			variableMap?.set(tweenTag, tween);
			return tween;
		};
		set('tweenGradientAlpha', tweenGradientAlphaFunc);
		set('doTweenGradientAlpha', tweenGradientAlphaFunc);
		var makeVignetteFunc = function(objName:String, width:Int = 0, height:Int = 0, color:String = '000000', strength:Float = 1, radius:Float = 0.55, softness:Float = 0.45) {
			var spr:FlxSprite = cast getObject(objName);
			if(spr == null)
				return false;
			if(Std.isOfType(spr, objects.VVIESpriteHandler))
				cast(spr, objects.VVIESpriteHandler).makeVignette(width, height, CoolUtil.colorFromString(color), strength, radius, softness);
			else
				spr.loadGraphic(backend.VignetteUtil.makeGraphic(width, height, CoolUtil.colorFromString(color), strength, radius, softness));
			return true;
		};
		set('makeVignette', makeVignetteFunc);
		set('makeVig', makeVignetteFunc);
		set('getWindowWidth', function(pixels:Bool = false):Int return pixels ? backend.VignetteUtil.windowPixelWidth() : backend.VignetteUtil.windowWidth());
		set('getWindowHeight', function(pixels:Bool = false):Int return pixels ? backend.VignetteUtil.windowPixelHeight() : backend.VignetteUtil.windowHeight());
		set('getFullScreenX', function(camera:String = 'other'):Float return backend.CameraResizeFix.pegarFSX(LuaUtils.cameraFromString(camera)));
		set('getFullScreenY', function(camera:String = 'other'):Float return backend.CameraResizeFix.pegarFSY(LuaUtils.cameraFromString(camera)));
		set('getFullScreenWidth', function(camera:String = 'other'):Float return backend.CameraResizeFix.pegarFSL(LuaUtils.cameraFromString(camera)));
		set('getFullScreenHeight', function(camera:String = 'other'):Float return backend.CameraResizeFix.pegarFSA(LuaUtils.cameraFromString(camera)));
		set('addLuaSprite', addInstance);
		set('addInstance', addInstance);
		set('addSprite', addInstance);
		set('addObject', addInstance);
		set('addLuaAtlas', addInstance);
		set('addAtlas', addInstance);
		set('addLuaAtlasSprite', addInstance);
		var removeSpriteFunc = function(tag:String, destroy:Bool = true, group:String = null) {
			var obj:Dynamic = getObject(tag);
			if(obj == null || obj.destroy == null)
				return false;
			var groupObj:Dynamic = group == null ? null : getObject(group);
			if(groupObj != null && groupObj.remove != null)
				groupObj.remove(obj, true);
			else
				targetInstance()?.remove(obj, true);
			if(destroy)
			{
				scriptVariables()?.remove(tag);
				obj.destroy();
			}
			return true;
		};
		set('removeLuaSprite', removeSpriteFunc);
		set('removeSprite', removeSpriteFunc);
		set('removeObject', removeSpriteFunc);
		var spriteExistsFunc = function(tag:String) {
			var obj:Dynamic = scriptVariables()?.get(tag);
			return obj != null && (Std.isOfType(obj, ModchartSprite) #if flxanimate || Std.isOfType(obj, ModchartAnimateSprite) #end);
		};
		set('luaSpriteExists', spriteExistsFunc);
		set('spriteExists', spriteExistsFunc);
		set('objectExists', function(tag:String) return getObject(tag) != null);
		set('addAnimationByPrefix', addAnimByPrefix);
		set('addAnim', addAnimByPrefix);
		set('addAnimation', function(obj:String, name:String, frames:Any, framerate:Float = 24, loop:Bool = true)
			return LuaUtils.addAnimByIndices(obj, name, null, frames, framerate, loop));
		set('addAnimationByIndices', function(obj:String, name:String, prefix:String, indices:Any, framerate:Float = 24, loop:Bool = false)
			return LuaUtils.addAnimByIndices(obj, name, prefix, indices, framerate, loop));
		var playAnimFunction = function(objName:String, name:String, forced:Bool = false, reverse:Bool = false, startFrame:Int = 0) {
			var obj:Dynamic = getObject(objName);
			if(obj == null)
				return false;
			if(Std.isOfType(obj, objects.Character) && name != null && name.startsWith('sing') && LuaUtils.currentCallbackIsSustainNote())
				return cast(obj, objects.Character).playSingAnimation(name, true);
			if(obj.playAnim != null) obj.playAnim(name, forced, reverse, startFrame);
			else if(obj.anim != null) obj.anim.play(name, forced, reverse, startFrame);
			else obj.animation.play(name, forced, reverse, startFrame);
			return true;
		};
		set('playAnim', playAnimFunction);
		set('objectPlayAnimation', playAnimFunction);
		set('addOffset', function(objName:String, anim:String, x:Float, y:Float) {
			var obj:Dynamic = getObject(objName);
			if(obj != null && obj.addOffset != null)
			{
				obj.addOffset(anim, x, y);
				return true;
			}
			return false;
		});
		set('setScrollFactor', function(objName:String, scrollX:Float = 0, scrollY:Float = 0) {
			var obj:Dynamic = getObject(objName);
			if(obj != null)
			{
				obj.scrollFactor.set(scrollX, scrollY);
				return true;
			}
			return PlayState.instance != null && PlayState.instance.queueExtraCharacterScroll(objName, scrollX, scrollY);
		});
		set('setGraphicSize', function(objName:String, x:Float, y:Float = 0, updateHitbox:Bool = true) {
			var obj:Dynamic = getObject(objName);
			if(obj == null)
				return false;
			obj.setGraphicSize(x, y);
			if(updateHitbox) obj.updateHitbox();
			return true;
		});
		var fitObjectToCameraFunc = function(objName:String, camera:String = 'other', autoUpdate:Bool = true) {
			var obj:Dynamic = getObject(objName);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if(obj == null)
				return false;

			obj.cameras = [cam];
			if(Std.isOfType(obj, objects.VVIESpriteHandler))
			{
				cast(obj, objects.VVIESpriteHandler).fitToCamera(cam, autoUpdate);
				return true;
			}
			if(Std.isOfType(obj, FlxSprite))
			{
				var sprite:FlxSprite = cast obj;
				sprite.scrollFactor.set();
				sprite.setPosition(backend.CameraResizeFix.pegarFSX(cam), backend.CameraResizeFix.pegarFSY(cam));
				sprite.setGraphicSize(Std.int(Math.ceil(backend.CameraResizeFix.pegarFSL(cam))), Std.int(Math.ceil(backend.CameraResizeFix.pegarFSA(cam))));
				sprite.updateHitbox();
				return true;
			}
			return false;
		};
		set('fitObjectToCamera', fitObjectToCameraFunc);
		set('fitObjectToScreen', fitObjectToCameraFunc);
		set('setObjectFullscreen', fitObjectToCameraFunc);
		set('scaleObject', function(objName:String, x:Float, y:Float, updateHitbox:Bool = true) {
			var obj:Dynamic = getObject(objName);
			if(obj == null)
				return false;
			obj.scale.set(x, y);
			if(updateHitbox) obj.updateHitbox();
			return true;
		});
		set('updateHitbox', function(objName:String) {
			var obj:Dynamic = getObject(objName);
			if(obj == null)
				return false;
			obj.updateHitbox();
			return true;
		});
		set('setObjectCamera', function(objName:String, camera:String = 'game') {
			var obj:FlxBasic = cast getObject(objName);
			if(obj == null)
				return false;
			obj.cameras = [LuaUtils.cameraFromString(camera)];
			return true;
		});
		set('setBlendMode', function(objName:String, blend:String = '') {
			var obj:FlxSprite = cast getObject(objName);
			if(obj == null)
				return false;
			obj.blend = LuaUtils.blendModeFromString(blend);
			return true;
		});
		set('screenCenter', function(objName:String, pos:String = 'xy') {
			var obj:FlxObject = cast getObject(objName);
			if(obj == null)
				return false;
			obj.screenCenter(switch(pos == null ? 'xy' : pos.trim().toLowerCase()) {
				case 'none': flixel.util.FlxAxes.NONE;
				case 'x': flixel.util.FlxAxes.X;
				case 'y': flixel.util.FlxAxes.Y;
				default: flixel.util.FlxAxes.XY;
			});
			return true;
		});
		#if VIDEOS_ALLOWED
		function getVideoObject(tag:String):objects.VideoSprite
		{
			if(tag == null)
				return null;
			if(PlayState.instance != null && PlayState.instance.videoCutscene != null && tag == 'videoCutscene')
				return PlayState.instance.videoCutscene;
			if(variableMap == null)
				return null;
			var obj:Dynamic = variableMap.get(tag.replace('.', ''));
			return Std.isOfType(obj, objects.VideoSprite) ? cast obj : null;
		}
		var makeVideoFunction = function(tag:String, videoFile:String, x:Float = 0, y:Float = 0, camera:String = 'other', canSkip:Bool = false, pauseWithGame:Bool = true, shouldLoop:Bool = false, playOnLoad:Bool = true, syncWithSong:Bool = false) {
			return PlayState.instance != null ? PlayState.instance.createVideo(tag, videoFile, x, y, camera, canSkip, pauseWithGame, shouldLoop, playOnLoad, syncWithSong) : null;
		};
		set('makeVideo', makeVideoFunction);
		set('makeLuaVideo', makeVideoFunction);
		set('addVideo', function(tag:String, front:Bool = true) {
			var video:objects.VideoSprite = getVideoObject(tag);
			if(video == null || PlayState.instance == null)
				return false;
			if(front) PlayState.instance.add(video);
			else PlayState.instance.insert(0, video);
			return true;
		});
		set('removeVideo', function(tag:String, destroy:Bool = true) {
			return PlayState.instance != null && PlayState.instance.removeVideo(tag, destroy);
		});
		set('videoExists', function(tag:String) return getVideoObject(tag) != null);
		set('playVideo', function(tag:String) {
			var video = getVideoObject(tag);
			if(video == null) return false;
			video.play();
			return true;
		});
		set('pauseVideo', function(tag:String) {
			var video = getVideoObject(tag);
			if(video == null) return false;
			video.pause();
			return true;
		});
		set('resumeVideo', function(tag:String) {
			var video = getVideoObject(tag);
			if(video == null) return false;
			video.resume();
			return true;
		});
		set('stopVideo', function(tag:String, destroy:Bool = true) {
			var video = getVideoObject(tag);
			if(video == null) return false;
			if(destroy && PlayState.instance != null)
				return PlayState.instance.removeVideo(tag, true);
			video.stop();
			return true;
		});
		set('setVideoCanSkip', function(tag:String, canSkip:Bool = true) {
			var video = getVideoObject(tag);
			if(video == null) return false;
			video.canSkip = canSkip;
			return true;
		});
		set('setVideoPauseWithGame', function(tag:String, pauseWithGame:Bool = true) {
			var video = getVideoObject(tag);
			if(video == null) return false;
			video.pauseWithGame = pauseWithGame;
			return true;
		});
		set('setVideoSyncWithSong', function(tag:String, syncWithSong:Bool = true) {
			var video = getVideoObject(tag);
			if(video == null) return false;
			video.syncWithSong = syncWithSong;
			return true;
		});
		set('seekVideo', function(tag:String, timeMs:Float) {
			var video = getVideoObject(tag);
			if(video == null) return false;
			video.setTime(timeMs);
			return true;
		});
		set('setVideoTime', function(tag:String, timeMs:Float) {
			var video = getVideoObject(tag);
			if(video == null) return false;
			video.setTime(timeMs);
			return true;
		});
		set('getVideoTime', function(tag:String) {
			var video = getVideoObject(tag);
			return video != null ? video.getTime() : 0;
		});
		set('getVideoLength', function(tag:String) {
			var video = getVideoObject(tag);
			return video != null ? video.getLength() : 0;
		});
		#end
		set('setVar', function(name:String, value:Dynamic) {
			variableMap?.set(name, value);
			return value;
		});
		set('getVar', function(name:String) {
			return variableMap?.get(name);
		});
		set('hasVar', function(name:String) {
			return variableMap?.exists(name);
		});
		set('removeVar', function(name:String) {
			if (variableMap?.exists(name) ?? false) {
				variableMap.remove(name);
				return true;
			}
			return false;
		});
		set('debugPrint', function(text:String, color:FlxColor = FlxColor.WHITE) {
			return ScriptedState.debugPrint(text, color);
		});
		set('getModSetting', function(saveTag:String, ?modName:String = null) {
			if(modName == null)
			{
				if(this.modFolder == null)
				{
					Iris.error('getModSetting: Argument #2 is null and script is not inside a packed Mod folder!', this.interp.posInfos());
					return null;
				}
				modName = this.modFolder;
			}
			return LuaUtils.getModSetting(saveTag, modName);
		});
		set('luaDeprecatedWarnings', true);
		set('luaDebugMode', true);

		// Keyboard & Gamepads
		set('keyboardJustPressed', function(name:String) return Reflect.getProperty(FlxG.keys.justPressed, name));
		set('keyboardPressed', function(name:String) return Reflect.getProperty(FlxG.keys.pressed, name));
		set('keyboardReleased', function(name:String) return Reflect.getProperty(FlxG.keys.justReleased, name));

		set('anyGamepadJustPressed', function(name:String) return FlxG.gamepads.anyJustPressed(name));
		set('anyGamepadPressed', function(name:String) FlxG.gamepads.anyPressed(name));
		set('anyGamepadReleased', function(name:String) return FlxG.gamepads.anyJustReleased(name));
		set('setCustomCursor', function(image:String = 'cursor', scale:Float = 1, hotspotX:Int = 0, hotspotY:Int = 0)
			return backend.CustomCursor.set(image, scale, hotspotX, hotspotY));
		set('reloadCustomCursor', function()
			return backend.CustomCursor.reloadFromMods());
		set('resetCustomCursor', function() {
			backend.CustomCursor.reset();
		});

		set('gamepadAnalogX', function(id:Int, ?leftStick:Bool = true) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;

			return controller.getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		set('gamepadAnalogY', function(id:Int, ?leftStick:Bool = true) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return 0.0;

			return controller.getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		set('gamepadJustPressed', function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.justPressed, name) == true;
		});
		set('gamepadPressed', function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.pressed, name) == true;
		});
		set('gamepadReleased', function(id:Int, name:String) {
			var controller = FlxG.gamepads.getByID(id);
			if (controller == null) return false;

			return Reflect.getProperty(controller.justReleased, name) == true;
		});

		set('keyJustPressed', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_P;
				case 'down': return Controls.instance.NOTE_DOWN_P;
				case 'up': return Controls.instance.NOTE_UP_P;
				case 'right': return Controls.instance.NOTE_RIGHT_P;
				default: return Controls.instance.justPressed(name);
			}
			return false;
		});
		set('keyPressed', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT;
				case 'down': return Controls.instance.NOTE_DOWN;
				case 'up': return Controls.instance.NOTE_UP;
				case 'right': return Controls.instance.NOTE_RIGHT;
				default: return Controls.instance.pressed(name);
			}
			return false;
		});
		set('keyReleased', function(name:String = '') {
			name = name.toLowerCase();
			switch(name) {
				case 'left': return Controls.instance.NOTE_LEFT_R;
				case 'down': return Controls.instance.NOTE_DOWN_R;
				case 'up': return Controls.instance.NOTE_UP_R;
				case 'right': return Controls.instance.NOTE_RIGHT_R;
				default: return Controls.instance.justReleased(name);
			}
			return false;
		});
		
		set('parentLua', null);
		
		#if LUA_ALLOWED
		set('parentLua', parentLua);
		set('runLuaCode', function(codeToRun:String, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null, keepAlive:Bool = false):Dynamic {
			return runLuaCodeFromHScript(codeToRun, funcToRun, funcArgs, keepAlive, parentState);
		});
		set('runLuaScript', function(luaFile:String, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null, keepAlive:Bool = true):Dynamic {
			return runLuaScriptFromHScript(luaFile, funcToRun, funcArgs, keepAlive, parentState);
		});
		
		set('createGlobalCallback', function(name:String, func:Dynamic)
		{
			if (!Reflect.isFunction(func)) {
				Iris.error('createGlobalCallback ($name): 2nd argument is not a function', this.interp.posInfos());
				return;
			}
			
			for (script in PlayState.instance.luaArray) {
				if(script != null && script.lua != null && !script.closed)
					Lua_helper.add_callback(script.lua, name, func);
			}
			
			FunkinLua.customFunctions.set(name, func);
		});
		
		set('createCallback', function(name:String, func:Dynamic, ?funk:FunkinLua = null)
		{
			if (!Reflect.isFunction(func)) {
				Iris.error('createCallback ($name): 2nd argument is not a function', this.interp.posInfos());
				return;
			}
			
			if(funk == null) funk = parentLua;
			
			if(funk != null) funk.addLocalCallback(name, func);
			else Iris.error('createCallback ($name): 3rd argument is null', this.interp.posInfos());
		});
		
		set('addHaxeLibrary', function(libName:String, ?libPackage:String = '') {
			try {
				var str:String = '';
				if(libPackage.length > 0)
					str = libPackage + '.';

				set(libName, Type.resolveClass(str + libName));
			} catch (e:Dynamic) {
				catchError(this, e);
			}
		});
		#end
		
		set('this', this);
		
		set('version', MainMenuState.psychEngineVersion.trim());
		set('modVersion', MainMenuState.modVersion.trim());
		set('modFolder', this.modFolder);
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);
		set('windowWidth', backend.VignetteUtil.windowWidth());
		set('windowHeight', backend.VignetteUtil.windowHeight());
		set('windowPixelWidth', backend.VignetteUtil.windowPixelWidth());
		set('windowPixelHeight', backend.VignetteUtil.windowPixelHeight());
		set('fullScreenX', backend.CameraResizeFix.pegarFSX(LuaUtils.cameraFromString('other')));
		set('fullScreenY', backend.CameraResizeFix.pegarFSY(LuaUtils.cameraFromString('other')));
		set('fullScreenWidth', backend.CameraResizeFix.pegarFSL(LuaUtils.cameraFromString('other')));
		set('fullScreenHeight', backend.CameraResizeFix.pegarFSA(LuaUtils.cameraFromString('other')));
		set('fullscreenX', backend.CameraResizeFix.pegarFSX(LuaUtils.cameraFromString('other')));
		set('fullscreenY', backend.CameraResizeFix.pegarFSY(LuaUtils.cameraFromString('other')));
		set('fullscreenWidth', backend.CameraResizeFix.pegarFSL(LuaUtils.cameraFromString('other')));
		set('fullscreenHeight', backend.CameraResizeFix.pegarFSA(LuaUtils.cameraFromString('other')));

		set('actualBuildTarget', LuaUtils.getBuildTarget());
		set('buildTarget', LuaUtils.getScriptBuildTarget());
		set('mobileBuild', LuaUtils.isMobileBuild());
		set('isMobile', LuaUtils.isMobileBuild());
		set('mobile', LuaUtils.isMobileBuild());
		set('actualMobileBuild', backend.DeveloperMode.actualMobileBuild());
		set('simulatedMobile', backend.DeveloperMode.mobileSimulation);
		set('developerMobile', backend.DeveloperMode.mobileSimulation);
		set('isMobileBuild', function():Bool return backend.DeveloperMode.isMobileLike());
		set('isActualMobileBuild', function():Bool return backend.DeveloperMode.actualMobileBuild());
		set('isMobileSimulation', function():Bool return backend.DeveloperMode.mobileSimulation);
		set('getRuntimeBuildTarget', function():String return backend.DeveloperMode.getScriptBuildTarget());
		set('getActualBuildTarget', function():String return backend.DeveloperMode.getActualBuildTarget());
		set('customSubstate', CustomSubstate.instance);
		set('customSubstateName', CustomSubstate.name);

		set('Function_Stop', LuaUtils.Function_Stop);
		set('Function_Continue', LuaUtils.Function_Continue);
		set('Function_StopLua', LuaUtils.Function_StopLua); //doesnt do much cuz HScript has a lower priority than Lua
		set('Function_StopHScript', LuaUtils.Function_StopHScript);
		set('Function_StopAll', LuaUtils.Function_StopAll);
		
		#if hscriptPos
		set('trace', Reflect.makeVarArgs(function(x:Array<Dynamic>) { // fix static target
			var pos = (this.interp?.posInfos() ?? Iris.getDefaultPos(origin));
			
			var v = x.shift();
			if (x.length > 0) pos.customParams = x;
			
			Iris.print(Std.string(v), pos);
		}));
		#end
	}

	static function normalizeCompatScript(code:String):String
	{
		if(code == null)
			return null;

		// NMV/Codename stages sometimes use spr.scrollFactor(x, y) as shorthand.
		code = ~/\.scrollFactor\s*\(/g.replace(code, '.scrollFactor.set(');
		return code;
	}

	function callInitialCallbacks():Void
	{
		if (exists('onLoad'))
			call('onLoad');
		if (exists('onCreate'))
			call('onCreate');
	}

	static function getCompatZIndex(obj:Dynamic):Int
	{
		if(obj == null)
			return 0;

		var value:Dynamic = null;
		try value = Reflect.getProperty(obj, 'zIndex') catch(e:Dynamic) {}

		if(value == null && Std.isOfType(obj, FlxBasic))
		{
			var basic:FlxBasic = cast obj;
			if(basic.hasVar('zIndex'))
				value = basic.getVar('zIndex');
		}

		if(value == null)
			return 0;
		return Std.int(value);
	}

	static function refreshZTarget(?target:Dynamic = null, ?state:FlxState = null):Dynamic
	{
		if(target == null)
			target = state ?? FlxG.state;
		if(target == null)
			return null;

		var members:Dynamic = Reflect.getProperty(target, 'members');
		if(!Std.isOfType(members, Array))
			return target;

		var list:Array<Dynamic> = cast members;
		var indexed:Array<Dynamic> = [];
		for(i in 0...list.length)
			indexed.push({index: i, member: list[i]});

		indexed.sort(function(a:Dynamic, b:Dynamic):Int {
			var z:Int = getCompatZIndex(a.member) - getCompatZIndex(b.member);
			return z != 0 ? z : Std.int(a.index - b.index);
		});

		for(i in 0...indexed.length)
			list[i] = indexed[i].member;
		return target;
	}
	
	public function getParent():Dynamic {
		return parentState;
	}
	public function getVariables():Map<String, Dynamic> {
		return parentState?.extraData;
	}
	public function configureCharacterScript(character:objects.Character, characterName:String):Void {
		if(character == null)
			return;

		characterScriptCharacter = character;
		characterScriptName = characterName ?? character.curCharacter;
		for(alias in ['character', 'char', 'chr', 'c'])
			set(alias, character);

		if(interp != null && Std.isOfType(interp, CustomInterp))
			cast(interp, CustomInterp).parentInstance = character;
	}
	public function matchesCharacterScript(character:objects.Character):Bool {
		if(character == null || characterScriptCharacter == null)
			return false;

		return characterScriptCharacter == character || (characterScriptName != null && characterScriptName == character.curCharacter);
	}

	#if LUA_ALLOWED
	static function runLuaCodeFromHScript(codeToRun:String, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null, keepAlive:Bool = false, ?state:FlxState):Dynamic {
		if(codeToRun == null || codeToRun.trim().length < 1)
			return null;

		state ??= FlxG.state;
		var lua:FunkinLua = FunkinLua.initFromFile(codeToRun, state);
		if(lua == null)
			return null;

		var ret:Dynamic = null;
		if(funcToRun != null && funcToRun.trim().length > 0)
			ret = lua.call(funcToRun, funcArgs);

		if(keepAlive && Std.isOfType(state, ScriptedSubState))
			cast(state, ScriptedSubState).luaArray.push(lua);
		else
			lua.stop();

		return LuaUtils.isLuaSupported(ret) ? ret : null;
	}

	static function runLuaScriptFromHScript(luaFile:String, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null, keepAlive:Bool = true, ?state:FlxState):Dynamic {
		var path:String = findLuaScriptPath(luaFile);
		if(path == null)
		{
			Iris.error('runLuaScript: Script does not exist: $luaFile', Iris.getDefaultPos('HScript'));
			return null;
		}

		state ??= FlxG.state;
		var lua:FunkinLua = null;
		if(keepAlive && Std.isOfType(state, ScriptedSubState))
			lua = cast(state, ScriptedSubState).initLuaScript(path);
		else
			lua = FunkinLua.initFromFile(path, state);

		if(lua == null)
			return null;

		var ret:Dynamic = true;
		if(funcToRun != null && funcToRun.trim().length > 0)
			ret = lua.call(funcToRun, funcArgs);

		if(!keepAlive)
			lua.stop();

		return LuaUtils.isLuaSupported(ret) ? ret : null;
	}

	static function findLuaScriptPath(luaFile:String):String {
		if(luaFile == null)
			return null;

		luaFile = luaFile.trim().replace('\\', '/');
		if(luaFile.length < 1)
			return null;
		if(!luaFile.toLowerCase().endsWith('.lua'))
			luaFile += '.lua';

		#if sys
		if(FileSystem.exists(luaFile))
			return luaFile;
		#end

		var path:String = Paths.getPath(luaFile, TEXT);
		#if sys
		return FileSystem.exists(path) ? path : null;
		#else
		return Assets.exists(path, TEXT) ? path : null;
		#end
	}

	public static function implementLocal(funk:FunkinLua) {
		funk.addLocalCallback("runHaxeCode", function(codeToRun:String, ?varsToBring:Any = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic {
			initHaxeModuleCode(funk, codeToRun, varsToBring);
			if (funk.hscript != null)
			{
				final retVal:IrisCall = funk.hscript.call(funcToRun, funcArgs);
				if (retVal != null)
				{
					return (LuaUtils.isLuaSupported(retVal.returnValue)) ? retVal.returnValue : null;
				}
				else if (funk.hscript.returnValue != null)
				{
					return funk.hscript.returnValue;
				}
			}
			return null;
		});
		
		funk.addLocalCallback("runHaxeFunction", function(funcToRun:String, ?funcArgs:Array<Dynamic> = null) {
			if (funk.hscript != null)
			{
				final retVal:IrisCall = funk.hscript.call(funcToRun, funcArgs);
				if (retVal != null)
				{
					return (LuaUtils.isLuaSupported(retVal.returnValue)) ? retVal.returnValue : null;
				}
			}
			else
			{
				var pos:HScriptInfos = cast {fileName: funk.scriptName, showLine: false};
				if (funk.lastCalledFunction != '') pos.funcName = funk.lastCalledFunction;
				Iris.error("runHaxeFunction: HScript has not been initialized yet! Use \"runHaxeCode\" to initialize it", pos);
			}
			return null;
		});
		// This function is unnecessary because import already exists in HScript as a native feature
		funk.addLocalCallback("addHaxeLibrary", function(libName:String, ?libPackage:String = '') {
			var str:String = '';
			if (libPackage.length > 0)
				str = libPackage + '.';
			else if (libName == null)
				libName = '';

			var c:Dynamic = Type.resolveClass(str + libName);
			if (c == null)
				c = Type.resolveEnum(str + libName);

			if (funk.hscript == null)
				initHaxeModule(funk);

			var pos:HScriptInfos = cast funk.hscript.interp.posInfos();
			pos.showLine = false;
			if (funk.lastCalledFunction != '')
				 pos.funcName = funk.lastCalledFunction;

			try {
				if (c != null)
					funk.hscript.set(libName, c);
			} catch (e:Dynamic) {
				catchError(funk.hscript, e);
			}
			FunkinLua.lastCalledScript = funk;
			if (FunkinLua.getBool('luaDebugMode') && FunkinLua.getBool('luaDeprecatedWarnings'))
				Iris.warn("addHaxeLibrary is deprecated! Import classes through \"import\" in HScript!", pos);
		});
	}
	#end

	function resolveScriptValue(path:String):Dynamic
	{
		if(path == null || interp == null)
			return null;

		var parts:Array<String> = path.split('.');
		if(parts.length < 2)
			return interp.variables.get(path);
		if(!interp.variables.exists(parts[0]))
			return null;

		var value:Dynamic = interp.variables.get(parts[0]);
		for(i in 1...parts.length)
		{
			if(value == null)
				return null;
			value = Reflect.getProperty(value, parts[i]);
		}
		return value;
	}

	override public function exists(field:String):Bool
	{
		if(super.exists(field))
			return true;

		if(field == null || field.indexOf('.') < 0)
			return false;

		return Reflect.isFunction(resolveScriptValue(field));
	}

	override function call(funcToRun:String, ?args:Array<Dynamic>):IrisCall {
		if (funcToRun == null || interp == null) return null;

		if (!exists(funcToRun)) {
			Iris.error('No function named: $funcToRun', this.interp.posInfos());
			return null;
		}
		
		LuaUtils.lastCalledHScript = this;
		
		try {
			var func:Dynamic = resolveScriptValue(funcToRun); // function signature
			final ret = Reflect.callMethod(null, func, args ?? []);
			
			LuaUtils.lastCalledHScript = null;
			return {funName: funcToRun, signature: func, returnValue: ret};
		} catch(e:Dynamic) {
			LuaUtils.lastCalledHScript = null;
			catchError(this, e, funcToRun);
		}
		
		LuaUtils.lastCalledHScript = null;
		return null;
	}
	
	public static function catchError(hs:HScript, e:Dynamic, ?funcToRun:String):Void {
		if (hs.unsafe) {
			throw e;
			return;
		}
		
		var pos:HScriptInfos = cast hs.interp.posInfos();
		pos.funcName = funcToRun;
		#if LUA_ALLOWED
		if (hs.parentLua != null) {
			pos.isLua = true;
			if (hs.parentLua.lastCalledFunction != '')
				pos.funcName = hs.parentLua.lastCalledFunction;
		}
		#end
		
		var errorString:String = 'Unknown Error';
		if (Std.isOfType(e, IrisError)) {
			errorString = Printer.errorToString(e, false);
		} else if (e != null) {
			errorString = Std.string(e);
		}
		
		(hs.unsafe ? Iris.fatal : Iris.error) (errorString, pos);
	}

	override public function destroy() {
		#if HSCRIPT_ALLOWED
		if(LuaUtils.lastCalledHScript == this)
			LuaUtils.lastCalledHScript = null;
		#end
		removeIrisInstanceAlias(filePath);
		removeIrisInstanceAlias(origin);
		removeIrisInstanceAlias(name);
		origin = null;
		closed = true;
		#if LUA_ALLOWED parentLua = null; #end
		super.destroy();
	}

	public function isReady():Bool
		return !closed && interp != null;

	function removeIrisInstanceAlias(alias:String):Void
	{
		if(alias != null && alias.length > 0 && Iris.instances.get(alias) == this)
			Iris.instances.remove(alias);
	}

	function set_varsToBring(values:Any) {
		if (varsToBring != null)
			for (key in Reflect.fields(varsToBring))
				if (exists(key.trim()))
					interp.variables.remove(key.trim());

		if (values != null)
		{
			for (key in Reflect.fields(values))
			{
				key = key.trim();
				set(key, Reflect.field(values, key));
			}
		}

		return varsToBring = values;
	}
}

class CustomFlxColor {
	public static var TRANSPARENT(default, null):Int = FlxColor.TRANSPARENT;
	public static var BLACK(default, null):Int = FlxColor.BLACK;
	public static var WHITE(default, null):Int = FlxColor.WHITE;
	public static var GRAY(default, null):Int = FlxColor.GRAY;

	public static var GREEN(default, null):Int = FlxColor.GREEN;
	public static var LIME(default, null):Int = FlxColor.LIME;
	public static var YELLOW(default, null):Int = FlxColor.YELLOW;
	public static var ORANGE(default, null):Int = FlxColor.ORANGE;
	public static var RED(default, null):Int = FlxColor.RED;
	public static var PURPLE(default, null):Int = FlxColor.PURPLE;
	public static var BLUE(default, null):Int = FlxColor.BLUE;
	public static var BROWN(default, null):Int = FlxColor.BROWN;
	public static var PINK(default, null):Int = FlxColor.PINK;
	public static var MAGENTA(default, null):Int = FlxColor.MAGENTA;
	public static var CYAN(default, null):Int = FlxColor.CYAN;

	public static function fromInt(Value:Int):Int 
		return cast FlxColor.fromInt(Value);

	public static function fromRGB(Red:Int, Green:Int, Blue:Int, Alpha:Int = 255):Int
		return cast FlxColor.fromRGB(Red, Green, Blue, Alpha);

	public static function fromRGBFloat(Red:Float, Green:Float, Blue:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromRGBFloat(Red, Green, Blue, Alpha);

	public static inline function fromCMYK(Cyan:Float, Magenta:Float, Yellow:Float, Black:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromCMYK(Cyan, Magenta, Yellow, Black, Alpha);

	public static function fromHSB(Hue:Float, Sat:Float, Brt:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromHSB(Hue, Sat, Brt, Alpha);

	public static function fromHSL(Hue:Float, Sat:Float, Light:Float, Alpha:Float = 1):Int
		return cast FlxColor.fromHSL(Hue, Sat, Light, Alpha);

	public static function fromString(str:String):Int
		return cast FlxColor.fromString(str);
}

class CustomInterp extends crowplexus.hscript.Interp {
	public var parentInstance(default, set):Dynamic = null;
	var _instanceFields:Array<String> = [];
	
	function set_parentInstance(inst:Dynamic):Dynamic {
		if (inst == null) {
			_instanceFields = [];
			return parentInstance = inst;
		}
		
		if (inst is Class) {
			_instanceFields = Type.getClassFields(inst);
		} else {
			_instanceFields = Type.getInstanceFields(Type.getClass(inst));
		}
		return parentInstance = inst;
	}

	public function new() {
		super();
	}
	
	override function get(o:Dynamic, id:String):Dynamic {
		if (o == null)
			error(EInvalidAccess(id));
		
		var val:Dynamic = Reflect.getProperty(o, id);
		val ??= Reflect.field(o, id);
		
		if (val == null && !LuaUtils.hasField(o, id) && o is FlxBasic) {
			return cast(o, FlxBasic).getVar(id);
		} else {
			return val;
		}
	}
	override function set(o:Dynamic, id:String, v:Dynamic):Dynamic {
		if (o == null)
			error(EInvalidAccess(id));
		
		var hadField:Bool = LuaUtils.hasField(o, id);
		try {
			Reflect.setProperty(o, id, v);
			if (!hadField && o is FlxBasic) {
				cast(o, FlxBasic).setVar(id, v);
			}
		} catch (e:Dynamic) {
			if (o.setVar != null) {
				o.setVar(id, v);
			} else {
				throw e;
			}
		}
		return v;
	}
	override function resolve(id:String):Dynamic {
		if (locals.exists(id)) 
			return locals.get(id).r;
		if (variables.exists(id))
			return variables.get(id);
		if (imports.exists(id))
			return imports.get(id);
		
		#if LUA_ALLOWED
		if (FunkinLua.customFunctions.exists(id))
			return FunkinLua.customFunctions.get(id);
		#end
		if (parentInstance != null) {
			if (_instanceFields.contains(id)) {
				return Reflect.getProperty(parentInstance, id);
			} else if (parentInstance is FlxBasic) {
				var basic:FlxBasic = cast parentInstance;
				if (basic.hasVar(id))
					return basic.getVar(id);
			}
		}
		
		error(EUnknownVariable(id));
		return null;
	}
	override function setVar(id:String, v:Dynamic):Void {
		if (parentInstance != null) {
			if (_instanceFields.contains(id)) {
				return Reflect.setProperty(parentInstance, id, v);
			} else if (parentInstance is FlxBasic) {
				var basic:FlxBasic = cast parentInstance;
				if (basic.hasVar(id)) {
					basic.setVar(id, v);
					return;
				}
			}
		}
		
		variables.set(id, v);
		
		// error(EUnknownVariable(id));
		// having "global variables" is pretty pointless,
		// but i figure disabling it would cause issues on existing scripts
	}
}
#else
class HScript
{
	#if LUA_ALLOWED
	public static function implement() {
		FunkinLua.registerFunction("runHaxeCode", function(codeToRun:String, ?varsToBring:Any = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null):Dynamic {
			Log.print('HScript is not supported on this platform!', ERROR);
			return null;
		});
		FunkinLua.registerFunction("runHaxeFunction", function(funcToRun:String, ?funcArgs:Array<Dynamic> = null) {
			Log.print('HScript is not supported on this platform!', ERROR);
			return null;
		});
		FunkinLua.registerFunction("addHaxeLibrary", function(libName:String, ?libPackage:String = '') {
			Log.print('HScript is not supported on this platform!', ERROR);
			return null;
		});
	}
	#end
}
#end
#end
