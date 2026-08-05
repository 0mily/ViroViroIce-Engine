#if LUA_ALLOWED
package psychlua;

import backend.Song;
import backend.WeekData;
import backend.Highscore;
import backend.ScriptedState;
import backend.ResolutionManager;

import openfl.Lib;
import openfl.utils.Assets;
import openfl.display.BitmapData;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxState;

#if (!flash && sys)
import flixel.addons.display.FlxRuntimeShader;
#end

import cutscenes.DialogueBoxPsych;
import cutscenes.DialoguePlus;

import objects.StrumNote;
import objects.Note;
import objects.NoteSplash;
import objects.Character;
import objects.VideoSprite;
import objects.PerspectiveSprite;

import states.MainMenuState;
import states.StoryMenuState;
import states.FreeplayState;

import substates.PauseSubState;
import substates.GameOverSubstate;
import substates.StickerSubState;

import psychlua.LuaUtils;
import psychlua.ModchartSprite;
#if HSCRIPT_ALLOWED
import psychlua.HScript;
#end

import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;

import haxe.Json;
import tjson.TJSON;

import flxgif.FlxGifSprite;
import com.yagp.GifDecoder;
import com.yagp.GifPlayer;

import haxe.io.Bytes;
import sys.io.File;

class FunkinLua {
	public var lua:State = null;
	public var camTarget:FlxCamera;
	public var scriptName:String = '';
	public var modFolder:String = null;
	public var parentState:FlxState;
	public var closed:Bool = false;
	public var characterScriptName:String = null;
	public var characterScriptCharacter:Character = null;

	#if HSCRIPT_ALLOWED
	public var hscript:HScript = null;
	#end

	public var callbacks:Map<String, Dynamic> = [];
	public static var customFunctions:Map<String, Dynamic> = [];
	public static var globalFunctions:Map<String, Dynamic> = [];
	static var globalFunctionOwners:Map<String, FunkinLua> = [];
	public static var globalValues:Map<String, Dynamic> = [];
	static var globalValueOwners:Map<String, FunkinLua> = [];
	
	public static function initFromFile(file:String, ?parent:FlxState, ?onCreateInstance:FunkinLua->Void, autoCallCreate:Bool = true):FunkinLua {
		var newScript:FunkinLua = null;
		
		try {
			trace('LOADING LUA: $file');
			
			newScript = new FunkinLua(file, parent);
			if(onCreateInstance != null)
				onCreateInstance(newScript);
			
			if (autoCallCreate)
				newScript.call('onCreate');
		} catch(e:Dynamic) {
			Log.print(e, FATAL);
			newScript = null;
		}
		
		return newScript;
	}

	public function new(scriptName:String, ?state:FlxState) { // TODO: allat
		lua = LuaL.newstate();
		LuaL.openlibs(lua);
		prepareScriptHelpers();

		//trace('Lua version: ' + Lua.version());
		//trace("LuaJIT version: " + Lua.versionJIT());

		//LuaL.dostring(lua, CLENSE);

		this.scriptName = scriptName.trim();
		this.parentState = state;
		
		#if ADDONS_ALLOWED
		this.modFolder = Mods.getModFolderFromPath(this.scriptName);
		#end
		
		for (define => value in backend.macro.Scripting.Defines.list)
			set('DEF_$define', value);
		
		set('Function_StopLua', LuaUtils.Function_StopLua);
		set('Function_StopHScript', LuaUtils.Function_StopHScript);
		set('Function_StopAll', LuaUtils.Function_StopAll);
		set('Function_Stop', LuaUtils.Function_Stop);
		set('Function_Continue', LuaUtils.Function_Continue);
		set('luaDebugMode', false);
		set('luaDeprecatedWarnings', true);
		set('version', MainMenuState.psychEngineVersion.trim());
		set('modVersion', MainMenuState.modVersion.trim());
		set('gameOverCharacter', GameOverSubstate.characterName);
		set('chrMusic', GameOverSubstate.musicCharacterName);
		set('pauseMusic', PauseSubState.pauseMusicName);
		
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);
		refreshScreenVariables();
		
		set('actualBuildTarget', LuaUtils.getBuildTarget());
		set('buildTarget', LuaUtils.getScriptBuildTarget());
		set('mobileBuild', LuaUtils.isMobileBuild());
		set('isMobile', LuaUtils.isMobileBuild());
		set('mobile', LuaUtils.isMobileBuild());
		set('actualMobileBuild', backend.DeveloperMode.actualMobileBuild());
		set('simulatedMobile', backend.DeveloperMode.mobileSimulation);
		set('developerMobile', backend.DeveloperMode.mobileSimulation);
		
		set('modFolder', modFolder);
		set('scriptName', scriptName);
		set('currentModDirectory', Mods.currentModDirectory);
		
		// mod settings
		addLocalCallback("getModSetting", function(saveTag:String, ?modName:String = null) {
			#if ADDONS_ALLOWED
			if(modName == null)
			{
				if(this.modFolder == null)
				{
					FunkinLua.luaTrace('getModSetting: Argument #2 is null and script is not inside a packed Mod folder!', false, false, ERROR);
					return null;
				}
				modName = this.modFolder;
			}
			return LuaUtils.getModSetting(saveTag, modName);
			#else
			luaTrace("getModSetting: Mods are disabled in this build!", false, false, ERROR);
			#end
		});
		//

		addLocalCallback('getWindowWidth', function(?pixels:Bool = false):Int return pixels ? backend.VignetteUtil.windowPixelWidth() : backend.VignetteUtil.windowWidth());
		addLocalCallback('getWindowHeight', function(?pixels:Bool = false):Int return pixels ? backend.VignetteUtil.windowPixelHeight() : backend.VignetteUtil.windowHeight());
		addLocalCallback('getFullScreenX', function(?camera:String = 'other'):Float return backend.CameraResizeFix.pegarFSX(LuaUtils.cameraFromString(camera)));
		addLocalCallback('getFullScreenY', function(?camera:String = 'other'):Float return backend.CameraResizeFix.pegarFSY(LuaUtils.cameraFromString(camera)));
		addLocalCallback('getFullScreenWidth', function(?camera:String = 'other'):Float return backend.CameraResizeFix.pegarFSL(LuaUtils.cameraFromString(camera)));
		addLocalCallback('getFullScreenHeight', function(?camera:String = 'other'):Float return backend.CameraResizeFix.pegarFSA(LuaUtils.cameraFromString(camera)));
		
		addLocalCallback('close', function() {
			closed = true;
			trace('Closing script $scriptName');
			return closed;
		});
		
		implementLocal();
		
		for (name => func in customFunctions) {
			if (func != null)
				Lua_helper.add_callback(lua, name, func);
		}
		for (name => func in globalFunctions) {
			if (func != null)
				Lua_helper.add_callback(lua, name, func);
		}
		for (name => func in registeredFunctions) {
			if (func != null)
				Lua_helper.add_callback(lua, name, func);
		}
		for (name => value in globalValues)
			set(name, value);

		var previousScript:FunkinLua = lastCalledScript;
		lastCalledScript = this;
		try {
			var isString:Bool = !FileSystem.exists(scriptName);
			var result:Dynamic = null;
			if(!isString) {
				var originalSource:String = File.getContent(scriptName);
				var processedSource:String = ScriptSyntax.process(originalSource);
				result = processedSource == originalSource ? LuaL.dofile(lua, scriptName) : LuaL.dostring(lua, processedSource);
			} else {
				result = LuaL.dostring(lua, ScriptSyntax.process(scriptName));
			}

			var resultStr:String = Lua.tostring(lua, result);
			if (resultStr != null && result != 0)
				throw resultStr;
			
			if (isString) scriptName = 'unknown';
			lastCalledScript = previousScript;
		} catch(e:Dynamic) {
			lastCalledScript = previousScript;
			trace(e);
			throw e;
		}
	}

	//main
	public var lastCalledFunction:String = '';
	public var lastCalledArgs:Array<Dynamic> = [];
	public static var lastCalledScript:FunkinLua = null;

	function prepareScriptHelpers():Void
	{
		if(lua != null)
			LuaL.dostring(lua, ScriptMacros.luaFile('flow'));
	}

	public function refreshScreenVariables(?camera:String = 'other'):Void
	{
		if(lua == null || closed)
			return;

		var cam:FlxCamera = LuaUtils.cameraFromString(camera);
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);
		set('windowWidth', backend.VignetteUtil.windowWidth());
		set('windowHeight', backend.VignetteUtil.windowHeight());
		set('windowPixelWidth', backend.VignetteUtil.windowPixelWidth());
		set('windowPixelHeight', backend.VignetteUtil.windowPixelHeight());
		set('fullScreenX', backend.CameraResizeFix.pegarFSX(cam));
		set('fullScreenY', backend.CameraResizeFix.pegarFSY(cam));
		set('fullScreenWidth', backend.CameraResizeFix.pegarFSL(cam));
		set('fullScreenHeight', backend.CameraResizeFix.pegarFSA(cam));
		set('fullscreenX', backend.CameraResizeFix.pegarFSX(cam));
		set('fullscreenY', backend.CameraResizeFix.pegarFSY(cam));
		set('fullscreenWidth', backend.CameraResizeFix.pegarFSL(cam));
		set('fullscreenHeight', backend.CameraResizeFix.pegarFSA(cam));
	}

	function pushLuaValue(path:String):Int
	{
		if(path == null || path.length < 1)
		{
			Lua.pushnil(lua);
			return Lua.LUA_TNIL;
		}

		var parts:Array<String> = path.split('.');
		Lua.getglobal(lua, parts[0]);

		for (i in 1...parts.length)
		{
			var parentType:Int = Lua.type(lua, -1);
			if(parentType != Lua.LUA_TTABLE)
				return parentType;

			Lua.getfield(lua, -1, parts[i]);
			Lua.remove(lua, -2);
		}

		return Lua.type(lua, -1);
	}
	
	public function call(func:String, ?args:Array<Dynamic>):Dynamic {
		if(closed) return LuaUtils.Function_Continue;
		
		var prevFunction:String = lastCalledFunction;
		var prevArgs:Array<Dynamic> = lastCalledArgs;
		var prevScript:FunkinLua = lastCalledScript;
		
		try {
			if (lua == null) return LuaUtils.Function_Continue;
			
			lastCalledFunction = func;
			lastCalledArgs = args ?? [];
			lastCalledScript = this;
			
			args = lastCalledArgs;
			var type:Int = pushLuaValue(func);
			
			if (type != Lua.LUA_TFUNCTION) {
				if (type > Lua.LUA_TNIL)
					luaTrace('$func: Expected function, got ${LuaUtils.typeToString(type)}', false, false, ERROR);
				
				Lua.pop(lua, 1);
				
				lastCalledFunction = prevFunction;
				lastCalledArgs = prevArgs;
				lastCalledScript = prevScript;
				
				return LuaUtils.Function_Continue;
			}
			
			for (arg in args) Convert.toLua(lua, arg);
			var status:Int = Lua.pcall(lua, args.length, 1, 0);
			
			// Checks if it's not successful, then show a error.
			if (status != Lua.LUA_OK) {
				var error:String = getErrorMessage(status);
				luaTrace('$func:$error', false, false, ERROR);
				
				lastCalledFunction = prevFunction;
				lastCalledArgs = prevArgs;
				lastCalledScript = prevScript;
				
				return LuaUtils.Function_Continue;
			}
			
			// If successful, pass and then return the result.
			var result:Dynamic = (cast Convert.fromLua(lua, -1) ?? LuaUtils.Function_Continue);

			Lua.pop(lua, 1);
			if (closed) stop();
			
			lastCalledFunction = prevFunction;
			lastCalledArgs = prevArgs;
			lastCalledScript = prevScript;
			
			return result;
		} catch (e:Dynamic) {
			trace(e);
		}
		
		lastCalledFunction = prevFunction;
		lastCalledArgs = prevArgs;
		lastCalledScript = prevScript;
		
		return LuaUtils.Function_Continue;
	}
	
	public function exists(variable:String):Bool {
		if (lua == null)
			return false;
		
		var type:Int = pushLuaValue(variable);
		Lua.pop(lua, 1);
		
		return (type != Lua.LUA_TNONE && type != Lua.LUA_TNIL);
	}

	public function set(variable:String, data:Dynamic):Void {
		if (lua == null)
			return;
		
		Convert.toLua(lua, data);
		Lua.setglobal(lua, variable);
	}
	public function configureCharacterScript(character:Character, characterName:String):Void {
		if(character == null)
			return;

		characterScriptCharacter = character;
		characterScriptName = characterName ?? character.curCharacter;
		for(alias in ['character', 'char', 'chr', 'c'])
			set(alias, character);
	}
	public function matchesCharacterScript(character:Character):Bool {
		if(character == null || characterScriptCharacter == null)
			return false;

		return characterScriptCharacter == character || (characterScriptName != null && characterScriptName == character.curCharacter);
	}
	
	public function get(variable:String):Dynamic {
		if (lua == null)
			return null;

		var previousTop:Int = Lua.gettop(lua);
		try {
			Lua.getglobal(lua, variable);
			var result:Dynamic = Convert.fromLua(lua, -1);
			Lua.settop(lua, previousTop);
			return result;
		} catch (e:Dynamic) {
			Lua.settop(lua, previousTop);
			throw e;
		}
	}

	public function stop() {
		milyMC.MilyMCCustom.releaseLua(this);
		closed = true;
		unregisterGlobalDataFor(this);

		if(lua == null) {
			return;
		}
		Lua.close(lua);
		lua = null;
		#if HSCRIPT_ALLOWED
		if(hscript != null)
		{
			hscript.destroy();
			hscript = null;
		}
		#end
	}

	static function oldTweenFunction(tag:String, vars:String, tweenValue:Any, duration:Float, ease:String, funcName:String) {
		var owner:FunkinLua = currentCallbackOwner();
		var ownerState:FlxState = currentCallbackState(owner);
		var target:Dynamic = LuaUtils.tweenPrepare(tag, vars);
		var variables = MusicBeatState.getVariables();
		if(target != null) {
			LuaUtils.cancelTweensOf(target, tweenValue);
			if (tag != null) {
				var originalTag:String = tag;
				tag = LuaUtils.formatVariable('tween_$tag');
				variables.set(tag, FlxTween.tween(target, tweenValue, duration, {ease: LuaUtils.getTweenEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						variables.remove(tag);
						luaCallGlobalFrom(owner, ownerState, 'onTweenCompleted', [originalTag, vars]);
					}
				}));
			}
			else FlxTween.tween(target, tweenValue, duration, {ease: LuaUtils.getTweenEaseByString(ease)});
			return tag;
		}
		else luaTrace('$funcName: Couldnt find object: $vars', false, false, ERROR);
		return null;
	}
	static function noteTweenFunction(tag:String, note:Int, data:Dynamic, duration:Float, ease:String) {
		if(PlayState.instance == null) return null;
		var owner:FunkinLua = currentCallbackOwner();
		var ownerState:FlxState = currentCallbackState(owner);
		
		var strumNote:StrumNote = PlayState.instance.strumLineNotes.members[note % PlayState.instance.strumLineNotes.length];
		if(strumNote == null) return null;

		LuaUtils.cancelTweensOf(strumNote, data);
		if(tag != null)
		{
			var originalTag:String = tag;
			tag = LuaUtils.formatVariable('tween_$tag');
			LuaUtils.cancelTween(tag);

			var variables = MusicBeatState.getVariables();
			variables.set(tag, FlxTween.tween(strumNote, data, duration, {ease: LuaUtils.getTweenEaseByString(ease),
				onComplete: function(twn:FlxTween)
				{
					variables.remove(tag);
					luaCallGlobalFrom(owner, ownerState, 'onTweenCompleted', [originalTag]);
				}
			}));
			return tag;
		}
		else FlxTween.tween(strumNote, data, duration, {ease: LuaUtils.getTweenEaseByString(ease)});
		return null;
	}

	public static function luaTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false, ?color:FlxColor, ?level:LogType) {
		LuaUtils.scriptTrace(text, ignoreCheck, deprecated, color, level);
	}

	public static function getBool(variable:String):Bool {
		return LuaUtils.getBool(variable);
	}

	static function findScript(scriptFile:String, ext:String = '.lua') {
		var candidates:Array<String> = [scriptFile];
		#if HSCRIPT_ALLOWED
		if(ext == '.hx')
			candidates = HScript.withScriptExtensions(scriptFile);
		else
		#end
		if(!scriptFile.endsWith(ext))
			candidates.push(scriptFile + ext);

		for(candidate in candidates)
		{
			var path:String = Paths.getPath(candidate, TEXT);
			#if ADDONS_ALLOWED
			if(FileSystem.exists(path))
			#else
			if(Assets.exists(path, TEXT))
			#end
			{
				return path;
			}
			#if ADDONS_ALLOWED
			else if(FileSystem.exists(candidate))
			#else
			else if(Assets.exists(candidate, TEXT))
			#end
			{
				return candidate;
			}
		}
		return null;
	}

	public function getErrorMessage(status:Int):String {
		var v:String = Lua.tostring(lua, -1);
		Lua.pop(lua, 1);

		if (v != null) v = v.trim();
		if (v == null || v == "") {
			switch(status) {
				case Lua.LUA_ERRRUN: return "Runtime Error";
				case Lua.LUA_ERRMEM: return "Memory Allocation Error";
				case Lua.LUA_ERRERR: return "Critical Error";
			}
			return "Unknown Error";
		}

		return v;
	}

	public function addLocalCallback(name:String, myFunction:Dynamic)
	{
		callbacks.set(name, myFunction);
		Lua_helper.add_callback(lua, name, null);
	}

	static function unregisterGlobalDataFor(owner:FunkinLua):Void
	{
		if (owner == null)
			return;

		var removeFunctions:Array<String> = [];
		for (name => script in globalFunctionOwners)
			if (script == owner)
				removeFunctions.push(name);

		for (name in removeFunctions)
		{
			globalFunctionOwners.remove(name);
			globalFunctions.remove(name);
		}

		var removeValues:Array<String> = [];
		for (name => script in globalValueOwners)
			if (script == owner)
				removeValues.push(name);

		for (name in removeValues)
		{
			globalValueOwners.remove(name);
			globalValues.remove(name);
		}
	}

	#if (!flash && sys)
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();
	#end

	public function initLuaShader(name:String)
	{
		if(!ClientPrefs.data.shaders) return false;

		#if (!flash && sys)
		if(runtimeShaders.exists(name))
		{
			var shaderData:Array<String> = runtimeShaders.get(name);
			if(shaderData != null && (shaderData[0] != null || shaderData[1] != null))
			{
				luaTrace('Shader already initialized: $name', WARN);
				return true;
			}
		}

		var foldersToCheck:Array<String> = [Paths.getSharedPath('shaders/')];
		#if ADDONS_ALLOWED
		if(Mods.rootAddonsAllowed())
			foldersToCheck.push(Paths.mods('shaders/'));
		for(mod in Mods.getActiveModDirectories())
			foldersToCheck.insert(0, Paths.mods(mod + '/shaders/'));
		#end

		for (folder in foldersToCheck)
		{
			if(FileSystem.exists(folder))
			{
				var frag:String = folder + name + '.frag';
				var vert:String = folder + name + '.vert';
				var found:Bool = false;
				if(FileSystem.exists(frag))
				{
					frag = Paths.getTextFromFile(frag);
					found = true;
				}
				else frag = null;

				if(FileSystem.exists(vert))
				{
					vert = Paths.getTextFromFile(vert);
					found = true;
				}
				else vert = null;

				if(found)
				{
					runtimeShaders.set(name, [frag, vert]);
					//trace('Found shader $name!');
					return true;
				}
			}
		}
		luaTrace('Missing shader $name .frag AND .vert files!', false, false, ERROR);
		#else
		luaTrace('This platform doesn\'t support Runtime Shaders!', false, false, ERROR);
		#end
		return false;
	}
	
	public static function luaCallGlobal(func:String, args:Array<Dynamic>, ?targetState:FlxState):Void {
		var state:FlxState = targetState ?? FlxG.state;
		do {
			if (state is ScriptedSubState)
				cast(state, ScriptedSubState).callOnLuas(func, args);
			state = state.subState;
		} while (state != null);
	}

	static function currentCallbackOwner():FunkinLua {
		return lastCalledScript;
	}

	static function currentCallbackState(owner:FunkinLua):FlxState {
		return owner != null && owner.parentState != null ? owner.parentState : FlxG.state;
	}

	public static function luaCallGlobalFrom(owner:FunkinLua, state:FlxState, func:String, args:Array<Dynamic>):Void {
		if (owner != null && owner.closed)
			return;

		var previousScript:FunkinLua = lastCalledScript;
		lastCalledScript = owner;
		luaCallGlobal(func, args, state);
		lastCalledScript = previousScript;
	}
	
	public static var registeredFunctions:Map<String, Dynamic> = [];
	static function getCallbackState():FlxState {
		if (lastCalledScript != null && lastCalledScript.parentState != null)
			return lastCalledScript.parentState;
		return FlxG.state;
	}

	static function getCallbackVariables():Map<String, Dynamic> {
		var state:FlxState = getCallbackState();
		return state != null ? state.extraData : MusicBeatState.getVariables();
	}

	public static function registerFunctions():Void {
		registeredFunctions.clear();
		
		implement();
		CustomState.implement();
		TextFunctions.implement();
		ClipFunctions.implement(); // o yea
		TileFunctions.implement();
		ExtraFunctions.implement();
		FreeplayLuaFunctions.implement();
		CustomSubstate.implement();
		ReflectionFunctions.implement();
		DeprecatedFunctions.implement();
		FlxAnimateFunctions.implement();
		
		#if (!HSCRIPT_ALLOWED) HScript.implement(); #end
		#if DISCORD_ALLOWED DiscordClient.implement(); #end
		#if TRANSLATIONS_ALLOWED Language.implement(); #end
		#if ACHIEVEMENTS_ALLOWED Achievements.implement(); #end
	}
	
	public function implementLocal():Void {
		addLocalCallback('setMC', milyMC.MilyMC.setMC);
		addLocalCallback('easeMC', milyMC.MilyMC.easeMC);
		addLocalCallback('removeMC', milyMC.MilyMC.removeMC);
		addLocalCallback('setQueueMC', milyMC.MilyMC.setQueueMC);
		addLocalCallback('easeQueueMC', milyMC.MilyMC.easeQueueMC);
		addLocalCallback('removeQueueMC', milyMC.MilyMC.removeQueueMC);
		addLocalCallback('kickMC', milyMC.MilyMC.kickMC);
		addLocalCallback('setStrum', milyMC.MilyMC.setStrum);
		addLocalCallback('easeStrum', milyMC.MilyMC.easeStrum);
		addLocalCallback('setQueueStrum', milyMC.MilyMC.setQueueStrum);
		addLocalCallback('easeQueueStrum', milyMC.MilyMC.easeQueueStrum);
		milyMC.MilyMCCustom.installLua(this);

		addLocalCallback('registerLuaFunction', function(name:String, ?funcName:String = null) {
			if (name == null || name.trim().length < 1)
				return false;

			name = name.trim();
			if (funcName == null || funcName.trim().length < 1)
				funcName = name;
			funcName = funcName.trim();

			var owner:FunkinLua = this;
			var callback = Reflect.makeVarArgs(function(args:Array<Dynamic>) {
				if (owner == null || owner.closed)
					return null;
				return owner.call(funcName, args);
			});

			globalFunctions.set(name, callback);
			globalFunctionOwners.set(name, owner);
			Lua_helper.add_callback(lua, name, callback);
			return true;
		});
		addLocalCallback('registerLuaConstant', function(name:String, value:Dynamic) {
			if (name == null || name.trim().length < 1)
				return false;

			name = name.trim();
			globalValues.set(name, value);
			globalValueOwners.set(name, this);
			set(name, value);
			return true;
		});
		addLocalCallback('registerLuaValue', function(name:String, value:Dynamic) {
			if (name == null || name.trim().length < 1)
				return false;

			name = name.trim();
			globalValues.set(name, value);
			globalValueOwners.set(name, this);
			set(name, value);
			return true;
		});

		ShaderFunctions.implementLocal(this);
		ReflectionFunctions.implementLocal(this);
		#if HSCRIPT_ALLOWED HScript.implementLocal(this); #end
		
		var st:ScriptedSubState = null;
		if (parentState is ScriptedSubState)
			st = cast parentState;
		else if (FlxG.state is ScriptedSubState)
			st = cast FlxG.state;
		
		if (st != null) {
			st.implementLua(this);
			
			set('curStep', st.curStep);
			set('curBeat', st.curBeat);
			set('curSection', st.curSection);
			set('curDecStep', st.curDecStep);
			set('curDecBeat', st.curDecBeat);
			set('curDecSection', st.curDecSection);
			set('curBpm', st.curBpm);
			set('crochet', st.crochet);
			set('stepCrochet', st.stepCrochet);
			set('stateConductorPosition', st.stateConductorPosition);
			set('usesStateConductor', st.useStateConductor);
			
			addLocalCallback('callScript', function(luaFile:String, funcName:String, ?args:Array<Dynamic>) {
				args ??= [];
				
				var luaPath:String = findScript(luaFile);
				if(luaPath != null)
					for (luaInstance in st.luaArray)
						if(luaInstance.scriptName == luaPath)
							return luaInstance.call(funcName, args);

				return null;
			});
			addLocalCallback('isRunning', function(scriptFile:String) {
				var luaPath:String = findScript(scriptFile);
				if (luaPath != null) {
					for (luaInstance in st.luaArray)
						if (luaInstance.scriptName == luaPath)
							return true;
				}
				
				#if HSCRIPT_ALLOWED
				var hscriptPath:String = findScript(scriptFile, '.hx');
				if (hscriptPath != null) {
					for (hscriptInstance in st.hscriptArray)
						if (hscriptInstance.origin == hscriptPath)
							return true;
				}
				#end
				return false;
			});
			addLocalCallback('getRunningScripts', function() {
				var runningScripts:Array<String> = [];
				for (script in st.luaArray)
					runningScripts.push(script.scriptName);
				
				return runningScripts;
			});
			
			addLocalCallback('addLuaScript', function(luaFile:String, ?ignoreAlreadyRunning:Bool = false) {
				var luaPath:String = findScript(luaFile);
				if (luaPath != null) {
					if (!ignoreAlreadyRunning) {
						for (luaInstance in st.luaArray) {
							if(luaInstance.scriptName == luaPath) {
								luaTrace('addLuaScript: The script "' + luaPath + '" is already running!', WARN);
								return;
							}
						}
					}
					
					st.initLuaScript(luaPath);
					return;
				}
				luaTrace("addLuaScript: Script doesn't exist!", false, false, ERROR);
			});
			addLocalCallback('addHScript', function(scriptFile:String, ?ignoreAlreadyRunning:Bool = false) {
				#if HSCRIPT_ALLOWED
				var scriptPath:String = findScript(scriptFile, '.hx');
				if (scriptPath != null) {
					if (!ignoreAlreadyRunning) {
						for (script in st.hscriptArray) {
							if(script.origin == scriptPath) {
								luaTrace('addHScript: The script "' + scriptPath + '" is already running!', WARN);
								return;
							}
						}
					}
					
					st.initHScript(scriptPath);
					return;
				}
				luaTrace("addHScript: Script doesn't exist!", false, false, ERROR);
				#else
				luaTrace("addHScript: HScript is not supported on this platform!", false, false, ERROR);
				#end
			});
			addLocalCallback('removeLuaScript', function(luaFile:String) {
				var luaPath:String = findScript(luaFile);
				if (luaPath != null) {
					var foundAny:Bool = false;
					for (luaInstance in st.luaArray) {
						if (luaInstance.scriptName == luaPath) {
							trace('Closing lua script $luaPath');
							luaInstance.stop();
							foundAny = true;
						}
					}
					if (foundAny) return true;
				}
				
				luaTrace('removeLuaScript: Script $luaFile isn\'t running!', false, false, WARN);
				return false;
			});
			addLocalCallback('removeHScript', function(scriptFile:String) {
				#if HSCRIPT_ALLOWED
				var scriptPath:String = findScript(scriptFile, '.hx');
				if (scriptPath != null) {
					var foundAny:Bool = false;
					for (script in st.hscriptArray) {
						if (script.origin == scriptPath) {
							trace('Closing hscript $scriptPath');
							script.destroy();
							foundAny = true;
						}
					}
					if (foundAny) return true;
				}
				
				luaTrace('removeHScript: Script $scriptFile isn\'t running!', false, false, WARN);
				return false;
				#else
				luaTrace("removeHScript: HScript is not supported on this platform!", false, false, ERROR);
				#end
			});
			addLocalCallback("setOnScripts", function(varName:String, arg:Dynamic, ignoreSelf:Bool = false, ?exclusions:Array<String>) {
				exclusions ??= [];
				if (ignoreSelf) exclusions.push(scriptName);
				st.setOnScripts(varName, arg, exclusions);
			});
			addLocalCallback("setOnHScript", function(varName:String, arg:Dynamic, ignoreSelf:Bool = false, ?exclusions:Array<String>) {
				exclusions ??= [];
				if (ignoreSelf) exclusions.push(scriptName);
				st.setOnHScript(varName, arg, exclusions);
			});
			addLocalCallback("setOnLuas", function(varName:String, arg:Dynamic, ignoreSelf:Bool = false, ?exclusions:Array<String>) {
				exclusions ??= [];
				if (ignoreSelf) exclusions.push(scriptName);
				st.setOnLuas(varName, arg, exclusions);
			});

			addLocalCallback("callOnScripts", function(funcName:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ignoreSelf:Bool = true, ?exclusions:Array<String>, ?excludeValues:Array<Dynamic>) {
				exclusions ??= [];
				if (ignoreSelf) exclusions.push(scriptName);
				return st.callOnScripts(funcName, args, ignoreStops, exclusions, excludeValues);
			});
			addLocalCallback("callOnLuas", function(funcName:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ignoreSelf:Bool = true, ?exclusions:Array<String>, ?excludeValues:Array<Dynamic>) {
				exclusions ??= [];
				if (ignoreSelf) exclusions.push(scriptName);
				return st.callOnLuas(funcName, args, ignoreStops, exclusions, excludeValues);
			});
			addLocalCallback("callOnHScript", function(funcName:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ignoreSelf:Bool = true, ?exclusions:Array<String>, ?excludeValues:Array<Dynamic>) {
				exclusions ??= [];
				if (ignoreSelf) exclusions.push(scriptName);
				return st.callOnHScript(funcName, args, ignoreStops, exclusions, excludeValues);
			});
		}
	}
	
	public static function registerFunction(name:String, func:Dynamic):Void {
		registeredFunctions.set(name, func);
	}

	static function registerMobileRuntimeFunctions():Void
	{
		registerFunction('isMobileBuild', function():Bool
			return backend.DeveloperMode.isMobileLike());
		registerFunction('isActualMobileBuild', function():Bool
			return backend.DeveloperMode.actualMobileBuild());
		registerFunction('isMobileSimulation', function():Bool
			return backend.DeveloperMode.mobileSimulation);
		registerFunction('getRuntimeBuildTarget', function():String
			return backend.DeveloperMode.getScriptBuildTarget());
		registerFunction('getActualBuildTarget', function():String
			return backend.DeveloperMode.getActualBuildTarget());
		registerFunction('mobileControlsMode', function():String
			return backend.DeveloperMode.mobileSimulation ? 'simulated' : 'hitbox');
		registerFunction('touchJustPressed', function():Bool
			return TouchUtil.justPressed);
		registerFunction('touchPressed', function():Bool
			return TouchUtil.pressed);
		registerFunction('touchJustReleased', function():Bool
			return TouchUtil.justReleased);
		registerFunction('touchReleased', function():Bool
			return TouchUtil.released);
		registerFunction('touchOverlapsObject', function(object:String, ?camera:String):Bool
			return touchObjectCheck(object, camera, false, 'touchOverlapsObject'));
		registerFunction('touchOverlapsObjectComplex', function(object:String, ?camera:String):Bool
			return touchObjectCheck(object, camera, true, 'touchOverlapsObjectComplex'));
		registerFunction('touchPressedObject', function(object:String, ?camera:String):Bool
			return TouchUtil.pressed && touchObjectCheck(object, camera, false, 'touchPressedObject'));
		registerFunction('touchJustPressedObject', function(object:String, ?camera:String):Bool
			return TouchUtil.justPressed && touchObjectCheck(object, camera, false, 'touchJustPressedObject'));
		registerFunction('touchJustReleasedObject', function(object:String, ?camera:String):Bool
			return TouchUtil.justReleased && touchObjectCheck(object, camera, false, 'touchJustReleasedObject'));
		registerFunction('touchReleasedObject', function(object:String, ?camera:String):Bool
			return TouchUtil.released && touchObjectCheck(object, camera, false, 'touchReleasedObject'));
		registerFunction('touchPressedObjectComplex', function(object:String, ?camera:String):Bool
			return TouchUtil.pressed && touchObjectCheck(object, camera, true, 'touchPressedObjectComplex'));
		registerFunction('touchJustPressedObjectComplex', function(object:String, ?camera:String):Bool
			return TouchUtil.justPressed && touchObjectCheck(object, camera, true, 'touchJustPressedObjectComplex'));
		registerFunction('touchJustReleasedObjectComplex', function(object:String, ?camera:String):Bool
			return TouchUtil.justReleased && touchObjectCheck(object, camera, true, 'touchJustReleasedObjectComplex'));
		registerFunction('touchReleasedObjectComplex', function(object:String, ?camera:String):Bool
			return TouchUtil.released && touchObjectCheck(object, camera, true, 'touchReleasedObjectComplex'));
	}

	static function touchObjectCheck(object:String, ?camera:String, complex:Bool = false, traceName:String = 'touchObject'):Bool
	{
		var obj:Dynamic = null;
		try {
			obj = LuaUtils.getObjectDirectly(object);
		} catch(e:Dynamic) {
			obj = null;
		}

		if(obj == null || !Std.isOfType(obj, FlxObject))
		{
			luaTrace('$traceName: $object does not exist.');
			return false;
		}

		var cam:FlxCamera = LuaUtils.cameraFromString(camera ?? 'game');
		return complex ? TouchUtil.overlapsComplex(cast obj, cam) : TouchUtil.overlaps(cast obj, cam);
	}

	public static function implement():Void {
		var game:PlayState = PlayState.instance;
		if (game != null) implementGame(game);

		var st:ScriptedSubState = null;
		if (FlxG.state is ScriptedSubState)
			st = cast FlxG.state;

		function cameraHost():Dynamic
		{
			var state:Dynamic = FlxG.state;
			if(state != null && Reflect.isFunction(Reflect.field(state, 'addCamera')))
				return state;
			if(PlayState.instance != null && Reflect.isFunction(Reflect.field(PlayState.instance, 'addCamera')))
				return PlayState.instance;
			return null;
		}

		registerMobileRuntimeFunctions();

		registerFunction('changeGameOver', GameOverSubstate.changeGameOver);
		registerFunction('changeGameOverMusic', GameOverSubstate.setGameOverMusic);
		registerFunction('gameOverMusic', GameOverSubstate.setGameOverMusic);
		registerFunction('startGameOver', GameOverSubstate.startGameOver);
		registerFunction('retrySong', GameOverSubstate.retrySong);
		registerFunction('changePauseMusic', PauseSubState.changePauseMusic);
		registerFunction('makeOption', function(tag:String, name:String, order:Int = 0)
			return PauseSubState.instance != null && PauseSubState.instance.makeOption(tag, name, order));
		registerFunction('setOptionName', function(tag:String, name:String)
			return PauseSubState.instance != null && PauseSubState.instance.setOptionName(tag, name));
		registerFunction('addOption', function(tag:String)
			return PauseSubState.instance != null && PauseSubState.instance.addOption(tag));
		registerFunction('removeOption', function(tag:String)
			return PauseSubState.instance != null && PauseSubState.instance.removeOption(tag));
		registerFunction('switchCategory', function(name:String)
			return PauseSubState.instance != null && PauseSubState.instance.switchCategory(name));
		registerFunction('switchDefault', function()
			return PauseSubState.instance != null && PauseSubState.instance.switchDefault());
		registerFunction('openPause', function()
			return PauseSubState.instance != null && PauseSubState.instance.finishPauseOpen());
		registerFunction('resume', function()
			return PauseSubState.instance != null && PauseSubState.instance.resumeGame());
		registerFunction('resumeNow', function()
			return PauseSubState.instance != null && PauseSubState.instance.resumeNow());
		registerFunction('restart', function()
			return PauseSubState.instance != null && PauseSubState.instance.restartGame());
		registerFunction('exit', function()
			return PauseSubState.instance != null && PauseSubState.instance.exitGame());
		registerFunction('options', function()
			return PauseSubState.instance != null && PauseSubState.instance.openOptionsMenu());
		registerFunction('setPauseOptionsCentered', function(value:Bool)
			return PauseSubState.instance != null && PauseSubState.instance.setOptionsCentered(value));
		registerFunction('addPauseObject', function(object:Dynamic)
			return PauseSubState.instance != null && PauseSubState.instance.addPauseObject(object));
		registerFunction('registerStageObject', function(tag:String)
		{
			var obj:Dynamic = LuaUtils.getObjectDirectly(tag);
			return backend.StageDataController.registerFromScript(obj, PlayState.instance);
		});
		registerFunction('unregisterStageObject', function(tag:String)
		{
			var obj:Dynamic = LuaUtils.getObjectDirectly(tag);
			return backend.StageDataController.unregisterFromScript(obj);
		});
		registerFunction('refreshStageData', function()
		{
			PlayState.instance?.stageData?.refresh();
			return PlayState.instance?.stageData != null;
		});

		registerFunction('addNameCropper', function(suffix:String) {
			if (game.bucetaTira == null)
				game.bucetaTira = [];

			if (suffix == null || suffix.trim() == "")
				return;

			if (!game.bucetaTira.contains(suffix))
				game.bucetaTira.push(suffix);

			game.refreshSongNameText();
		});

		registerFunction('clearRemixes', function() {
			game.bucetaTira = [];
			game.refreshSongNameText();
		});

			

			// oi shihooooo
			// oi milyyyyyy

		registerFunction("setColorBrightness", function(color:String, value:Float = 0) {
            if (color != null) {
				if (value < 0) {
					return FlxColor.fromString('#$color').getDarkened(value*-1);
				} else {
					return FlxColor.fromString('#$color').getLightened(value);
				}
			}
			return FlxColor.fromString('#FFFFFF');
			luaTrace("setColorBrightness: Insert a color silly", false, false, ERROR);
        });

		registerFunction("changeTransStickers", function(stickerSet:String = null, stickerPack:String = null) {
            if (stickerSet != null && stickerSet != '') StickerSubState.STICKER_SET = stickerSet;
            if (stickerPack != null && stickerPack != '') StickerSubState.STICKER_PACK = stickerPack;
        });

		registerFunction("createLabel", function(spr:String, txt:String, box:String, tab:String){
			if (box != null && tab != null)
			{
				var myObj:FlxSprite = MusicBeatState.getVariables().get(spr);
				var myBox:PsychUIBox = MusicBeatState.getVariables().get(box);

				var huh = new FlxText(myObj.x, myObj.y - 15, 250, txt);
				huh.size = 9;
				var instance = myBox.getTab(tab).menu;
				instance.add(huh);
			}
			else
			{
				var myObj:FlxSprite = MusicBeatState.getVariables().get(spr);

				var huh = new FlxText(myObj.x, myObj.y - 15, 250, txt);
				huh.size = 9;
				var instance = LuaUtils.getTargetInstance();
				instance.add(huh);
			}
		});

		registerFunction("makeLuaBox", function(tag:String, tabs:Array<String>, defSelect:String, width:Int = 300, height:Int = 280, x:Float = 0, y:Float = 0) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var leBox = new PsychUIBox(x, y, width, height, tabs);
			leBox.selectedName = defSelect;
			MusicBeatState.getVariables().set(tag, leBox);
		});

		registerFunction("addToBox", function(tag:String, box:String, tab:String) {
			var myObj:FlxSprite = MusicBeatState.getVariables().get(tag);
			var myBox:PsychUIBox = MusicBeatState.getVariables().get(box);

			if(myObj == null) return;

			var instance = myBox.getTab(tab).menu;
			instance.add(myObj);
		});

		registerFunction("makeLuaButton", function(tag:String, label:String = '', scaleX:Int = 100, scaleY:Int = 40, x:Float = 0, y:Float = 0) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var originalTag:String = tag;
			var leButton = new PsychUIButton(x, y, label, function() st.callOnScripts('onButtonPressed', [originalTag], false, null, null), scaleX, scaleY);
			MusicBeatState.getVariables().set(tag, leButton);
		});

		registerFunction("makeLuaInputText", function(tag:String, input:String = '', size:Int = 8, width:Int = 0, x:Float = 0, y:Float = 0) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var leInput = new PsychUIInputText(x, y, width, input, size);
			MusicBeatState.getVariables().set(tag, leInput);
		});

		registerFunction("makeLuaSlider", function(tag:String, label:String = '', min:Float = 0.0, max:Float = 1.0, defValue:Float = 0.5, width:Int = 200, x:Float = 0, y:Float = 0) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var originalTag:String = tag;
			var leSlider = new PsychUISlider(x, y, function(v:Float) st.callOnScripts('onSliderChanged', [originalTag, v], false, null, null), defValue, min, max, width);
			leSlider.label = label;
			MusicBeatState.getVariables().set(tag, leSlider);
		});

		registerFunction("makeLuaCheckBox", function(tag:String, label:String = '', checked:Bool = false, hitbox:Int = 100, x:Float = 0, y:Float = 0) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var originalTag:String = tag;
			var leCheckBox = new PsychUICheckBox(x, y, label, hitbox, function() st.callOnScripts('onCheckBoxChecked', [originalTag, MusicBeatState.getVariables().get(originalTag).checked], false, null, null));
			leCheckBox.checked = checked;
			MusicBeatState.getVariables().set(tag, leCheckBox);
		});

		registerFunction("makeLuaNumericStepper", function(tag:String, step:Float = 1, decimals:Int = 0, min:Float = -999, max:Float = 999, defValue:Float = 0, ?wid:Int = 60, x:Float = 0, y:Float = 0, ?isPercent:Bool = false) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var originalTag:String = tag;
			var leNumStepper = new PsychUINumericStepper(x, y, step, defValue, min, max, decimals, wid, isPercent);
			leNumStepper.onValueChange = function() {st.callOnScripts('onNumericStepperChange', [originalTag, MusicBeatState.getVariables().get(originalTag).value], false, null, null);}
			MusicBeatState.getVariables().set(tag, leNumStepper);
		});

		registerFunction("getInputTextString", function(tag:String) {
			var obj:PsychUIInputText = LuaUtils.getObjectDirectly(tag);
			if(obj != null && obj.text != null)
			{
				return obj.text;
			}
			FunkinLua.luaTrace("getInputTextString: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return null;
		});

		registerFunction("isInputTextOnFocus", function() {
			if (PsychUIInputText.focusOn == null) return false; else return true;
		});

		registerFunction("makeLuaRadio", function(tag:String, labels:Array<String>, x:Float = 0, y:Float = 0, ?isHorizontal:Bool = false, space:Float = 25, ?textWidth:Int = 100, maxItems:Int = 0) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var originalTag:String = tag;
			var leRadio:PsychUIRadioGroup = new PsychUIRadioGroup(x, y, labels, space, maxItems, isHorizontal, textWidth);
			leRadio.onClick = function() {game.callOnScripts('onRadioChecked', [originalTag, MusicBeatState.getVariables().get(originalTag).checked + 1], false, null, null);}
			MusicBeatState.getVariables().set(tag, leRadio);
		});

		registerFunction("makeLuaDropdown", function(tag:String, list:Array<String>, defLabel:String, ?width:Float = 100, x:Float = 0, y:Float = 0) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var originalTag:String = tag;
			var leDropdown:PsychUIDropDownMenu = new PsychUIDropDownMenu(x, y, list, function(index:Int, label:String) {game.callOnScripts('onDropdownLabelSelected', [originalTag, index, label], false, null, null);}, width);
			leDropdown.selectedLabel = defLabel;
			MusicBeatState.getVariables().set(tag, leDropdown);
		});

		registerFunction("parseJson", function(jsonStuff:String, ?getFromFile:Bool = true) {
			// preciso fazer um handler de erro aqui ou seja lá qual é o nome... tô com preguiça no momento -Shiho
			var funnyJson:String = getFromFile ? Paths.getTextFromFile(jsonStuff, false) : jsonStuff;
			var funnyParse:Dynamic = TJSON.parse(funnyJson);

			return funnyParse;
		});

		registerFunction("makeLuaGif", function(tag:String, ?gif:String = null, ?x:Float = 0, ?y:Float = 0) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
    		var path:String = Paths.getPath('images/$gif.gif', IMAGE);

			var leGif:FlxGifSprite = new FlxGifSprite(x, y);
			if(gif != null && gif.length > 0)
			{
				var bytes:Bytes = File.getBytes(path);
				leGif.loadGif(bytes);
				leGif.antialiasing = ClientPrefs.data.antialiasing;
			}
			MusicBeatState.getVariables().set(tag, leGif);
			leGif.active = true;
		});
		
		registerFunction('debugPrint', function(?text:Dynamic, ?color:String) ScriptedState.debugPrint(text, color == null ? null : CoolUtil.colorFromString(color)));

		registerFunction('setVar', (varName:String, value:Dynamic) -> {
			MusicBeatState.getVariables().set(varName, ReflectionFunctions.parseInstances(value));
			return value;
		});
		registerFunction('getVar', (varName:String) -> MusicBeatState.getVariables().get(varName));

		registerFunction('loadSong', (?name:String, difficultyNum:Int = -1) -> StoryMenuState.loadSong(name, difficultyNum));
		registerFunction('loadWeek', (?name:String, difficultyNum:Int = -1) -> {
			var week:WeekData = (name == null ? PlayState.storyWeekData : StoryMenuState.getWeek(name));
			if (week == null) {
				luaTrace('loadWeek: Week ${name == null ? 'is null!' : '$name not found!'}', false, false, ERROR);
			} else {
				StoryMenuState.loadWeek(week, difficultyNum);
			}
		});
		
		registerFunction('loadGraphic', function(variable:String, image:String, ?gridX:Int = 0, ?gridY:Int = 0) {
			var object:Dynamic = LuaUtils.getObjectDirectly(variable);
			if (object == null) {
				luaTrace('loadGraphic: Object $object doesn\'t exist!', false, false, ERROR);
			} else {
				var animated:Bool = (gridX != 0 || gridY != 0);
				if (image != null && image.length > 0)
					object.loadGraphic(Paths.image(image), animated, gridX, gridY);
			}
		});
		registerFunction('loadFrames', function(variable:String, image:String, spriteType:String = 'auto') {
			var object:FlxSprite = LuaUtils.getObjectDirectly(variable);

			if (object != null && image != null && image.length > 0)
				LuaUtils.loadFrames(object, image, spriteType);
		});
		registerFunction('loadMultipleFrames', function(variable:String, images:Array<String>) {
			var object:FlxSprite = LuaUtils.getObjectDirectly(variable);

			if (object != null && images != null && images.length > 0)
				object.frames = Paths.getMultiAtlas(images);
		});

		function getOrderContainer(?group:String = null):Dynamic {
			if (group != null) {
				var groupOrArray:Dynamic = LuaUtils.getObjectDirectly(group);
				if (groupOrArray == null)
					luaTrace('Object order: Group $group doesn\'t exist!', false, false, ERROR);
				return groupOrArray;
			}

			return CustomSubstate.instance != null ? CustomSubstate.instance : LuaUtils.getTargetInstance();
		}

		function getOrderMembers(container:Dynamic):Array<Dynamic> {
			if(container == null)
				return null;
			if(Type.typeof(container).match(TClass(Array)))
				return cast container;

			var members:Dynamic = Reflect.getProperty(container, 'members');
			return members != null ? cast members : null;
		}

		function findOrderContainerFor(object:FlxBasic, root:Dynamic, depth:Int = 0):Dynamic {
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
		}

		function removeFromOrderContainer(container:Dynamic, object:FlxBasic):Void {
			if(container == null || object == null)
				return;

			if(Type.typeof(container).match(TClass(Array)))
				container.remove(object);
			else if(Reflect.isFunction(Reflect.field(container, 'remove')))
				container.remove(object, true);
			else
				getOrderMembers(container)?.remove(object);
		}

		function insertIntoOrderContainer(container:Dynamic, index:Int, object:FlxBasic):Void {
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
		}

		function moveObjectRelative(obj:String, target:String, behind:Bool = true, ?group:String = null):Bool {
			var leObj:FlxBasic = LuaUtils.getObjectDirectly(obj);
			var targetObj:FlxBasic = LuaUtils.getObjectDirectly(target);
			var root:Dynamic = getOrderContainer(group);

			if (leObj == null) {
				luaTrace('moveObjectRelative: Object $obj doesn\'t exist!', false, false, ERROR);
				return false;
			}
			if (targetObj == null) {
				luaTrace('moveObjectRelative: Target $target doesn\'t exist!', false, false, ERROR);
				return false;
			}
			if (root == null)
				return false;

			var targetContainer:Dynamic = group != null ? root : findOrderContainerFor(targetObj, root);
			var sourceContainer:Dynamic = group != null ? root : findOrderContainerFor(leObj, root);
			if (targetContainer == null) {
				luaTrace('moveObjectRelative: Target $target is not inside the selected state/group!', false, false, ERROR);
				return false;
			}

			var members:Array<Dynamic> = getOrderMembers(targetContainer);
			var targetIndex:Int = members.indexOf(targetObj);
			if (targetIndex < 0) {
				luaTrace('moveObjectRelative: Target $target is not inside the selected state/group!', false, false, ERROR);
				return false;
			}

			var oldIndex:Int = (sourceContainer == targetContainer) ? members.indexOf(leObj) : -1;
			if (oldIndex >= 0 && oldIndex < targetIndex)
				targetIndex--;

			if(sourceContainer != null)
				removeFromOrderContainer(sourceContainer, leObj);

			var insertIndex:Int = behind ? targetIndex : targetIndex + 1;
			insertIntoOrderContainer(targetContainer, insertIndex, leObj);
			return true;
		}

		//shitass stuff for epic coders like me B)  *image of obama giving himself a medal*
		registerFunction('getObjectOrder', function(obj:String, ?group:String = null) {
			var leObj:FlxBasic = LuaUtils.getObjectDirectly(obj);
			
			if (leObj != null) {
				if (group != null) {
					var groupOrArray:Dynamic = LuaUtils.getObjectDirectly(group);
					if (groupOrArray != null) {
						switch (Type.typeof(groupOrArray)) {
							case TClass(Array): //Is Array
								return groupOrArray.indexOf(leObj);
							default: //Is Group
								return Reflect.getProperty(groupOrArray, 'members').indexOf(leObj); //Has to use a Reflect here because of FlxTypedSpriteGroup
						}
					} else {
						luaTrace('getObjectOrder: Group $group doesn\'t exist!', false, false, ERROR);
						return -1;
					}
				}
				var groupOrArray:Dynamic = CustomSubstate.instance != null ? CustomSubstate.instance : LuaUtils.getTargetInstance();
				return groupOrArray.members.indexOf(leObj);
			}
			
			luaTrace('getObjectOrder: Object $obj doesn\'t exist!', false, false, ERROR);
			return -1;
		});
		registerFunction('setObjectOrder', function(obj:String, position:Int, ?group:String = null) {
			var leObj:FlxBasic = LuaUtils.getObjectDirectly(obj);
			
			if (leObj != null) {
				if (group != null) {
					var groupOrArray:Dynamic = LuaUtils.getObjectDirectly(group);
					if (groupOrArray != null) {
						switch (Type.typeof(groupOrArray)) {
							case TClass(Array): //Is Array
								groupOrArray.remove(leObj);
								groupOrArray.insert(position, leObj);
							default: //Is Group
								groupOrArray.remove(leObj, true);
								groupOrArray.insert(position, leObj);
						}
					}
					else luaTrace('setObjectOrder: Group $group doesn\'t exist!', false, false, ERROR);
				}
				else {
					var groupOrArray:Dynamic = (CustomSubstate.instance != null ? CustomSubstate.instance : LuaUtils.getTargetInstance());
					groupOrArray.remove(leObj, true);
					groupOrArray.insert(position, leObj);
				}
				return;
			}
			
			luaTrace('setObjectOrder: Object $obj doesn\'t exist!', false, false, ERROR);
		});
		registerFunction('setObjectBehind', function(obj:String, target:String, ?group:String = null) {
			return moveObjectRelative(obj, target, true, group);
		});
		registerFunction('setObjectInFront', function(obj:String, target:String, ?group:String = null) {
			return moveObjectRelative(obj, target, false, group);
		});

		// gay ass tweens
		registerFunction('startTween', function(tag:String, vars:String, values:Any = null, duration:Float, ?options:Any = null) {
			var owner:FunkinLua = currentCallbackOwner();
			var ownerState:FlxState = currentCallbackState(owner);
			var penisExam:Dynamic = LuaUtils.tweenPrepare(tag, vars);
			if (penisExam != null) {
				if (values != null) {
					LuaUtils.cancelTweensOf(penisExam, values);
					var myOptions:LuaTweenOptions = LuaUtils.getLuaTween(options);
					if (tag != null) {
						var originalTag:String = tag;
						var variables = MusicBeatState.getVariables();
						tag = LuaUtils.formatVariable('tween_$tag');
						variables.set(tag, FlxTween.tween(penisExam, values, duration, myOptions != null ? {
							type: myOptions.type,
							ease: myOptions.ease,
							startDelay: myOptions.startDelay,
							loopDelay: myOptions.loopDelay,
	
							onUpdate: (myOptions.onUpdate == null ? null : function(twn:FlxTween) luaCallGlobalFrom(owner, ownerState, myOptions.onUpdate, [originalTag, vars])),
							onStart: (myOptions.onUpdate == null ? null : function(twn:FlxTween) luaCallGlobalFrom(owner, ownerState, myOptions.onStart, [originalTag, vars])),
							onComplete: function(twn:FlxTween) {
								if (twn.type == FlxTweenType.ONESHOT || twn.type == FlxTweenType.BACKWARD) variables.remove(tag);
								if (myOptions.onComplete != null) luaCallGlobalFrom(owner, ownerState, myOptions.onComplete, [originalTag, vars]);
							}
						} : null));
						return tag;
					} else {
						FlxTween.tween(penisExam, values, duration, myOptions != null ? {
							type: myOptions.type,
							ease: myOptions.ease,
							startDelay: myOptions.startDelay,
							loopDelay: myOptions.loopDelay,
							
							onComplete: (myOptions.onComplete == null ? null : function(twn:FlxTween) luaCallGlobalFrom(owner, ownerState, myOptions.onComplete, [null, vars])),
							onUpdate: (myOptions.onUpdate == null ? null : function(twn:FlxTween) luaCallGlobalFrom(owner, ownerState, myOptions.onUpdate, [null, vars])),
							onStart: (myOptions.onStart == null ? null : function(twn:FlxTween) luaCallGlobalFrom(owner, ownerState, myOptions.onStart, [null, vars])),
						} : null);
					}
				} else {
					luaTrace('startTween: No values provided on 2nd argument!', false, false, ERROR);
				}
			}
			else luaTrace('startTween: Couldnt find object: ' + vars, false, false, ERROR);
			return null;
		});

		registerFunction('doTweenX', function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') return oldTweenFunction(tag, vars, {x: value}, duration, ease, 'doTweenX'));
		registerFunction('doTweenY', function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') return oldTweenFunction(tag, vars, {y: value}, duration, ease, 'doTweenY'));
		registerFunction('doTweenAngle', function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') return oldTweenFunction(tag, vars, {angle: value}, duration, ease, 'doTweenAngle'));
		registerFunction('doTweenAlpha', function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') return oldTweenFunction(tag, vars, {alpha: value}, duration, ease, 'doTweenAlpha'));
		registerFunction('doTweenZoom', function(tag:String, camera:String, value:Dynamic, duration:Float, ?ease:String = 'linear') return oldTweenFunction(tag, LuaUtils.cameraString(camera), {zoom: value}, duration, ease, 'doTweenZoom'));
		registerFunction('doTweenColor', function(tag:String, vars:String, targetColor:String, duration:Float, ?ease:String = 'linear') {
			var owner:FunkinLua = currentCallbackOwner();
			var ownerState:FlxState = currentCallbackState(owner);
			var penisExam:Dynamic = LuaUtils.tweenPrepare(tag, vars);
			if (penisExam != null) {
				FlxTween.cancelTweensOf(penisExam, ['color', 'alpha']);
				var curColor:FlxColor = penisExam.color;
				curColor.alphaFloat = penisExam.alpha;
				
				if(tag != null) {
					var originalTag:String = tag;
					tag = LuaUtils.formatVariable('tween_$tag');
					var variables = MusicBeatState.getVariables();
					variables.set(tag, FlxTween.color(penisExam, duration, curColor, CoolUtil.colorFromString(targetColor), {ease: LuaUtils.getTweenEaseByString(ease),
						onComplete: function(twn:FlxTween) {
							variables.remove(tag);
							luaCallGlobalFrom(owner, ownerState, 'onTweenCompleted', [originalTag, vars]);
						}
					}));
					return tag;
				} else {
					FlxTween.color(penisExam, duration, curColor, CoolUtil.colorFromString(targetColor), {ease: LuaUtils.getTweenEaseByString(ease)});
				}
			}
			else luaTrace('doTweenColor: Couldnt find object: ' + vars, false, false, ERROR);
			return null;
		});

		registerFunction('doTweenVolume', function(tag:String, vars:String, value:Float, duration:Float, ?ease:String = 'linear') {
			var owner:FunkinLua = currentCallbackOwner();
			var ownerState:FlxState = currentCallbackState(owner);
			var target:Dynamic = null;
			vars = vars.trim();
			if (vars == null || vars == '') {
				target = FlxG.sound.music;
			} else {
				target = MusicBeatState.getVariables().get(LuaUtils.formatVariable('sound_$vars'));
			}

			if (target != null) {
				LuaUtils.cancelTweensOf(target, {volume: value});
				
				if (tag != null && tag != '') {
					var originalTag:String = tag;
					tag = LuaUtils.formatVariable('tween_$tag');
					
					var variables = MusicBeatState.getVariables();
					variables.set(tag, FlxTween.tween(target, {volume: value}, duration, {
						ease: LuaUtils.getTweenEaseByString(ease),
						onComplete: function(twn:FlxTween) {
							variables.remove(tag);
							luaCallGlobalFrom(owner, ownerState, 'onTweenCompleted', [originalTag, vars]);
						}
					}));
					return tag;
				} else {
					FlxTween.tween(target, {volume: value}, duration, {ease: LuaUtils.getTweenEaseByString(ease)});
				}
			} else {
				luaTrace('doTweenVolume: Coudnt find sound/music: ' + vars, false, false, ERROR);
			}
			return null;
		});

		registerFunction('cancelTween', function(tag:String) LuaUtils.cancelTween(tag));
		registerFunction('cancelTimer', function(tag:String) LuaUtils.cancelTimer(tag));
		
		registerFunction('runTimer', function(tag:String, time:Float = 1, loops:Int = 1) {
			var owner:FunkinLua = currentCallbackOwner();
			var ownerState:FlxState = currentCallbackState(owner);
			LuaUtils.cancelTimer(tag);
			var variables = MusicBeatState.getVariables();
			
			var originalTag:String = tag;
			tag = LuaUtils.formatVariable('timer_$tag');
			variables.set(tag, new FlxTimer().start(time, function(tmr:FlxTimer) {
				if (tmr.finished) variables.remove(tag);
				luaCallGlobalFrom(owner, ownerState, 'onTimerCompleted', [originalTag, tmr.loops, tmr.loopsLeft]);
				//trace('Timer Completed: ' + tag);
			}, loops));
			return tag;
		});
		
		// yippee!
		registerFunction('resetState', function() {
			FlxG.state.persistentUpdate = false;
			MusicBeatState.resetState();
		});
		registerFunction('changeRes', function(width:Int, height:Int, resizable:Bool = true) return ResolutionManager.changeRes(width, height, resizable));
		registerFunction('ChangeRes', function(width:Int, height:Int, resizable:Bool = true) return ResolutionManager.changeRes(width, height, resizable));
		registerFunction('resetRes', function() return ResolutionManager.reset());
		registerFunction('ResetRes', function() return ResolutionManager.reset());
		registerFunction('addCamera', function(tag:String, bgColor:String = '00000000', x:Float = 0, y:Float = 0, width:Int = -1, height:Int = -1, zoom:Float = 1, front:Bool = false) {
			var host:Dynamic = cameraHost();
			return host != null && host.addCamera(tag, bgColor, x, y, width, height, zoom, front) != null;
		});
		registerFunction('removeCamera', function(tag:String, destroy:Bool = true) {
			var host:Dynamic = cameraHost();
			return host != null && host.removeCamera(tag, destroy);
		});
		registerFunction('setMainCamera', function(tag:String) {
			var host:Dynamic = cameraHost();
			return host != null && host.setMainCamera(tag);
		});
		registerFunction('setCameraOrder', function(tag:String, index:Int) {
			var host:Dynamic = cameraHost();
			return host != null && host.setCameraOrder(tag, index);
		});
		registerFunction('tweenRes', function(width:Int, height:Int, duration:Float = 1, ease:String = 'linear', resizable:Bool = true) // never tested btw
			return ResolutionManager.tweenRes(width, height, duration, LuaUtils.getTweenEaseByString(ease), resizable) != null);
		registerFunction('TweenRes', function(width:Int, height:Int, duration:Float = 1, ease:String = 'linear', resizable:Bool = true)
			return ResolutionManager.tweenRes(width, height, duration, LuaUtils.getTweenEaseByString(ease), resizable) != null);
		registerFunction('tweenResFrom', function(fromWidth:Int, fromHeight:Int, toWidth:Int, toHeight:Int, duration:Float = 1, ease:String = 'linear', resizable:Bool = true)
			return ResolutionManager.tweenResFrom(fromWidth, fromHeight, toWidth, toHeight, duration, LuaUtils.getTweenEaseByString(ease), resizable) != null);
		registerFunction('doTweenRes', function(tag:String, width:Int, height:Int, duration:Float, ease:String = 'linear', resizable:Bool = true) {
			var owner:FunkinLua = currentCallbackOwner();
			var ownerState:FlxState = currentCallbackState(owner);
			var variables = MusicBeatState.getVariables();
			var originalTag:String = tag;
			tag = LuaUtils.formatVariable('tween_$tag');
			LuaUtils.cancelTween(tag);
			variables.set(tag, ResolutionManager.tweenRes(width, height, duration, LuaUtils.getTweenEaseByString(ease), resizable, function(twn:FlxTween) {
				variables.remove(tag);
				luaCallGlobalFrom(owner, ownerState, 'onTweenCompleted', [originalTag, 'resolution']);
			}));
			return tag;
		});
		registerFunction('doTweenResolution', function(tag:String, width:Int, height:Int, duration:Float, ease:String = 'linear', resizable:Bool = true) {
			var owner:FunkinLua = currentCallbackOwner();
			var ownerState:FlxState = currentCallbackState(owner);
			var variables = MusicBeatState.getVariables();
			var originalTag:String = tag;
			tag = LuaUtils.formatVariable('tween_$tag');
			LuaUtils.cancelTween(tag);
			variables.set(tag, ResolutionManager.tweenRes(width, height, duration, LuaUtils.getTweenEaseByString(ease), resizable, function(twn:FlxTween) {
				variables.remove(tag);
				luaCallGlobalFrom(owner, ownerState, 'onTweenCompleted', [originalTag, 'resolution']);
			}));
			return tag;
		});
		registerFunction('cancelTweenRes', function() ResolutionManager.cancelTweenRes());

		//Identical functions
		registerFunction('FlxColor', function(color:String) return FlxColor.fromString(color));
		registerFunction('getColorFromName', function(color:String) return FlxColor.fromString(color));
		registerFunction('getColorFromString', function(color:String) return FlxColor.fromString(color));
		registerFunction('getColorFromHex', function(color:String) return FlxColor.fromString('#$color'));

		function stateScriptsUseMenuMusic():Bool
		{
			return Std.isOfType(FlxG.state, ScriptedState) && !Std.isOfType(FlxG.state, PlayState);
		}

		function resolveScriptMusic(name:String)
		{
			return stateScriptsUseMenuMusic() ? Paths.menuMusic(name) : Paths.music(name);
		}

		// precaching
		registerFunction('precacheImage', function(name:String, ?allowGPU:Bool = true) Paths.image(name, allowGPU));
		registerFunction('precacheSound', function(name:String) Paths.sound(name));
		registerFunction('precacheMusic', function(name:String) resolveScriptMusic(name));
		registerFunction('precacheMenuMusic', function(name:String, ?track:String = 'music') Paths.menuMusic(name, track));
		registerFunction('preloadVideo', function(name:String) return LoadingState.preloadVideo(name) != null);
		registerFunction('precacheVideo', function(name:String) return LoadingState.preloadVideo(name) != null);
		
		registerFunction('getSongPosition', () -> Conductor.songPosition);
		registerFunction('setSongTime', function(time:Float, ?offset:Bool = true, ?clearPastNotes:Bool = true) {
			if(game == null)
				return false;
			game.setSongTime(time, offset);
			if(clearPastNotes)
				game.clearNotesBefore(Conductor.songPosition);
			return true;
		});

		registerFunction('setCameraScroll', function(x:Float, y:Float) backend.CameraResizeFix.centralizarScroll(FlxG.camera, x, y));
		registerFunction('addCameraScroll', function(?x:Float = 0, ?y:Float = 0) FlxG.camera.scroll.add(x, y));
		registerFunction('desgracaX', () -> backend.CameraResizeFix.desgracaX(FlxG.camera));
		registerFunction('desgracaY', () -> backend.CameraResizeFix.desgracaY(FlxG.camera));

		registerFunction('cameraShake', function(camera:String, intensity:Float, duration:Float) LuaUtils.cameraFromString(camera).shake(intensity, duration));
		registerFunction('cameraFlash', function(camera:String, color:String, duration:Float, forced:Bool) {
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			backend.CameraResizeFix.aplyCentroOFS(cam);
			cam.flash(CoolUtil.colorFromString(color), duration, null, forced);
			backend.CameraResizeFix.aplyCentroOFS(cam);
		});
		registerFunction('cameraFade', function(camera:String, color:String, duration:Float, forced:Bool, ?fadeOut:Bool = false) LuaUtils.cameraFromString(camera).fade(CoolUtil.colorFromString(color), duration, fadeOut, null, forced));
		registerFunction('setCameraAngle', function(camera:String, angle:Float) {
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if(cam != null)
				cam.angle = angle;
			return angle;
		});
		registerFunction('addCameraAngle', function(camera:String, angle:Float) {
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if(cam != null)
				cam.angle += angle;
			return cam != null ? cam.angle : 0;
		});
		registerFunction('getCameraAngle', function(camera:String) {
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			return cam != null ? cam.angle : 0;
		});
		registerFunction('setCameraRotateSprite', function(camera:String, rotateSprite:Bool = false) {
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if(Std.isOfType(cam, backend.PsychCamera))
			{
				cast(cam, backend.PsychCamera).rotateSprite = rotateSprite;
				return true;
			}
			return false;
		});

		registerFunction('getMidpointX', function(variable:String) {
			var obj:FlxObject = LuaUtils.getObjectDirectly(variable);
			if (obj != null) return obj.getMidpoint().x;

			return 0;
		});
		registerFunction('getMidpointY', function(variable:String) {
			var obj:FlxObject = LuaUtils.getObjectDirectly(variable);
			if (obj != null) return obj.getMidpoint().y;

			return 0;
		});
		registerFunction('getGraphicMidpointX', function(variable:String) {
			var obj:FlxSprite = LuaUtils.getObjectDirectly(variable);
			if (obj != null) return obj.getGraphicMidpoint().x;

			return 0;
		});
		registerFunction('getGraphicMidpointY', function(variable:String) {
			var obj:FlxSprite = LuaUtils.getObjectDirectly(variable);
			if (obj != null) return obj.getGraphicMidpoint().y;

			return 0;
		});
		registerFunction('getScreenPositionX', function(variable:String, ?camera:String = 'game') {
			var obj:FlxObject = LuaUtils.getObjectDirectly(variable);
			if (obj != null) return obj.getScreenPosition(LuaUtils.cameraFromString(camera)).x;

			return 0;
		});
		registerFunction('getScreenPositionY', function(variable:String, ?camera:String = 'game') {
			var obj:FlxObject = LuaUtils.getObjectDirectly(variable);
			if (obj != null) return obj.getScreenPosition(LuaUtils.cameraFromString(camera)).y;

			return 0;
		});
		registerFunction('characterDance', function(character:String) {
			if (game != null) {
				switch (character.toLowerCase()) {
					case 'gf' | 'girlfriend': return game.gf?.dance();
					case 'boyfriend': return game.boyfriend.dance();
					case 'dad': return game.dad.dance();
				}
			}
			
			var char:Dynamic = LuaUtils.getObjectDirectly(character);
			if (char != null && char.dance != null) {
				char.dance();
				return;
			}
			
			game?.boyfriend.dance();
		});

		registerFunction('makeLuaSprite', function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0) {
			if (tag == null || tag.trim().length < 1)
				return false;

			tag = tag.replace('.', '');
			var state:FlxState = getCallbackState();
			var variables:Map<String, Dynamic> = getCallbackVariables();
			LuaUtils.destroyObject(tag, state);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			
			if (image != null && image.length > 0)
			{
				var graphic = Paths.image(image);
				if(graphic == null)
				{
					luaTrace('makeLuaSprite: image "$image" could not be found.', false, false, ERROR); // ik, ik, i also hate silent shit
					return false;
				}
				leSprite.loadGraphic(graphic);
			}
			
			variables.set(tag, leSprite);
			leSprite.active = true;
			return true;
		});
		registerFunction('makeAnimatedLuaSprite', function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0, ?spriteType:String = 'auto') {
			if (tag == null || tag.trim().length < 1)
				return false;

			tag = tag.replace('.', '');
			var state:FlxState = getCallbackState();
			var variables:Map<String, Dynamic> = getCallbackVariables();
			LuaUtils.destroyObject(tag, state);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);

			if (image != null && image.length > 0)
				LuaUtils.loadFrames(leSprite, image, spriteType);

			variables.set(tag, leSprite);
			return true;
		});
		var makePerspectiveSpriteFunc = function(tag:String, ?image:String = null, ?bottomX:Float = 0, ?bottomY:Float = 0, ?topX:Float = 0, ?topY:Float = 0) {
			if(tag == null)
				return false;
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var leSprite:PerspectiveSprite = new PerspectiveSprite();

			if (image != null && image.length > 0)
				leSprite.loadGraphic(Paths.image(image));

			leSprite.setPositions(bottomX, bottomY, topX, topY);
			MusicBeatState.getVariables().set(tag, leSprite);
			leSprite.active = true;
			return true;
		};
		var getPerspectiveSprite = function(tag:String):PerspectiveSprite {
			var obj:Dynamic = LuaUtils.getObjectDirectly(tag);
			return Std.isOfType(obj, PerspectiveSprite) ? cast obj : null;
		};
		registerFunction('makePerspectiveSprite', makePerspectiveSpriteFunc);
		registerFunction('makeLuaPerspectiveSprite', makePerspectiveSpriteFunc);
		registerFunction('setPerspectivePositions', function(tag:String, bottomX:Float, bottomY:Float, topX:Float, topY:Float) {
			var leSprite = getPerspectiveSprite(tag);
			if(leSprite == null)
				return false;
			leSprite.setPositions(bottomX, bottomY, topX, topY);
			return true;
		});
		registerFunction('setPerspectiveWidths', function(tag:String, bottomWidth:Float, topWidth:Float) {
			var leSprite = getPerspectiveSprite(tag);
			if(leSprite == null)
				return false;
			leSprite.setWidths(bottomWidth, topWidth);
			return true;
		});
		registerFunction('setPerspectiveScrollFactors', function(tag:String, bottomX:Float, bottomY:Float, topX:Float, topY:Float) {
			var leSprite = getPerspectiveSprite(tag);
			if(leSprite == null)
				return false;
			leSprite.setScrollFactors(bottomX, bottomY, topX, topY);
			return true;
		});
		registerFunction('updatePerspectiveSprite', function(tag:String, ?camera:String = 'game') {
			var leSprite = getPerspectiveSprite(tag);
			if(leSprite == null)
				return false;
			leSprite.updateSkew(LuaUtils.cameraFromString(camera));
			return true;
		});
		registerFunction('updatePerspectiveSkew', function(tag:String, ?camera:String = 'game') {
			var leSprite = getPerspectiveSprite(tag);
			if(leSprite == null)
				return false;
			leSprite.updateSkew(LuaUtils.cameraFromString(camera));
			return true;
		});

		registerFunction('makeGraphic', function(obj:String, width:Int = 256, height:Int = 256, color:String = 'FFFFFF') {
			var spr:FlxSprite = LuaUtils.getObjectDirectly(obj);
			
			if (spr != null) spr.makeGraphic(width, height, CoolUtil.colorFromString(color));
		});
		registerFunction('makeGradient', function(obj:String, width:Int = 256, height:Int = 256, colors:Dynamic = null, ?alphas:Dynamic = null, rotation:Int = 90,
			chunkSize:Int = 1, interpolate:Bool = true) {
			return backend.GradientUtil.applyToSprite(LuaUtils.getObjectDirectly(obj), width, height, colors, alphas, rotation, chunkSize, interpolate);
		});
		var makeLuaGradientFunc = function(tag:String, width:Int = 256, height:Int = 256, colors:Dynamic = null, ?alphas:Dynamic = null, ?x:Float = 0,
			?y:Float = 0, rotation:Int = 90, chunkSize:Int = 1, interpolate:Bool = true) {
			if(tag == null)
				return false;
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			backend.GradientUtil.applyToSprite(leSprite, width, height, colors, alphas, rotation, chunkSize, interpolate);
			MusicBeatState.getVariables().set(tag, leSprite);
			leSprite.active = true;
			return true;
		};
		registerFunction('makeLuaGradient', makeLuaGradientFunc);
		registerFunction('makeGradientSprite', makeLuaGradientFunc);
		registerFunction('setGradientStop', function(obj:String, index:Int, ?color:Dynamic = null, ?alpha:Dynamic = null) {
			return backend.GradientUtil.setStop(LuaUtils.getObjectDirectly(obj), index, color, alpha);
		});
		var tweenGradientFunc = function(tag:String, obj:String, colors:Dynamic = null, ?alphas:Dynamic = null, duration:Float = 1, ?ease:String = 'linear') {
			var owner:FunkinLua = currentCallbackOwner();
			var ownerState:FlxState = currentCallbackState(owner);
			var spr:FlxSprite = LuaUtils.getObjectDirectly(obj);
			if(spr == null)
			{
				luaTrace('tweenGradient: Couldnt find object: ' + obj, false, false, ERROR);
				return null;
			}

			var variables = MusicBeatState.getVariables();
			var originalTag:String = tag;
			tag = LuaUtils.formatVariable('tween_$tag');
			LuaUtils.cancelTween(originalTag);
			variables.set(tag, backend.GradientUtil.tweenSprite(spr, colors, alphas, duration, LuaUtils.getTweenEaseByString(ease), function(twn:FlxTween) {
				variables.remove(tag);
				luaCallGlobalFrom(owner, ownerState, 'onTweenCompleted', [originalTag, obj]);
			}));
			return tag;
		};
		registerFunction('tweenGradient', tweenGradientFunc);
		registerFunction('doTweenGradient', tweenGradientFunc);
		var tweenGradientAlphaFunc = function(tag:String, obj:String, alphas:Dynamic = null, duration:Float = 1, ?ease:String = 'linear') {
			var owner:FunkinLua = currentCallbackOwner();
			var ownerState:FlxState = currentCallbackState(owner);
			var spr:FlxSprite = LuaUtils.getObjectDirectly(obj);
			if(spr == null)
			{
				luaTrace('tweenGradientAlpha: Couldnt find object: ' + obj, false, false, ERROR);
				return null;
			}

			var variables = MusicBeatState.getVariables();
			var originalTag:String = tag;
			tag = LuaUtils.formatVariable('tween_$tag');
			LuaUtils.cancelTween(originalTag);
			variables.set(tag, backend.GradientUtil.tweenSpriteAlpha(spr, alphas, duration, LuaUtils.getTweenEaseByString(ease), function(twn:FlxTween) {
				variables.remove(tag);
				luaCallGlobalFrom(owner, ownerState, 'onTweenCompleted', [originalTag, obj]);
			}));
			return tag;
		};
		registerFunction('tweenGradientAlpha', tweenGradientAlphaFunc);
		registerFunction('doTweenGradientAlpha', tweenGradientAlphaFunc);
		var makeVignetteFunc = function(obj:String, width:Int = 0, height:Int = 0, color:String = '000000', strength:Float = 1, radius:Float = 0.55, softness:Float = 0.45) {
			var spr:FlxSprite = LuaUtils.getObjectDirectly(obj);
			if(spr == null)
				return false;

			if(Std.isOfType(spr, objects.VVIESpriteHandler))
				cast(spr, objects.VVIESpriteHandler).makeVignette(width, height, CoolUtil.colorFromString(color), strength, radius, softness);
			else
				spr.loadGraphic(backend.VignetteUtil.makeGraphic(width, height, CoolUtil.colorFromString(color), strength, radius, softness));
			return true;
		};
		registerFunction('makeVignette', makeVignetteFunc);
		registerFunction('makeVig', makeVignetteFunc);
		var addAnimByPrefix = function(obj:String, name:String, prefix:String, framerate:Float = 24, loop:Bool = true) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			
			if (obj != null) {
				if (obj.animation != null) {
					if(Std.isOfType(obj, FlxAnimate))
						AtlasUtil.addAnimation(obj, name, prefix, null, framerate, loop);
					else
						obj.animation.addByPrefix(name, prefix, framerate, loop);
					if (obj.animation.curAnim == null) {
						if (obj.playAnim != null) obj.playAnim(name, true);
						else obj.animation.play(name, true);
					}
					return true;
				}
			}
			return false;
		};
		registerFunction('addAnimationByPrefix', addAnimByPrefix);
		registerFunction('addAnim', addAnimByPrefix);

		registerFunction('addAnimation', function(obj:String, name:String, frames:Any, framerate:Float = 24, loop:Bool = true) return LuaUtils.addAnimByIndices(obj, name, null, frames, framerate, loop));
		registerFunction('addAnimationByIndices', function(obj:String, name:String, prefix:String, indices:Any, framerate:Float = 24, loop:Bool = false) return LuaUtils.addAnimByIndices(obj, name, prefix, indices, framerate, loop));

		registerFunction('playAnim', function(obj:String, name:String, ?forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			if(obj == null) return false;
			if(Std.isOfType(obj, Character) && name != null && name.startsWith('sing') && LuaUtils.currentCallbackIsSustainNote())
			{
				var characterObj:Character = cast obj;
				return characterObj.playSingAnimation(name, true);
			}

			if (obj.playAnim != null) {
				obj.playAnim(name, forced, reverse, startFrame);
				return true;
			} else {
				if (obj.anim != null) obj.anim.play(name, forced, reverse, startFrame); //FlxAnimate
				else obj.animation.play(name, forced, reverse, startFrame);
				return true;
			}
			return false;
		});
		registerFunction('addOffset', function(obj:String, anim:String, x:Float, y:Float) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			if (obj != null && obj.addOffset != null) {
				obj.addOffset(anim, x, y);
				return true;
			}
			return false;
		});

		registerFunction('setScrollFactor', function(obj:String, ?scrollX:Float, ?scrollY:Float) {
			var objectName:String = obj;
			var obj:Dynamic = LuaUtils.getObjectDirectly(objectName);
			if (obj != null) {
				obj.scrollFactor.set(scrollX, scrollY);
				return;
			}

			if (game != null && game.queueExtraCharacterScroll(objectName, scrollX, scrollY))
				return;

			luaTrace('setScrollFactor: Couldnt find object: ' + objectName, false, false, ERROR);
		});
		registerFunction('setGraphicSize', function(obj:String, x:Float, y:Float = 0, updateHitbox:Bool = true) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			if (obj != null) {
				obj.setGraphicSize(x, y);
				if (updateHitbox) obj.updateHitbox();
				return;
			}
			luaTrace('setGraphicSize: Couldnt find object: ' + obj, false, false, ERROR);
		});
		var fitObjectToCameraFunc = function(obj:String, camera:String = 'other', autoUpdate:Bool = true) {
			var object:FlxBasic = LuaUtils.getObjectDirectly(obj);
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			if(object == null)
			{
				luaTrace('fitObjectToCamera: Couldnt find object: ' + obj, false, false, ERROR);
				return false;
			}

			object.cameras = [cam];
			if(Std.isOfType(object, objects.VVIESpriteHandler))
			{
				cast(object, objects.VVIESpriteHandler).fitToCamera(cam, autoUpdate);
				return true;
			}

			if(Std.isOfType(object, FlxSprite))
			{
				var sprite:FlxSprite = cast object;
				sprite.scrollFactor.set();
				sprite.setPosition(backend.CameraResizeFix.pegarFSX(cam), backend.CameraResizeFix.pegarFSY(cam));
				sprite.setGraphicSize(Std.int(Math.ceil(backend.CameraResizeFix.pegarFSL(cam))), Std.int(Math.ceil(backend.CameraResizeFix.pegarFSA(cam))));
				sprite.updateHitbox();
				return true;
			}
			return false;
		};
		registerFunction('fitObjectToCamera', fitObjectToCameraFunc);
		registerFunction('fitObjectToScreen', fitObjectToCameraFunc);
		registerFunction('setObjectFullscreen', fitObjectToCameraFunc);
		registerFunction('scaleObject', function(obj:String, x:Float, y:Float, updateHitbox:Bool = true) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			if (obj != null) {
				obj.scale.set(x, y);
				if (updateHitbox) obj.updateHitbox();
				return;
			}
			luaTrace('scaleObject: Couldnt find object: ' + obj, false, false, ERROR);
		});
		registerFunction('updateHitbox', function(obj:String) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			if (obj != null) {
				obj.updateHitbox();
				return;
			}
			luaTrace('updateHitbox: Couldnt find object: ' + obj, false, false, ERROR);
		});

		registerFunction('removeLuaSprite', function(tag:String, destroy:Bool = true, ?group:String = null) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(tag);
			if (obj == null || obj.destroy == null)
				return false;
			
			var groupObj:Dynamic = group == null ? null : LuaUtils.getObjectDirectly(group);
			if (groupObj != null && groupObj.remove != null)
				groupObj.remove(obj, true);
			else
				LuaUtils.getTargetInstance()?.remove(obj, true);
			backend.StageDataController.unregisterFromScript(obj);
			
			if (destroy) {
				MusicBeatState.getVariables().remove(tag);
				obj.destroy();
			}
			return true;
		});

		registerFunction('luaSpriteExists', function(tag:String) {
			var obj:FlxSprite = getCallbackVariables().get(tag);
			return (obj != null && (Std.isOfType(obj, ModchartSprite) || Std.isOfType(obj, ModchartAnimateSprite)));
		});
		registerFunction('luaTextExists', function(tag:String) {
			var obj:FlxText = getCallbackVariables().get(tag);
			return (obj != null && Std.isOfType(obj, FlxText));
		});
		registerFunction('luaSoundExists', function(tag:String) {
			var obj:FlxSound = getCallbackVariables().get(LuaUtils.formatVariable('sound_$tag'));
			return (obj != null && Std.isOfType(obj, FlxSound));
		});

		registerFunction('setObjectCamera', function(obj:String, camera:String = 'game') {
			var object:FlxBasic = LuaUtils.getObjectDirectly(obj, false, getCallbackState());
			if (object != null) {
				object.cameras = [LuaUtils.cameraFromString(camera)];
				return true;
			}
			
			luaTrace("setObjectCamera: Object " + obj + " doesn't exist!", false, false, ERROR);
			return false;
		});
		registerFunction('setBlendMode', function(obj:String, blend:String = '') {
			var object:FlxSprite = LuaUtils.getObjectDirectly(obj);
			if (object != null) {
				object.blend = LuaUtils.blendModeFromString(blend);
				return true;
			}
			
			luaTrace("setBlendMode: Object " + obj + " doesn't exist!", false, false, ERROR);
			return false;
		});
		registerFunction('screenCenter', function(obj:String, pos:String = 'xy') {
			var object:FlxObject = LuaUtils.getObjectDirectly(obj);

			if (object != null) {
				object.screenCenter(switch (pos.trim().toLowerCase()) {
					case 'none': NONE; // are you stupid
					case 'x': X;
					case 'y': Y;
					default: XY;
				});
				return;
			}
			luaTrace("screenCenter: Object " + obj + " doesn't exist!", false, false, ERROR);
		});
		registerFunction('objectsOverlap', function(obj1:String, obj2:String) {
			var objectsArray:Array<FlxBasic> = [LuaUtils.getObjectDirectly(obj1), LuaUtils.getObjectDirectly(obj2)];
			
			return (!objectsArray.contains(null) && FlxG.overlap(objectsArray[0], objectsArray[1]));
		});
		registerFunction('getPixelColor', function(obj:String, x:Int, y:Int) {
			var object:FlxSprite = LuaUtils.getObjectDirectly(obj);

			if (object != null) return object.pixels.getPixel32(x, y);
			return FlxColor.BLACK;
		});
		
		// Sounds
		function getSound(tag:String):FlxSound {
			if (tag == null || tag.length < 1) {
				return FlxG.sound.music;
			} else {
				return MusicBeatState.getVariables().get(LuaUtils.formatVariable('sound_$tag'));
			}
		}
		registerFunction('playMusic', function(sound:String, ?volume:Float = 1, ?loop:Bool = false) FlxG.sound.playMusic(resolveScriptMusic(sound), volume, loop));
		registerFunction('playMenuMusic', function(sound:String, ?volume:Float = 1, ?loop:Bool = false, ?track:String = 'music') FlxG.sound.playMusic(Paths.menuMusic(sound, track), volume, loop));
		registerFunction('playSound', function(sound:String, ?volume:Float = 1, ?tag:String = null, ?loop:Bool = false):String {
			var owner:FunkinLua = currentCallbackOwner();
			var ownerState:FlxState = currentCallbackState(owner);
			if (tag != null && tag.length > 0) {
				var originalTag:String = tag;
				
				tag = LuaUtils.formatVariable('sound_$tag');
				var variables = MusicBeatState.getVariables();
				var oldSnd = variables.get(tag);
				if (oldSnd != null) {
					oldSnd.stop();
					oldSnd.destroy();
				}

				variables.set(tag, FlxG.sound.play(Paths.sound(sound), volume, loop, null, true, () -> {
					if (!loop) variables.remove(tag);
					luaCallGlobalFrom(owner, ownerState, 'onSoundFinished', [originalTag]);
				}));
				
				return tag;
			} else {
				FlxG.sound.play(Paths.sound(sound), volume);
			}
			return null;
		});
		registerFunction('stopSound', function(tag:String) {
			var snd:FlxSound = getSound(tag);
			snd?.stop();
			
			if (tag != null && tag.length > 0) {
				tag = LuaUtils.formatVariable('sound_$tag');
				MusicBeatState.getVariables().remove(tag);
			}
		});
		registerFunction('pauseSound', function(tag:String) getSound(tag)?.pause());
		registerFunction('resumeSound', function(tag:String) getSound(tag)?.resume());
		registerFunction('soundFadeIn', function(tag:String, duration:Float, fromValue:Float = 0, toValue:Float = 1) getSound(tag)?.fadeIn(duration, fromValue, toValue));
		registerFunction('soundFadeOut', function(tag:String, duration:Float, toValue:Float = 0) getSound(tag)?.fadeOut(duration, toValue));
		registerFunction('soundFadeCancel', function(tag:String) getSound(tag)?.fadeTween?.cancel());
		registerFunction('getSoundVolume', function(tag:String) return (getSound(tag)?.volume ?? 0));
		registerFunction('setSoundVolume', function(tag:String, value:Float) {
			var snd:FlxSound = getSound(tag);
			if (snd != null) snd.volume = value;
		});
		registerFunction('getSoundTime', function(tag:String) return (getSound(tag)?.time ?? 0));
		registerFunction('setSoundTime', function(tag:String, value:Float) {
			var snd:FlxSound = getSound(tag);
			if (snd != null) snd.time = value;
		});
		registerFunction('getSoundPitch', function(tag:String) {
			#if FLX_PITCH
			return (getSound(tag)?.pitch ?? 1);
			#else
			luaTrace("getSoundPitch: Sound Pitch is not supported on this platform!", false, false, ERROR);
			return 1;
			#end
		});
		registerFunction('setSoundPitch', function(tag:String, value:Float, ?doPause:Bool = false) {
			#if FLX_PITCH
			var snd:FlxSound = getSound(tag);
			if (snd != null) {
				var wasResumed:Bool = snd.playing;
				if (doPause) snd.pause();
				snd.pitch = value;
				if (doPause && wasResumed) snd.play();
			}
			#else
			luaTrace("setSoundPitch: Sound Pitch is not supported on this platform!", false, false, ERROR);
			#end
		});
	}
	public static function implementGame(game:PlayState):Void {
		// trace('implement game functions');
		
		#if UNHOLYWANDERER04
		var unholyed:Bool = false;
		registerFunction(lua, 'unholywanderer04', function() {
			var fgame:Main.UnholyGame = cast FlxG.game;
			if (fgame.frameCounter % 2 == 1) {
				FlxG.resetGame();
			} else if (!unholyed) {
				var unholy:FlxSprite = new FlxSprite().loadGraphic(Paths.image('unholywanderer04', 'embed'));
				unholy.antialiasing = ClientPrefs.data.antialiasing;
				unholy.setGraphicSize(FlxG.width, FlxG.height);
				unholy.updateHitbox();
				unholy.alpha = 0;
				unholyed = true;
				game.uiGroup.insert(0, unholy);
				FlxTween.tween(unholy, {alpha: 1}, 3);
			}
		});
		#end
		
		registerFunction('addScore', function(value:Int = 0) {
			game.songScore += value;
			game.RecalculateRating();
		});
		registerFunction('addMisses', function(value:Int = 0) {
			game.songMisses += value;
			game.RecalculateRating();
		});
		registerFunction('addHits', function(value:Int = 0) {
			game.songHits += value;
			game.RecalculateRating();
		});
		registerFunction('setScore', function(value:Int = 0) {
			game.songScore = value;
			game.RecalculateRating();
		});
		registerFunction('setMisses', function(value:Int = 0) {
			game.songMisses = value;
			game.RecalculateRating();
		});
		registerFunction('setHits', function(value:Int = 0) {
			game.songHits = value;
			game.RecalculateRating();
		});
		registerFunction('setHealth', function(value:Float = 1) game.health = value);
		registerFunction('addHealth', function(value:Float = 0) game.health += value);
		registerFunction('getHealth', function() return game.health);
		registerFunction('setRatingPercent', function(value:Float) {
			game.ratingPercent = value;
			game.setOnScripts('rating', game.ratingPercent);
		});
		registerFunction('setRatingName', function(value:String) {
			game.ratingName = value;
			game.setOnScripts('ratingName', game.ratingName);
		});
		registerFunction('setRatingFC', function(value:String) {
			game.ratingFC = value;
			game.setOnScripts('ratingFC', game.ratingFC);
		});
		registerFunction('updateScoreText', function() game.updateScoreText());
		
		// precaching
		registerFunction('addCharacterToList', function(name:String, type:String) {
			game.addCharacterToList(name, switch (type.toLowerCase()) {
				case 'gf' | 'girlfriend': 2;
				case 'dad': 1;
				default: 0;
			});
		});
		registerFunction('createChar', function(name:String, ?x:Float = 0, ?y:Float = 0, ?noteType:String = '', ?isPlayer:Bool = false, ?offsetSide:String = null) {
			return game.createChar(name, x, y, noteType, isPlayer, offsetSide);
		});
		registerFunction('createCharacter', function(name:String, ?x:Float = 0, ?y:Float = 0, ?noteType:String = '', ?isPlayer:Bool = false, ?offsetSide:String = null) {
			return game.createChar(name, x, y, noteType, isPlayer, offsetSide);
		});
		registerFunction('getCharacterTag', function(name:String) {
			return game.getExtraCharacterTag(name);
		});
		
		// others
		registerFunction('triggerEvent', function(name:String, ?value1:String = '', ?value2:String = '') {
			game.triggerEvent(name, value1, value2, Conductor.songPosition);
			return true;
		});
		registerFunction('startCountdown', function() {
			game.startCountdown();
			return true;
		});
		registerFunction('endSong', function() {
			game.KillNotes();
			game.endSong();
			return true;
		});
		registerFunction('restartSong', function(skipTransition:Bool = false) {
			game.persistentUpdate = false;
			FlxG.camera.followLerp = 0;
			PlayState.restartSong(skipTransition);
			return true;
		});
		registerFunction('exitSong', function(skipTransition:Bool = false) {
			#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
			PlayState.deathCounter = 0;
			PlayState.seenCutscene = false;

			PlayState.instance.canResync = false;
			var target = game.subState != null ? game.subState : game;
			if (PlayState.isStoryMode)
			{
				PlayState.storyPlaylist = [];
				if (skipTransition) {
					FlxG.switchState(() -> new StoryMenuState());
					FlxTransitionableState.skipNextTransOut = true;
					FlxG.sound.playMusic(Paths.menuMusic('mainMenu'));
				} else {
					if (Mods.modUsesStickerTrans()) {
						target.openSubState(new StickerSubState(null, (sticker) -> new StoryMenuState(sticker)));
					} else {
						MusicBeatState.switchState(new StoryMenuState());
						FlxG.sound.playMusic(Paths.menuMusic('mainMenu'));
					}
				}
			}
			else
			{
				if(skipTransition) {
					FlxG.switchState(() -> new FreeplayState());
					FlxTransitionableState.skipNextTransOut = true;
					FlxG.sound.playMusic(Paths.menuMusic('mainMenu'));
				} else {
					if (Mods.modUsesStickerTrans()) {
						target.openSubState(new StickerSubState(null, (sticker) -> new FreeplayState(sticker)));
					} else {
						MusicBeatState.switchState(new FreeplayState());
						FlxG.sound.playMusic(Paths.menuMusic('mainMenu'));
					}
				}
			}
			PlayState.changedDifficulty = false;
			PlayState.chartingMode = false;
			FlxG.camera.followLerp = 0;
			return true;
		});
		
		// idk bro
		registerFunction('setHealthBarColors', function(left:String, right:String) {
			var left_color:Null<FlxColor> = null;
			var right_color:Null<FlxColor> = null;
			if (left != null && left != '')
				left_color = CoolUtil.colorFromString(left);
			if (right != null && right != '')
				right_color = CoolUtil.colorFromString(right);
			game.healthBar.setColors(left_color, right_color);
		});
		registerFunction('setTimeBarColors', function(left:String, right:String) {
			var left_color:Null<FlxColor> = null;
			var right_color:Null<FlxColor> = null;
			if (left != null && left != '')
				left_color = CoolUtil.colorFromString(left);
			if (right != null && right != '')
				right_color = CoolUtil.colorFromString(right);
			game.timeBar.setColors(left_color, right_color);
		});
		registerFunction('startDialogue', function(dialogueFile:String, ?music:String = null) {
			if(!DialoguePlus.start(game, dialogueFile, music)) {
				luaTrace('startDialogue: Dialogue file not found', false, false, ERROR);
				if (game.endingSong) {
					game.endSong();
				} else {
					game.startCountdown();
				}
				return false;
			}
			return true;
		});
		registerFunction('startDialoguePlus', function(dialogueFile:String = 'dialogue', ?music:String = null) return game.startDialoguePlus(dialogueFile, music));

		#if VIDEOS_ALLOWED
		function getVideoObject(tag:String):VideoSprite
		{
			if(tag == null)
				return null;
			if(game != null && game.videoCutscene != null && tag == 'videoCutscene')
				return game.videoCutscene;
			var obj:Dynamic = MusicBeatState.getVariables().get(tag.replace('.', ''));
			return Std.isOfType(obj, VideoSprite) ? cast obj : null;
		}
		function makeVideoCallback(tag:String, videoFile:String, ?x:Float = 0, ?y:Float = 0, ?camera:String = 'other', ?canSkip:Bool = false, ?pauseWithGame:Bool = true, ?shouldLoop:Bool = false, ?playOnLoad:Bool = true, ?syncWithSong:Bool = false) {
			#if VIDEOS_ALLOWED
			if(game == null)
				return false;
			return game.createVideo(tag, videoFile, x, y, camera, canSkip, pauseWithGame, shouldLoop, playOnLoad, syncWithSong) != null;
			#else
			luaTrace('makeVideo: Platform not supported!', false, false, ERROR);
			return false;
			#end
		}
		registerFunction('makeVideo', makeVideoCallback);
		registerFunction('makeLuaVideo', makeVideoCallback);
		registerFunction('addVideo', function(tag:String, ?front:Bool = true) {
			var video:VideoSprite = getVideoObject(tag);
			if(video == null || game == null) {
				luaTrace('addVideo: Video "$tag" does not exist!', false, false, ERROR);
				return false;
			}
			if(front) game.add(video);
			else game.insert(0, video);
			if(video.playOnAdd) {
				video.playOnAdd = false;
				video.play();
			}
			return true;
		});
		registerFunction('removeVideo', function(tag:String, ?destroy:Bool = true) {
			return game != null && game.removeVideo(tag, destroy);
		});
		registerFunction('videoExists', function(tag:String) {
			return getVideoObject(tag) != null;
		});
		registerFunction('playVideo', function(tag:String) {
			var video:VideoSprite = getVideoObject(tag);
			if(video != null) {
				video.play();
				return true;
			}
			return false;
		});
		registerFunction('pauseVideo', function(tag:String) {
			var video:VideoSprite = getVideoObject(tag);
			if(video != null) {
				video.pause();
				return true;
			}
			return false;
		});
		registerFunction('resumeVideo', function(tag:String) {
			var video:VideoSprite = getVideoObject(tag);
			if(video != null) {
				video.resume();
				return true;
			}
			return false;
		});
		registerFunction('stopVideo', function(tag:String, ?destroy:Bool = true) {
			var video:VideoSprite = getVideoObject(tag);
			if(video == null)
				return false;
			if(destroy && game != null)
				return game.removeVideo(tag, true);
			video.stop();
			return true;
		});
		registerFunction('setVideoCanSkip', function(tag:String, canSkip:Bool = true) {
			var video:VideoSprite = getVideoObject(tag);
			if(video != null) {
				video.canSkip = canSkip;
				return true;
			}
			return false;
		});
		registerFunction('setVideoPauseWithGame', function(tag:String, pauseWithGame:Bool = true) {
			var video:VideoSprite = getVideoObject(tag);
			if(video != null) {
				video.pauseWithGame = pauseWithGame;
				return true;
			}
			return false;
		});
		registerFunction('setVideoSyncWithSong', function(tag:String, syncWithSong:Bool = true) {
			var video:VideoSprite = getVideoObject(tag);
			if(video != null) {
				video.syncWithSong = syncWithSong;
				return true;
			}
			return false;
		});
		registerFunction('seekVideo', function(tag:String, timeMs:Float) {
			var video:VideoSprite = getVideoObject(tag);
			if(video != null) {
				video.setTime(timeMs);
				return true;
			}
			return false;
		});
		registerFunction('setVideoTime', function(tag:String, timeMs:Float) {
			var video:VideoSprite = getVideoObject(tag);
			if(video != null) {
				video.setTime(timeMs);
				return true;
			}
			return false;
		});
		registerFunction('getVideoTime', function(tag:String) {
			var video:VideoSprite = getVideoObject(tag);
			return video != null ? video.getTime() : 0;
		});
		registerFunction('getVideoLength', function(tag:String) {
			var video:VideoSprite = getVideoObject(tag);
			return video != null ? video.getLength() : 0;
		});
		#end
		registerFunction('startVideo', function(videoFile:String, ?canSkip:Bool = true, ?forMidSong:Bool = false, ?shouldLoop:Bool = false, ?playOnLoad:Bool = true, ?pauseWithGame:Bool = true) {
			#if VIDEOS_ALLOWED
			if (FileSystem.exists(Paths.video(videoFile))) {
				if (game.videoCutscene != null) {
					game.remove(game.videoCutscene);
					game.videoCutscene.destroy();
				}
				game.videoCutscene = game.startVideo(videoFile, forMidSong, canSkip, shouldLoop, playOnLoad, pauseWithGame);
				return true;
			} else {
				luaTrace('startVideo: Video file not found: ' + videoFile, false, false, ERROR);
			}
			return false;

			#else
			PlayState.instance.inCutscene = true;
			new FlxTimer().start(0.1, function(tmr:FlxTimer) {
				PlayState.instance.inCutscene = false;
				if (game.endingSong) {
					game.endSong();
				} else {
					game.startCountdown();
				}
			});
			return true;
			#end
		});
		
		// character
		registerFunction('getCharacterX', function(type:String) {
			var group = game.getCharacterGroupByName(type);
			return group != null ? group.x : 0;
		});
		registerFunction('getCharacterY', function(type:String) {
			var group = game.getCharacterGroupByName(type);
			return group != null ? group.y : 0;
		});
		registerFunction('setCharacterX', function(type:String, value:Float) {
			var group = game.getCharacterGroupByName(type);
			if(group != null) group.x = value;
		});
		registerFunction('setCharacterY', function(type:String, value:Float) {
			var group = game.getCharacterGroupByName(type);
			if(group != null) group.y = value;
		});
		registerFunction('cameraSetTarget', function(target:String) {
			game.changeFocus(target);
		});
		registerFunction('changeFocus', function(target:String, ?x:Float = 0, ?y:Float = 0, ?ease:String = 'classic', ?steps:Float = 0) {
			game.changeFocus(target, x, y, ease, steps);
		});
		registerFunction('ChangeFocus', function(target:String, ?x:Float = 0, ?y:Float = 0, ?ease:String = 'classic', ?steps:Float = 0) {
			game.changeFocus(target, x, y, ease, steps);
		});
		registerFunction('cameraZoom', function(zoom:Float, ?steps:Float = 0, ?ease:String = 'classic', ?type:String = 'nll') {
			return game.applyCameraZoom(zoom, steps, ease, type);
		});
		registerFunction('CameraZoom', function(zoom:Float, ?steps:Float = 0, ?ease:String = 'classic', ?type:String = 'nll') {
			return game.applyCameraZoom(zoom, steps, ease, type);
		});
		registerFunction('cameraZoomEvent', function(value1:String = '', value2:String = '') {
			return game.applyCameraZoomEvent(value1, value2);
		});
		registerFunction('changeIcon', function(icon:String, ?side:Int = 0) {
			return game.changeHealthIcon(icon, side);
		});
		registerFunction('ChangeIcon', function(icon:String, ?side:Int = 0) {
			return game.changeHealthIcon(icon, side);
		});
		registerFunction('setIconFrame', function(side:Int = 0, frame:Int = 0) {
			return game.setIconFrame(side, frame);
		});
		registerFunction('addIcon', function(frame:Int = 0, ?side:Null<Int> = null) {
			if(side == null)
				return game.setIconFrame(0, frame) && game.setIconFrame(1, frame);
			return game.setIconFrame(side, frame);
		});
		registerFunction('AddIcon', function(frame:Int = 0, ?side:Null<Int> = null) {
			if(side == null)
				return game.setIconFrame(0, frame) && game.setIconFrame(1, frame);
			return game.setIconFrame(side, frame);
		});
		
		// camfollow
		registerFunction('setCameraFollowPoint', function(x:Float, y:Float) game.camFollow.setPosition(x, y));
		registerFunction('addCameraFollowPoint', function(?x:Float = 0, ?y:Float = 0) {
			game.camFollow.x += x;
			game.camFollow.y += y;
		});
		registerFunction('getCameraFollowX', () -> game.camFollow.x);
		registerFunction('getCameraFollowY', () -> game.camFollow.y);
		
		//Tween shit, but for strums
		registerFunction('noteTweenX', function(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear') return noteTweenFunction(tag, note, {x: value}, duration, ease));
		registerFunction('noteTweenY', function(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear') return noteTweenFunction(tag, note, {y: value}, duration, ease));
		registerFunction('noteTweenAngle', function(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear') return noteTweenFunction(tag, note, {angle: value}, duration, ease));
		registerFunction('noteTweenAlpha', function(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear') return noteTweenFunction(tag, note, {alpha: value}, duration, ease));
		registerFunction('noteTweenDirection', function(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear') return noteTweenFunction(tag, note, {direction: value}, duration, ease));

		// haha, notes (RGB never used and i uhhmmmm theres 3 colors on rgb i'm stupid) PROBABLY SHIHO WILL FIX IT LATER
		registerFunction('setStrumSkin', function(strum:Dynamic, skinName:String) return game.setStrumSkin(strum, skinName));
		registerFunction('setPlayerSplash', function(splashName:String) return game.setPlayerSplash(splashName));
		registerFunction('setStrumRGB', function(strum:Dynamic, colorHex:String) return game.setStrumRGB(strum, colorHex));
		registerFunction('allowStrumRGB', function(strum:Dynamic, ?enabled:Bool = true) return game.allowStrumRGB(strum, enabled));
		registerFunction('tweenStrumRGB', function(tag:String, strum:Dynamic, seconds:Float, colorHex:String, ?ease:String = 'linear')
			return game.tweenStrumRGB(tag, strum, seconds, colorHex, ease));
	}
}
#end
