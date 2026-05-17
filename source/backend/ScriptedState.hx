package backend;

#if LUA_ALLOWED
import flixel.addons.display.FlxBackdrop;
import flixel.addons.display.FlxGridOverlay;
import flixel.util.FlxAxes;
import psychlua.FunkinLua;
import psychlua.LuaUtils;
#end

#if GLOBAL_SCRIPTS
import psychlua.GlobalScriptHandler;
#end

class ScriptedState extends ScriptedSubState {
	public var camOther:FlxCamera = null;
	
	@:dox(hide) var _psychCameraInitialized:Bool = false;
	
	/**
	 * Shows a text string at the top-left of the game screen. Useful for debugging.
	 * 
	 * @param 	text 	The text to add.
	 * @param 	color 	The color of the text to add.
	 * @param 	size 	Optional parameter for the size of the text to add.
	*/
	public static function debugPrint(text:String, ?color:FlxColor, ?size:Int):Void {
		Log.print(text, (color == null ? NONE : CUSTOM(color)), size);
	}
	
	public override function create():Void {
		#if MODS_ALLOWED Mods.updatedOnState = false; #end
		
		super.create();
		
		if (!FlxTransitionableState.skipNextTransOut && _requestedSubState == null)
			openSubState(new CustomFadeTransition(0.5, true));
		FlxTransitionableState.skipNextTransOut = false;
		
		MusicBeatState.timePassedOnState = 0;
	}
	public override function preCreate():Void {
		#if GLOBAL_SCRIPTS GlobalScriptHandler.refreshScripts(); #end
		
		if (camOther == null) {
			camOther = new FlxCamera();
			camOther.bgColor.alpha = 0;
			FlxG.cameras.add(camOther, false);
		}
		setVar('camOther', camOther);
		setVar('camHUD', camOther);
		
		if (!_psychCameraInitialized)
			initPsychCamera();
		
		super.preCreate();
	}
	override function _preCreate():Void {
		#if SCRIPTS_ALLOWED startStateScripts(); #end
		
		MusicBeatSubstate.callGlobal('onCreateState', [this, Type.getClass(this)]);
	}
	override function _postCreate():Void {
		callOnScripts('onCreatePost');
		
		MusicBeatSubstate.callGlobal('onCreateStatePost', [this, Type.getClass(this)]);
	}

	public override function update(elapsed:Float):Void {
		#if MODS_ALLOWED
		if (FlxG.keys.justPressed.TAB && subState == null && MusicBeatState.isMainMenuContext(this))
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
			MusicBeatState.switchState(new states.ContentMenuState());
			return;
		}
		#end
		super.update(elapsed);
	}
	#if SCRIPTS_ALLOWED
	public override function startStateScripts():Bool {
		var loaded:Bool = false;
		
		#if HSCRIPT_ALLOWED
		loaded = startHScripts();
		#end
		#if LUA_ALLOWED
		FunkinLua.registerFunctions();
		MusicBeatSubstate.callGlobal('onRegisterLuaAPI');
		callOnHScript('onRegisterLuaAPI');
		loaded = (startLuas() || loaded);
		#end
		
		return loaded;
	}
	#end
	
	public function initPsychCamera():PsychCamera {
		var camera = new PsychCamera();
		FlxG.cameras.reset(camera);
		FlxG.cameras.setDefaultDrawTarget(camera, true);
		setVar('camMain', camera);
		setVar('camGame', camera);
		setVar('camHUD', camOther);
		_psychCameraInitialized = true;
		return camera;
	}
	
	override function getFolderName():String {
		return 'states';
	}

	#if LUA_ALLOWED
	public override function implementLua(lua:FunkinLua):Void {
		super.implementLua(lua);

		function parseBackdropAxes(value:String):FlxAxes {
			if (value == null)
				return XY;

			switch (value.trim().toLowerCase()) {
				case 'x', 'horizontal':
					return X;
				case 'y', 'vertical':
					return Y;
				case 'none':
					return NONE;
				default:
					return XY;
			}
		}

		function getBackdrop(tag:String):FlxBackdrop {
			if (tag == null || tag.trim().length < 1)
				return null;

			var object:Dynamic = LuaUtils.getObjectDirectly(tag, false, this);
			return Std.isOfType(object, FlxBackdrop) ? cast object : null;
		}
		function getCamera(tag:String):FlxCamera {
			if (tag == null || tag.trim().length < 1)
				return null;

			var object:Dynamic = LuaUtils.getObjectDirectly(tag, false, this);
			return Std.isOfType(object, FlxCamera) ? cast object : null;
		}
		function setMainCameraInternal(camera:FlxCamera):Bool {
			if (camera == null)
				return false;

			FlxG.cameras.setDefaultDrawTarget(camera, true);
			MusicBeatState.getVariables().set('camMain', camera);
			MusicBeatState.getVariables().set('camGame', camera);
			return true;
		}

		lua.addLocalCallback('addGridBackdrop', function(tag:String, cellWidth:Int = 80, cellHeight:Int = 80, width:Int = 160, height:Int = 160, velocityX:Float = 0, velocityY:Float = 0, color1:String = '33FFFFFF', color2:String = '000000', alpha:Float = 1, x:Float = 0, y:Float = 0, repeatAxes:String = 'xy') {
			if (tag == null || tag.trim().length < 1)
				return false;
			if (LuaUtils.getObjectDirectly(tag, false, this) != null)
				return false;

			var grid = FlxGridOverlay.createGrid(cellWidth, cellHeight, width, height, true, CoolUtil.colorFromString(color1), CoolUtil.colorFromString(color2));
			var backdrop:FlxBackdrop = new FlxBackdrop(grid, parseBackdropAxes(repeatAxes));
			backdrop.setPosition(x, y);
			backdrop.velocity.set(velocityX, velocityY);
			backdrop.alpha = alpha;

			MusicBeatState.getVariables().set(tag, backdrop);
			add(backdrop);
			return true;
		});

		lua.addLocalCallback('setBackdropVelocity', function(tag:String, velocityX:Float = 0, velocityY:Float = 0) {
			var backdrop = getBackdrop(tag);
			if (backdrop == null)
				return false;

			backdrop.velocity.set(velocityX, velocityY);
			return true;
		});

		lua.addLocalCallback('removeBackdrop', function(tag:String, destroy:Bool = true) {
			var backdrop = getBackdrop(tag);
			if (backdrop == null)
				return false;

			remove(backdrop, destroy);
			if (destroy)
				backdrop.destroy();
			MusicBeatState.getVariables().remove(tag);
			return true;
		});

		lua.addLocalCallback('addCamera', function(tag:String, bgColor:String = '00000000', x:Float = 0, y:Float = 0, width:Int = -1, height:Int = -1, zoom:Float = 1, front:Bool = false) {
			if (tag == null || tag.trim().length < 1)
				return false;
			if (LuaUtils.getObjectDirectly(tag, false, this) != null)
				return false;

			var camera:FlxCamera = new FlxCamera(x, y, width, height, zoom);
			camera.bgColor = CoolUtil.colorFromString(bgColor);
			FlxG.cameras.add(camera, front);
			MusicBeatState.getVariables().set(tag, camera);
			return true;
		});

		lua.addLocalCallback('setMainCamera', function(tag:String) {
			return setMainCameraInternal(getCamera(tag));
		});

		lua.addLocalCallback('removeCamera', function(tag:String, destroy:Bool = true) {
			var camera = getCamera(tag);
			if (camera == null)
				return false;
			if (camera == MusicBeatState.getVariables().get('camMain'))
				return false;

			FlxG.cameras.remove(camera, destroy);
			if (destroy)
				camera.destroy();
			MusicBeatState.getVariables().remove(tag);
			return true;
		});
	}
	#end
}
