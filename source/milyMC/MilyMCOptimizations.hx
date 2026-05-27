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
	static var noteInfoCache:Array<Array<Dynamic>> = [];

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

		var info:Array<Dynamic> = noteInfoCache[index];
		if (info == null)
			info = noteInfoCache[index] = [];

		info[0] = note.noteData;
		info[1] = note.mustPress;
		info[2] = note.isSustainNote;
		info[3] = note.offsetX;
		info[4] = note.offsetY;
		info[5] = note.distance;
		info[6] = noteSpeed;
		info[7] = sustainPixels;
		info[8] = note.multAlpha;
		info[9] = note.isSustainEnd;
		return info;
	}

	static function applyStrumState(index:Int, x:Float, y:Float, angle:Float, scaleX:Float, scaleY:Float, alpha:Float, brightness:Float):Void
	{
		var game:PlayState = PlayState.instance;
		var strum:StrumNote = game?.strumLineNotes?.members[index];
		if (strum == null)
			return;

		if (strum.x != x) strum.x = x;
		if (strum.y != y) strum.y = y;
		if (strum.angle != angle) strum.angle = angle;
		if (strum.scale.x != scaleX) strum.scale.x = scaleX;
		if (strum.scale.y != scaleY) strum.scale.y = scaleY;
		if (strum.alpha != alpha) strum.alpha = alpha;
		applyBrightness(strum, brightness);
	}

	static function applyNoteState(index:Int, strumID:Int, x:Float, y:Float, angle:Float, scaleX:Float, scaleY:Float, alpha:Float, brightness:Float,
			isSustainNote:Bool, flipX:Bool, tangentAngle:Float, drawLength:Float):Void
	{
		var note:Note = getNote(index);
		if (note == null)
			return;

		if (note.scale.x != scaleX) note.scale.x = scaleX;
		if (note.alpha != alpha) note.alpha = alpha;
		applyBrightness(note, brightness);

		if (!isSustainNote)
		{
			if (note.x != x) note.x = x;
			if (note.y != y) note.y = y;
			if (note.angle != angle) note.angle = angle;
			if (note.scale.y != scaleY) note.scale.y = scaleY;
			return;
		}

		var strum:StrumNote = PlayState.instance?.strumLineNotes?.members[strumID];
		var strumWidth:Float = strum?.width ?? 112;
		var strumHeight:Float = strum?.height ?? 112;

		var originX:Float = note.frameWidth * 0.5;
		if (note.origin.x != originX || note.origin.y != 0)
			note.origin.set(originX, 0);
		if (note.offset.x != 0 || note.offset.y != 0)
			note.offset.set();
		if (note.flipX != flipX) note.flipX = flipX;
		if (note.flipY) note.flipY = false;
		if (note.angle != tangentAngle) note.angle = tangentAngle;

		var finalX:Float = x + ((strumWidth - note.frameWidth) * 0.5);
		var finalY:Float = y + (strumHeight * 0.5);
		if (note.x != finalX) note.x = finalX;
		if (note.y != finalY) note.y = finalY;

		if (!note.isSustainEnd && drawLength > 1 && note.frameHeight > 0)
		{
			var scaleY:Float = Math.max(0.001, drawLength / Math.max(1, note.frameHeight));
			if (note.scale.y != scaleY) note.scale.y = scaleY;
		}
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
