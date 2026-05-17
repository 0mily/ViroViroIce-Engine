package shaders;

#if (!flash && sys)
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.addons.display.FlxRuntimeShader;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.display.ShaderInput;
import openfl.display.ShaderParameter;
import shaders.ErrorHandledShader.ErrorHandledRuntimeShader;
using StringTools;

@:access(openfl.display.Shader)
class CodenameRuntimeShader extends ErrorHandledRuntimeShader // foda a codename num quero tb
{
	static final IMPORT_REGEX:EReg = ~/#import\s+<(.*)>/;
	public var fileName:String = "CodenameRuntimeShader";
	public var fragFileName:String = "CodenameRuntimeShader";
	public var vertFileName:String = "CodenameRuntimeShader";

	public function new(?shaderName:String, ?fragmentSource:String, ?vertexSource:String)
	{
		super(shaderName, fragmentSource, vertexSource);

		if(shaderName != null && shaderName.length > 0)
			fileName = fragFileName = vertFileName = shaderName;
	}

	@:noCompletion override private function set_glFragmentSource(value:String):String
	{
		if(value == null || value.length < 1)
			value = ShaderTemplates.defaultFragmentSource;

		value = processoPorraimport(value);
		value = value.replace("#pragma header", ShaderTemplates.fragHeader).replace("#pragma body", ShaderTemplates.fragBody);

		if(value != __glFragmentSource)
			__glSourceDirty = true;

		return __glFragmentSource = value;
	}

	@:noCompletion override private function set_glVertexSource(value:String):String
	{
		if(value == null || value.length < 1)
			value = ShaderTemplates.defaultVertexSource;

		value = processoPorraimport(value);

		var useBackCompat:Bool = true;
		for(regex in ShaderTemplates.vertBackCompatVarList)
		{
			if(!regex.match(value))
			{
				useBackCompat = false;
				break;
			}
		}

		var header = useBackCompat ? ShaderTemplates.vertHeaderBackCompat : ShaderTemplates.vertHeader;
		var body = useBackCompat ? ShaderTemplates.vertBodyBackCompat : ShaderTemplates.vertBody;
		value = value.replace("#pragma header", header).replace("#pragma body", body);

		if(value != __glVertexSource)
			__glSourceDirty = true;

		return __glVertexSource = value;
	}

	static function processoPorraimport(value:String):String
	{
		while(IMPORT_REGEX.match(value))
		{
			var importPath:String = IMPORT_REGEX.matched(1);
			var importSource:String = getShaderText(importPath);

			if(importSource == null)
				FlxG.log.warn('Failed to import shader "$importPath"');
			else
				value = value.replace(IMPORT_REGEX.matched(0), importSource);
		}

		return value;
	}

	public static function getShaderText(path:String):String
	{
		path = path.replace("\\", "/");

		var paths:Array<String> = [
			Paths.getSharedPath('shaders/$path'),
			'assets/shaders/$path'
		];

		#if MODS_ALLOWED
		if(Mods.rootAddonsAllowed())
			paths.insert(0, Paths.mods('shaders/$path'));
		for(mod in Mods.getActiveModDirectories())
			paths.insert(0, Paths.mods(mod + '/shaders/$path'));
		#end

		for(file in paths)
			if(FileSystem.exists(file))
				return File.getContent(file);

		return null;
	}

	public static function findShaderSource(name:String, extension:String):String
	{
		return getShaderText('$name.$extension');
	}

	public static function applyCameraUniforms(shader:FlxRuntimeShader, camera:FlxCamera):Void
	{
		if(shader == null || shader.data == null || camera == null)
			return;

		if(Reflect.hasField(shader.data, "_camSize"))
			shader.setFloatArray("_camSize", [0, 0, FlxG.width, FlxG.height]);

		if(Reflect.hasField(shader.data, "iResolution"))
			shader.setFloatArray("iResolution", [FlxG.width, FlxG.height]);

		if(Reflect.hasField(shader.data, "chromaKey"))
			shader.setBool("chromaKey", camera.bgColor.alpha < 255);
	}

	public static function applyScreenUniforms(shader:FlxRuntimeShader):Void
	{
		if(shader == null || shader.data == null)
			return;

		if(Reflect.hasField(shader.data, "_camSize"))
			shader.setFloatArray("_camSize", [0, 0, FlxG.width, FlxG.height]);

		if(Reflect.hasField(shader.data, "iResolution"))
			shader.setFloatArray("iResolution", [FlxG.width, FlxG.height]);

		if(Reflect.hasField(shader.data, "chromaKey"))
			shader.setBool("chromaKey", false);
	}

	public function hget(name:String):Dynamic
	{
		if(!Reflect.hasField(data, name))
			return Reflect.getProperty(this, name);

		var field:Dynamic = Reflect.field(data, name);
		var className:String = Type.getClassName(Type.getClass(field));

		if(className != null && className.startsWith("openfl.display.ShaderParameter"))
			return (field.__length > 1) ? field.value : (field.value != null ? field.value[0] : null);

		if(className != null && className.startsWith("openfl.display.ShaderInput"))
			return field.input;

		return field;
	}

	public function hset(name:String, value:Dynamic):Dynamic
	{
		if(!Reflect.hasField(data, name))
		{
			Reflect.setProperty(this, name, value);
			return value;
		}

		var field:Dynamic = Reflect.field(data, name);
		var className:String = Type.getClassName(Type.getClass(field));

		if(className != null && className.startsWith("openfl.display.ShaderParameter"))
		{
			if(field.__length <= 1)
				field.value = value != null ? [value] : null;
			else
				field.value = value;
			return value;
		}

		if(className != null && className.startsWith("openfl.display.ShaderInput"))
		{
			var bitmap:BitmapData = null;
			if(value is BitmapData)
				bitmap = value;
			else if(value is FlxGraphic)
				bitmap = cast(value, FlxGraphic).bitmap;

			field.input = bitmap;
			return value;
		}

		Reflect.setField(data, name, value);
		return value;
	}
}

class ShaderTemplates
{
	public static final fragHeader:String = "varying float openfl_Alphav;
varying vec4 openfl_ColorMultiplierv;
varying vec4 openfl_ColorOffsetv;
varying vec2 openfl_TextureCoordv;

uniform bool openfl_HasColorTransform;
uniform vec2 openfl_TextureSize;
uniform sampler2D bitmap;

uniform bool hasTransform;
uniform bool hasColorTransform;

vec4 applyFlixelEffects(vec4 color) {
	if(!hasTransform) {
		return color;
	}

	if(color.a == 0.0) {
		return vec4(0.0, 0.0, 0.0, 0.0);
	}

	if(!hasColorTransform) {
		return color * openfl_Alphav;
	}

	color.rgb = color.rgb / color.a;
	color = clamp(openfl_ColorOffsetv + (color * openfl_ColorMultiplierv), 0.0, 1.0);

	if(color.a > 0.0) {
		return vec4(color.rgb * color.a * openfl_Alphav, color.a * openfl_Alphav);
	}
	return vec4(0.0, 0.0, 0.0, 0.0);
}

vec4 flixel_texture2D(sampler2D bitmap, vec2 coord) {
	vec4 color = texture2D(bitmap, coord);
	return applyFlixelEffects(color);
}

uniform vec4 _camSize;

float map(float value, float min1, float max1, float min2, float max2) {
	return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}

vec2 getCamPos(vec2 pos) {
	vec4 size = _camSize / vec4(openfl_TextureSize, openfl_TextureSize);
	return vec2(map(pos.x, size.x, size.x + size.z, 0.0, 1.0), map(pos.y, size.y, size.y + size.w, 0.0, 1.0));
}

vec2 camToOg(vec2 pos) {
	vec4 size = _camSize / vec4(openfl_TextureSize, openfl_TextureSize);
	return vec2(map(pos.x, 0.0, 1.0, size.x, size.x + size.z), map(pos.y, 0.0, 1.0, size.y, size.y + size.w));
}

vec4 textureCam(sampler2D bitmap, vec2 pos) {
	return flixel_texture2D(bitmap, camToOg(pos));
}";

	public static final fragBody:String = "gl_FragColor = flixel_texture2D(bitmap, openfl_TextureCoordv);";

	public static final vertHeader:String = "attribute float openfl_Alpha;
attribute vec4 openfl_ColorMultiplier;
attribute vec4 openfl_ColorOffset;
attribute vec4 openfl_Position;
attribute vec2 openfl_TextureCoord;

varying float openfl_Alphav;
varying vec4 openfl_ColorMultiplierv;
varying vec4 openfl_ColorOffsetv;
varying vec2 openfl_TextureCoordv;

uniform mat4 openfl_Matrix;
uniform bool openfl_HasColorTransform;
uniform vec2 openfl_TextureSize;

attribute float alpha;
attribute vec4 colorMultiplier;
attribute vec4 colorOffset;
uniform bool hasColorTransform;";

	public static final vertBody:String = "openfl_Alphav = openfl_Alpha;
openfl_TextureCoordv = openfl_TextureCoord;

if(openfl_HasColorTransform) {
	openfl_ColorMultiplierv = openfl_ColorMultiplier;
	openfl_ColorOffsetv = openfl_ColorOffset / 255.0;
}

openfl_Alphav = openfl_Alpha * alpha;

if(hasColorTransform) {
	openfl_ColorOffsetv = colorOffset / 255.0;
	openfl_ColorMultiplierv = colorMultiplier;
}

gl_Position = openfl_Matrix * openfl_Position;";

	public static final vertBackCompatVarList:Array<EReg> = [
		~/attribute float alpha/,
		~/attribute vec4 colorMultiplier/,
		~/attribute vec4 colorOffset/,
		~/uniform bool hasColorTransform/
	];

	public static final vertHeaderBackCompat:String = "attribute float openfl_Alpha;
attribute vec4 openfl_ColorMultiplier;
attribute vec4 openfl_ColorOffset;
attribute vec4 openfl_Position;
attribute vec2 openfl_TextureCoord;

varying float openfl_Alphav;
varying vec4 openfl_ColorMultiplierv;
varying vec4 openfl_ColorOffsetv;
varying vec2 openfl_TextureCoordv;

uniform mat4 openfl_Matrix;
uniform bool openfl_HasColorTransform;
uniform vec2 openfl_TextureSize;";

	public static final vertBodyBackCompat:String = "openfl_Alphav = openfl_Alpha;
openfl_TextureCoordv = openfl_TextureCoord;

if(openfl_HasColorTransform) {
	openfl_ColorMultiplierv = openfl_ColorMultiplier;
	openfl_ColorOffsetv = openfl_ColorOffset / 255.0;
}

gl_Position = openfl_Matrix * openfl_Position;";

	public static final defaultVertexSource:String = "#pragma header

void main(void) {
	#pragma body
}";

	public static final defaultFragmentSource:String = "#pragma header

void main(void) {
	#pragma body
}";
}
#end
