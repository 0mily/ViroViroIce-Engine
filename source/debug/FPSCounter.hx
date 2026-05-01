package debug;

import flixel.FlxG;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFormat;
// import openfl.system.System; https://media.tenor.com/I5hK9OAjDcsAAAAM/middle-finger-middle-finger-emoji.gif

/**
	The FPS class provides an easy-to-use monitor to display
	the current frame rate of an OpenFL project
**/
class FPSCounter extends Sprite
{
	/**
		The current frame rate, expressed using frames-per-second
	**/
	public var currentFPS(default, null):Int;

	/**
		The current memory usage (WARNING: this is NOT your total program memory usage, rather it shows the garbage collector memory)
	**/
	public var memoryMegas(get, never):Float;


	public static var engineName:String = "ViroVirolce Engine"; // "Cool as Ice Engine";

	@:noCompletion private var times:Array<Float>;
	@:noCompletion private var peakMemory:Float = 0;
	@:noCompletion private var label:TextField;
	@:noCompletion private var bg:Shape;

	static inline final PINTOLAS:Int   = 4;
	static inline final FPS_PINTO:Int  = 30;
	static inline final SUF_PINTO:Int  = 10;
	static inline final MEM_PINTO:Int  = 15;
	static inline final ENG_PINTO:Int  = 12; // surpreendente oq realmente foi feito por mim de 2025 e oq foi feito por mim em 2026

	public function new(x:Float = 10, y:Float = 10, color:Int = 0xFFFFFF) // eu sou bura e esqueci do main oi
	{
		super();
		this.x = x;
		this.y = y;
		

		bg = new Shape();
		addChild(bg);

		label = new TextField();
		label.x = PINTOLAS;
		label.y = PINTOLAS;
		label.selectable   = false;
		label.mouseEnabled = false;
		label.autoSize     = LEFT;
		label.multiline    = true;
		label.defaultTextFormat = new TextFormat(Paths.font('fpsfont.ttf'), SUF_PINTO, color);
		label.shader = new debug.ScriptTraceDisplay.DebugTextShader();
		addChild(label);

		currentFPS = 0;
		times = [];
	}

	var deltaTimeout:Float = 0.0;
	// Event Handlers
	private override function __enterFrame(deltaTime:Float):Void
	{
		final now:Float = haxe.Timer.stamp() * 1000;
		times.push(now);
		while (times[0] < now - 1000) times.shift();
		// prevents the overlay from updating every frame, why would you need to anyways @crowplexus
		if (deltaTimeout < 50) {
			deltaTimeout += deltaTime;
			return;
		}

		currentFPS = times.length < FlxG.updateFramerate ? times.length : FlxG.updateFramerate;
		updateText();
		deltaTimeout = 0.0;
	}

	public dynamic function updateText():Void { // so people can override it in hscript
		var mem:Float = memoryMegas;
		if (mem > peakMemory) peakMemory = mem;

		var memStr:String  = flixel.util.FlxStringUtil.formatBytes(mem);
		var peakStr:String = flixel.util.FlxStringUtil.formatBytes(peakMemory);

		var fpsColor:Int = (currentFPS < FlxG.drawFramerate * 0.5) ? 0xFFFF4444 : 0xFFFFFFFF;

		final fpsStr:String    = '$currentFPS';
		final sufStr:String    = ' FPS\n';
		final memLine:String   = '$memStr / $peakStr\n';
		final engLine:String   = engineName;

		label.text = fpsStr + sufStr + memLine + engLine;

		var font = Paths.font('fpsfont.ttf');

		var fmtFPS  = new TextFormat(font, FPS_PINTO, fpsColor,  true);
		var fmtSuf  = new TextFormat(font, SUF_PINTO, 0xFFFFFF,  false);
		var fmtMem  = new TextFormat(font, MEM_PINTO, 0xFFFFFF,  false);
		var fmtEng  = new TextFormat(font, ENG_PINTO, 0xAAAAAA,  false);

		var p0:Int = 0;
		var p1:Int = p0 + fpsStr.length;
		var p2:Int = p1 + sufStr.length;
		var p3:Int = p2 + memLine.length;
		var p4:Int = p3 + engLine.length;

		label.setTextFormat(fmtFPS, p0, p1);
		label.setTextFormat(fmtSuf, p1, p2);
		label.setTextFormat(fmtMem, p2, p3);
		label.setTextFormat(fmtEng, p3, p4);

		var w:Float = label.width  + PINTOLAS * 2;
		var h:Float = label.height + PINTOLAS * 2;

		bg.graphics.clear();
		bg.graphics.beginFill(0x000000, 0.5);
		bg.graphics.drawRoundRect(0, 0, w, h, 0, 0);
		bg.graphics.endFill();
	}

	inline function get_memoryMegas():#if cpp Float #else Int #end {
		#if cpp
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
		#else
		return openfl.system.System.totalMemory;
		#end
	}
}
