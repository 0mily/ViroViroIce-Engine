package objects;

import haxe.ds.ObjectMap;
import states.PlayState;

/**
 * I CANT CHANGE MEMBERS SO I MADE THIS AS A RENDER THING OF THE SUSTAINS
 * SO THEY WILL NOT BE DRAWN IN FRONT OF THE DAMN NOTES
  */
@:access(flixel.FlxCamera)
class NoteRenderGroup extends FlxTypedGroup<Note>
{
	var sustainMeshes:ObjectMap<Note, SustainMesh> = new ObjectMap();

	override public function draw():Void
	{
		var oldDefaultCameras:Array<FlxCamera> = FlxCamera._defaultCameras;
		FlxCamera._defaultCameras = getCameras();

		var chains:ObjectMap<Note, Array<Note>> = new ObjectMap();
		var activeHeads:ObjectMap<Note, Bool> = new ObjectMap();
		var activeChains:ObjectMap<Note, Bool> = new ObjectMap();
		for (note in members)
		{
			if (!canDraw(note))
				continue;
			if (!note.isSustainNote)
				activeHeads.set(note, true);
			else if (note.parent != null)
			{
				activeChains.set(note.parent, true);
				if (!chains.exists(note.parent))
					chains.set(note.parent, []);
				chains.get(note.parent).push(note);
			}
		}

		var drawn:ObjectMap<Note, Bool> = new ObjectMap();
		var drawnChains:ObjectMap<Note, Bool> = new ObjectMap();
		for (note in members)
		{
			if (!canDraw(note) || drawn.exists(note))
				continue;

			if (note.isSustainNote)
			{
				if (note.parent != null && activeHeads.exists(note.parent))
					continue;
				drawChain(note.parent, chains.get(note.parent), drawn, drawnChains);
				continue;
			}

			var chain:Array<Note> = chains.get(note);
			if (chain != null)
				drawChain(note, chain, drawn, drawnChains);
			drawNote(note, drawn);
		}

		cleanupMeshes(activeChains);

		FlxCamera._defaultCameras = oldDefaultCameras;
	}

	function drawChain(parent:Note, chain:Array<Note>, drawn:ObjectMap<Note, Bool>, drawnChains:ObjectMap<Note, Bool>):Void
	{
		if (parent == null || chain == null || drawnChains.exists(parent))
			return;
		drawnChains.set(parent, true);

		var body:Array<Note> = [];
		var end:Note = null;
		for (note in chain)
		{
			drawn.set(note, true);
			if (note.isSustainEnd)
			{
				if (end == null || note.strumTime > end.strumTime)
					end = note;
			}
			else
				body.push(note);
		}

		var mesh:SustainMesh = sustainMeshes.get(parent);
		if (mesh == null)
		{
			mesh = new SustainMesh();
			sustainMeshes.set(parent, mesh);
		}

		var clipTargetX:Float = Math.NaN;
		var clipTargetY:Float = Math.NaN;
		var game:PlayState = PlayState.instance;
		if (game != null && game.notes == this && parent.noteData >= 0)
		{
			var strumGroup:FlxTypedGroup<StrumNote> = parent.mustPress ? game.playerStrums : game.opponentStrums;
			var strum:StrumNote = strumGroup != null && parent.noteData < strumGroup.members.length
				? strumGroup.members[parent.noteData] : null;
			if (strum != null)
			{
				clipTargetX = strum.x + strum.width * 0.5;
				clipTargetY = strum.y + strum.height * 0.5;
			}
		}

		if (mesh.rebuild(parent, body, end, clipTargetX, clipTargetY))
			mesh.draw();
		else
		{
			for (note in body)
			{
				drawn.remove(note);
				drawNote(note, drawn);
			}
		}

		if (end != null)
		{
			drawn.remove(end);
			drawNote(end, drawn);
		}
	}

	function cleanupMeshes(activeChains:ObjectMap<Note, Bool>):Void
	{
		var expired:Array<Note> = [];
		for (parent in sustainMeshes.keys())
			if (!activeChains.exists(parent))
				expired.push(parent);

		for (parent in expired)
		{
			sustainMeshes.get(parent)?.destroy();
			sustainMeshes.remove(parent);
		}
	}

	override public function destroy():Void
	{
		for (mesh in sustainMeshes)
			mesh?.destroy();
		sustainMeshes = null;
		super.destroy();
	}

	static inline function canDraw(note:Note):Bool
		return note != null && note.exists && note.visible;

	static inline function drawNote(note:Note, drawn:ObjectMap<Note, Bool>):Void
	{
		if (drawn.exists(note))
			return;
		if (!note.isSustainNote && note.tail.length > 0)
			note.storeSustainMeshStart();
		note.draw();
		drawn.set(note, true);
	}
}
