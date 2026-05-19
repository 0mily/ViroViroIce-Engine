package backend;

import flixel.graphics.FlxGraphic;
import flixel.FlxState;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.keyboard.FlxKey;
import openfl.display.BitmapData;
import openfl.display.PNGEncoderOptions;
import openfl.events.KeyboardEvent;
#if sys
import sys.FileSystem;
import sys.io.File;
#end

class ScreenshotUtil // eu só roubei do Vslice e adaptei essa bct
{
	static inline final SCREENSHOT_FOLDER:String = 'screenshots';
	static inline final RAW_PRINTSCREEN_KEY:Int = 301;
	static var lastCaptureTick:Int = -1;
	static var initialized:Bool = false;

	public static function initialize():Void
	{
		if(initialized || FlxG.stage == null)
			return;

		initialized = true;
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onRawKeyDown);
	}

	static function onRawKeyDown(event:KeyboardEvent):Void
	{
		if(event.keyCode == RAW_PRINTSCREEN_KEY)
			tryCapture();
	}

	static function pad(value:Int, length:Int = 2):String
	{
		var text:String = Std.string(value);
		while(text.length < length)
			text = '0' + text;
		return text;
	}

	static function timestamp():String
	{
		var date:Date = Date.now();
		return '${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}_${pad(date.getHours())}-${pad(date.getMinutes())}-${pad(date.getSeconds())}-${pad(Std.int(date.getTime() % 1000), 3)}';
	}

	static function saveBitmap(bitmap:BitmapData):String
	{
		#if sys
		if(!FileSystem.exists(SCREENSHOT_FOLDER))
			FileSystem.createDirectory(SCREENSHOT_FOLDER);

		var baseName:String = 'screenshot-${timestamp()}';
		var path:String = '$SCREENSHOT_FOLDER/$baseName.png';
		var copy:Int = 2;
		while(FileSystem.exists(path))
		{
			path = '$SCREENSHOT_FOLDER/$baseName ($copy).png';
			copy++;
		}

		File.saveBytes(path, bitmap.encode(bitmap.rect, new PNGEncoderOptions()));
		return path;
		#else
		return null;
		#end
	}

	static function overlayCamera():FlxCamera
	{
		return FlxG.cameras.list.length > 0 ? FlxG.cameras.list[FlxG.cameras.list.length - 1] : FlxG.camera;
	}

	static function showFeedback(bitmap:BitmapData):Void
	{
		var camera:FlxCamera = overlayCamera();
		var state:FlxState = FlxG.state;

		var flash:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.WHITE);
		flash.scrollFactor.set();
		flash.cameras = [camera];
		flash.alpha = ClientPrefs.data.flashing ? 1 : 0.45;
		state.add(flash);
		FlxTween.tween(flash, {alpha: 0}, 0.18, {
			onComplete: function(_)
			{
				state.remove(flash, true);
				flash.destroy();
			}
		});

		var previewBitmap:BitmapData = bitmap.clone();
		var graphic:FlxGraphic = FlxGraphic.fromBitmapData(previewBitmap, false, 'screenshot-preview-${timestamp()}');
		var previewWidth:Int = Std.int(Math.min(260, FlxG.width * 0.22));
		var preview:FlxSprite = new FlxSprite().loadGraphic(graphic);
		preview.setGraphicSize(previewWidth);
		preview.updateHitbox();

		var frame:FlxSprite = new FlxSprite().makeGraphic(Std.int(preview.width + 8), Std.int(preview.height + 8), FlxColor.WHITE);
		var group:FlxSpriteGroup = new FlxSpriteGroup();
		group.scrollFactor.set();
		group.cameras = [camera];
		group.x = FlxG.width - frame.width - 18;
		group.y = 18;
		group.alpha = 0;

		frame.setPosition(0, 0);
		preview.setPosition(4, 4);
		group.add(frame);
		group.add(preview);
		state.add(group);

		FlxTween.tween(group, {alpha: 1, y: group.y - 8}, 0.22, {
			ease: FlxEase.quartOut,
			onComplete: function(_)
			{
				new FlxTimer().start(1.2, function(_)
				{
					FlxTween.tween(group, {alpha: 0, y: group.y + 12}, 0.28, {
						ease: FlxEase.quartInOut,
						onComplete: function(_)
						{
							state.remove(group, true);
							group.destroy();
						}
					});
				});
			}
		});
	}

	static function screenshotKeyData():Dynamic
		return Reflect.field(ClientPrefs.data, 'screenshotKey');

	static function screenshotKeyboardKey():FlxKey
	{
		var data:Dynamic = screenshotKeyData();
		var keyName:String = data != null && Reflect.hasField(data, 'keyboard') ? Std.string(Reflect.field(data, 'keyboard')) : 'F10';
		return FlxKey.fromString(keyName);
	}

	static function screenshotGamepadKey():FlxGamepadInputID
	{
		var data:Dynamic = screenshotKeyData();
		var keyName:String = data != null && Reflect.hasField(data, 'gamepad') ? Std.string(Reflect.field(data, 'gamepad')) : 'NONE';
		return FlxGamepadInputID.fromString(keyName);
	}

	static function configuredKeyPressed():Bool
	{
		var keyboardKey:FlxKey = screenshotKeyboardKey();
		if(keyboardKey != NONE && FlxG.keys.anyJustPressed([keyboardKey]))
			return true;

		var gamepadKey:FlxGamepadInputID = screenshotGamepadKey();
		return gamepadKey != NONE && FlxG.gamepads.anyJustPressed(gamepadKey);
	}

	public static function updateInput():Void
	{
		initialize();
		if(ClientPrefs.data.screenshots && (configuredKeyPressed() || FlxG.keys.justPressed.PRINTSCREEN))
			capture();
	}

	static function tryCapture():Void
	{
		if(ClientPrefs.data.screenshots)
			capture();
	}

	public static function capture():Void
	{
		if(FlxG.game.ticks == lastCaptureTick)
			return;
		lastCaptureTick = FlxG.game.ticks;

		try
		{
			var bitmap:BitmapData = BitmapData.fromImage(FlxG.stage.window.readPixels());
			saveBitmap(bitmap);
			showFeedback(bitmap);
		}
		catch(e:Dynamic)
		{
			trace('Failed to save screenshot: $e');
		}
	}
}
