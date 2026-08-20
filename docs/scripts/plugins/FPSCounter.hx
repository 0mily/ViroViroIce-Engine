// HOLY fnf configurations
// since i don't have too much time for coding directly here without test it,
// i'll leave this sketch here.

class FPSCounter extends Sprite {

	public static var engineName:String = "ViroVirolce Engine"; // "Cool as Ice Engine";
	public static var stateName:String = ""; // "Cool as Ice Engine";

	static inline final PINTOLAS:Int   = 4;
	static inline final FPS_PINTO:Int  = 30;
	static inline final SUF_PINTO:Int  = 10;
	static inline final MEM_PINTO:Int  = 15;
	static inline final STA_PINTO:Int  = 15;
	static inline final ENG_PINTO:Int  = 12; // não vou questionar minha mente de meses atrás.

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
}
