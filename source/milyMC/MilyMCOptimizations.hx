package milyMC;

#if LUA_ALLOWED
import objects.Note;
import objects.StrumNote;
import psychlua.FunkinLua;
import states.PlayState;
#end

class MilyMCOptimizations
{
	#if LUA_ALLOWED
	public static function registerLuaCallbacks():Void
	{
		FunkinLua.registerFunction('_milyMCGetNoteCount', getNoteCount);
		FunkinLua.registerFunction('_milyMCGetNoteInfo', getNoteInfo);
		FunkinLua.registerFunction('_milyMCApplyStrumState', applyStrumState);
		FunkinLua.registerFunction('_milyMCApplyNoteState', applyNoteState);
	}

	static function getNoteCount():Int
		return PlayState.instance?.notes?.length ?? 0;

	static function getNoteInfo(index:Int, laneMaskBits:Int = 255):Array<Dynamic>
	{
		var note:Note = getNote(index);
		var game:PlayState = PlayState.instance;
		if (note == null || game == null)
			return null;

		var strumID:Int = note.noteData + (note.mustPress ? 4 : 0);
		if (strumID >= 0 && strumID <= 7 && (laneMaskBits & (1 << strumID)) == 0)
			return null;

		var noteSpeed:Float = (game.songSpeed * note.multSpeed) / Math.max(0.001, game.playbackRate);
		var sustainPixels:Float = Math.abs(0.45 * note.sustainLength * noteSpeed);

		return [
			note.noteData,
			note.mustPress,
			note.isSustainNote,
			note.offsetX,
			note.offsetY,
			note.distance,
			noteSpeed,
			sustainPixels,
			note.multAlpha,
			note.isSustainEnd
		];
	}

	static function applyStrumState(index:Int, x:Float, y:Float, angle:Float, scaleX:Float, scaleY:Float, alpha:Float, brightness:Float):Void
	{
		var game:PlayState = PlayState.instance;
		var strum:StrumNote = game?.strumLineNotes?.members[index];
		if (strum == null)
			return;

		strum.x = x;
		strum.y = y;
		strum.angle = angle;
		strum.scale.x = scaleX;
		strum.scale.y = scaleY;
		strum.alpha = alpha;
		applyBrightness(strum, brightness);
	}

	static function applyNoteState(index:Int, strumID:Int, x:Float, y:Float, angle:Float, scaleX:Float, scaleY:Float, alpha:Float, brightness:Float,
			isSustainNote:Bool, flipX:Bool, tangentAngle:Float, drawLength:Float):Void
	{
		var note:Note = getNote(index);
		if (note == null)
			return;

		note.scale.x = scaleX;
		note.alpha = alpha;
		applyBrightness(note, brightness);

		if (!isSustainNote)
		{
			note.x = x;
			note.y = y;
			note.angle = angle;
			note.scale.y = scaleY;
			return;
		}

		var strum:StrumNote = PlayState.instance?.strumLineNotes?.members[strumID];
		var strumWidth:Float = strum?.width ?? 112;
		var strumHeight:Float = strum?.height ?? 112;

		note.origin.set(note.frameWidth * 0.5, 0);
		note.offset.set();
		note.flipX = flipX;
		note.flipY = false;
		note.angle = tangentAngle;
		note.x = x + ((strumWidth - note.frameWidth) * 0.5);
		note.y = y + (strumHeight * 0.5);

		if (!note.isSustainEnd && drawLength > 1 && note.frameHeight > 0)
			note.scale.y = Math.max(0.001, drawLength / Math.max(1, note.frameHeight - 1));
	}

	static function getNote(index:Int):Note
	{
		var note:Note = PlayState.instance?.notes?.members[index];
		if (note == null || !note.exists || !note.alive)
			return null;
		return note;
	}

	static function applyBrightness(sprite:flixel.FlxSprite, brightness:Float):Void
	{
		brightness = Math.max(0, Math.min(1, brightness));
		var offset:Float = brightness * 255;
		var transform = sprite.colorTransform;

		if (Math.abs(transform.redOffset - offset) <= 0.001
			&& Math.abs(transform.greenOffset - offset) <= 0.001
			&& Math.abs(transform.blueOffset - offset) <= 0.001
			&& transform.redMultiplier == 1
			&& transform.greenMultiplier == 1
			&& transform.blueMultiplier == 1)
			return;

		transform.redMultiplier = 1;
		transform.greenMultiplier = 1;
		transform.blueMultiplier = 1;
		transform.redOffset = offset;
		transform.greenOffset = offset;
		transform.blueOffset = offset;
	}
	#else
	public static function registerLuaCallbacks():Void {}
	#end
}
