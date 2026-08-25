package states.editors.content;

import backend.Song;
import backend.Toml;
import backend.lists.ListLoader;
import backend.lists.ListLoader.ListCategoryData;
import backend.lists.ListLoader.ListKind;
import states.editors.ChartingState;
import states.editors.ChartingState.SelectedEventData;
import states.editors.ChartingState.UndoAction;
import states.editors.CharacterEditorState.CharacterHealthColorPicker;
import states.editors.content.MetaNote.EventMetaNote;

private typedef EventDefinition =
{
	var name:String;
	var displayName:String;
	var description:String;
	var layoutType:String;
	var tabs:Array<String>;
	var fields:Array<EventFieldDefinition>;
}

private typedef EventFieldDefinition =
{
	var id:String;
	var type:String;
	var label:String;
	var defaultValue:String;
	var hasDefault:Bool;
	var outputIndex:Int;
	var groupIndex:Int;
	var partIndex:Int;
	var separator:String;
	var options:Array<String>;
	var includeExtraCharacters:Bool;
	var xOffset:Float;
	var yOffset:Float;
	var labelXOffset:Float;
	var labelYOffset:Float;
	var width:Int;
	var labelWidth:Int;
	var step:Float;
	var min:Float;
	var max:Float;
	var decimals:Int;
	var textSize:Int;
	var maxLength:Int;
	var buttonSize:Int;
	var length:Int;
	var maxSize:Int;
	var columns:Int;
	var gap:Int;
	var rowHeight:Float;
	var rowGap:Float;
	var height:Int;
	var advance:Bool;
}

private typedef EventCatalogEntry =
{
	var name:String;
	var displayName:String;
	var description:String;
}

private typedef FieldViewValue =
{
	var value:String;
	var mixed:Bool;
}

private typedef CameraBopEditorState =
{
	var every:Float;
	var unit:String;
	var mode:String;
	var patternSize:Int;
	var pattern:Array<Int>;
	var enabled:Bool;
	var gameZoom:Float;
	var hudZoom:Float;
}

private typedef ChainEditorState =
{
	var every:Float;
	var unit:String;
	var mode:String;
	var patternSize:Int;
	var pattern:Array<Int>;
	var enabled:Bool;
	var color:String;
	var duration:Float;
	var camera:String;
}

// handle the toml thingh
@:access(states.editors.ChartingState)
class ChartEditorEvents
{
	static inline final PANEL_WIDTH:Int = 420;
	static inline final TOOLTIP_DELAY:Float = 0.65;

	public var editor(default, null):ChartingState;
	public var tab(default, null):FlxSpriteGroup;

	var definitions:Map<String, EventDefinition> = new Map();
	var catalog:Array<EventCatalogEntry> = [];
	var eventVisualCategories:Array<ListCategoryData> = [];
	var selectedName:String = '';
	var draftData:Array<String> = ['', '', ''];
	var rebuilding:Bool = false;
	var rebuildQueued:Bool = false;
	var destroyed:Bool = false;

	var ownedControls:Array<FlxSprite> = [];
	var dynamicControls:Array<FlxSprite> = [];

	var eventDropDown:PsychUIDropDownMenu;
	var selectedEventText:FlxText;
	var descriptionText:FlxText;
	var resetDefaultIcon:FlxSprite;
	var fullResetIcon:FlxSprite;
	var tooltipBg:FlxSprite;
	var tooltipText:FlxText;
	var hoveredReset:FlxSprite;
	var resetHoverTime:Float = 0;

	public function new(editor:ChartingState, tab:FlxSpriteGroup)
	{
		this.editor = editor;
		this.tab = tab;
		createBaseUI();
	}

	function createBaseUI():Void
	{
		var objX:Float = 10;
		var objY:Float = 25;
		var dropdownWidth:Int = PANEL_WIDTH - 168;

		eventDropDown = new PsychUIDropDownMenu(objX, objY, [], function(id:Int, label:String)
		{
			if(rebuilding || id < 0 || id >= catalog.length)
				return;
			changeEventType(catalog[id].name);
		}, dropdownWidth);
		eventDropDown.onVisualOpen = function():Bool
		{
			var values:Array<String> = [for(entry in catalog) entry.name];
			var displayNames:Map<String, String> = new Map();
			for(entry in catalog)
				displayNames.set(entry.name, entry.displayName);
			return editor.openVisualListPicker(ListKind.EVENT, eventDropDown, values, eventVisualCategories, displayNames);
		};

		var buttonsX:Float = objX + dropdownWidth + 24;
		var removeButton:PsychUIButton = new PsychUIButton(buttonsX, objY, '-', removeEventFromGroup, 20);
		var addButton:PsychUIButton = new PsychUIButton(buttonsX + 30, objY, '+', addEventToGroup, 20);
		var previousButton:PsychUIButton = new PsychUIButton(buttonsX + 80, objY, '<', function() selectSiblingEvent(-1), 20);
		var nextButton:PsychUIButton = new PsychUIButton(buttonsX + 110, objY, '>', function() selectSiblingEvent(1), 20);
		removeButton.normalStyle.bgColor = FlxColor.RED;
		removeButton.normalStyle.textColor = FlxColor.WHITE;
		addButton.normalStyle.bgColor = FlxColor.GREEN;
		addButton.normalStyle.textColor = FlxColor.WHITE;

		var eventLabel:FlxText = new FlxText(objX, objY - 15, 80, 'Event:');
		selectedEventText = new FlxText(objX, objY + 28, PANEL_WIDTH - 20, '', 8);
		selectedEventText.visible = false;
		descriptionText = new FlxText(objX, 68, PANEL_WIDTH - 20, '', 8);
		descriptionText.wordWrap = true;

		addOwned(eventLabel);
		addOwned(removeButton);
		addOwned(addButton);
		addOwned(previousButton);
		addOwned(nextButton);
		addOwned(selectedEventText);
		addOwned(descriptionText);
		addOwned(eventDropDown);

		resetDefaultIcon = createResetIcon(0, PANEL_WIDTH + 8, 38);
		fullResetIcon = createResetIcon(1, PANEL_WIDTH + 8, 98);
		addOwned(resetDefaultIcon);
		addOwned(fullResetIcon);

		tooltipBg = new FlxSprite();
		tooltipText = new FlxText(0, 0, 190, '', 8);
		tooltipText.wordWrap = true;
		HaxeUITheme.applyText(tooltipText, 8);
		addOwned(tooltipBg);
		addOwned(tooltipText);
		hideResetTooltip();
	}

	function createResetIcon(frame:Int, x:Float, y:Float):FlxSprite
	{
		var icon:FlxSprite = new FlxSprite(x, y).loadGraphic(Paths.image('editors/chart/reset-icons'), true, 150, 150);
		icon.animation.add('icon', [frame], false);
		icon.animation.play('icon');
		icon.setGraphicSize(50, 50);
		icon.updateHitbox();
		icon.antialiasing = ClientPrefs.data.antialiasing;
		return icon;
	}

	function addOwned(control:FlxSprite):Void
	{
		tab.add(control);
		ownedControls.push(control);
	}

	function addDynamic(control:FlxSprite):Void
	{
		tab.add(control);
		dynamicControls.push(control);
	}

	public function update(elapsed:Float):Void
	{
		if(destroyed)
			return;

		if(rebuildQueued)
		{
			rebuildQueued = false;
			rebuild();
		}

		updateResetButtons(elapsed);
	}

	function updateResetButtons(elapsed:Float):Void
	{
		if(editor.mainBox == null || editor.mainBox.selectedName != 'Events')
		{
			hoveredReset = null;
			resetHoverTime = 0;
			hideResetTooltip();
			return;
		}

		var hovered:FlxSprite = null;
		if(FlxG.mouse.overlaps(resetDefaultIcon, resetDefaultIcon.camera))
			hovered = resetDefaultIcon;
		else if(FlxG.mouse.overlaps(fullResetIcon, fullResetIcon.camera))
			hovered = fullResetIcon;

		if(hovered != hoveredReset)
		{
			hoveredReset = hovered;
			resetHoverTime = 0;
			hideResetTooltip();
		}
		else if(hovered != null)
		{
			resetHoverTime += elapsed;
			if(resetHoverTime >= TOOLTIP_DELAY)
				showResetTooltip(hovered);
		}

		resetDefaultIcon.scale.set(hovered == resetDefaultIcon ? 1.08 : 1, hovered == resetDefaultIcon ? 1.08 : 1);
		fullResetIcon.scale.set(hovered == fullResetIcon ? 1.08 : 1, hovered == fullResetIcon ? 1.08 : 1);

		if(hovered != null && FlxG.mouse.justPressed)
		{
			editor.ignoreClickForThisFrame = true;
			if(hovered == resetDefaultIcon)
				resetToDefaults();
			else
				fullReset();
			EditorSFX.playClick(0.65);
		}
	}

	function showResetTooltip(icon:FlxSprite):Void
	{
		var isDefault:Bool = icon == resetDefaultIcon;
		tooltipText.text = isDefault
			? 'Reset to Default\nRestores every value defined by this event.'
			: 'Full Reset\nClears every value and leaves the event empty.';
		tooltipText.updateHitbox();
		tooltipText.setPosition(icon.x + icon.width + 8, icon.y + (icon.height - tooltipText.height) * 0.5);
		HaxeUITheme.drawRoundedBox(tooltipBg, Std.int(tooltipText.width + 10), Std.int(tooltipText.height + 8), HaxeUITheme.BG, 0.98);
		tooltipBg.setPosition(tooltipText.x - 5, tooltipText.y - 4);
		tooltipBg.visible = tooltipText.visible = true;
		bringToFront(tooltipBg);
		bringToFront(tooltipText);
	}

	function hideResetTooltip():Void
	{
		if(tooltipBg != null) tooltipBg.visible = false;
		if(tooltipText != null) tooltipText.visible = false;
	}

	public function reload():Void
	{
		if(destroyed)
			return;

		var previousName:String = selectedName;
		definitions = new Map();
		catalog = [];

		var txtDescriptions:Map<String, String> = new Map();
		for(file in editor.loadFileList('data/events/', null, ['.txt']))
			txtDescriptions.set(file, Paths.getTextFromFile('data/events/$file.txt'));

		for(file in editor.loadFileList('data/events/', null, ['.toml']))
		{
			var definition:EventDefinition = loadDefinition(file, txtDescriptions.get(file));
			if(definition != null)
			{
				definitions.set(definition.name, definition);
				upsertCatalog(definition.name, definition.displayName, definition.description);
			}
		}

		for(file in editor.loadFileList('data/events/', null, ['.lua', '.hx']))
			if(!catalogContains(file))
				upsertCatalog(file, file, txtDescriptions.exists(file) ? txtDescriptions.get(file) : 'Scripted event.');

		for(file in txtDescriptions.keys())
			if(!catalogContains(file))
				upsertCatalog(file, file, txtDescriptions.get(file));

		eventVisualCategories = ListLoader.load(ListKind.EVENT, editor);
		for(eventName in ListLoader.names(eventVisualCategories))
			if(!catalogContains(eventName))
				upsertCatalog(eventName, eventName, 'Event added by a list script.');

		var displayList:Array<String> = [];
		for(index => entry in catalog)
			displayList.push('${index + 1}. ${entry.displayName}');
		eventDropDown.list = displayList;

		if(!catalogContains(previousName))
			previousName = '';
		selectedName = previousName;
		setDropDownName(selectedName);

		if(draftData == null || draftData.length < 1 || draftData[0] != selectedName)
			draftData = createDefaultEventData(selectedName);

		onSelectionChanged();
	}

	public function onSelectionChanged():Void
	{
		if(destroyed || rebuilding)
			return;

		if(editor.selectedEvents.length > 0)
		{
			var firstName:String = eventName(editor.selectedEvents[0].event);
			var sameName:Bool = true;
			for(selection in editor.selectedEvents)
				if(eventName(selection.event) != firstName)
				{
					sameName = false;
					break;
				}

			selectedName = sameName ? firstName : '';
			if(sameName)
				draftData = copyEventData(editor.selectedEvents[0].event);
		}
		else if(draftData == null)
			draftData = createDefaultEventData(selectedName);

		setDropDownName(selectedName);
		rebuild();
	}

	public function handleUIEvent(id:String, sender:Dynamic):Void
	{
		if(id != PsychUIDropDownMenu.REVEAL_EVENT || sender == null)
			return;

		var control:FlxSprite = cast sender;
		if(control == eventDropDown || dynamicControls.contains(control))
		{
			bringToFront(control);
			bringToFront(resetDefaultIcon);
			bringToFront(fullResetIcon);
			bringToFront(tooltipBg);
			bringToFront(tooltipText);
		}
	}

	public function buildEventData():Array<String>
	{
		var source:Array<String> = null;
		if(editor.selectedEvents.length > 0)
			source = editor.selectedEvents[0].event;
		else
			source = draftData;

		if(source == null || source.length < 1)
			source = createDefaultEventData(selectedName);
		return copyEventData(source);
	}

	function changeEventType(name:String):Void
	{
		selectedName = name ?? '';
		var oldBPMMap = selectionTouchesBPM(selectedName) ? Conductor.copyBPMChanges() : null;

		if(editor.selectedEvents.length > 0)
		{
			for(selection in editor.selectedEvents)
			{
				replaceEventData(selection.event, createDefaultEventData(selectedName));
				selection.note.updateEventInfo();
			}
			draftData = copyEventData(editor.selectedEvents[0].event);
		}
		else
			draftData = createDefaultEventData(selectedName);

		if(oldBPMMap != null)
			editor.adaptNotes(oldBPMMap, false);
		rebuild();
	}

	function resetToDefaults():Void
	{
		var oldBPMMap = selectionTouchesBPM(selectedName) ? Conductor.copyBPMChanges() : null;
		if(editor.selectedEvents.length > 0)
		{
			for(selection in editor.selectedEvents)
			{
				var name:String = eventName(selection.event);
				replaceEventData(selection.event, createDefaultEventData(name));
				selection.note.updateEventInfo();
			}
			draftData = copyEventData(editor.selectedEvents[0].event);
		}
		else
			draftData = createDefaultEventData(selectedName);

		if(oldBPMMap != null)
			editor.adaptNotes(oldBPMMap, false);
		rebuild();
	}

	function fullReset():Void
	{
		var oldBPMMap = selectionTouchesBPM(selectedName) ? Conductor.copyBPMChanges() : null;
		if(editor.selectedEvents.length > 0)
		{
			for(selection in editor.selectedEvents)
			{
				var name:String = eventName(selection.event);
				replaceEventData(selection.event, createBlankEventData(name, selection.event.length));
				selection.note.updateEventInfo();
			}
			draftData = copyEventData(editor.selectedEvents[0].event);
		}
		else
			draftData = createBlankEventData(selectedName, draftData != null ? draftData.length : 3);

		if(oldBPMMap != null)
			editor.adaptNotes(oldBPMMap, false);
		rebuild();
	}

	function removeEventFromGroup():Void
	{
		var targets:Array<SelectedEventData> = getButtonTargets(true);
		if(targets.length < 1)
			return;

		var oldBPMMap = targetsTouchBPM(targets) ? Conductor.copyBPMChanges() : null;
		var removed:Array<SelectedEventData> = [];
		for(target in targets)
		{
			var note = target.note;
			if(note == null || !note.events.contains(target.event))
				continue;

			note.events.remove(target.event);
			note.updateEventInfo();
			editor.selectedEvents.remove(target);
			removed.push(target);

			if(note.events.length < 1)
			{
				editor.selectedNotes.remove(note);
				editor.events.remove(note);
				editor.curRenderedNotes.remove(note, true);
			}
		}

		if(removed.length > 0)
			editor.addUndoAction(UndoAction.DELETE_EVENT, {events: removed});
		editor.updateSelectedEvents();
		editor.curEventSelected = Std.int(Math.max(0, editor.curEventSelected - 1));
		if(oldBPMMap != null)
			editor.adaptNotes(oldBPMMap, false);
		onSelectionChanged();
	}

	function addEventToGroup():Void
	{
		var targets:Array<SelectedEventData> = getButtonTargets(true);
		if(targets.length < 1)
			return;

		var newSelections:Array<SelectedEventData> = [];
		var touchedNotes:Array<Dynamic> = [];
		var addsBPM:Bool = Song.isBPMChangeEventName(selectedName);
		var oldBPMMap = addsBPM ? Conductor.copyBPMChanges() : null;

		for(target in targets)
		{
			var note = target.note;
			if(note == null || touchedNotes.contains(note))
				continue;
			touchedNotes.push(note);

			var newEvent:Array<String> = createDefaultEventData(selectedName);
			note.events.push(newEvent);
			note.updateEventInfo();
			newSelections.push({event: newEvent, note: note});
		}

		if(newSelections.length < 1)
			return;

		editor.selectedEvents.resize(0);
		for(selection in newSelections)
			editor.selectedEvents.push(selection);
		editor.curEventSelected = newSelections[0].note.events.length - 1;
		editor.addUndoAction(UndoAction.ADD_EVENT, {events: newSelections});
		if(oldBPMMap != null)
			editor.adaptNotes(oldBPMMap, false);
		onSelectionChanged();
	}

	function selectSiblingEvent(direction:Int):Void
	{
		var targets:Array<SelectedEventData> = getButtonTargets(false);
		if(targets.length != 1)
			return;

		var note = targets[0].note;
		if(note == null || note.events.length < 1)
			return;

		editor.curEventSelected = FlxMath.wrap(editor.curEventSelected + direction, 0, note.events.length - 1);
		editor.selectedEvents.resize(0);
		editor.selectedEvents.push({event: note.events[editor.curEventSelected], note: note});
		onSelectionChanged();
	}

	function getButtonTargets(allowMultiple:Bool):Array<SelectedEventData>
	{
		if(editor.selectedEvents.length < 1 && editor.selectedNotes.length == 1 && editor.selectedNotes[0].isEvent)
		{
			var note:EventMetaNote = cast editor.selectedNotes[0];
			if(note.events.length > 0)
			{
				var index:Int = Std.int(FlxMath.bound(editor.curEventSelected, 0, note.events.length - 1));
				return [{event: note.events[index], note: note}];
			}
		}

		if(editor.selectedEvents.length < 1)
		{
			editor.showOutput('No events are selected!', true);
			return [];
		}
		if(!allowMultiple && editor.selectedEvents.length > 1)
		{
			editor.showOutput("Can't perform this action with multiple events selected!", true);
			return [];
		}
		return editor.selectedEvents.copy();
	}

	function selectionTouchesBPM(nextName:String):Bool
	{
		if(Song.isBPMChangeEventName(nextName))
			return true;
		for(selection in editor.selectedEvents)
			if(Song.isBPMChangeEventName(eventName(selection.event)))
				return true;
		return false;
	}

	function targetsTouchBPM(targets:Array<SelectedEventData>):Bool
	{
		for(target in targets)
			if(Song.isBPMChangeEventName(eventName(target.event)))
				return true;
		return false;
	}

	public function destroy():Void
	{
		if(destroyed)
			return;
		destroyed = true;

		clearDynamicControls();
		if(tab != null)
		{
			for(control in ownedControls)
			{
				if(control == null) continue;
				tab.remove(control, true);
				control.destroy();
			}
		}
		ownedControls.resize(0);
		definitions = null;
		catalog = null;
		eventVisualCategories = null;
		draftData = null;
		editor = null;
		tab = null;
	}

	function rebuild():Void
	{
		if(destroyed || tab == null || eventDropDown == null)
			return;

		rebuilding = true;
		clearDynamicControls();
		hideResetTooltip();

		var selectedCount:Int = editor.selectedEvents.length;
		if(selectedCount == 1)
		{
			var note = editor.selectedEvents[0].note;
			var index:Int = note != null ? note.events.indexOf(editor.selectedEvents[0].event) : -1;
			selectedEventText.text = index >= 0
				? 'Selected Event: ${index + 1} / ${note.events.length}'
				: 'Selected Event';
			selectedEventText.visible = true;
		}
		else if(selectedCount > 1)
		{
			selectedEventText.text = 'Selected Events: $selectedCount';
			selectedEventText.visible = true;
		}
		else
			selectedEventText.visible = false;

		setDropDownName(selectedName);
		var definition:EventDefinition = definitions.get(selectedName);
		var description:String = definition != null ? definition.description : catalogDescription(selectedName);
		setDescription(description);

		var startY:Float = Math.min(250, Math.max(165, 68 + descriptionText.height + 22));
		if(hasMixedEventNames())
		{
			var mixedText:FlxText = new FlxText(10, startY, PANEL_WIDTH - 20, 'Multiple event types are selected.', 10);
			mixedText.color = HaxeUITheme.TEXT_MUTED;
			addDynamic(mixedText);
		}
		else if(isCameraBopDefinition(selectedName, definition))
		{
			var value1:FieldViewValue = getOutputView(1);
			var value2:FieldViewValue = getOutputView(2);
			if(value1.mixed || value2.mixed)
				buildMixedSpecialInputs(startY);
			else if(value1.value.length < 1 || value2.value.length < 1 || !validCameraBopValues(value1.value, value2.value))
				buildRawSpecialInputs(startY, value1.value, value2.value);
			else
				buildCameraBopLayout(startY, value1.value, value2.value);
		}
		else if(isChainDefinition(definition))
		{
			var value1:FieldViewValue = getOutputView(1);
			var value2:FieldViewValue = getOutputView(2);
			if(value1.mixed || value2.mixed)
				buildMixedSpecialInputs(startY);
			else if(value1.value.length < 1 || value2.value.length < 1 || !validChainValues(value1.value, value2.value))
				buildRawSpecialInputs(startY, value1.value, value2.value);
			else
				buildChainLayout(startY, value1.value, value2.value);
		}
		else if(definition != null && definition.fields.length > 0)
			buildDefinitionLayout(definition, startY);
		else
			buildRawSpecialInputs(startY, getOutputView(1).value, getOutputView(2).value);

		bringToFront(eventDropDown);
		bringToFront(resetDefaultIcon);
		bringToFront(fullResetIcon);
		bringToFront(tooltipBg);
		bringToFront(tooltipText);
		rebuilding = false;
	}

	function clearDynamicControls():Void
	{
		if(tab == null)
		{
			dynamicControls.resize(0);
			return;
		}

		for(control in dynamicControls)
		{
			if(control == null) continue;
			if(Std.isOfType(control, PsychUIInputText) && PsychUIInputText.focusOn == cast control)
				PsychUIInputText.focusOn = null;
			tab.remove(control, true);
			control.destroy();
		}
		dynamicControls.resize(0);
	}

	function bringToFront(control:FlxSprite):Void
	{
		if(control == null || tab == null || !tab.members.contains(control))
			return;
		var localX:Float = control.x - tab.x;
		var localY:Float = control.y - tab.y;
		tab.remove(control, true);
		control.setPosition(localX, localY);
		tab.add(control);
	}

	function setDescription(value:String):Void
	{
		var raw:String = value ?? '';
		var lines:Array<String> = raw.split('\n');
		if(lines.length > 10)
			raw = lines.slice(0, 10).concat(['...']).join('\n');
		descriptionText.text = raw;
		descriptionText.updateHitbox();
	}

	function buildMixedSpecialInputs(y:Float):Void
	{
		var message:FlxText = new FlxText(10, y, PANEL_WIDTH - 20, 'The selected events have different values. Type a value to apply it to all of them.', 8);
		message.color = HaxeUITheme.TEXT_MUTED;
		addDynamic(message);
		buildRawSpecialInputs(y + message.height + 12, '', '');
	}

	function buildRawSpecialInputs(y:Float, value1:String, value2:String):Void
	{
		var label1:FlxText = new FlxText(10, y - 14, 120, 'Value 1:');
		var label2:FlxText = new FlxText(215, y - 14, 120, 'Value 2:');
		var input1:PsychUIInputText = new PsychUIInputText(10, y, 170, value1 ?? '', 8);
		var input2:PsychUIInputText = new PsychUIInputText(215, y, 170, value2 ?? '', 8);
		input1.onChange = function(old:String, current:String) writeOutputValue(1, current);
		input2.onChange = function(old:String, current:String) writeOutputValue(2, current);
		addDynamic(label1);
		addDynamic(label2);
		addDynamic(input1);
		addDynamic(input2);
	}

	function buildDefinitionLayout(definition:EventDefinition, startY:Float):Void
	{
		var baseX:Float = 10;
		var cursorX:Float = baseX;
		var cursorY:Float = startY;

		for(field in definition.fields)
		{
			if(!fieldStoresValue(field))
			{
				var headerX:Float = cursorX + field.xOffset;
				var headerY:Float = cursorY + field.yOffset;
				var header:FlxText = new FlxText(headerX, headerY, field.width, field.label, field.textSize);
				header.color = HaxeUITheme.TEXT;
				addDynamic(header);
				if(field.type == 'layer' || field.type == 'section' || field.type == 'box')
				{
					var line:FlxSprite = new FlxSprite(headerX, headerY + header.height + 2).makeGraphic(field.width, 1, HaxeUITheme.PURPLE_DARK);
					addDynamic(line);
				}
				if(field.advance)
				{
					cursorY = Math.max(cursorY + header.height + 12, headerY + header.height + 12);
					cursorX = baseX;
				}
				else
					cursorX = headerX + field.width + field.gap;
				continue;
			}

			var controlX:Float = cursorX + field.xOffset;
			var controlY:Float = cursorY + field.yOffset;
			var view:FieldViewValue = getFieldView(field);
			var type:String = field.type;
			var advanceHeight:Float = fieldAdvanceHeight(field);

			if(view.mixed)
			{
				addFieldLabel(field, controlX, controlY, field.label + ' (mixed)');
				buildRawFieldInput(field, controlX, controlY, '');
			}
			else if(isCheckType(type) && isBoolValue(view.value))
			{
				var checkbox:PsychUICheckBox = null;
				checkbox = new PsychUICheckBox(controlX, controlY, field.label, field.width, function()
					writeFieldValue(field, checkbox.checked ? 'true' : 'false'));
				checkbox.checked = parseBool(view.value);
				applyCheckMetrics(checkbox, field);
				addDynamic(checkbox);
			}
			else
			{
				addFieldLabel(field, controlX, controlY, field.label);
				switch(type)
				{
					case 'number' | 'stepper' | 'numeric':
						if(view.value.length < 1 || !isFiniteNumber(view.value))
							buildRawFieldInput(field, controlX, controlY, view.value);
						else
							buildStepper(field, controlX, controlY, view.value);

					case 'slider':
						if(view.value.length < 1 || !isFiniteNumber(view.value))
							buildRawFieldInput(field, controlX, controlY, view.value);
						else
							buildSlider(field, controlX, controlY, view.value);

					case 'dropdown' | 'select' | 'options':
						buildDropDown(field, controlX, controlY, view.value);

					case 'color' | 'colour' | 'colorwheel' | 'colorpicker':
						if(view.value.length < 1 || !isValidColor(view.value))
							buildRawFieldInput(field, controlX, controlY, view.value);
						else
							buildColorInput(field, controlX, controlY, view.value);

					case 'cyclearray' | 'cycle_array':
						if(!isValidCycleArray(view.value, field.length))
							buildRawFieldInput(field, controlX, controlY, view.value);
						else
							buildCycleArray(field, controlX, controlY, view.value);

					case 'string' | 'literal' | 'tag':
						if(view.value.length < 1)
							buildRawFieldInput(field, controlX, controlY, view.value);
						else
						{
							var constantText:FlxText = new FlxText(controlX, controlY, field.width, view.value, field.textSize);
							constantText.color = HaxeUITheme.TEXT;
							addDynamic(constantText);
						}

					default:
						buildTextInput(field, controlX, controlY, view.value);
				}
			}

			if(field.advance)
			{
				cursorY = Math.max(cursorY + advanceHeight, controlY + advanceHeight);
				cursorX = baseX;
			}
			else
				cursorX = controlX + field.width + field.gap;
		}
	}

	function addFieldLabel(field:EventFieldDefinition, controlX:Float, controlY:Float, text:String):Void
	{
		if(isCheckType(field.type))
			return;
		var label:FlxText = new FlxText(
			controlX + field.labelXOffset,
			controlY - 14 + field.labelYOffset,
			field.labelWidth,
			text + ':',
			field.textSize
		);
		addDynamic(label);
	}

	function buildRawFieldInput(field:EventFieldDefinition, x:Float, y:Float, value:String):Void
	{
		var input:PsychUIInputText = new PsychUIInputText(x, y, field.width, value ?? '', field.textSize);
		input.maxLength = field.maxLength;
		input.onChange = function(old:String, current:String) writeFieldValue(field, current);
		addDynamic(input);
	}

	function buildTextInput(field:EventFieldDefinition, x:Float, y:Float, value:String):Void
	{
		buildRawFieldInput(field, x, y, value);
	}

	function buildStepper(field:EventFieldDefinition, x:Float, y:Float, value:String):Void
	{
		var parsed:Float = snapNumber(Std.parseFloat(value), field);
		var stepper:PsychUINumericStepper = null;
		stepper = new PsychUINumericStepper(x, y, field.step, parsed, field.min, field.max, field.decimals, field.width);
		stepper.onValueChange = function()
			writeFieldValue(field, formatNumber(stepper.value, field.decimals));
		addDynamic(stepper);
	}

	function buildSlider(field:EventFieldDefinition, x:Float, y:Float, value:String):Void
	{
		var parsed:Float = snapNumber(Std.parseFloat(value), field);
		var slider:PsychUISlider = new PsychUISlider(x, y, null, parsed, field.min, field.max, field.width);
		slider.decimals = field.decimals;
		slider.value = parsed;
		slider.onChange = function(current:Float)
			writeFieldValue(field, formatNumber(snapNumber(current, field), field.decimals));
		addDynamic(slider);
	}

	function buildDropDown(field:EventFieldDefinition, x:Float, y:Float, value:String):Void
	{
		var options:Array<String> = fieldOptions(field);
		if(value.length > 0 && !options.contains(value))
			options.push(value);
		var dropdown:PsychUIDropDownMenu = new PsychUIDropDownMenu(x, y, options, function(id:Int, label:String)
			writeFieldValue(field, label), field.width);
		if(value.length > 0)
			dropdown.selectedLabel = value;
		else
			dropdown.selectedIndex = -1;
		addDynamic(dropdown);
	}

	function buildColorInput(field:EventFieldDefinition, x:Float, y:Float, value:String):Void
	{
		var normalized:String = normalizeColor(value);
		var size:Int = Std.int(Math.max(18, field.buttonSize));
		var inputWidth:Int = Std.int(Math.max(50, field.width - size - 6));
		var input:PsychUIInputText = new PsychUIInputText(x + size + 6, y, inputWidth, normalized.substr(1), field.textSize);
		input.maxLength = 6;
		input.filterMode = ONLY_HEXADECIMAL;
		input.forceCase = UPPER_CASE;

		var button:PsychUIButton = null;
		button = new PsychUIButton(x, y, '', function()
		{
			var initial:FlxColor = CoolUtil.colorFromString('#' + input.text);
			editor.openSubState(new CharacterHealthColorPicker(initial, [FlxColor.WHITE, FlxColor.BLACK], function(color:FlxColor)
			{
				var next:String = '#' + color.toHexString(false, false);
				input.text = next.substr(1);
				styleColorButton(button, next);
				writeFieldValue(field, next);
			}, 'Event Color'));
		}, size, field.height > 0 ? field.height : size);
		styleColorButton(button, normalized);
		input.onChange = function(old:String, current:String)
		{
			if(current.length == 6)
			{
				var next:String = '#' + current;
				styleColorButton(button, next);
				writeFieldValue(field, next);
			}
		};
		addDynamic(button);
		addDynamic(input);
	}

	function buildCycleArray(field:EventFieldDefinition, x:Float, y:Float, value:String):Void
	{
		var size:Int = Std.int(FlxMath.bound(field.length, 1, Math.max(1, field.maxSize)));
		var columns:Int = Std.int(FlxMath.bound(field.columns, 1, size));
		var pattern:Array<Int> = parsePattern(value);
		pattern = trimPattern(pattern, size);

		for(index in 0...size)
		{
			var marker:Int = index;
			var button:PsychUIButton = null;
			button = new PsychUIButton(
				x + (marker % columns) * (field.buttonSize + field.gap),
				y + Std.int(marker / columns) * (field.buttonSize + field.gap),
				Std.string(marker),
				function()
				{
					if(pattern.contains(marker)) pattern.remove(marker); else pattern.push(marker);
					pattern.sort(Reflect.compare);
					styleMarker(button, pattern.contains(marker));
					writeFieldValue(field, formatPattern(pattern, field.separator));
				},
				field.buttonSize,
				field.buttonSize
			);
			button.text.size = Std.int(Math.max(6, field.textSize - 1));
			styleMarker(button, pattern.contains(marker));
			addDynamic(button);
		}
	}

	function styleColorButton(button:PsychUIButton, color:String):Void
	{
		var parsed:FlxColor = CoolUtil.colorFromString(normalizeColor(color));
		button.normalStyle.bgColor = parsed;
		button.hoverStyle.bgColor = parsed;
		button.clickStyle.bgColor = parsed;
		button.normalStyle.textColor = FlxColor.TRANSPARENT;
		button.hoverStyle.textColor = FlxColor.TRANSPARENT;
		button.clickStyle.textColor = FlxColor.TRANSPARENT;
		button.forceCheckNext = true;
	}

	function applyCheckMetrics(check:PsychUICheckBox, field:EventFieldDefinition):Void
	{
		check.text.size = field.textSize;
		check.text.updateHitbox();
		var originX:Float = check.x;
		var originY:Float = check.y;
		var gap:Float = field.gap;
		switch(field.type)
		{
			case 'checkerl':
				check.text.x = originX;
				check.text.fieldWidth = Math.max(1, field.width - Std.int(check.box.width + gap));
				check.text.alignment = RIGHT;
				check.box.x = check.text.x + check.text.fieldWidth + gap;
			case 'checkeru':
				check.box.x = originX + field.width * 0.5 - check.box.width * 0.5;
				check.text.x = originX;
				check.text.fieldWidth = field.width;
				check.text.alignment = CENTER;
				check.text.y = check.box.y + check.box.height + gap;
			case 'checkerd':
				check.text.x = originX;
				check.text.fieldWidth = field.width;
				check.text.alignment = CENTER;
				check.box.x = originX + field.width * 0.5 - check.box.width * 0.5;
				check.box.y = check.text.y + check.text.height + gap;
			default:
		}
	}

	function getFieldView(field:EventFieldDefinition):FieldViewValue
	{
		if(editor.selectedEvents.length < 1)
			return {value: readDataField(draftData, field), mixed: false};

		var first:String = readDataField(editor.selectedEvents[0].event, field);
		for(index in 1...editor.selectedEvents.length)
			if(readDataField(editor.selectedEvents[index].event, field) != first)
				return {value: '', mixed: true};
		return {value: first, mixed: false};
	}

	function getOutputView(index:Int):FieldViewValue
	{
		if(editor.selectedEvents.length < 1)
			return {value: dataValue(draftData, index), mixed: false};
		var first:String = dataValue(editor.selectedEvents[0].event, index);
		for(selectionIndex in 1...editor.selectedEvents.length)
			if(dataValue(editor.selectedEvents[selectionIndex].event, index) != first)
				return {value: '', mixed: true};
		return {value: first, mixed: false};
	}

	function writeFieldValue(field:EventFieldDefinition, value:String):Void
	{
		var tempoChanged:Bool = field.outputIndex == 1 && selectionTouchesBPM(selectedName);
		var oldBPMMap = tempoChanged ? Conductor.copyBPMChanges() : null;
		if(editor.selectedEvents.length < 1)
			setDataField(draftData, field, value);
		else
		{
			for(selection in editor.selectedEvents)
			{
				setDataField(selection.event, field, value);
				selection.note.updateEventInfo();
			}
			draftData = copyEventData(editor.selectedEvents[0].event);
		}
		if(oldBPMMap != null)
			editor.adaptNotes(oldBPMMap, false);
	}

	function writeOutputValue(index:Int, value:String):Void
	{
		var tempoChanged:Bool = index == 1 && selectionTouchesBPM(selectedName);
		var oldBPMMap = tempoChanged ? Conductor.copyBPMChanges() : null;
		if(editor.selectedEvents.length < 1)
		{
			ensureDataLength(draftData, index);
			draftData[index] = value ?? '';
		}
		else
		{
			for(selection in editor.selectedEvents)
			{
				ensureDataLength(selection.event, index);
				selection.event[index] = value ?? '';
				selection.note.updateEventInfo();
			}
			draftData = copyEventData(editor.selectedEvents[0].event);
		}
		if(oldBPMMap != null)
			editor.adaptNotes(oldBPMMap, false);
	}

	function readDataField(data:Array<String>, field:EventFieldDefinition):String
	{
		var raw:String = dataValue(data, field.outputIndex);
		if(field.groupIndex < 1)
			return raw;
		var parts:Array<String> = splitGroupValue(raw, field.separator);
		return parts.length >= field.partIndex ? parts[field.partIndex - 1] : '';
	}

	function setDataField(data:Array<String>, field:EventFieldDefinition, value:String):Void
	{
		if(data == null)
			return;
		ensureDataLength(data, field.outputIndex);
		if(field.groupIndex < 1)
		{
			data[field.outputIndex] = value ?? '';
			return;
		}

		var parts:Array<String> = splitGroupValue(data[field.outputIndex], field.separator);
		while(parts.length < field.partIndex)
			parts.push('');
		parts[field.partIndex - 1] = value ?? '';
		data[field.outputIndex] = parts.join(field.separator);
	}

	function createDefaultEventData(name:String):Array<String>
	{
		name = name ?? '';
		var definition:EventDefinition = definitions.get(name);
		if(isCameraBopDefinition(name, definition))
			return [name, '1, beat, cycle', '0.015, 0.03'];
		if(isChainDefinition(definition))
			return [name, '1, beat, cycle', '#FF0000, 0.6, game'];
		if(definition == null || definition.fields.length < 1)
			return [name, '', ''];

		var result:Array<String> = [name, '', ''];
		for(field in definition.fields)
		{
			if(!fieldStoresValue(field)) continue;
			setDataField(result, field, effectiveDefault(field));
		}
		return result;
	}

	function createBlankEventData(name:String, previousLength:Int):Array<String>
	{
		var definition:EventDefinition = definitions.get(name);
		var length:Int = Std.int(Math.max(3, previousLength));
		if(definition != null)
			for(field in definition.fields)
				if(fieldStoresValue(field))
					length = Std.int(Math.max(length, field.outputIndex + 1));
		var result:Array<String> = [name ?? ''];
		while(result.length < length)
			result.push('');
		return result;
	}

	function effectiveDefault(field:EventFieldDefinition):String
	{
		if(field.hasDefault)
			return canonicalDefault(field, field.defaultValue);
		return switch(field.type)
		{
			case 'number' | 'stepper' | 'numeric' | 'slider':
				canonicalDefault(field, Std.string(FlxMath.bound(0, field.min, field.max)));
			case 'dropdown' | 'select' | 'options':
				field.options.length > 0 ? field.options[0] : '';
			case 'toggle' | 'checkbox' | 'check' | 'checker' | 'checkerl' | 'checkeru' | 'checkerd':
				'false';
			case 'color' | 'colour' | 'colorwheel' | 'colorpicker':
				'#FFFFFF';
			case 'string' | 'literal' | 'tag':
				field.defaultValue;
			default:
				'';
		}
	}

	function canonicalDefault(field:EventFieldDefinition, value:String):String
	{
		return switch(field.type)
		{
			case 'number' | 'stepper' | 'numeric' | 'slider':
				var parsed:Float = Std.parseFloat(value);
				if(Math.isNaN(parsed)) parsed = FlxMath.bound(0, field.min, field.max);
				formatNumber(snapNumber(parsed, field), field.decimals);
			case 'toggle' | 'checkbox' | 'check' | 'checker' | 'checkerl' | 'checkeru' | 'checkerd':
				parseBool(value) ? 'true' : 'false';
			case 'color' | 'colour' | 'colorwheel' | 'colorpicker':
				normalizeColor(value);
			default:
				value ?? '';
		}
	}

	function copyEventData(data:Array<String>):Array<String>
	{
		var result:Array<String> = data != null ? data.copy() : ['', '', ''];
		while(result.length < 3) result.push('');
		return result;
	}

	function replaceEventData(target:Array<String>, source:Array<String>):Void
	{
		target.resize(0);
		for(value in source)
			target.push(value ?? '');
		while(target.length < 3) target.push('');
	}

	function ensureDataLength(data:Array<String>, index:Int):Void
	{
		while(data.length <= index)
			data.push('');
	}

	function dataValue(data:Array<String>, index:Int):String
		return data != null && data.length > index && data[index] != null ? data[index] : '';

	function eventName(data:Array<String>):String
		return dataValue(data, 0);

	function hasMixedEventNames():Bool
	{
		if(editor.selectedEvents.length < 2)
			return false;
		var first:String = eventName(editor.selectedEvents[0].event);
		for(index in 1...editor.selectedEvents.length)
			if(eventName(editor.selectedEvents[index].event) != first)
				return true;
		return false;
	}

	function fieldStoresValue(field:EventFieldDefinition):Bool
		return field.type != 'label' && field.type != 'layer' && field.type != 'section' && field.type != 'box';

	function isCheckType(type:String):Bool
		return type == 'toggle' || type == 'checkbox' || type == 'check' || type == 'checker' || type.startsWith('checker');

	function fieldAdvanceHeight(field:EventFieldDefinition):Float
	{
		var base:Float = switch(field.type)
		{
			case 'slider': 58;
			case 'cyclearray' | 'cycle_array':
				var size:Int = Std.int(FlxMath.bound(field.length, 1, Math.max(1, field.maxSize)));
				var columns:Int = Std.int(FlxMath.bound(field.columns, 1, size));
				20 + Math.ceil(size / columns) * (field.buttonSize + field.gap);
			default: 45;
		};
		return Math.max(base, field.rowHeight) + field.rowGap;
	}

	function isCameraBopDefinition(name:String, definition:EventDefinition):Bool
	{
		var layout:String = definition != null ? definition.layoutType : '';
		return name == 'Camera Module Bop' || layout.toLowerCase().trim() == 'camerabop';
	}

	function isChainDefinition(definition:EventDefinition):Bool
	{
		var layout:String = definition != null ? definition.layoutType.toLowerCase().trim() : '';
		return layout == 'chain' || layout == 'timingchain' || layout == 'eventchain';
	}

	function validCameraBopValues(timing:String, zoom:String):Bool
	{
		var timingParts:Array<String> = splitGroupValue(timing, ', ');
		if(timingParts.length < 3 || !isFiniteNumber(timingParts[0])) return false;
		var unit:String = timingParts[1].toLowerCase().trim();
		if(unit != 'beat' && unit != 'beats' && unit != 'step' && unit != 'steps') return false;
		var mode:String = timingParts[2].toLowerCase().trim();
		if(mode != 'cycle' && mode != 'pattern' && !isPatternString(timingParts[2])) return false;
		if(isDisabledValue(zoom)) return true;
		var zoomParts:Array<String> = splitGroupValue(zoom, ', ');
		return zoomParts.length >= 2 && isFiniteNumber(zoomParts[0]) && isFiniteNumber(zoomParts[1]);
	}

	function validChainValues(timing:String, flash:String):Bool
	{
		if(!validCameraBopValues(timing, '0, 0')) return false;
		if(isDisabledValue(flash)) return true;
		var parts:Array<String> = splitGroupValue(flash, ', ');
		return parts.length >= 3 && isValidColor(parts[0]) && isFiniteNumber(parts[1]) && parts[2].trim().length > 0;
	}

	function buildCameraBopLayout(y:Float, timingRaw:String, zoomRaw:String):Void
	{
		var state:CameraBopEditorState = parseCameraBopState(timingRaw, zoomRaw);
		function commitTiming():Void
			writeOutputValue(1, formatTiming(state.every, state.unit, state.mode, state.pattern));
		function commitZoom():Void
			writeOutputValue(2, formatNumber(state.gameZoom, 4) + ', ' + formatNumber(state.hudZoom, 4));

		var cycleButton:PsychUIButton = new PsychUIButton(10, y, 'Cycle', function()
		{
			state.mode = 'cycle';
			state.every = 1;
			commitTiming();
			rebuildQueued = true;
		}, 90, 22);
		var patternButton:PsychUIButton = new PsychUIButton(106, y, 'Pattern', function()
		{
			state.mode = 'pattern';
			state.every = state.patternSize;
			if(state.pattern.length < 1) state.pattern.push(0);
			commitTiming();
			rebuildQueued = true;
		}, 90, 22);
		var enableButton:PsychUIButton = new PsychUIButton(202, y, state.enabled ? 'Bop: On' : 'Bop: Off', function()
		{
			state.enabled = !state.enabled;
			if(state.enabled)
			{
				state.gameZoom = 0.015;
				state.hudZoom = 0.03;
			}
			else
				state.gameZoom = state.hudZoom = 0;
			commitZoom();
			rebuildQueued = true;
		}, 90, 22);
		styleModeButton(cycleButton, state.mode != 'pattern');
		styleModeButton(patternButton, state.mode == 'pattern');
		styleToggleButton(enableButton, state.enabled);
		addDynamic(cycleButton);
		addDynamic(patternButton);
		addDynamic(enableButton);

		var rowY:Float = y + 30;
		addDynamic(new FlxText(10, rowY, 80, 'Unit:'));
		var unitDropdown:PsychUIDropDownMenu = new PsychUIDropDownMenu(10, rowY + 14, ['beat', 'step'], function(id:Int, label:String)
		{
			state.unit = normalizeUnit(label);
			commitTiming();
		}, 96);
		unitDropdown.selectedLabel = state.unit;
		addDynamic(unitDropdown);

		if(state.mode == 'pattern')
		{
			addDynamic(new FlxText(130, rowY, 90, 'Pattern:'));
			var sizeDropdown:PsychUIDropDownMenu = new PsychUIDropDownMenu(130, rowY + 14, ['16', '32'], function(id:Int, label:String)
			{
				state.patternSize = label == '32' ? 32 : 16;
				state.every = state.patternSize;
				state.pattern = trimPattern(state.pattern, state.patternSize);
				if(state.pattern.length < 1) state.pattern.push(0);
				commitTiming();
				rebuildQueued = true;
			}, 82);
			sizeDropdown.selectedLabel = Std.string(state.patternSize);
			addDynamic(sizeDropdown);
		}
		else
		{
			addDynamic(new FlxText(130, rowY, 80, 'Every:'));
			var everyStepper:PsychUINumericStepper = new PsychUINumericStepper(130, rowY + 14, 1, state.every, 1, 999, 0, 78);
			everyStepper.onValueChange = function()
			{
				state.every = everyStepper.value;
				commitTiming();
			};
			addDynamic(everyStepper);
		}

		var zoomY:Float = rowY + 50;
		addDynamic(new FlxText(10, zoomY, 80, 'Game:'));
		var gameStepper:PsychUINumericStepper = new PsychUINumericStepper(10, zoomY + 14, 0.005, state.gameZoom, -2, 2, 4, 82);
		gameStepper.onValueChange = function()
		{
			state.gameZoom = gameStepper.value;
			state.enabled = state.gameZoom != 0 || state.hudZoom != 0;
			commitZoom();
		};
		addDynamic(gameStepper);

		addDynamic(new FlxText(130, zoomY, 80, 'HUD:'));
		var hudStepper:PsychUINumericStepper = new PsychUINumericStepper(130, zoomY + 14, 0.005, state.hudZoom, -2, 2, 4, 82);
		hudStepper.onValueChange = function()
		{
			state.hudZoom = hudStepper.value;
			state.enabled = state.gameZoom != 0 || state.hudZoom != 0;
			commitZoom();
		};
		addDynamic(hudStepper);

		if(state.mode == 'pattern')
			buildPatternGrid(10, zoomY + 48, state.patternSize, state.pattern, state.unit == 'step' ? 'Steps in cycle:' : 'Beats in cycle:', function()
			{
				commitTiming();
			});
	}

	function buildChainLayout(y:Float, timingRaw:String, flashRaw:String):Void
	{
		var state:ChainEditorState = parseChainState(timingRaw, flashRaw);
		function commitTiming():Void
			writeOutputValue(1, formatTiming(state.every, state.unit, state.mode, state.pattern));
		function commitFlash():Void
			writeOutputValue(2, state.enabled ? '${normalizeColor(state.color)}, ${formatNumber(state.duration, 3)}, ${state.camera}' : 'off');

		var cycleButton:PsychUIButton = new PsychUIButton(10, y, 'Cycle', function()
		{
			state.mode = 'cycle';
			state.every = 1;
			commitTiming();
			rebuildQueued = true;
		}, 90, 22);
		var patternButton:PsychUIButton = new PsychUIButton(106, y, 'Pattern', function()
		{
			state.mode = 'pattern';
			state.every = state.patternSize;
			if(state.pattern.length < 1) state.pattern.push(0);
			commitTiming();
			rebuildQueued = true;
		}, 90, 22);
		var enableButton:PsychUIButton = new PsychUIButton(202, y, state.enabled ? 'Chain: On' : 'Chain: Off', function()
		{
			state.enabled = !state.enabled;
			if(state.enabled)
			{
				state.color = '#FF0000';
				state.duration = 0.6;
				state.camera = 'game';
			}
			commitFlash();
			rebuildQueued = true;
		}, 90, 22);
		styleModeButton(cycleButton, state.mode != 'pattern');
		styleModeButton(patternButton, state.mode == 'pattern');
		styleToggleButton(enableButton, state.enabled);
		addDynamic(cycleButton);
		addDynamic(patternButton);
		addDynamic(enableButton);

		var rowY:Float = y + 30;
		addDynamic(new FlxText(10, rowY, 80, 'Unit:'));
		var unitDropdown:PsychUIDropDownMenu = new PsychUIDropDownMenu(10, rowY + 14, ['beat', 'step'], function(id:Int, label:String)
		{
			state.unit = normalizeUnit(label);
			commitTiming();
		}, 96);
		unitDropdown.selectedLabel = state.unit;
		addDynamic(unitDropdown);

		if(state.mode == 'pattern')
		{
			addDynamic(new FlxText(130, rowY, 90, 'Pattern:'));
			var sizeDropdown:PsychUIDropDownMenu = new PsychUIDropDownMenu(130, rowY + 14, ['16', '32'], function(id:Int, label:String)
			{
				state.patternSize = label == '32' ? 32 : 16;
				state.every = state.patternSize;
				state.pattern = trimPattern(state.pattern, state.patternSize);
				if(state.pattern.length < 1) state.pattern.push(0);
				commitTiming();
				rebuildQueued = true;
			}, 82);
			sizeDropdown.selectedLabel = Std.string(state.patternSize);
			addDynamic(sizeDropdown);
		}
		else
		{
			addDynamic(new FlxText(130, rowY, 80, 'Every:'));
			var everyStepper:PsychUINumericStepper = new PsychUINumericStepper(130, rowY + 14, 1, state.every, 1, 999, 0, 78);
			everyStepper.onValueChange = function()
			{
				state.every = everyStepper.value;
				commitTiming();
			};
			addDynamic(everyStepper);
		}

		var flashY:Float = rowY + 50;
		addDynamic(new FlxText(10, flashY, 80, 'Color:'));
		var colorInput:PsychUIInputText = new PsychUIInputText(36, flashY + 14, 70, normalizeColor(state.color).substr(1), 8);
		colorInput.maxLength = 6;
		colorInput.filterMode = ONLY_HEXADECIMAL;
		colorInput.forceCase = UPPER_CASE;
		var colorButton:PsychUIButton = null;
		colorButton = new PsychUIButton(10, flashY + 14, '', function()
		{
			var initial:FlxColor = CoolUtil.colorFromString(state.color);
			editor.openSubState(new CharacterHealthColorPicker(initial, [FlxColor.WHITE, FlxColor.BLACK], function(color:FlxColor)
			{
				state.color = '#' + color.toHexString(false, false);
				colorInput.text = state.color.substr(1);
				styleColorButton(colorButton, state.color);
				commitFlash();
			}, 'Event Color'));
		}, 20, 20);
		styleColorButton(colorButton, state.color);
		colorInput.onChange = function(old:String, current:String)
		{
			if(current.length == 6)
			{
				state.color = '#' + current;
				styleColorButton(colorButton, state.color);
				commitFlash();
			}
		};
		addDynamic(colorButton);
		addDynamic(colorInput);

		addDynamic(new FlxText(130, flashY, 80, 'Duration:'));
		var durationStepper:PsychUINumericStepper = new PsychUINumericStepper(130, flashY + 14, 0.05, state.duration, 0, 999, 2, 78);
		durationStepper.onValueChange = function()
		{
			state.duration = durationStepper.value;
			commitFlash();
		};
		addDynamic(durationStepper);

		addDynamic(new FlxText(230, flashY, 70, 'Camera:'));
		var cameraOptions:Array<String> = ['game', 'hud', 'other'];
		if(!cameraOptions.contains(state.camera)) cameraOptions.push(state.camera);
		var cameraDropdown:PsychUIDropDownMenu = new PsychUIDropDownMenu(230, flashY + 14, cameraOptions, function(id:Int, label:String)
		{
			state.camera = label;
			commitFlash();
		}, 70);
		cameraDropdown.selectedLabel = state.camera;
		addDynamic(cameraDropdown);

		if(state.mode == 'pattern')
			buildPatternGrid(10, flashY + 48, state.patternSize, state.pattern, state.unit == 'step' ? 'Steps in cycle:' : 'Beats in cycle:', function()
			{
				commitTiming();
			});
	}

	function buildPatternGrid(x:Float, y:Float, size:Int, pattern:Array<Int>, label:String, onChanged:Void->Void):Void
	{
		addDynamic(new FlxText(x, y, PANEL_WIDTH - 20, label));
		var buttonSize:Int = 18;
		var gap:Int = 2;
		var gridY:Float = y + 16;
		for(index in 0...size)
		{
			var marker:Int = index;
			var button:PsychUIButton = null;
			button = new PsychUIButton(
				x + (marker % 16) * (buttonSize + gap),
				gridY + Std.int(marker / 16) * (buttonSize + gap),
				Std.string(marker),
				function()
				{
					if(pattern.contains(marker)) pattern.remove(marker); else pattern.push(marker);
					pattern.sort(Reflect.compare);
					styleMarker(button, pattern.contains(marker));
					onChanged();
				},
				buttonSize,
				buttonSize
			);
			button.text.size = 7;
			styleMarker(button, pattern.contains(marker));
			addDynamic(button);
		}
	}

	function parseCameraBopState(timingRaw:String, zoomRaw:String):CameraBopEditorState
	{
		var timing:Array<String> = splitGroupValue(timingRaw, ', ');
		var zoom:Array<String> = splitGroupValue(zoomRaw, ', ');
		var mode:String = normalizeMode(timing.length > 2 ? timing[2] : 'cycle');
		var patternRaw:String = timing.length > 3 ? timing[3] : '';
		if(timing.length > 2 && isPatternString(timing[2]))
		{
			mode = 'pattern';
			patternRaw = timing[2];
		}
		var every:Float = Std.parseFloat(timing.length > 0 ? timing[0] : '1');
		if(Math.isNaN(every) || every <= 0) every = mode == 'pattern' ? 16 : 1;
		var patternSize:Int = normalizePatternSize(Math.round(every));
		var enabled:Bool = !isDisabledValue(zoomRaw);
		var game:Float = enabled && zoom.length > 0 ? Std.parseFloat(zoom[0]) : 0;
		var hud:Float = enabled && zoom.length > 1 ? Std.parseFloat(zoom[1]) : 0;
		if(Math.isNaN(game)) game = 0.015;
		if(Math.isNaN(hud)) hud = 0.03;
		return {
			every: mode == 'pattern' ? patternSize : every,
			unit: normalizeUnit(timing.length > 1 ? timing[1] : 'beat'),
			mode: mode,
			patternSize: patternSize,
			pattern: trimPattern(parsePattern(patternRaw), patternSize),
			enabled: enabled && (game != 0 || hud != 0),
			gameZoom: game,
			hudZoom: hud
		};
	}

	function parseChainState(timingRaw:String, flashRaw:String):ChainEditorState
	{
		var timingState:CameraBopEditorState = parseCameraBopState(timingRaw, '0.015, 0.03');
		var flash:Array<String> = splitGroupValue(flashRaw, ', ');
		var enabled:Bool = !isDisabledValue(flashRaw);
		var duration:Float = enabled && flash.length > 1 ? Std.parseFloat(flash[1]) : 0.6;
		if(Math.isNaN(duration) || duration < 0) duration = 0.6;
		return {
			every: timingState.every,
			unit: timingState.unit,
			mode: timingState.mode,
			patternSize: timingState.patternSize,
			pattern: timingState.pattern,
			enabled: enabled,
			color: enabled && flash.length > 0 ? normalizeColor(flash[0]) : '#FF0000',
			duration: duration,
			camera: enabled && flash.length > 2 && flash[2].trim().length > 0 ? flash[2].trim() : 'game'
		};
	}

	function formatTiming(every:Float, unit:String, mode:String, pattern:Array<Int>):String
	{
		mode = normalizeMode(mode);
		unit = normalizeUnit(unit);
		if(mode == 'pattern')
		{
			var size:Int = normalizePatternSize(Math.round(every));
			var hits:Array<Int> = trimPattern(pattern, size);
			return '$size, $unit, pattern, {' + hits.join(', ') + '}';
		}
		return '${Math.max(1, Math.round(every))}, $unit, cycle';
	}

	function normalizeUnit(value:String):String
	{
		value = (value ?? '').toLowerCase().trim();
		return value == 'step' || value == 'steps' || value == 's' ? 'step' : 'beat';
	}

	function normalizeMode(value:String):String
	{
		value = (value ?? '').toLowerCase().trim();
		return value == 'pattern' || value == 'patterns' || value == 'irregular' || value == 'inconsistent' ? 'pattern' : 'cycle';
	}

	function normalizePatternSize(value:Int):Int
		return value > 16 ? 32 : 16;

	function isDisabledValue(value:String):Bool
	{
		value = (value ?? '').toLowerCase().trim();
		return value == 'off' || value == 'disable' || value == 'disabled' || value == 'false' || value == 'no' || value == 'none';
	}

	function styleModeButton(button:PsychUIButton, selected:Bool):Void
	{
		button.normalStyle.bgColor = selected ? HaxeUITheme.PURPLE_DARK : HaxeUITheme.PANEL;
		button.hoverStyle.bgColor = selected ? HaxeUITheme.PURPLE_DARK : HaxeUITheme.PANEL_LIGHT;
		button.clickStyle.bgColor = HaxeUITheme.PURPLE_DARK;
		button.normalStyle.textColor = selected ? FlxColor.WHITE : HaxeUITheme.TEXT;
		button.forceCheckNext = true;
	}

	function styleToggleButton(button:PsychUIButton, enabled:Bool):Void
	{
		button.normalStyle.bgColor = enabled ? HaxeUITheme.PURPLE_DARK : HaxeUITheme.INPUT_FILL;
		button.hoverStyle.bgColor = enabled ? HaxeUITheme.PURPLE_DARK : HaxeUITheme.PANEL_LIGHT;
		button.clickStyle.bgColor = HaxeUITheme.PURPLE_DARK;
		button.normalStyle.textColor = enabled ? FlxColor.WHITE : HaxeUITheme.INPUT_TEXT;
		button.forceCheckNext = true;
	}

	function styleMarker(button:PsychUIButton, selected:Bool):Void
	{
		button.normalStyle.bgColor = selected ? HaxeUITheme.PURPLE_DARK : HaxeUITheme.INPUT_FILL;
		button.hoverStyle.bgColor = selected ? HaxeUITheme.PURPLE_DARK : HaxeUITheme.PANEL_LIGHT;
		button.clickStyle.bgColor = selected ? HaxeUITheme.INPUT_FILL : HaxeUITheme.PURPLE_DARK;
		button.normalStyle.textColor = selected ? FlxColor.WHITE : HaxeUITheme.INPUT_TEXT;
		button.forceCheckNext = true;
	}

	function loadDefinition(file:String, txtDescription:String):EventDefinition
	{
		var raw:String = Paths.getTextFromFile('data/events/$file.toml');
		if(raw == null || raw.trim().length < 1)
			return null;

		try
		{
			var document = Toml.parse(raw, 'data/events/$file.toml');
			var root:Dynamic = document.root;
			var ordered:Array<{raw:Dynamic, id:String, order:Float, sourceIndex:Int}> = [];
			var sourceIndex:Int = 0;
			for(table in document.tables)
			{
				var fieldRaw:Dynamic = table.data;
				ordered.push({
					raw: fieldRaw,
					id: table.name,
					order: readFloat(fieldRaw, ['order', 'sort'], table.order),
					sourceIndex: sourceIndex++
				});
			}
			ordered.sort(function(a, b)
			{
				if(a.order == b.order) return a.sourceIndex - b.sourceIndex;
				return a.order < b.order ? -1 : 1;
			});

			var fields:Array<EventFieldDefinition> = [];
			for(item in ordered)
				fields.push(parseField(item.id, item.raw));
			resolveOutputIndexes(fields);

			var tabs:Array<String> = [];
			var rawTabs:Dynamic = rawValue(root, ['tabs']);
			if(Std.isOfType(rawTabs, Array))
				for(tabData in (cast rawTabs:Array<Dynamic>))
					tabs.push(Type.typeof(tabData) == TObject ? readString(tabData, ['id', 'name', 'label'], '') : Std.string(tabData));

			return {
				name: file,
				displayName: readString(root, ['name', 'displayName', 'display_name', 'label'], file),
				description: readString(root, ['description', 'desc'], txtDescription ?? ''),
				layoutType: readString(root, ['layoutType', 'customLayout', 'editorLayout'], ''),
				tabs: tabs,
				fields: fields
			};
		}
		catch(error:Dynamic)
		{
			trace('Could not load event definition "$file.toml": $error');
		}
		return null;
	}

	function parseField(id:String, raw:Dynamic):EventFieldDefinition
	{
		var type:String = readString(raw, ['type', 'kind'], 'text').toLowerCase().trim();
		var rawDefault:Dynamic = rawValue(raw, ['defaultValue', 'default', 'valueDefault', 'result']);
		var hasDefault:Bool = rawDefault != null;
		var defaultValue:String = hasDefault ? Std.string(rawDefault) : '';
		if((type == 'string' || type == 'literal' || type == 'tag') && !hasDefault)
		{
			defaultValue = readString(raw, ['string', 'tag', 'id', 'label', 'name'], id);
			hasDefault = true;
		}

		var step:Float = readFloat(raw, ['step'], 1);
		var min:Float = type == 'slider' ? 0 : -99999;
		var max:Float = type == 'slider' ? 1 : 99999;
		var range:Dynamic = rawValue(raw, ['min_max', 'minMax', 'range']);
		if(Std.isOfType(range, Array))
		{
			var values:Array<Dynamic> = cast range;
			if(values.length > 0) min = parseFloatOr(values[0], min);
			if(values.length > 1) max = parseFloatOr(values[1], max);
		}
		min = readFloat(raw, ['min'], min);
		max = readFloat(raw, ['max'], max);
		var decimals:Int = readInt(raw, ['decimals', 'precision'], decimalsForStep(step));
		var length:Int = readInt(raw, ['length', 'count', 'size'], 16);
		var maxSize:Int = readInt(raw, ['maxSize', 'max_size'], 64);
		var buttonSize:Int = readInt(raw, ['buttonSize', 'button_size', 'selectorSize', 'height', 'h'], 18);
		var gap:Int = readInt(raw, ['gap', 'spacing'], 2);
		var width:Int = readInt(raw, ['width', 'w'], type == 'label' || type == 'layer' || type == 'section' || type == 'box' ? 280 : 135);

		return {
			id: id,
			type: type,
			label: readString(raw, ['label', 'title', 'text', 'name', 'id', 'tag', 'key'], id),
			defaultValue: defaultValue,
			hasDefault: hasDefault,
			outputIndex: parseFieldIndex(rawValue(raw, ['value', 'valueIndex', 'index', 'slot'])),
			groupIndex: parseFieldIndex(rawValue(raw, ['group', 'join', 'output', 'groupValue', 'valueGroup', 'targetValue'])),
			partIndex: Std.int(Math.max(1, parseFieldIndex(rawValue(raw, ['part', 'groupIndex', 'partIndex', 'item', 'position'])))),
			separator: readString(raw, ['separator', 'sep', 'joiner'], ', '),
			options: readOptions(raw),
			includeExtraCharacters: parseBool(readString(raw, ['includeExtraCharacters', 'extraCharacters', 'charactersFromScripts'], 'false')),
			xOffset: readFloat(raw, ['x'], 0) + readFloat(raw, ['xOffset', 'offsetX'], 0),
			yOffset: readFloat(raw, ['y'], 0) + readFloat(raw, ['yOffset', 'offsetY'], 0),
			labelXOffset: readFloat(raw, ['labelX'], 0) + readFloat(raw, ['labelXOffset', 'labelOffsetX'], 0),
			labelYOffset: readFloat(raw, ['labelY'], 0) + readFloat(raw, ['labelYOffset', 'labelOffsetY'], 0),
			width: width,
			labelWidth: readInt(raw, ['labelWidth', 'labelW'], Std.int(Math.max(80, width))),
			step: step,
			min: min,
			max: max,
			decimals: decimals,
			textSize: readInt(raw, ['textSize', 'fontSize', 'size'], 8),
			maxLength: readInt(raw, ['maxLength', 'maxlength'], 0),
			buttonSize: buttonSize,
			length: length,
			maxSize: maxSize,
			columns: readInt(raw, ['columns', 'cols'], Std.int(Math.min(16, Math.max(1, length)))),
			gap: gap,
			rowHeight: readFloat(raw, ['rowHeight', 'row_height', 'advanceHeight', 'advance_height'], 0),
			rowGap: readFloat(raw, ['rowGap', 'row_gap', 'verticalSpacing', 'vertical_spacing'], 0),
			height: readInt(raw, ['height', 'h'], buttonSize),
			advance: parseBool(readString(raw, ['advance', 'nextLine', 'flow'], 'true'))
		};
	}

	function resolveOutputIndexes(fields:Array<EventFieldDefinition>):Void
	{
		var next:Int = 1;
		for(field in fields)
		{
			if(!fieldStoresValue(field)) continue;
			if(field.groupIndex > 0)
				field.outputIndex = field.groupIndex;
			else if(field.outputIndex < 1)
				field.outputIndex = next;
			next = Std.int(Math.max(next, field.outputIndex + 1));
		}
	}

	function fieldOptions(field:EventFieldDefinition):Array<String>
	{
		var options:Array<String> = field.options.copy();
		if(field.includeExtraCharacters)
		{
			var data = editor.getScriptCreatedCharacterData();
			for(tag in data.tags)
				if(!options.contains(tag)) options.push(tag);
		}
		return options;
	}

	function readOptions(raw:Dynamic):Array<String>
	{
		var value:Dynamic = rawValue(raw, ['options', 'values', 'items']);
		if(Std.isOfType(value, Array))
			return [for(option in (cast value:Array<Dynamic>)) Std.string(option)];
		if(value != null)
			return [for(option in Std.string(value).split(',')) option.trim()];
		return [];
	}

	function rawValue(object:Dynamic, names:Array<String>):Dynamic
	{
		if(object == null) return null;
		for(name in names)
			if(Reflect.hasField(object, name)) return Reflect.field(object, name);
		return null;
	}

	function readString(object:Dynamic, names:Array<String>, fallback:String):String
	{
		var value:Dynamic = rawValue(object, names);
		return value != null ? Std.string(value) : fallback;
	}

	function readInt(object:Dynamic, names:Array<String>, fallback:Int):Int
	{
		var value:Dynamic = rawValue(object, names);
		if(value == null) return fallback;
		var parsed:Null<Int> = Std.parseInt(Std.string(value));
		return parsed != null ? parsed : fallback;
	}

	function readFloat(object:Dynamic, names:Array<String>, fallback:Float):Float
	{
		var value:Dynamic = rawValue(object, names);
		return value != null ? parseFloatOr(value, fallback) : fallback;
	}

	function parseFloatOr(value:Dynamic, fallback:Float):Float
	{
		var parsed:Float = Std.parseFloat(Std.string(value));
		return Math.isNaN(parsed) ? fallback : parsed;
	}

	function parseFieldIndex(value:Dynamic):Int
	{
		if(value == null) return 0;
		var text:String = Std.string(value).toLowerCase();
		for(prefix in ['value', 'val', 'group', 'part', 'v']) text = text.replace(prefix, '');
		var parsed:Null<Int> = Std.parseInt(text);
		return parsed != null && parsed > 0 ? parsed : 0;
	}

	function decimalsForStep(step:Float):Int
	{
		var text:String = Std.string(step);
		var dot:Int = text.indexOf('.');
		return dot >= 0 ? Std.int(Math.min(6, text.length - dot - 1)) : 0;
	}

	function parseBool(value:String):Bool
	{
		value = (value ?? '').toLowerCase().trim();
		return value == 'true' || value == '1' || value == 'yes' || value == 'on';
	}

	function isBoolValue(value:String):Bool
	{
		value = (value ?? '').toLowerCase().trim();
		return value == 'true' || value == 'false' || value == '1' || value == '0' || value == 'yes' || value == 'no' || value == 'on' || value == 'off';
	}

	function isFiniteNumber(value:String):Bool
	{
		var parsed:Float = Std.parseFloat(value ?? '');
		return !Math.isNaN(parsed) && parsed != Math.POSITIVE_INFINITY && parsed != Math.NEGATIVE_INFINITY;
	}

	function snapNumber(value:Float, field:EventFieldDefinition):Float
	{
		if(field.step > 0)
			value = field.min + Math.round((value - field.min) / field.step) * field.step;
		return FlxMath.roundDecimal(FlxMath.bound(value, field.min, field.max), field.decimals);
	}

	function formatNumber(value:Float, decimals:Int):String
		return Std.string(FlxMath.roundDecimal(value, decimals));

	function isValidColor(value:String):Bool
	{
		var clean:String = (value ?? '').toUpperCase().replace('#', '').replace('0X', '').trim();
		if(clean.length != 6) return false;
		for(index in 0...clean.length)
			if(!'0123456789ABCDEF'.contains(clean.charAt(index))) return false;
		return true;
	}

	function normalizeColor(value:String):String
	{
		var clean:String = (value ?? '').toUpperCase().replace('#', '').replace('0X', '').trim();
		var filtered:String = '';
		for(index in 0...clean.length)
			if('0123456789ABCDEF'.contains(clean.charAt(index))) filtered += clean.charAt(index);
		if(filtered.length < 6) filtered = (filtered + 'FFFFFF').substr(0, 6);
		if(filtered.length > 6) filtered = filtered.substr(filtered.length - 6);
		return '#' + filtered;
	}

	function isPatternString(value:String):Bool
	{
		var text:String = (value ?? '').trim();
		return (text.startsWith('{') && text.endsWith('}')) || (text.startsWith('[') && text.endsWith(']'));
	}

	function parsePattern(value:String):Array<Int>
	{
		var pattern:Array<Int> = [];
		var text:String = value ?? '';
		for(character in ['{', '}', '[', ']']) text = text.replace(character, ' ');
		var splitter:EReg = ~/[,\s;|]+/g;
		for(part in splitter.split(text))
		{
			var parsed:Null<Int> = Std.parseInt(part.trim());
			if(parsed != null && parsed >= 0 && !pattern.contains(parsed)) pattern.push(parsed);
		}
		pattern.sort(Reflect.compare);
		return pattern;
	}

	function trimPattern(pattern:Array<Int>, size:Int):Array<Int>
		return [for(value in pattern) if(value >= 0 && value < size) value];

	function formatPattern(pattern:Array<Int>, separator:String):String
		return [for(value in pattern) Std.string(value)].join(separator != null && separator.length > 0 ? separator : ', ');

	function isValidCycleArray(value:String, size:Int):Bool
	{
		if(value == null || value.trim().length < 1) return true;
		var clean:String = value;
		for(character in ['{', '}', '[', ']']) clean = clean.replace(character, ' ');
		var splitter:EReg = ~/[,\s;|]+/g;
		for(part in splitter.split(clean))
		{
			if(part.trim().length < 1) continue;
			var parsed:Null<Int> = Std.parseInt(part.trim());
			if(parsed == null || parsed < 0 || parsed >= size) return false;
		}
		return true;
	}

	function splitGroupValue(value:String, separator:String):Array<String>
	{
		if(value == null) return [];
		if(separator == null || separator.length < 1) separator = ', ';
		if(!separator.contains(',')) return [for(part in value.split(separator)) part.trim()];

		var parts:Array<String> = [];
		var current:String = '';
		var depth:Int = 0;
		for(index in 0...value.length)
		{
			var character:String = value.charAt(index);
			switch(character)
			{
				case '{' | '[' | '(':
					depth++;
					current += character;
				case '}' | ']' | ')':
					depth = Std.int(Math.max(0, depth - 1));
					current += character;
				case ',':
					if(depth == 0)
					{
						parts.push(current.trim());
						current = '';
					}
					else current += character;
				default:
					current += character;
			}
		}
		parts.push(current.trim());
		return parts;
	}

	function setDropDownName(name:String):Void
	{
		var index:Int = catalogIndex(name);
		eventDropDown.selectedIndex = index;
	}

	function catalogIndex(name:String):Int
	{
		for(index in 0...catalog.length)
			if(catalog[index].name == name) return index;
		return -1;
	}

	function catalogContains(name:String):Bool
		return catalogIndex(name) >= 0;

	function catalogDescription(name:String):String
	{
		var index:Int = catalogIndex(name);
		return index >= 0 ? catalog[index].description : '';
	}

	function upsertCatalog(name:String, displayName:String, description:String):Void
	{
		var index:Int = catalogIndex(name);
		var entry:EventCatalogEntry = {
			name: name,
			displayName: displayName != null && displayName.trim().length > 0 ? displayName.trim() : name,
			description: description ?? ''
		};
		if(index >= 0) catalog[index] = entry; else catalog.push(entry);
	}
}
