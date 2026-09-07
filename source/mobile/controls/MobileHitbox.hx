package mobile.controls;

import flixel.FlxG;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;

import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.display.GradientType;
import openfl.geom.Matrix;

import mobile.backend.MobileUtil;
import mobile.backend.flixel.TouchButton;
import mobile.backend.flixel.input.TouchInputManager;
import mobile.backend.flixel.input.TouchInputID;

/**
 * Hitbox... HIT (Now with smooth gradients!)
 * @author StarNova (Cream.BR)
 */
class MobileHitbox extends TouchInputManager
{
	public var buttons:Array<TouchButton> = [];
	
	var extraButtons:Int;
	
	public var buttonLeft:TouchButton;
	public var buttonDown:TouchButton;
	public var buttonUp:TouchButton;
	public var buttonRight:TouchButton;
	
	public var buttonAction:TouchButton;
	public var buttonActionTwo:TouchButton;

	private final alphaTarget:Float = 0.5; 
	
	private var _cachedGraphics:Map<String, flixel.graphics.FlxGraphic> = new Map();

	public function new():Void
	{
		super();

		extraButtons = ClientPrefs.data.extraButtons;

		var hasExtraButtons:Bool = extraButtons > 0;
		var hitboxY:Int = hasExtraButtons ? Std.int(FlxG.height * 0.25) : 0;
		var hitboxHeight:Int = hasExtraButtons ? Std.int(FlxG.height * 0.75) : FlxG.height;
		var extraHeight:Int = hasExtraButtons ? Std.int(FlxG.height * 0.25) : 0;

		var buttonWidth:Int = Std.int(FlxG.width / 4);
		var mainData = [
			{color: 0xFF00FF, ids: [TouchInputID.NOTE_LEFT]},
			{color: 0x00FFFF, ids: [TouchInputID.NOTE_DOWN]},
			{color: 0x00FF00, ids: [TouchInputID.NOTE_UP]},
			{color: 0xFF0000, ids: [TouchInputID.NOTE_RIGHT]}
		];
		
		for (i in 0...mainData.length) {
			var btn = createHint(i * buttonWidth, hitboxY, buttonWidth, hitboxHeight, mainData[i].color, mainData[i].ids);
			add(btn);
			buttons.push(btn);
		}

		buttonLeft  = buttons[0];
		buttonDown  = buttons[1];
		buttonUp    = buttons[2];
		buttonRight = buttons[3];

		if (hasExtraButtons)
		{
			if (extraButtons == 2)
			{
				buttonAction = createHint(0, 0, Std.int(FlxG.width / 2), extraHeight, 0xFFFF00, [TouchInputID.NONE]);
				buttonActionTwo = createHint(Std.int(FlxG.width / 2), 0, Std.int(FlxG.width / 2), extraHeight, 0x800080, [TouchInputID.NONE]);
				
				add(buttonAction);
				buttons.push(buttonAction);
				add(buttonActionTwo);
				buttons.push(buttonActionTwo);
			}
			else if (extraButtons == 1)
			{
				buttonAction = createHint(0, 0, FlxG.width, extraHeight, 0xFFFF00, [TouchInputID.NONE]);
				
				add(buttonAction);
				buttons.push(buttonAction);
			}
		}

		scrollFactor.set();
		refreshMappedButtons();
	}

	private function createHint(X:Float, Y:Float, Width:Int, Height:Int, Color:FlxColor, IDs:Array<TouchInputID>):TouchButton
	{
		var hint:TouchButton = new TouchButton(X, Y, IDs);
		
		var graphicKey:String = Width + "x" + Height + "_" + Color;
		var bgGraphic:flixel.graphics.FlxGraphic = _cachedGraphics.get(graphicKey);
		
		if (bgGraphic == null) {
			var shape:Shape = new Shape();
			var matrix:Matrix = new Matrix();
			
			matrix.createGradientBox(Width, Height, Math.PI / 2, 0, 0);

			var colors:Array<Int> = [Color, Color];
			var alphas:Array<Float> = [0.0, 0.8]; 
			var ratios:Array<Int> = [0, 255];

			shape.graphics.beginGradientFill(GradientType.LINEAR, colors, alphas, ratios, matrix);
			shape.graphics.drawRect(0, 0, Width, Height);
			shape.graphics.endFill();

			var bitmap:BitmapData = new BitmapData(Width, Height, true, 0x00000000);
			bitmap.draw(shape);
			
			bgGraphic = FlxG.bitmap.add(bitmap, false, "hitbox_" + graphicKey);
			_cachedGraphics.set(graphicKey, bgGraphic);
		}
		
		hint.loadGraphic(bgGraphic);
		hint.solid = hint.moves = false;
		hint.immovable = true;
		hint.scrollFactor.set();
		hint.alpha = 0.00001;

		if (!ClientPrefs.data.invisibleHitbox) {
			var hintTween:FlxTween = null;
			hint.onDown.callback = function() {
				if (hintTween != null) hintTween.cancel();
				
				hintTween = FlxTween.tween(hint, {alpha: alphaTarget}, 0.075, {
					ease: FlxEase.circInOut,
					onComplete: function(_) { hintTween = null; }
				});
			}
			
			hint.onUp.callback = function() {
				if (hintTween != null) hintTween.cancel();
				
				hintTween = FlxTween.tween(hint, {alpha: 0.00001}, 0.15, {
					ease: FlxEase.circInOut,
					onComplete: function(_) { hintTween = null; }
				});
			}
			
			hint.onOut.callback = hint.onUp.callback;
		}

		#if FLX_DEBUG
		hint.ignoreDrawDebug = true;
		#end
		
		return hint;
	}
	
	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		MobileUtil.setControlsState(this, buttons);
	}

	override function destroy():Void
	{
		super.destroy();

		for (btn in buttons)
			FlxDestroyUtil.destroy(btn);
			
		for (key in _cachedGraphics.keys()) {
			var graphic = _cachedGraphics.get(key);
			FlxG.bitmap.remove(graphic);
			graphic.destroy();
		}
		_cachedGraphics.clear();
	}
}