package psychlua;

#if (!flash && sys)
import flixel.addons.display.FlxRuntimeShader;
#end

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.system.FlxAssets.FlxShader;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import openfl.Lib;
import openfl.filters.BitmapFilter;
import openfl.filters.BlurFilter;
import openfl.filters.ShaderFilter;

private typedef FilterTarget = {
	var owner:String;
	var camera:FlxCamera;
	var sprite:FlxSprite;
	var isWindow:Bool;
	var isSprite:Bool;
}

private typedef SpriteBlur = {
	var blurX:Float;
	var blurY:Float;
	var quality:Int;
}



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
	public static var blurMap:Map<String, Map<String, BlurFilter>> = new Map();
	public static var spriteBlurMap:Map<String, Map<String, SpriteBlur>> = new Map();
	static var spriteBlurShaders:Map<String, FlxRuntimeShader> = new Map();
	static var spriteBlurPreviousShaders:Map<String, Dynamic> = new Map();

	static final SPRITE_BLUR_FRAGMENT:String = '
		#pragma header

		uniform float blurX;
		uniform float blurY;
		uniform float blurQuality;

		void main()
		{
			vec2 uv = openfl_TextureCoordv;
			float quality = clamp(floor(blurQuality + 0.5), 1.0, 8.0);
			float xLimit = abs(blurX) > 0.001 ? quality : 0.0;
			float yLimit = abs(blurY) > 0.001 ? quality : 0.0;
			float sigma = max(quality * 0.45, 0.45);
			vec3 colorSum = vec3(0.0);
			float alphaSum = 0.0;
			float weightSum = 0.0;

			for (int x = -8; x <= 8; x++)
			{
				float fx = float(x);
				if (abs(fx) <= xLimit)
				{
					for (int y = -8; y <= 8; y++)
					{
						float fy = float(y);
						if (abs(fy) <= yLimit)
						{
							float dist = fx * fx + fy * fy;
							float weight = exp(-dist / (2.0 * sigma * sigma));
							vec2 offset = vec2((fx * blurX) / quality, (fy * blurY) / quality) / openfl_TextureSize;
							vec4 sample = texture2D(bitmap, uv + offset);
							colorSum += sample.rgb * sample.a * weight;
							alphaSum += sample.a * weight;
							weightSum += weight;
						}
					}
				}
			}

			if (weightSum <= 0.0)
			{
				gl_FragColor = texture2D(bitmap, uv);
			}
			else
			{
				float outAlpha = alphaSum / weightSum;
				vec3 outColor = alphaSum > 0.0001 ? colorSum / alphaSum : vec3(0.0);
				gl_FragColor = vec4(outColor, outAlpha) * openfl_Alphav;
			}
		}
	';

	static inline function normalizeFilterTag(tag:String):String
		return (tag == null || tag.trim().length < 1) ? 'blur' : tag.trim();

	static function cameraOwnerFromString(cam:String):String
	{
		if (cam == null) return null;

		var trimmed:String = cam.trim();
		switch (trimmed.toLowerCase())
		{
			case 'cammain' | 'main' | 'camgame' | 'game':
				return 'camGame';
			case 'camhud' | 'hud':
				return 'camHUD';
			case 'camother' | 'other':
				return 'camOther';
			default:
		}

		var customCamera:Dynamic = MusicBeatState.getVariables().get(trimmed);
		if (customCamera != null && Std.isOfType(customCamera, FlxCamera))
			return trimmed;

		return null;
	}

	static function normalizeFilterOwner(owner:String):String
	{
		if (owner == null) return null;

		var trimmed:String = owner.trim();
		switch (trimmed.toLowerCase())
		{
			case 'window' | 'screen' | 'stage':
				return 'window';
			default:
		}

		var cameraOwner:String = cameraOwnerFromString(trimmed);
		return cameraOwner != null ? cameraOwner : trimmed;
	}

	static function targetFromString(target:String, funcName:String):FilterTarget
	{
		if (target == null || target.trim().length < 1)
			target = 'camGame';

		var trimmed:String = target.trim();
		switch (trimmed.toLowerCase())
		{
			case 'window' | 'screen' | 'stage':
				return {owner: 'window', camera: null, sprite: null, isWindow: true, isSprite: false};
			default:
		}

		var owner:String = cameraOwnerFromString(trimmed);
		if (owner != null)
			return {owner: owner, camera: LuaUtils.cameraFromString(trimmed), sprite: null, isWindow: false, isSprite: false};

		var sprite:FlxSprite = resolveSpriteTarget(trimmed);
		if (sprite != null)
			return {owner: normalizeFilterOwner(trimmed), camera: null, sprite: sprite, isWindow: false, isSprite: true};

		FunkinLua.luaTrace('$funcName: target "$target" is not a window, camera or sprite.', false, false, ERROR);
		return null;
	}

	static function resolveSpriteTarget(name:String):FlxSprite
	{
		if (name == null || name.trim().length < 1)
			return null;

		var obj:Dynamic = LuaUtils.getObjectDirectly(name);
		if (obj != null)
		{
			if (Std.isOfType(obj, FlxSpriteGroup))
			{
				if (PlayState.instance != null)
				{
					var character = PlayState.instance.getCharacterByName(name);
					if (character != null)
						return character;
				}

				var group:FlxSpriteGroup = cast obj;
				for (member in group.members)
					if (member != null)
						return member;
			}

			if (Std.isOfType(obj, FlxSprite))
				return cast obj;
		}

		if (PlayState.instance != null)
		{
			var character = PlayState.instance.getCharacterByName(name);
			if (character != null)
				return character;
		}

		return null;
	}

	static function resolveShaderObject(name:String):FlxShader
	{
		if (name == null || name.trim().length < 1)
			return null;

		var obj:Dynamic = MusicBeatState.getVariables().get(LuaUtils.formatVariable(name));
		if (obj == null)
			obj = LuaUtils.getObjectDirectly(name);

		if (Std.isOfType(obj, FlxShader))
			return cast obj;

		if (Std.isOfType(obj, FlxSprite))
		{
			var sprite:FlxSprite = cast obj;
			if (sprite.shader != null && Std.isOfType(sprite.shader, FlxShader))
				return cast sprite.shader;
		}

		#if flxanimate
		var atlas:Dynamic = backend.AtlasUtil.getAtlas(obj);
		if (atlas != null)
		{
			var shader:Dynamic = try Reflect.getProperty(atlas, 'shader') catch(e:Dynamic) null;
			if (Std.isOfType(shader, FlxShader))
				return cast shader;
		}
		#end

		return null;
	}

	static function colorFromDynamic(value:Dynamic, fallback:FlxColor = FlxColor.WHITE):FlxColor
	{
		if (value == null)
			return fallback;
		if (Std.isOfType(value, Int))
			return cast value;
		if (Std.isOfType(value, Float))
			return cast Std.int(value);
		return CoolUtil.colorFromString(Std.string(value));
	}

	static function getTargetFilters(target:FilterTarget):Array<BitmapFilter>
	{
		if (target == null) return [];
		if (target.isWindow)
			return Lib.current.filters != null ? Lib.current.filters : [];

		return target.camera != null && target.camera.filters != null ? target.camera.filters : [];
	}

	static function applyTargetFilters(target:FilterTarget, filters:Array<BitmapFilter>):Void
	{
		if (target == null) return;

		if (target.isWindow)
		{
			Lib.current.filters = filters;
			shaders.ShaderResizeFix.fixSprite(Lib.current);
		}
		else if (target.camera != null)
		{
			target.camera.filters = filters;
			shaders.ShaderResizeFix.fixCamera(target.camera);
		}
	}

	static function rebuildSpriteBlur(target:FilterTarget):Void
	{
		if (target == null || target.sprite == null) return;

		var ownerMap = spriteBlurMap.get(target.owner);
		var blurX:Float = 0;
		var blurY:Float = 0;
		var quality:Float = 1;
		var hasBlurs:Bool = false;

		if (ownerMap != null)
		{
			for (blur in ownerMap)
			{
				if (blur != null)
				{
					blurX += blur.blurX;
					blurY += blur.blurY;
					quality = Math.max(quality, blur.quality);
					hasBlurs = true;
				}
			}
		}

		if (!hasBlurs || (Math.abs(blurX) <= 0.001 && Math.abs(blurY) <= 0.001))
		{
			if (spriteBlurShaders.exists(target.owner))
			{
				target.sprite.shader = cast spriteBlurPreviousShaders.get(target.owner);
				spriteBlurShaders.remove(target.owner);
				spriteBlurPreviousShaders.remove(target.owner);
			}
			return;
		}

		var shader:FlxRuntimeShader = spriteBlurShaders.get(target.owner);
		if (shader == null)
		{
			if (!spriteBlurPreviousShaders.exists(target.owner))
				spriteBlurPreviousShaders.set(target.owner, target.sprite.shader);
			shader = new FlxRuntimeShader(SPRITE_BLUR_FRAGMENT);
			spriteBlurShaders.set(target.owner, shader);
		}

		shader.setFloat('blurX', blurX);
		shader.setFloat('blurY', blurY);
		shader.setFloat('blurQuality', Math.max(1, Math.min(8, quality)));
		target.sprite.shader = shader;
	}

	static function rebuildBlurFilters(target:FilterTarget):Void
	{
		if (target == null) return;

		if (target.isSprite)
		{
			rebuildSpriteBlur(target);
			return;
		}

		var filters:Array<BitmapFilter> = getTargetFilters(target).filter(function(filter:BitmapFilter) {
			return !Std.isOfType(filter, BlurFilter);
		});

		var blurOwner = blurMap.get(target.owner);
		if (blurOwner != null)
			for (blur in blurOwner)
				if (blur != null)
					filters.push(blur);

		applyTargetFilters(target, filters);
	}

	static function storeShader(owner:String, tag:String, shader:FlxRuntimeShader, normalizeOwner:Bool = false):Void
	{
		if (normalizeOwner)
			owner = normalizeFilterOwner(owner);
		if (!shaderMap.exists(owner))
			shaderMap.set(owner, new Map());
		shaderMap.get(owner).set(tag, shader);
	}

	static function storeBlur(owner:String, tag:String, blur:BlurFilter):Void
	{
		owner = normalizeFilterOwner(owner);
		tag = normalizeFilterTag(tag);
		if (!blurMap.exists(owner))
			blurMap.set(owner, new Map());
		blurMap.get(owner).set(tag, blur);
	}

	static function storeSpriteBlur(owner:String, tag:String, blur:SpriteBlur):Void
	{
		owner = normalizeFilterOwner(owner);
		tag = normalizeFilterTag(tag);
		if (!spriteBlurMap.exists(owner))
			spriteBlurMap.set(owner, new Map());
		spriteBlurMap.get(owner).set(tag, blur);
	}

	static function getBlur(target:FilterTarget, blurTag:String, funcName:String):Dynamic
	{
		if (target == null) return null;

		blurTag = normalizeFilterTag(blurTag);
		if (target.isSprite)
		{
			var spriteOwnerMap = spriteBlurMap.get(target.owner);
			if (spriteOwnerMap != null && spriteOwnerMap.exists(blurTag))
				return spriteOwnerMap.get(blurTag);
		}
		else
		{
			var ownerMap = blurMap.get(target.owner);
			if (ownerMap != null && ownerMap.exists(blurTag))
				return ownerMap.get(blurTag);
		}

		FunkinLua.luaTrace('$funcName: Blur "$blurTag" in "${target.owner}" not found!', false, false, ERROR);
		return null;
	}

	static function setBlur(targetName:String, blurTag:String, blurX:Float, ?blurY:Null<Float>, ?quality:Int = 1, ?funcName:String = 'setBlurFilter'):Bool
	{
		if (!ClientPrefs.data.shaders) return false;

		var target:FilterTarget = targetFromString(targetName, funcName);
		if (target == null) return false;

		blurTag = normalizeFilterTag(blurTag);
		if (blurY == null) blurY = blurX;
		if (quality < 1) quality = 1;
		else if (quality > 15) quality = 15;

		if (target.isSprite)
		{
			var spriteBlur:SpriteBlur = null;
			var spriteOwnerMap = spriteBlurMap.get(target.owner);
			if (spriteOwnerMap != null && spriteOwnerMap.exists(blurTag))
				spriteBlur = spriteOwnerMap.get(blurTag);

			if (spriteBlur == null)
			{
				spriteBlur = {blurX: blurX, blurY: blurY, quality: quality};
				storeSpriteBlur(target.owner, blurTag, spriteBlur);
			}
			else
			{
				spriteBlur.blurX = blurX;
				spriteBlur.blurY = blurY;
				spriteBlur.quality = quality;
			}

			rebuildBlurFilters(target);
			return true;
		}

		var blur:BlurFilter = null;
		var ownerMap = blurMap.get(target.owner);
		if (ownerMap != null && ownerMap.exists(blurTag))
			blur = ownerMap.get(blurTag);

		if (blur == null)
		{
			blur = new BlurFilter(blurX, blurY, quality);
			storeBlur(target.owner, blurTag, blur);
		}
		else
		{
			blur.blurX = blurX;
			blur.blurY = blurY;
			blur.quality = quality;
		}

		rebuildBlurFilters(target);
		return true;
	}

	static function removeBlur(targetName:String, ?blurTag:String, ?funcName:String = 'removeBlurFilter'):Bool
	{
		var target:FilterTarget = targetFromString(targetName, funcName);
		if (target == null) return false;

		if (target.isSprite)
		{
			var spriteOwnerMap = spriteBlurMap.get(target.owner);
			if (spriteOwnerMap != null)
			{
				if (blurTag != null && blurTag.trim().length > 0)
					spriteOwnerMap.remove(normalizeFilterTag(blurTag));
				else
					spriteOwnerMap.clear();

				var hasSpriteBlurs:Bool = false;
				for (_ in spriteOwnerMap)
				{
					hasSpriteBlurs = true;
					break;
				}
				if (!hasSpriteBlurs)
					spriteBlurMap.remove(target.owner);
			}

			rebuildBlurFilters(target);
			return true;
		}

		var ownerMap = blurMap.get(target.owner);
		if (ownerMap != null)
		{
			if (blurTag != null && blurTag.trim().length > 0)
				ownerMap.remove(normalizeFilterTag(blurTag));
			else
				ownerMap.clear();

			var hasBlurs:Bool = false;
			for (_ in ownerMap)
			{
				hasBlurs = true;
				break;
			}
			if (!hasBlurs)
				blurMap.remove(target.owner);
		}

		rebuildBlurFilters(target);
		return true;
	}

	static function tweenBlur(tag:String, targetName:String, blurTag:String, blurX:Float, blurY:Float, duration:Float, ?ease:String = 'linear', ?funcName:String = 'doTweenBlur'):Bool
	{
		if (!ClientPrefs.data.shaders) return false;

		var owner:FunkinLua = FunkinLua.lastCalledScript;
		var ownerState:flixel.FlxState = owner != null && owner.parentState != null ? owner.parentState : FlxG.state;
		var target:FilterTarget = targetFromString(targetName, funcName);
		var blur:Dynamic = getBlur(target, blurTag, funcName);
		if (blur == null) return false;

		LuaUtils.cancelTween(tag);

		var originalTag:String = tag;
		var tweenTag:String = LuaUtils.formatVariable('tween_$tag');
		var variables = MusicBeatState.getVariables();
		var tweenEase:Dynamic = LuaUtils.getTweenEaseByString(ease);

		variables.set(tweenTag, FlxTween.tween(blur, {blurX: blurX, blurY: blurY}, duration, {
			ease: tweenEase,
			onUpdate: function(_) rebuildBlurFilters(target),
			onComplete: function(_) {
				variables.remove(tweenTag);
				rebuildBlurFilters(target);
				FunkinLua.luaCallGlobalFrom(owner, ownerState, 'onTweenCompleted', [originalTag, targetName]);
			}
		}));
		return true;
	}

	#if (!flash && ADDONS_ALLOWED && sys)
	public static function getShader(obj:String, ?shaderTag:String):FlxRuntimeShader
	{
		var owner:String = normalizeFilterOwner(obj);
		if (shaderTag != null && shaderTag.length > 0)
		{
			if (shaderMap.exists(obj) && shaderMap.get(obj).exists(shaderTag))
				return shaderMap.get(obj).get(shaderTag);
			if (shaderMap.exists(owner) && shaderMap.get(owner).exists(shaderTag))
				return shaderMap.get(owner).get(shaderTag);
		}
		else
		{
			if (shaderMap.exists(obj))
				for (shader in shaderMap.get(obj))
					if (shader != null) return shader;
			if (shaderMap.exists(owner))
				for (shader in shaderMap.get(owner))
					if (shader != null) return shader;
		}

		if (owner == 'window' && Lib.current.filters != null)
			for (f in Lib.current.filters)
				if (Std.isOfType(f, ShaderFilter))
					return cast(cast(f, ShaderFilter).shader);

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
			#if (!flash && ADDONS_ALLOWED && sys)
			return funk.initLuaShader(name);
			#else
			FunkinLua.luaTrace("initLuaShader: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			return false;
			#end
		});

		funk.addLocalCallback("setObjectShaderObject", function(target:String, shaderTag:String) {
			if (!ClientPrefs.data.shaders) return false;

			var shader:FlxShader = resolveShaderObject(shaderTag);
			var obj:Dynamic = LuaUtils.getObjectDirectly(target);
			return shader != null && backend.AtlasUtil.setShader(obj, shader);
		});
		funk.addLocalCallback("setLuaObjectShader", function(target:String, shaderTag:String) {
			if (!ClientPrefs.data.shaders) return false;

			var shader:FlxShader = resolveShaderObject(shaderTag);
			var obj:Dynamic = LuaUtils.getObjectDirectly(target);
			return shader != null && backend.AtlasUtil.setShader(obj, shader);
		});
		funk.addLocalCallback("copyObjectShader", function(source:String, target:String) {
			if (!ClientPrefs.data.shaders) return false;
			return backend.AtlasUtil.copyShader(LuaUtils.getObjectDirectly(source), LuaUtils.getObjectDirectly(target));
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
			var leObj:FlxSprite = resolveSpriteTarget(obj);
			if (leObj != null) {
				var arr:Array<String> = funk.runtimeShaders.get(shader);
				var runtime = new shaders.CodenameRuntimeShader(shader, arr[0], arr[1]);
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
			#if (!flash && ADDONS_ALLOWED && sys)
			if (shaderTag != null && shaderTag.length > 0) {
				if (shaderMap.exists(obj)) shaderMap.get(obj).remove(shaderTag);
			} else {
				if (shaderMap.exists(obj)) shaderMap.get(obj).clear();
			}
			#end
			var leObj:FlxSprite = resolveSpriteTarget(obj);
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
			#if (!flash && ADDONS_ALLOWED && sys)
			if (!funk.runtimeShaders.exists(shader) && !funk.initLuaShader(shader)) {
				FunkinLua.luaTrace('setCameraShader: Shader "$shader" não encontrado!', false, false, ERROR);
				return false;
			}
			var leCam:FlxCamera = LuaUtils.cameraFromString(cam);
			if (leCam != null) {
				var arr:Array<String> = funk.runtimeShaders.get(shader);
				var runtime = new shaders.CodenameRuntimeShader(shader, arr[0], arr[1]);
				shaders.CodenameRuntimeShader.applyCameraUniforms(runtime, leCam);
				if (leCam.filters == null) leCam.filters = [];
				leCam.filters.push(new ShaderFilter(runtime));
				shaders.ShaderResizeFix.fixCamera(leCam);
				if (shaderTag != null && shaderTag.length > 0)
					storeShader(cam, shaderTag, runtime, true);
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
			#if (!flash && ADDONS_ALLOWED && sys)
			var leCam:FlxCamera = LuaUtils.cameraFromString(cam);
			if (leCam != null) {
				var owner:String = normalizeFilterOwner(cam);
				if (shaderTag != null && shaderTag.length > 0) {
					if (shaderMap.exists(owner) && shaderMap.get(owner).exists(shaderTag)) {
						var toRemove:FlxRuntimeShader = shaderMap.get(owner).get(shaderTag);
						shaderMap.get(owner).remove(shaderTag);
						if (leCam.filters != null)
							leCam.filters = leCam.filters.filter(function(f) {
								return !(Std.isOfType(f, ShaderFilter) && cast(f, ShaderFilter).shader == cast toRemove);
							});
						shaders.ShaderResizeFix.fixCamera(leCam);
					}
				} else {
					if (leCam.filters != null)
						leCam.filters = leCam.filters.filter(function(f) return !Std.isOfType(f, ShaderFilter));
					if (shaderMap.exists(owner)) shaderMap.get(owner).clear();
					shaders.ShaderResizeFix.fixCamera(leCam);
				}
				return true;
			}
			FunkinLua.luaTrace('removeCameraShader: camera "$cam" not found god damnit its only three cams how could you misstype that?????', false, false, ERROR);
			#else
			FunkinLua.luaTrace("removeCameraShader: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			#end
			return false;
		});

		// setWindowShader(shader, ?shaderTag)
		funk.addLocalCallback("setWindowShader", function(shader:String, ?shaderTag:String) {
			if (!ClientPrefs.data.shaders) return false;
			#if (!flash && ADDONS_ALLOWED && sys)
			if (!funk.runtimeShaders.exists(shader) && !funk.initLuaShader(shader)) {
				FunkinLua.luaTrace('setWindowShader: Shader "$shader" não encontrado!', false, false, ERROR);
				return false;
			}
			var arr:Array<String> = funk.runtimeShaders.get(shader);
			var runtime = new shaders.CodenameRuntimeShader(shader, arr[0], arr[1]);
			shaders.CodenameRuntimeShader.applyScreenUniforms(runtime);
			var filters = Lib.current.filters;
			filters.push(new ShaderFilter(runtime));
			Lib.current.filters = filters;
			shaders.ShaderResizeFix.fixSprite(Lib.current);
			if (shaderTag != null && shaderTag.length > 0)
				storeShader("window", shaderTag, runtime, true);
			FunkinLua.luaTrace('setWindowShader: applied "$shader" to window.', false, false, INFO);
			return true;
			#else
			FunkinLua.luaTrace("setWindowShader: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			return false;
			#end
		});

		// removeWindowShader(?shaderTag)
		funk.addLocalCallback("removeWindowShader", function(?shaderTag:String) {
			#if (!flash && ADDONS_ALLOWED && sys)
			if (shaderTag != null && shaderTag.length > 0) {
				if (shaderMap.exists("window") && shaderMap.get("window").exists(shaderTag)) {
					var toRemove:FlxRuntimeShader = shaderMap.get("window").get(shaderTag);
					shaderMap.get("window").remove(shaderTag);
					if (Lib.current.filters != null)
						Lib.current.filters = Lib.current.filters.filter(function(f) {
							return !(Std.isOfType(f, ShaderFilter) && cast(f, ShaderFilter).shader == cast toRemove);
						});
				}
			} else {
				if (Lib.current.filters != null)
					Lib.current.filters = Lib.current.filters.filter(function(f) return !Std.isOfType(f, ShaderFilter));
				if (shaderMap.exists("window")) shaderMap.get("window").clear();
			}
			shaders.ShaderResizeFix.fixSprite(Lib.current);
			return true;
			#else
			FunkinLua.luaTrace("removeWindowShader: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			return false;
			#end
		});

/*  =======================================================
	openfl blur filters
    =======================================================
*/

		// setBlurFilter(target, blurTag, blurX, ?blurY, ?quality)
		funk.addLocalCallback("setBlurFilter", function(target:String, blurTag:String, blurX:Float, ?blurY:Null<Float>, ?quality:Int = 1) {
			return setBlur(target, blurTag, blurX, blurY, quality);
		});

		// setCameraBlur(cam, blurTag, blurX, ?blurY, ?quality)
		funk.addLocalCallback("setCameraBlur", function(cam:String, blurTag:String, blurX:Float, ?blurY:Null<Float>, ?quality:Int = 1) {
			return setBlur(cam, blurTag, blurX, blurY, quality, 'setCameraBlur');
		});

		// setWindowBlur(blurTag, blurX, ?blurY, ?quality)
		funk.addLocalCallback("setWindowBlur", function(blurTag:String, blurX:Float, ?blurY:Null<Float>, ?quality:Int = 1) {
			return setBlur('window', blurTag, blurX, blurY, quality, 'setWindowBlur');
		});

		// removeBlurFilter(target, ?blurTag)
		funk.addLocalCallback("removeBlurFilter", function(target:String, ?blurTag:String) {
			return removeBlur(target, blurTag);
		});

		// removeCameraBlur(cam, ?blurTag)
		funk.addLocalCallback("removeCameraBlur", function(cam:String, ?blurTag:String) {
			return removeBlur(cam, blurTag, 'removeCameraBlur');
		});

		// removeWindowBlur(?blurTag)
		funk.addLocalCallback("removeWindowBlur", function(?blurTag:String) {
			return removeBlur('window', blurTag, 'removeWindowBlur');
		});

		// getBlurX(target, blurTag)
		funk.addLocalCallback("getBlurX", function(target:String, blurTag:String) {
			var filterTarget:FilterTarget = targetFromString(target, 'getBlurX');
			var blur:Dynamic = getBlur(filterTarget, blurTag, 'getBlurX');
			return blur != null ? Reflect.field(blur, 'blurX') : null;
		});

		// getBlurY(target, blurTag)
		funk.addLocalCallback("getBlurY", function(target:String, blurTag:String) {
			var filterTarget:FilterTarget = targetFromString(target, 'getBlurY');
			var blur:Dynamic = getBlur(filterTarget, blurTag, 'getBlurY');
			return blur != null ? Reflect.field(blur, 'blurY') : null;
		});

		// doTweenBlur(tag, target, blurTag, value, duration, ?ease)
		funk.addLocalCallback("doTweenBlur", function(tag:String, target:String, blurTag:String, value:Float, duration:Float, ?ease:String = "linear") {
			return tweenBlur(tag, target, blurTag, value, value, duration, ease);
		});

		// doTweenBlurXY(tag, target, blurTag, blurX, blurY, duration, ?ease)
		funk.addLocalCallback("doTweenBlurXY", function(tag:String, target:String, blurTag:String, blurX:Float, blurY:Float, duration:Float, ?ease:String = "linear") {
			return tweenBlur(tag, target, blurTag, blurX, blurY, duration, ease, 'doTweenBlurXY');
		});

/*  =======================================================
	twIIIIIIIIIIIIIIIIIIIIII
    =======================================================
*/

		// doTweenShader(tag, obj, shaderTag, prop, value, duration, ?ease)
		funk.addLocalCallback("doTweenShader", function(tag:String, obj:String, shaderTag:String, prop:String, value:Float, duration:Float, ?ease:String = "linear") {
			#if (!flash && ADDONS_ALLOWED && sys)
			var shader:FlxRuntimeShader = getShader(obj, shaderTag);
			if (shader == null) {
				FunkinLua.luaTrace('doTweenShader: Shader "$shaderTag" in "$obj" not found!!!!!', false, false, ERROR);
				return false;
			}
			var startValue:Float = shader.getFloat(prop) ?? 0.0;
			var tweenEase:Dynamic = Reflect.field(FlxEase, ease);
			if (tweenEase == null) tweenEase = FlxEase.linear;
			var owner:FunkinLua = FunkinLua.lastCalledScript;
			var ownerState:flixel.FlxState = owner != null && owner.parentState != null ? owner.parentState : FlxG.state;
			FlxTween.num(startValue, value, duration, {
				ease: tweenEase,
				onComplete: function(_) FunkinLua.luaCallGlobalFrom(owner, ownerState, 'onTweenCompleted', [tag])
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
			#if (!flash && ADDONS_ALLOWED && sys)
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
			#if (!flash && ADDONS_ALLOWED && sys)
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
			#if (!flash && ADDONS_ALLOWED && sys)
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
			#if (!flash && ADDONS_ALLOWED && sys)
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
			#if (!flash && ADDONS_ALLOWED && sys)
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
			#if (!flash && ADDONS_ALLOWED && sys)
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
			#if (!flash && ADDONS_ALLOWED && sys)
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
			#if (!flash && ADDONS_ALLOWED && sys)
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
			#if (!flash && ADDONS_ALLOWED && sys)
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
			#if (!flash && ADDONS_ALLOWED && sys)
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
			#if (!flash && ADDONS_ALLOWED && sys)
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
			#if (!flash && ADDONS_ALLOWED && sys)
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
			#if (!flash && ADDONS_ALLOWED && sys)
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

		funk.addLocalCallback("setShaderValue", function(obj:String, prop:String, value:Dynamic, ?shaderTag:String) {
			#if (!flash && ADDONS_ALLOWED && sys)
			var shader = getShader(obj, shaderTag);
			if (shader == null) { FunkinLua.luaTrace('setShaderValue: shader not found in "$obj"!', false, false, ERROR); return false; }
			if (Std.isOfType(shader, shaders.CodenameRuntimeShader)) {
				cast(shader, shaders.CodenameRuntimeShader).hset(prop, value);
				return true;
			}
			FunkinLua.luaTrace('setShaderValue: shader in "$obj" is not a CodenameRuntimeShader!', false, false, ERROR);
			return false;
			#else
			FunkinLua.luaTrace("setShaderValue: Platform unsupported for Runtime Shaders!!!!!", false, false, ERROR);
			return false;
			#end
		});
	}
}
