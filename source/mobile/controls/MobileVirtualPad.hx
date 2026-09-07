package mobile.controls;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxTileFrames;
import flixel.math.FlxPoint;
import flixel.util.FlxDestroyUtil;

import mobile.backend.flixel.TouchButton;

import openfl.utils.Assets;
import openfl.display.BitmapData;

import mobile.backend.MobileUtil;
import mobile.backend.flixel.input.TouchInputManager;
import mobile.backend.flixel.input.TouchInputID;

import haxe.Json;

#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end

typedef VirtualPadButtonData = {
	var name:String;
	var x:Float;
	var y:Float;
	var anchorX:String;
	var anchorY:String;
	var graphic:String;
	var color:String;
	var ids:Array<String>;
}

typedef VirtualPadData = {
	var buttons:Array<VirtualPadButtonData>;
}

/**
 * Virtual Pad.... Virtual... Buttons
 * @author StarNova (Cream.BR)
 */
class MobileVirtualPad extends TouchInputManager
{
	public var buttons:Array<TouchButton> = [];
	
	private var buttonMap:Map<String, TouchButton> = new Map<String, TouchButton>();

	public function new(DPad:String, Action:String)
	{
		super();
		
		loadLayout("dpad", DPad);
		loadLayout("action", Action);
		
		scrollFactor.set();
		refreshMappedButtons();
	}

	/**
	 * Returns a specific button by the name defined in the JSON.
	 * Ex: pad.getButton("buttonA")
	 */
	public function getButton(name:String):TouchButton
	{
		return buttonMap.get(name);
	}

	private function loadLayout(folder:String, layoutName:String):Void
	{
		if (layoutName == null || layoutName.toUpperCase() == "NONE") return;

		var path:String = 'assets/mobile/data/$folder/$layoutName.json';
		var content:String = null;

		#if MODS_ALLOWED
		var modsPath:String = Paths.modFolders('mobile/data/$folder/$layoutName.json');
		if (FileSystem.exists(modsPath)) {
			content = File.getContent(modsPath);
		} else if (FileSystem.exists(path)) {
			content = File.getContent(path);
		}
		#else
		if (Assets.exists(path)) {
			content = Assets.getText(path);
		}
		#end

		if (content != null)
		{
			try {
				var data:VirtualPadData = Json.parse(content);
				
				if (data != null && data.buttons != null)
				{
					for (btnData in data.buttons)
					{
						var actualX:Float = btnData.x;
						var actualY:Float = btnData.y;

						if (btnData.anchorX != null && btnData.anchorX.toLowerCase() == "right") actualX = FlxG.width - btnData.x;
						if (btnData.anchorY != null && btnData.anchorY.toLowerCase() == "bottom") actualY = FlxG.height - btnData.y;

						var colorInt:Int = 0xFFFFFF;
						if (btnData.color != null) {
							var hexString = StringTools.replace(btnData.color, "#", "0x");
							colorInt = Std.parseInt(hexString);
						}

						var touchIDs:Array<TouchInputID> = [];
						for (idStr in btnData.ids) {
							touchIDs.push(TouchInputID.fromString(idStr));
						}

						var newButton = add(createButton(actualX, actualY, btnData.graphic, colorInt, touchIDs));
						
						buttonMap.set(btnData.name, newButton);
					}
				}
			} catch (e:Dynamic) {
				trace('Error parsing VirtualPad JSON ($layoutName): $e');
			}
		} else {
			trace('VirtualPad JSON file not found: $path');
		}
	}
	
	private function createButton(X:Float, Y:Float, Graphic:String, Color:Int, IDs:Array<TouchInputID>):TouchButton
	{
		var graphic:FlxGraphic = null;
		var path:String = 'assets/mobile/images/virtualpad/${Graphic}.png';
		var cacheKey:String = path;
		
		#if MODS_ALLOWED
		var modsPath:String = Paths.modFolders('mobile/images/virtualpad/${Graphic}.png');
		if (FileSystem.exists(modsPath))
		{
			cacheKey = modsPath;
			graphic = FlxG.bitmap.get(cacheKey);
			
			if (graphic == null) graphic = FlxGraphic.fromBitmapData(BitmapData.fromFile(modsPath), false, cacheKey);
		}
		else
		#end
		{
			if (!Assets.exists(path))
			{
				path = 'assets/mobile/images/virtualpad/default.png';
				cacheKey = path;
			}
			
			graphic = FlxG.bitmap.get(cacheKey);
			if (graphic == null) graphic = FlxGraphic.fromBitmapData(Assets.getBitmapData(path), false, cacheKey);
		}
		
		var button = new TouchButton(X, Y, IDs);
		
		button.frames = FlxTileFrames.fromGraphic(graphic, FlxPoint.weak(Std.int(graphic.width / 3), graphic.height));
		
		button.solid = false;
		button.moves = false;
		button.immovable = true;
		button.scrollFactor.set();
		button.color = Color;
		button.alpha = 0.5;
		button.active = MobileUtil.isTouchActive;
		button.visible = MobileUtil.isTouchActive;
		
		#if FLX_DEBUG button.ignoreDrawDebug = true; #end
		
		buttons.push(button);
		return button;
	}
	
	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		MobileUtil.setControlsState(this, buttons);
	}
	
	override public function destroy():Void
	{
		for (btn in buttons)
			FlxDestroyUtil.destroy(btn);
			
		buttonMap.clear();
		super.destroy();
	}
}