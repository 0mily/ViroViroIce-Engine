package funkin.data;

class Conductor
{
	public static var bpm(get, set):Float;
	public static var crochet(get, set):Float;
	public static var crotchet(get, set):Float;
	public static var stepCrochet(get, set):Float;
	public static var stepCrotchet(get, set):Float;
	public static var songPosition(get, set):Float;
	public static var offset(get, set):Float;
	public static var safeZoneOffset(get, set):Float;

	static function get_bpm():Float return backend.Conductor.bpm;
	static function set_bpm(value:Float):Float return backend.Conductor.bpm = value;
	static function get_crochet():Float return backend.Conductor.crochet;
	static function set_crochet(value:Float):Float return backend.Conductor.crochet = value;
	static function get_crotchet():Float return backend.Conductor.crochet;
	static function set_crotchet(value:Float):Float return backend.Conductor.crochet = value;
	static function get_stepCrochet():Float return backend.Conductor.stepCrochet;
	static function set_stepCrochet(value:Float):Float return backend.Conductor.stepCrochet = value;
	static function get_stepCrotchet():Float return backend.Conductor.stepCrochet;
	static function set_stepCrotchet(value:Float):Float return backend.Conductor.stepCrochet = value;
	static function get_songPosition():Float return backend.Conductor.songPosition;
	static function set_songPosition(value:Float):Float return backend.Conductor.songPosition = value;
	static function get_offset():Float return backend.Conductor.offset;
	static function set_offset(value:Float):Float return backend.Conductor.offset = value;
	static function get_safeZoneOffset():Float return backend.Conductor.safeZoneOffset;
	static function set_safeZoneOffset(value:Float):Float return backend.Conductor.safeZoneOffset = value;

	public static function getStepCrotchetAtTime(time:Float, ?bpmChangeMap:Array<backend.BPMChangeEvent>):Float
		return backend.Conductor.getStepCrotchetAtTime(time, bpmChangeMap);

	public static function getCrotchetAtTime(time:Float, ?bpmChangeMap:Array<backend.BPMChangeEvent>):Float
		return backend.Conductor.getCrotchetAtTime(time, bpmChangeMap);

	public static function getBPMFromSeconds(time:Float, ?bpmChangeMap:Array<backend.BPMChangeEvent>):backend.BPMChangeEvent
		return backend.Conductor.getBPMFromSeconds(time, bpmChangeMap);

	public static function getBPMFromStep(step:Float, ?bpmChangeMap:Array<backend.BPMChangeEvent>):backend.BPMChangeEvent
		return backend.Conductor.getBPMFromStep(step, bpmChangeMap);

	public static function stepToSeconds(step:Float, ?bpmChangeMap:Array<backend.BPMChangeEvent>):Float
		return backend.Conductor.stepToSeconds(step, bpmChangeMap);

	public static function beatToSeconds(beat:Float, ?bpmChangeMap:Array<backend.BPMChangeEvent>):Float
		return backend.Conductor.beatToSeconds(beat, bpmChangeMap);
}
