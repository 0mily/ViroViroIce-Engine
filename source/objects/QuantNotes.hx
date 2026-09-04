package objects;

// ok i will comment more
class QuantNotes
{
	public static inline final ROWS_PER_BEAT:Int = 240;
	public static inline final BEATS_PER_MEASURE:Int = 4;
	public static inline final ROWS_PER_MEASURE:Int = ROWS_PER_BEAT * BEATS_PER_MEASURE;

	public static final QUANTIZATIONS:Array<Int> = [4, 8, 12, 16, 20, 24, 32, 48, 64, 96, 192];

	/*
	 * Flat colors shared with the chart editor's quantization indicator!! Uhm, yeah!!!
	 */
	public static final PRIMARY_COLORS:Array<FlxColor> = [
		0xFFDF0000, // 4th  - red
		0xFF4040CF, // 8th  - blue
		0xFFAF00AF, // 12th - purple
		0xFFFFAF00, // 16th - yellow
		0xFFFFFFFF, // 20th - white
		0xFFFFA0FF, // 24th - pink
		0xFFFF6030, // 32nd - orange
		0xFF00CFCF, // 48th - cyan
		0xFF00CF00, // 64th - green
		0xFF9F9F9F, // 96th - gray
		0xFF3F3F3F  // 192nd - dark gray
	];

	/*
	 * Hi Nightmare vision evil colors
	 */
	static final PALETTES:Array<Array<FlxColor>> = [
		[0xFFDF0000, 0xFFFFFFFF, 0xFF5B0A30], // 4th  - red
		[0xFF4040CF, 0xFFFFFFFF, 0xFF0A3B5B], // 8th  - blue
		[0xFFAF00AF, 0xFFFFFFFF, 0xFF1D0A5B], // 12th - purple
		[0xFFFFAF00, 0xFFFFFFFF, 0xFF5B2A0A], // 16th - yellow
		[0xFFFFFFFF, 0xFFFFFFFF, 0xFF4F4F4F], // 20th - white
		[0xFFFFA0FF, 0xFFFFFFFF, 0xFF5B0A3A], // 24th - pink
		[0xFFFF6030, 0xFFFFFFFF, 0xFF5B220A], // 32nd - orange
		[0xFF00CFCF, 0xFFFFFFFF, 0xFF0A4B5B], // 48th - cyan
		[0xFF00CF00, 0xFFFFFFFF, 0xFF24560F], // 64th - green
		[0xFF9F9F9F, 0xFFFFFFFF, 0xFF383838], // 96th - gray
		[0xFF3F3F3F, 0xFFFFFFFF, 0xFF171717]  // 192nd - dark gray
	];

	/*
	 * Returns the quantin of a chart timestamp with BPM changes
	 */
	public static function fromTime(strumTime:Float):Int
	{
		var step:Float = Conductor.getStep(strumTime);
		if (Math.isNaN(step))
			return QUANTIZATIONS[QUANTIZATIONS.length - 1];

		return fromRow(Math.round(step * (ROWS_PER_BEAT / 4)));
	}

	public static function fromRow(row:Int):Int
	{
		row = Std.int(Math.abs(row));
		for (quant in QUANTIZATIONS)
		{
			var rowsPerQuant:Int = Std.int(ROWS_PER_MEASURE / quant);
			if (rowsPerQuant > 0 && row % rowsPerQuant == 0)
				return quant;
		}

		return QUANTIZATIONS[QUANTIZATIONS.length - 1];
	}

	public static function getPalette(quant:Int):Array<FlxColor>
	{
		var index:Int = QUANTIZATIONS.indexOf(quant);
		if (index < 0)
			index = PALETTES.length - 1;
		return PALETTES[index].copy();
	}

	/*
	 * Palette config for strums!
	 */
	public static function applyToStrum(strum:StrumNote, ?note:Note):Void
	{
		if (strum == null)
			return;

		var palette:Array<FlxColor> = getPalette(note != null ? note.quant : 4);
		strum.setQuantRGBPalette(palette[0], palette[1], palette[2]);
	}
}
