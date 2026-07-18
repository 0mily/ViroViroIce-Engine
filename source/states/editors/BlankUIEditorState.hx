package states.editors;

import haxe.crypto.Crc32;
import haxe.ds.List;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.ui.RuntimeComponentBuilder;
import haxe.ui.Toolkit;
import haxe.ui.components.Button;
import haxe.ui.components.Canvas;
import haxe.ui.components.CheckBox;
import haxe.ui.components.DropDown;
import haxe.ui.components.Label;
import haxe.ui.components.NumberStepper;
import haxe.ui.components.TextField;
import haxe.ui.containers.Absolute;
import haxe.ui.containers.HBox;
import haxe.ui.containers.ScrollView;
import haxe.ui.containers.TableView;
import haxe.ui.containers.VBox;
import haxe.ui.containers.dialogs.CollapsibleDialog;
import haxe.ui.containers.dialogs.Dialog;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.data.ArrayDataSource;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import haxe.ui.focus.FocusManager;
import haxe.ui.backend.flixel.components.SpriteWrapper;
import haxe.zip.Entry;
import haxe.zip.Reader;
import haxe.zip.Writer;
import backend.EditorSFX;
import backend.ui.ViroUICursor;
import flixel.tweens.FlxTween;
import lime.ui.FileDialog;
import lime.ui.FileDialogType;
import objects.Character;
import objects.Character.CharacterEditorIconData;

// QUANTO IMPORT PORRA

typedef BlankUIWidgetData = {
	var kind:String;
	var id:String;
	var tag:String;
	var call:String;
	var x:Float;
	var y:Float;
	var width:Float;
	var height:Float;
	var text:String;
	var value:String;
	var options:String;
	var min:String;
	var max:String;
	var color:String;
	var tab:String;
}

typedef BlankUIWindowData = {
	var id:String;
	var title:String;
	var type:String;
	var tabs:String;
	var x:Float;
	var y:Float;
	var width:Float;
	var height:Float;
	var widgets:Array<BlankUIWidgetData>;
}

class BlankUIEditorState extends ScriptedState
{
	// Nothing the state
}
