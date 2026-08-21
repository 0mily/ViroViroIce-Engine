package states.editors.content;

import flixel.group.FlxSpriteGroup;
import states.editors.ChartingState;

@:access(states.editors.ChartingState) // ur dur
class ChartEditorEvents
{
  public var editor(default, null):ChartingState;
	public var tab(default, null):FlxSpriteGroup;

  public function new(editor:ChartingState, tab:FlxSpriteGroup)
	{
		this.editor = editor;
		this.tab = tab;
	}

  // called once per chart editor framee!
	public function update(elapsed:Float):Void {}

  // reloads the availabel event defination and ther editor metadata
	public function reload():Void {}

  // rebulds the events tab from the current chart selection
	public function onSelectionChanged():Void {}

  // builds da data stored by a newly placed event
	public function buildEventData():Array<String>
	{
		return ['', '', '']; // o vazio do HaxeFlixel
	}
  
}
