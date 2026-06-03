package shaders;

import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.system.FlxAssets.FlxShader;
import openfl.display.BitmapData;

class OverlayShader extends FlxShader
{
	@:glFragmentSource('
		#pragma header
		
		uniform sampler2D bitmapOverlay;
		
		vec4 blendOverlay(vec4 base, vec4 blend) {
			return mix(base, mix(1.0 - 2.0 * (1.0 - base) * (1.0 - blend), 2.0 * base * blend, step(base, vec4(0.5))), blend.a);
		}
		
		void main() {
			vec4 base = texture2D(bitmap, openfl_TextureCoordv);
			vec4 blend = texture2D(bitmapOverlay, openfl_TextureCoordv);
			gl_FragColor = blendOverlay(base, blend);
		}')
	
	public function new()
	{
		super();
	}

	public function setBitmapOverlay(bitmap:BitmapData):Void
	{
		if(bitmap != null)
			this.bitmapOverlay.input = bitmap;
	}

	public function setGraphicOverlay(graphic:FlxGraphic):Void
	{
		if(graphic != null)
			setBitmapOverlay(graphic.bitmap);
	}

	public function setSpriteOverlay(sprite:FlxSprite):Void
	{
		if(sprite != null)
			setGraphicOverlay(sprite.graphic);
	}

	public function setOverlay(overlay:Dynamic):Void
	{
		if(overlay == null)
			return;

		if(Std.isOfType(overlay, BitmapData))
			setBitmapOverlay(cast overlay);
		else if(Std.isOfType(overlay, FlxGraphic))
			setGraphicOverlay(cast overlay);
		else if(Std.isOfType(overlay, FlxSprite))
			setSpriteOverlay(cast overlay);
		else if(Reflect.hasField(overlay, 'bitmap') && Std.isOfType(Reflect.field(overlay, 'bitmap'), BitmapData))
			setBitmapOverlay(cast Reflect.field(overlay, 'bitmap'));
	}
}
