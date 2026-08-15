package objects;

import haxe.ds.ObjectMap;

/**
 * I CANT CHANGE MEMBERS SO I MADE THIS AS A RENDER THING OF THE SUSTAINS
 * SO THEY WILL NOT BE DRAWN IN FRONT OF THE DAMN NOTES
  */
@:access(flixel.FlxCamera)
class NoteRenderGroup extends FlxTypedGroup<Note>
{
	override public function draw():Void
	{
		var oldDefaultCameras:Array<FlxCamera> = FlxCamera._defaultCameras;
		FlxCamera._defaultCameras = getCameras();

		var activeHeads:ObjectMap<Note, Bool> = new ObjectMap();
		var chains:ObjectMap<Note, Array<Note>> = new ObjectMap();
		for (note in members)
		{
			if (!canDraw(note))
				continue;
			if (!note.isSustainNote)
				activeHeads.set(note, true);
			else if (note.parent != null)
			{
				if (!chains.exists(note.parent))
					chains.set(note.parent, []);
				chains.get(note.parent).push(note);
			}
		}

		var drawn:ObjectMap<Note, Bool> = new ObjectMap();
		for (note in members)
		{
			if (!canDraw(note) || drawn.exists(note))
				continue;

			if (note.isSustainNote)
			{
				// A living parent will draw its entire chain immediately before itselff!
				if (note.parent != null && activeHeads.exists(note.parent))
					continue;
				drawNote(note, drawn);
				continue;
			}

			// preserve the group current odrer (modchart aswell) moving ony its parents
			var chain:Array<Note> = chains.get(note);
			if (chain != null)
				for (sustain in chain)
					drawNote(sustain, drawn);
			drawNote(note, drawn);
		}

		FlxCamera._defaultCameras = oldDefaultCameras;
	}

	static inline function canDraw(note:Note):Bool
		return note != null && note.exists && note.visible;

	static inline function drawNote(note:Note, drawn:ObjectMap<Note, Bool>):Void
	{
		if (drawn.exists(note))
			return;
		note.draw();
		drawn.set(note, true);
	}
}
