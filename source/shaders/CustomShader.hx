package shaders;

#if (!flash && sys)
class CustomShader extends CodenameRuntimeShader
{
	public var path:String = "";

	public function new(name:String)
	{
		var fragPath:String = 'shaders/$name.frag';
		var vertPath:String = 'shaders/$name.vert';
		var frag:String = CodenameRuntimeShader.findShaderSource(name, "frag");
		var vert:String = CodenameRuntimeShader.findShaderSource(name, "vert");

		if(frag == null && vert == null)
			FlxG.log.warn('Shader "$name" could not be found.');

		super(name, frag, vert);

		path = fragPath + vertPath;
		fileName = name;
		fragFileName = fragPath;
		vertFileName = vertPath;
	}
}
#end
