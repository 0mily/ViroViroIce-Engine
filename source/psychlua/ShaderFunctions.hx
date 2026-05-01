package psychlua;

#if (!flash && sys)
import flixel.addons.display.FlxRuntimeShader;
#end

import flixel.FlxCamera;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import openfl.filters.ShaderFilter;



/*
	eu dei uma mudada BOA em como funcionam os shaders.
	    Eu tive que primeiramente pegar da minha outra engine, a cool as Ice, TUUUUUDO AQUILO e
	TENTAR portar pra cá, pq compilar isso sempre dava erro.
	INFELIZMENTE eu usei uma IA chamada chatgpt pra organizar esta buceta pq vcs NÃO QUEREM VER como estava antes.

	abraços <3
*/

class ShaderFunctions
{
	public static var shaderMap:Map<String, Map<String, FlxRuntimeShader>> = new Map();

	static function storeShader(owner:String, tag:String, shader:FlxRuntimeShader):Void
	{
		if (!shaderMap.exists(owner))
			shaderMap.set(owner, new Map());
		shaderMap.get(owner).set(tag, shader);
	}

	#if (!flash && MODS_ALLOWED && sys)
	public static function getShader(obj:String, ?shaderTag:String):FlxRuntimeShader
	{
		if (shaderTag != null && shaderTag.length > 0)
		{
			if (shaderMap.exists(obj) && shaderMap.get(obj).exists(shaderTag))
				return shaderMap.get(obj).get(shaderTag);
		}
		else
		{
			if (shaderMap.exists(obj))
				for (shader in shaderMap.get(obj))
					if (shader != null) return shader;
		}

		var target:FlxSprite = LuaUtils.getObjectDirectly(obj);
		if (target != null && target.shader != null)
			return cast target.shader;

		var cam:FlxCamera = LuaUtils.cameraFromString(obj);
		if (cam != null && cam.filters != null)
			for (f in cam.filters)
				if (Std.isOfType(f, ShaderFilter))
					return cast(cast(f, ShaderFilter).shader);

		var tagInfo = (shaderTag != null && shaderTag.length > 0) ? ' (tag: "$shaderTag")' : '';
		FunkinLua.luaTrace('getShader: Nenhum shader encontrado em "$obj"$tagInfo', false, false, ERROR);
		return null;
	}
	#end


	public static function implementLocal(funk:FunkinLua)
	{
		funk.addLocalCallback("initLuaShader", function(name:String) {
			if (!ClientPrefs.data.shaders) return false;
			#if (!flash && MODS_ALLOWED && sys)
			return funk.initLuaShader(name);
			#else
			FunkinLua.luaTrace("initLuaShader: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			return false;
			#end
		});

/*  =======================================================
	spritegs
    =======================================================
*/

		// setSpriteShader(obj, shader, ?shaderTag)
		funk.addLocalCallback("setSpriteShader", function(obj:String, shader:String, ?shaderTag:String) {
			if (!ClientPrefs.data.shaders) return false;
			#if (!flash && sys)
			if (!funk.runtimeShaders.exists(shader) && !funk.initLuaShader(shader)) {
				FunkinLua.luaTrace('setSpriteShader: Shader "$shader" não encontrado!', false, false, ERROR);
				return false;
			}
			var leObj:FlxSprite = LuaUtils.getObjectDirectly(obj);
			if (leObj != null) {
				var arr:Array<String> = funk.runtimeShaders.get(shader);
				var runtime = new shaders.ErrorHandledShader.ErrorHandledRuntimeShader(shader, arr[0], arr[1]);
				leObj.shader = runtime;
				if (shaderTag != null && shaderTag.length > 0)
					storeShader(obj, shaderTag, runtime);
				return true;
			}
			#else
			FunkinLua.luaTrace("setSpriteShader: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			#end
			return false;
		});

		// removeSpriteShader(obj, ?shaderTag)
		funk.addLocalCallback("removeSpriteShader", function(obj:String, ?shaderTag:String) {
			#if (!flash && MODS_ALLOWED && sys)
			if (shaderTag != null && shaderTag.length > 0) {
				if (shaderMap.exists(obj)) shaderMap.get(obj).remove(shaderTag);
			} else {
				if (shaderMap.exists(obj)) shaderMap.get(obj).clear();
			}
			#end
			var leObj:FlxSprite = LuaUtils.getObjectDirectly(obj);
			if (leObj != null) {
				leObj.shader = null;
				return true;
			}
			return false;
		});

/*  =======================================================
	camera shaderds
    =======================================================
*/

		// setCameraShader(cam, shader, ?shaderTag)
		funk.addLocalCallback("setCameraShader", function(cam:String, shader:String, ?shaderTag:String) {
			if (!ClientPrefs.data.shaders) return false;
			#if (!flash && MODS_ALLOWED && sys)
			if (!funk.runtimeShaders.exists(shader) && !funk.initLuaShader(shader)) {
				FunkinLua.luaTrace('setCameraShader: Shader "$shader" não encontrado!', false, false, ERROR);
				return false;
			}
			var leCam:FlxCamera = LuaUtils.cameraFromString(cam);
			if (leCam != null) {
				var arr:Array<String> = funk.runtimeShaders.get(shader);
				var runtime = new shaders.ErrorHandledShader.ErrorHandledRuntimeShader(shader, arr[0], arr[1]);
				if (leCam.filters == null) leCam.filters = [];
				leCam.filters.push(new ShaderFilter(runtime));
				if (shaderTag != null && shaderTag.length > 0)
					storeShader(cam, shaderTag, runtime);
				return true;
			}
			FunkinLua.luaTrace('setCameraShader: camera "$cam" not found god damnit its only three cams how could you misstype that?????', false, false, ERROR);
			#else
			FunkinLua.luaTrace("setCameraShader: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			#end
			return false;
		});

		// removeCameraShader(cam, ?shaderTag)
		funk.addLocalCallback("removeCameraShader", function(cam:String, ?shaderTag:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var leCam:FlxCamera = LuaUtils.cameraFromString(cam);
			if (leCam != null) {
				if (shaderTag != null && shaderTag.length > 0) {
					if (shaderMap.exists(cam) && shaderMap.get(cam).exists(shaderTag)) {
						var toRemove:FlxRuntimeShader = shaderMap.get(cam).get(shaderTag);
						shaderMap.get(cam).remove(shaderTag);
						if (leCam.filters != null)
							leCam.filters = leCam.filters.filter(function(f) {
								return !(Std.isOfType(f, ShaderFilter) && cast(f, ShaderFilter).shader == cast toRemove);
							});
					}
				} else {
					leCam.filters = [];
					if (shaderMap.exists(cam)) shaderMap.get(cam).clear();
				}
				return true;
			}
			FunkinLua.luaTrace('removeCameraShader: camera "$cam" not found god damnit its only three cams how could you misstype that?????', false, false, ERROR);
			#else
			FunkinLua.luaTrace("removeCameraShader: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			#end
			return false;
		});

/*  =======================================================
	twIIIIIIIIIIIIIIIIIIIIII
    =======================================================
*/

		// doTweenShader(tag, obj, shaderTag, prop, value, duration, ?ease)
		funk.addLocalCallback("doTweenShader", function(tag:String, obj:String, shaderTag:String, prop:String, value:Float, duration:Float, ?ease:String = "linear") {
			#if (!flash && MODS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj, shaderTag);
			if (shader == null) {
				FunkinLua.luaTrace('doTweenShader: Shader "$shaderTag" in "$obj" not found!!!!!', false, false, ERROR);
				return false;
			}
			var startValue:Float = shader.getFloat(prop) ?? 0.0;
			var tweenEase:Dynamic = Reflect.field(FlxEase, ease);
			if (tweenEase == null) tweenEase = FlxEase.linear;
			FlxTween.num(startValue, value, duration, {
				ease: tweenEase,
				onComplete: function(_) FunkinLua.luaCallGlobal('onTweenCompleted', [tag])
			}, function(v:Float) shader.setFloat(prop, v));
			return true;
			#else
			FunkinLua.luaTrace("doTweenShader: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			return false;
			#end
		});

/*  =======================================================
	gets getters getterses ?
    =======================================================
*/

		// getShaderBool(obj, prop, ?shaderTag)
		funk.addLocalCallback("getShaderBool", function(obj:String, prop:String, ?shaderTag:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader = getShader(obj, shaderTag);
			if (shader == null) { FunkinLua.luaTrace('getShaderBool: shader not found in "$obj"!', false, false, ERROR); return null; }
			return shader.getBool(prop);
			#else
			FunkinLua.luaTrace("getShaderBool: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			return null;
			#end
		});

		// getShaderBoolArray(obj, prop, ?shaderTag)
		funk.addLocalCallback("getShaderBoolArray", function(obj:String, prop:String, ?shaderTag:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader = getShader(obj, shaderTag);
			if (shader == null) { FunkinLua.luaTrace('getShaderBoolArray: shader not found in "$obj"!', false, false, ERROR); return null; }
			return shader.getBoolArray(prop);
			#else
			FunkinLua.luaTrace("getShaderBoolArray: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			return null;
			#end
		});

		// getShaderInt(obj, prop, ?shaderTag)
		funk.addLocalCallback("getShaderInt", function(obj:String, prop:String, ?shaderTag:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader = getShader(obj, shaderTag);
			if (shader == null) { FunkinLua.luaTrace('getShaderInt: shader not found in "$obj"!', false, false, ERROR); return null; }
			return shader.getInt(prop);
			#else
			FunkinLua.luaTrace("getShaderInt: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			return null;
			#end
		});

		// getShaderIntArray(obj, prop, ?shaderTag)
		funk.addLocalCallback("getShaderIntArray", function(obj:String, prop:String, ?shaderTag:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader = getShader(obj, shaderTag);
			if (shader == null) { FunkinLua.luaTrace('getShaderIntArray: shader not found in "$obj"!', false, false, ERROR); return null; }
			return shader.getIntArray(prop);
			#else
			FunkinLua.luaTrace("getShaderIntArray: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			return null;
			#end
		});

		// getShaderFloat(obj, prop, ?shaderTag)
		funk.addLocalCallback("getShaderFloat", function(obj:String, prop:String, ?shaderTag:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader = getShader(obj, shaderTag);
			if (shader == null) { FunkinLua.luaTrace('getShaderFloat: shader not found in "$obj"!', false, false, ERROR); return null; }
			return shader.getFloat(prop);
			#else
			FunkinLua.luaTrace("getShaderFloat: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			return null;
			#end
		});

		// getShaderFloatArray(obj, prop, ?shaderTag)
		funk.addLocalCallback("getShaderFloatArray", function(obj:String, prop:String, ?shaderTag:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader = getShader(obj, shaderTag);
			if (shader == null) { FunkinLua.luaTrace('getShaderFloatArray: shader not found in "$obj"!', false, false, ERROR); return null; }
			return shader.getFloatArray(prop);
			#else
			FunkinLua.luaTrace("getShaderFloatArray: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			return null;
			#end
		});

/*  =======================================================
	setores (?)
    =======================================================
*/

		// setShaderBool(obj, prop, value, ?shaderTag)
		funk.addLocalCallback("setShaderBool", function(obj:String, prop:String, value:Bool, ?shaderTag:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader = getShader(obj, shaderTag);
			if (shader == null) { FunkinLua.luaTrace('setShaderBool: shader not found in "$obj"!', false, false, ERROR); return false; }
			shader.setBool(prop, value);
			return true;
			#else
			FunkinLua.luaTrace("setShaderBool: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			return false;
			#end
		});

		// setShaderBoolArray(obj, prop, values, ?shaderTag)
		funk.addLocalCallback("setShaderBoolArray", function(obj:String, prop:String, values:Dynamic, ?shaderTag:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader = getShader(obj, shaderTag);
			if (shader == null) { FunkinLua.luaTrace('setShaderBoolArray: shader not found in "$obj"!', false, false, ERROR); return false; }
			shader.setBoolArray(prop, values);
			return true;
			#else
			FunkinLua.luaTrace("setShaderBoolArray: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			return false;
			#end
		});

		// setShaderInt(obj, prop, value, ?shaderTag)
		funk.addLocalCallback("setShaderInt", function(obj:String, prop:String, value:Int, ?shaderTag:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader = getShader(obj, shaderTag);
			if (shader == null) { FunkinLua.luaTrace('setShaderInt: shader not found in "$obj"!', false, false, ERROR); return false; }
			shader.setInt(prop, value);
			return true;
			#else
			FunkinLua.luaTrace("setShaderInt: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			return false;
			#end
		});

		// setShaderIntArray(obj, prop, values, ?shaderTag)
		funk.addLocalCallback("setShaderIntArray", function(obj:String, prop:String, values:Dynamic, ?shaderTag:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader = getShader(obj, shaderTag);
			if (shader == null) { FunkinLua.luaTrace('setShaderIntArray: shader not found in "$obj"!', false, false, ERROR); return false; }
			shader.setIntArray(prop, values);
			return true;
			#else
			FunkinLua.luaTrace("setShaderIntArray: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			return false;
			#end
		});

		// setShaderFloat(obj, prop, value, ?shaderTag)
		funk.addLocalCallback("setShaderFloat", function(obj:String, prop:String, value:Float, ?shaderTag:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader = getShader(obj, shaderTag);
			if (shader == null) { FunkinLua.luaTrace('setShaderFloat: shader not found in "$obj"!', false, false, ERROR); return false; }
			shader.setFloat(prop, value);
			return true;
			#else
			FunkinLua.luaTrace("setShaderFloat: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			return false;
			#end
		});

		// setShaderFloatArray(obj, prop, values, ?shaderTag)
		funk.addLocalCallback("setShaderFloatArray", function(obj:String, prop:String, values:Dynamic, ?shaderTag:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader = getShader(obj, shaderTag);
			if (shader == null) { FunkinLua.luaTrace('setShaderFloatArray: shader not found in "$obj"!', false, false, ERROR); return false; }
			shader.setFloatArray(prop, values);
			return true;
			#else
			FunkinLua.luaTrace("setShaderFloatArray: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			return false; // true;
			#end
		});

		// setShaderSampler2D(obj, prop, bitmapdataPath, ?shaderTag)
		funk.addLocalCallback("setShaderSampler2D", function(obj:String, prop:String, bitmapdataPath:String, ?shaderTag:String) {
			#if (!flash && MODS_ALLOWED && sys)
			var shader = getShader(obj, shaderTag);
			if (shader == null) { FunkinLua.luaTrace('setShaderSampler2D: shader not found in "$obj"!', false, false, ERROR); return false; }
			var value = Paths.image(bitmapdataPath);
			if (value != null && value.bitmap != null) {
				shader.setSampler2D(prop, value.bitmap);
				return true;
			}
			return false;
			#else
			FunkinLua.luaTrace("setShaderSampler2D: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			return false;
			#end
		});
	}
}
