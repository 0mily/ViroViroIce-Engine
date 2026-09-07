package mobile.backend.flixel;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.atlas.FlxAtlas;
import flixel.graphics.atlas.FlxNode;
import flixel.graphics.frames.FlxTileFrames;
import flixel.input.FlxInput;
import flixel.input.FlxPointer;
import flixel.input.IFlxInput;
import flixel.input.touch.FlxTouch;
import flixel.math.FlxPoint;
#if (flixel > "5.3.0")
import flixel.sound.FlxSound;
#else
import flixel.system.FlxSound;
#end
import flixel.text.FlxText;
import flixel.util.FlxDestroyUtil;
import mobile.backend.flixel.input.TouchInputID;

/**
 * A simple button class that calls a function when clicked by the touch.
 */
class TouchButton extends FlxTypedTouch<FlxText>
{
	public static inline var NORMAL:Int = 0;
	public static inline var HIGHLIGHT:Int = 1;
	public static inline var PRESSED:Int = 2;

	public var text(get, set):String;
	public var IDs:Array<TouchInputID> = [];

	public function new(X:Float = 0, Y:Float = 0, ?IDs:Array<TouchInputID>, ?Text:String, ?OnClick:Void->Void)
	{
		super(X, Y, OnClick);

		for (point in labelOffsets)
			point.set(point.x - 1, point.y + 3);

		initLabel(Text);
		
		if (IDs != null) 
			this.IDs = IDs.copy();
	}

	override function resetHelpers():Void
	{
		super.resetHelpers();

		if (label != null)
		{
			label.fieldWidth = label.frameWidth = Std.int(width);
			label.size = label.size; // Calls set_size(), don't remove!
		}
	}

	inline function initLabel(Text:String):Void
	{
		if (Text != null)
		{
			label = new FlxText(x + labelOffsets[NORMAL].x, y + labelOffsets[NORMAL].y, 80, Text);
			label.setFormat(null, 8, 0x333333, 'center');
			label.alpha = labelAlphas[status];
			label.drawFrame(true);
		}
	}

	inline function get_text():String return (label != null) ? label.text : null;

	inline function set_text(Text:String):String
	{
		if (label == null) initLabel(Text);
		else label.text = Text;
		return Text;
	}
}

/**
 * A simple button class that calls a function when clicked by the touch.
 */
#if !display
@:generic
#end
class FlxTypedTouch<T:FlxSprite> extends FlxSprite implements IFlxInput
{
	public var label(default, set):T;
	public var labelOffsets:Array<FlxPoint> = [FlxPoint.get(), FlxPoint.get(), FlxPoint.get(0, 1)];
	public var labelAlphas:Array<Float> = [0.8, 1.0, 0.5];
	public var statusAnimations:Array<String> = ['normal', 'highlight', 'pressed'];
	public var allowSwiping:Bool = true;
	public var maxInputMovement:Float = Math.POSITIVE_INFINITY;
	public var status(default, set):Int;
	public var onUp(default, null):TouchEvent;
	public var onDown(default, null):TouchEvent;
	public var onOver(default, null):TouchEvent;
	public var onOut(default, null):TouchEvent;

	public var justReleased(get, never):Bool;
	public var released(get, never):Bool;
	public var pressed(get, never):Bool;
	public var justPressed(get, never):Bool;

	var _spriteLabel:FlxSprite;
	var input:FlxInput<Int>;
	var currentInput:IFlxInput;
	var lastStatus = -1;

	public function new(X:Float = 0, Y:Float = 0, ?OnClick:Void->Void)
	{
		super(X, Y);
		loadDefaultGraphic();

		onUp = new TouchEvent(OnClick);
		onDown = new TouchEvent();
		onOver = new TouchEvent();
		onOut = new TouchEvent();

		status = TouchButton.NORMAL;
		scrollFactor.set();

		statusAnimations[TouchButton.HIGHLIGHT] = 'normal';
		labelAlphas[TouchButton.HIGHLIGHT] = 1;

		input = new FlxInput(0);
	}

	override public function graphicLoaded():Void
	{
		super.graphicLoaded();
		setupAnimation('normal', TouchButton.NORMAL);
		setupAnimation('highlight', TouchButton.HIGHLIGHT);
		setupAnimation('pressed', TouchButton.PRESSED);
	}

	inline function loadDefaultGraphic():Void loadGraphic('flixel/images/ui/button.png', true, 80, 20);

	function setupAnimation(animationName:String, frameIndex:Int):Void
	{
		frameIndex = Std.int(Math.min(frameIndex, #if (flixel > "3.3.12") animation.numFrames #else animation.frames #end - 1));
		animation.add(animationName, [frameIndex]);
	}

	override public function destroy():Void
	{
		label = FlxDestroyUtil.destroy(label);
		_spriteLabel = null;
		onUp = FlxDestroyUtil.destroy(onUp);
		onDown = FlxDestroyUtil.destroy(onDown);
		onOver = FlxDestroyUtil.destroy(onOver);
		onOut = FlxDestroyUtil.destroy(onOut);
		labelOffsets = FlxDestroyUtil.putArray(labelOffsets);
		labelAlphas = null;
		currentInput = null;
		input = null;

		super.destroy();
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (visible)
		{
			#if FLX_POINTER_INPUT
			updateButton();
			#end

			if (lastStatus != status)
			{
				updateStatusAnimation();
				lastStatus = status;
			}
		}
		input.update();
	}

	inline function updateStatusAnimation():Void animation.play(statusAnimations[status]);

	override public function draw():Void
	{
		super.draw();
		if (_spriteLabel != null && _spriteLabel.visible)
		{
			_spriteLabel.cameras = cameras;
			_spriteLabel.draw();
		}
	}

	#if FLX_DEBUG
	override public function drawDebug():Void
	{
		super.drawDebug();
		if (_spriteLabel != null) _spriteLabel.drawDebug();
	}
	#end

	public function stampOnAtlas(atlas:FlxAtlas):Bool
	{
		var buttonNode:FlxNode = atlas.addNode(graphic.bitmap, graphic.key);
		var result:Bool = (buttonNode != null);

		if (buttonNode != null)
		{
			var buttonFrames:FlxTileFrames = cast frames;
			var tileSize:FlxPoint = FlxPoint.get(buttonFrames.tileSize.x, buttonFrames.tileSize.y);
			this.frames = buttonNode.getTileFrames(tileSize);
		}

		if (result && label != null)
		{
			var labelNode:FlxNode = atlas.addNode(label.graphic.bitmap, label.graphic.key);
			result = result && (labelNode != null);
			if (labelNode != null) label.frames = labelNode.getImageFrame();
		}
		return result;
	}

	function updateButton():Void
	{
		var overlapFound = checkTouchOverlap();

		if (currentInput != null && currentInput.justReleased && overlapFound)
			onUpHandler();

		if (status != TouchButton.NORMAL && (!overlapFound || (currentInput != null && currentInput.justReleased)))
			onOutHandler();
	}

	function checkTouchOverlap():Bool
	{
		for (camera in cameras) {
			for (touch in FlxG.touches.list) {
				if (checkInput(touch, touch, touch.justPressedPosition, camera)) {
					return true;
				}
			}
		}
		return false;
	}

	function checkInput(pointer:FlxPointer, input:IFlxInput, justPressedPosition:FlxPoint, camera:FlxCamera):Bool
	{
		if (maxInputMovement != Math.POSITIVE_INFINITY
			&& input == currentInput
			&& justPressedPosition.distanceTo(pointer.getScreenPosition(_point)) > maxInputMovement)
		{
			currentInput = null;
		}
		else if (overlapsPoint(pointer.getWorldPosition(camera, _point), true, camera))
		{
			updateStatus(input);
			return true;
		}

		return false;
	}

	function updateStatus(input:IFlxInput):Void
	{
		if (input.justPressed)
		{
			currentInput = input;
			onDownHandler();
		}
		else if (status == TouchButton.NORMAL)
		{
			if (allowSwiping && input.pressed) onDownHandler();
			else onOverHandler();
		}
	}

	inline function updateLabelPosition()
	{
		if (_spriteLabel != null)
		{
			_spriteLabel.x = (pixelPerfectPosition ? Math.floor(x) : x) + labelOffsets[status].x;
			_spriteLabel.y = (pixelPerfectPosition ? Math.floor(y) : y) + labelOffsets[status].y;
		}
	}

	inline function updateLabelAlpha()
	{
		if (_spriteLabel != null && labelAlphas.length > status)
			_spriteLabel.alpha = alpha * labelAlphas[status];
	}

	function onUpHandler():Void
	{
		status = TouchButton.NORMAL;
		input.release();
		currentInput = null;
		onUp.fire();
	}

	function onDownHandler():Void
	{
		status = TouchButton.PRESSED;
		input.press();
		onDown.fire();
	}

	function onOverHandler():Void
	{
		status = TouchButton.HIGHLIGHT;
		onOver.fire();
	}

	function onOutHandler():Void
	{
		status = TouchButton.NORMAL;
		input.release();
		onOut.fire();
	}

	function set_label(Value:T):T
	{
		if (Value != null)
		{
			Value.scrollFactor.put();
			Value.scrollFactor = scrollFactor;
		}
		label = Value;
		_spriteLabel = label;
		updateLabelPosition();
		return Value;
	}

	function set_status(Value:Int):Int
	{
		status = Value;
		updateLabelAlpha();
		return status;
	}

	override function set_alpha(Value:Float):Float
	{
		super.set_alpha(Value);
		updateLabelAlpha();
		return alpha;
	}

	override function set_x(Value:Float):Float
	{
		super.set_x(Value);
		updateLabelPosition();
		return x;
	}

	override function set_y(Value:Float):Float
	{
		super.set_y(Value);
		updateLabelPosition();
		return y;
	}

	inline function get_justReleased():Bool return input.justReleased;
	inline function get_released():Bool return input.released;
	inline function get_pressed():Bool return input.pressed;
	inline function get_justPressed():Bool return input.justPressed;
}

private class TouchEvent implements IFlxDestroyable
{
	public var callback:Void->Void;

	#if FLX_SOUND_SYSTEM
	public var sound:FlxSound;
	#end

	public function new(?Callback:Void->Void, ?sound:FlxSound)
	{
		callback = Callback;
		#if FLX_SOUND_SYSTEM
		this.sound = sound;
		#end
	}

	public inline function destroy():Void
	{
		callback = null;
		#if FLX_SOUND_SYSTEM
		sound = FlxDestroyUtil.destroy(sound);
		#end
	}

	public inline function fire():Void
	{
		if (callback != null) callback();
		#if FLX_SOUND_SYSTEM
		if (sound != null) sound.play(true);
		#end
	}
}