package options;

import objects.Character;

#if nape
import nape.geom.Vec2;
import nape.phys.Body;
import nape.phys.BodyType;
import nape.phys.Material;
import nape.shape.Polygon;
import nape.space.Space;
#end

class GraphicsSettingsSubState extends BaseOptionsMenu
{
	static inline final BOYFRIEND_GRAVITY:Float = 1500;
	static inline final BOYFRIEND_BOUNCE:Float = 0.62;
	static inline final BOYFRIEND_MAX_SPEED:Float = 1150;
	static inline final BOYFRIEND_PIVOT_X:Float = 210;
	static inline final BOYFRIEND_PIVOT_Y:Float = 95;
	static inline final BOYFRIEND_DRAG_INFLUENCE:Float = 0.02;
	static inline final BOYFRIEND_RETURN_GRAVITY:Float = 70;
	static inline final BOYFRIEND_DAMPING:Float = 0.86;
	static inline final BOYFRIEND_FOLLOW_SMOOTH:Float = 1;
	static inline final BOYFRIEND_MAX_ANGLE:Float = 360;
	static inline final BOYFRIEND_FLOOR_MARGIN:Float = 185;

	var antialiasingOption:Int;
	var boyfriend:Character = null;
	var boyfriendGrabbed:Bool = false;
	var previousMouseVisible:Bool = false;
	var lastMouseX:Float = 0;
	var lastMouseY:Float = 0;
	var mouseVelocityX:Float = 0;
	var mouseVelocityY:Float = 0;
	var boyfriendAngleVelocity:Float = 0;
	#if nape
	var napeSpace:Space = null;
	var boyfriendBody:Body = null;
	var napeWalls:Body = null;
	#end

	public function new() {
		super(Language.getPhrase('graphics_menu', 'Graphics Settings'), 'Graphics Settings Menu');
		
		boyfriend = new Character(840, 170, 'bf', true);
		boyfriend.scale.set(boyfriend.scale.x * 0.75, boyfriend.scale.y * 0.75);
		boyfriend.updateHitbox();
		boyfriend.dance(true);
		boyfriend.animation.onFinish.add((_) -> boyfriend.dance(true));
		boyfriend.visible = false;
		#if !nape
		boyfriend.acceleration.y = BOYFRIEND_GRAVITY;
		#end
		boyfriend.origin.set(BOYFRIEND_PIVOT_X, BOYFRIEND_PIVOT_Y);

		//I'd suggest using "Low Quality" as an example for making your own option since it is the simplest here
		var option:Option = new Option('Low Quality', //Name
			'If checked, background details will be disabled,\ndecreasing loading times and improving performance.', //Description
			'lowQuality', //Save data variable name
			BOOL); //Variable type
		addOption(option);

		var option:Option = new Option('Anti-Aliasing',
			'If unchecked, disables anti-aliasing, improving performance\nat the cost of rougher visuals.',
			'antialiasing',
			BOOL);
		option.onChange = onChangeAntiAliasing; //Changing onChange is only needed if you want to make a special interaction after it changes the value
		addOption(option);
		antialiasingOption = optionsArray.length-1;

		var option:Option = new Option('Shaders', //Name
			"Enables shaders, commonly used for visual effects.\nMight be CPU intensive for weaker PCs.", //Description
			'shaders',
			BOOL);
		addOption(option);

		var option:Option = new Option('GPU Caching', //Name
			"Allows caching textures to the GPU, decreasing RAM usage.\nDisable this if your Graphics Card is weak.", //Description
			'cacheOnGPU',
			BOOL);
		addOption(option);

		#if !html5 //Apparently other framerates isn't correctly supported on Browser? Probably it has some V-Sync shit enabled by default, idk
		var option:Option = new Option('Framerate',
			"Changes how many frames the game can display per second.",
			'framerate',
			INT);
		addOption(option);

		final refreshRate:Int = FlxG.stage.application.window.displayMode.refreshRate;
		option.minValue = 60;
		option.maxValue = 240;
		option.defaultValue = Std.int(FlxMath.bound(refreshRate, option.minValue, option.maxValue));
		option.displayFormat = '%v FPS';
		option.onChange = onChangeFramerate;
		option.visible = function() return !ClientPrefs.data.unlockedFPS;

		var option:Option = new Option('Unlocked FPS',
			'If checked, removes the game framerate cap.',
			'unlockedFPS',
			BOOL);
		option.onChange = onChangeUnlockedFPS;
		addOption(option);
		#end
		
		insert(1, boyfriend);
	}

	public override function create():Void
	{
		previousMouseVisible = FlxG.mouse.visible;
		super.create();
	}

	function onChangeAntiAliasing(?_, ?_)
	{
		for (sprite in members)
		{
			var sprite:FlxSprite = cast sprite;
			if(sprite != null && (sprite is FlxSprite) && !(sprite is FlxText)) {
				sprite.antialiasing = ClientPrefs.data.antialiasing;
			}
		}
	}

	function onChangeFramerate(?_, ?_)
	{
		ClientPrefs.applyFramerate(ClientPrefs.data.framerate);
	}

	function onChangeUnlockedFPS(?_, ?_)
	{
		ClientPrefs.applyFramerate(ClientPrefs.data.framerate);
		refreshVisibleOptions();
	}

	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);

		var showBoyfriend:Bool = (antialiasingOption == curSelected);
		if(showBoyfriend && !boyfriend.visible)
			spawnBoyfriendPreview();
		else if(!showBoyfriend)
			boyfriendGrabbed = false;

		boyfriend.visible = showBoyfriend;
		FlxG.mouse.visible = (showBoyfriend || previousMouseVisible);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(boyfriend != null && boyfriend.visible)
		{
			if(boyfriend.isAnimationFinished())
				boyfriend.dance(true);

			updateBoyfriendPreview(elapsed);
		}
	}

	override function destroy()
	{
		FlxG.mouse.visible = previousMouseVisible;
		#if nape
		if(boyfriendBody != null)
		{
			boyfriendBody.space = null;
			boyfriendBody = null;
		}
		if(napeWalls != null)
		{
			napeWalls.space = null;
			napeWalls = null;
		}
		napeSpace = null;
		#end
		super.destroy();
	}

	function spawnBoyfriendPreview():Void
	{
		boyfriend.visible = true;
		boyfriendGrabbed = false;
		boyfriend.origin.set(BOYFRIEND_PIVOT_X, BOYFRIEND_PIVOT_Y);
		setBoyfriendVisualPosition(
			FlxG.random.float(520, Math.max(520, FlxG.width - boyfriend.width - 40)),
			FlxG.random.float(35, Math.max(35, FlxG.height - BOYFRIEND_FLOOR_MARGIN - boyfriend.height))
		);
		boyfriend.angle = FlxG.random.float(-18, 18);
		boyfriendAngleVelocity = FlxG.random.float(-170, 170);
		#if nape
		resetBoyfriendBody(
			FlxG.random.float(-260, 260),
			FlxG.random.float(-80, 220),
			boyfriendAngleVelocity
		);
		#else
		boyfriend.velocity.set(FlxG.random.float(-260, 260), FlxG.random.float(-80, 220));
		boyfriend.acceleration.set(0, BOYFRIEND_GRAVITY);
		boyfriend.angularVelocity = boyfriendAngleVelocity;
		#end
		lastMouseX = FlxG.mouse.x;
		lastMouseY = FlxG.mouse.y;
		boyfriend.dance(true);
	}

	function updateBoyfriendPreview(elapsed:Float):Void
	{
		if(elapsed <= 0)
			elapsed = 1 / 60;

		var mouseX:Float = FlxG.mouse.x;
		var mouseY:Float = FlxG.mouse.y;
		mouseVelocityX = (mouseX - lastMouseX) / elapsed;
		mouseVelocityY = (mouseY - lastMouseY) / elapsed;
		lastMouseX = mouseX;
		lastMouseY = mouseY;

		#if nape
		updateBoyfriendNapePreview(elapsed, mouseX, mouseY);
		return;
		#end

		if(FlxG.mouse.justPressed)
		{
			boyfriendGrabbed = true;
			boyfriendAngleVelocity = boyfriend.angularVelocity;
			boyfriend.velocity.set();
			boyfriend.acceleration.set();
			boyfriend.angularVelocity = 0;
		}

		if(boyfriendGrabbed)
		{
			if(FlxG.mouse.pressed)
			{
				var targetX:Float = mouseX + boyfriend.offset.x - boyfriend.origin.x;
				var targetY:Float = mouseY + boyfriend.offset.y - boyfriend.origin.y;
				var follow:Float = FlxMath.bound(BOYFRIEND_FOLLOW_SMOOTH * elapsed * 60, 0, 1);

				boyfriend.x += (targetX - boyfriend.x) * follow;
				boyfriend.y += (targetY - boyfriend.y) * follow;
				keepBoyfriendInBounds(false);

				var targetAngle:Float = FlxMath.bound(mouseVelocityX * BOYFRIEND_DRAG_INFLUENCE, -BOYFRIEND_MAX_ANGLE, BOYFRIEND_MAX_ANGLE);
				var verticalKick:Float = FlxMath.bound(mouseVelocityY * 0.015, -10, 10);
				var torque:Float = ((targetAngle - boyfriend.angle) * 8) - (boyfriend.angle * BOYFRIEND_RETURN_GRAVITY * elapsed) + verticalKick;
				boyfriendAngleVelocity += torque * elapsed * 60;
				boyfriendAngleVelocity *= Math.pow(BOYFRIEND_DAMPING, elapsed * 60);
				boyfriend.angle = FlxMath.bound(boyfriend.angle + boyfriendAngleVelocity * elapsed, -BOYFRIEND_MAX_ANGLE, BOYFRIEND_MAX_ANGLE);
			}
			else
			{
				boyfriendGrabbed = false;
				boyfriend.acceleration.set(0, BOYFRIEND_GRAVITY);
				boyfriend.velocity.set(
					FlxMath.bound(mouseVelocityX * 0.35, -BOYFRIEND_MAX_SPEED, BOYFRIEND_MAX_SPEED),
					FlxMath.bound(mouseVelocityY * 0.35, -BOYFRIEND_MAX_SPEED, BOYFRIEND_MAX_SPEED)
				);
				boyfriend.angularVelocity = FlxMath.bound(boyfriendAngleVelocity, -720, 720);
			}
		}
		else
		{
			boyfriend.acceleration.set(0, BOYFRIEND_GRAVITY);
			boyfriend.angularVelocity *= Math.max(0, 1 - elapsed * 0.75);
			boyfriendAngleVelocity = boyfriend.angularVelocity;
			bounceBoyfriendPreview();
		}
	}

	#if nape
	function ensureNapeSpace():Void
	{
		if(napeSpace == null)
		{
			napeSpace = new Space(new Vec2());
			napeSpace.gravity.setxy(0, BOYFRIEND_GRAVITY);
		}

		rebuildNapeWalls();
	}

	function rebuildNapeWalls():Void
	{
		if(napeSpace == null)
			return;

		if(napeWalls != null)
			napeWalls.space = null;

		var thickness:Float = 120;
		var material:Material = new Material(BOYFRIEND_BOUNCE, 0.25, 0.45, 1, 0.001);
		napeWalls = new Body(BodyType.STATIC);
		napeWalls.shapes.add(new Polygon(Polygon.rect(-thickness, -thickness, thickness, FlxG.height + thickness * 2)));
		napeWalls.shapes.add(new Polygon(Polygon.rect(FlxG.width, -thickness, thickness, FlxG.height + thickness * 2)));
		napeWalls.shapes.add(new Polygon(Polygon.rect(-thickness, -thickness, FlxG.width + thickness * 2, thickness)));
		napeWalls.shapes.add(new Polygon(Polygon.rect(-thickness, FlxG.height, FlxG.width + thickness * 2, thickness)));
		napeWalls.setShapeMaterials(material);
		napeWalls.space = napeSpace;
	}

	function resetBoyfriendBody(velocityX:Float = 0, velocityY:Float = 0, angularVelocityDegrees:Float = 0):Void
	{
		ensureNapeSpace();

		if(boyfriendBody != null)
			boyfriendBody.space = null;

		boyfriendBody = new Body(BodyType.DYNAMIC, Vec2.weak(boyfriendPhysicsX(), boyfriendPhysicsY()));
		boyfriendBody.shapes.add(new Polygon(Polygon.rect(
			-boyfriendPhysicsOriginX(),
			-boyfriendPhysicsOriginY(),
			Math.max(16, boyfriend.width),
			Math.max(16, boyfriend.height)
		)));
		boyfriendBody.setShapeMaterials(new Material(BOYFRIEND_BOUNCE, 0.3, 0.45, 1, 0.001));
		boyfriendBody.rotation = boyfriend.angle * Math.PI / 180;
		boyfriendBody.velocity.setxy(velocityX, velocityY);
		boyfriendBody.angularVel = angularVelocityDegrees * Math.PI / 180;
		boyfriendBody.space = napeSpace;
	}

	function updateBoyfriendNapePreview(elapsed:Float, mouseX:Float, mouseY:Float):Void
	{
		if(boyfriendBody == null)
			resetBoyfriendBody();

		if(FlxG.mouse.justPressed)
		{
			boyfriendGrabbed = true;
			boyfriendAngleVelocity = boyfriendBody.angularVel * 180 / Math.PI;
			boyfriendBody.velocity.setxy(0, 0);
			boyfriendBody.angularVel = 0;
		}

		if(boyfriendGrabbed)
		{
			if(FlxG.mouse.pressed)
			{
				var follow:Float = FlxMath.bound(BOYFRIEND_FOLLOW_SMOOTH * elapsed * 60, 0, 1);
				boyfriendBody.position.x += (mouseX - boyfriendBody.position.x) * follow;
				boyfriendBody.position.y += (mouseY - boyfriendBody.position.y) * follow;
				boyfriendBody.velocity.setxy(0, 0);

				var targetAngle:Float = FlxMath.bound(mouseVelocityX * BOYFRIEND_DRAG_INFLUENCE, -BOYFRIEND_MAX_ANGLE, BOYFRIEND_MAX_ANGLE);
				var verticalKick:Float = FlxMath.bound(mouseVelocityY * 0.015, -10, 10);
				var currentAngle:Float = boyfriendBody.rotation * 180 / Math.PI;
				var torque:Float = ((targetAngle - currentAngle) * 8) - (currentAngle * BOYFRIEND_RETURN_GRAVITY * elapsed) + verticalKick;
				boyfriendAngleVelocity += torque * elapsed * 60;
				boyfriendAngleVelocity *= Math.pow(BOYFRIEND_DAMPING, elapsed * 60);
				boyfriendBody.rotation += (boyfriendAngleVelocity * Math.PI / 180) * elapsed;
				keepBoyfriendBodyInBounds();
			}
			else
			{
				boyfriendGrabbed = false;
				boyfriendBody.velocity.setxy(
					FlxMath.bound(mouseVelocityX * 0.35, -BOYFRIEND_MAX_SPEED, BOYFRIEND_MAX_SPEED),
					FlxMath.bound(mouseVelocityY * 0.35, -BOYFRIEND_MAX_SPEED, BOYFRIEND_MAX_SPEED)
				);
				boyfriendBody.angularVel = FlxMath.bound(boyfriendAngleVelocity, -720, 720) * Math.PI / 180;
			}
		}
		else
		{
			napeSpace.step(elapsed, 10, 10);
			boyfriendBody.angularVel *= Math.max(0, 1 - elapsed * 0.75);
			boyfriendAngleVelocity = boyfriendBody.angularVel * 180 / Math.PI;
		}

		syncBoyfriendFromBody();
	}

	function keepBoyfriendBodyInBounds():Void
	{
		if(boyfriendBody == null)
			return;

		var minX:Float = boyfriendPhysicsOriginX();
		var maxX:Float = Math.max(minX, FlxG.width - boyfriend.width + boyfriendPhysicsOriginX());
		var minY:Float = boyfriendPhysicsOriginY();
		var maxY:Float = Math.max(minY, FlxG.height - boyfriend.height + boyfriendPhysicsOriginY());

		boyfriendBody.position.x = FlxMath.bound(boyfriendBody.position.x, minX, maxX);
		boyfriendBody.position.y = FlxMath.bound(boyfriendBody.position.y, minY, maxY);
	}

	function syncBoyfriendFromBody():Void
	{
		if(boyfriendBody == null)
			return;

		setBoyfriendVisualPosition(
			boyfriendBody.position.x - boyfriendPhysicsOriginX(),
			boyfriendBody.position.y - boyfriendPhysicsOriginY()
		);
		boyfriend.angle = boyfriendBody.rotation * 180 / Math.PI;
		boyfriend.velocity.set(boyfriendBody.velocity.x, boyfriendBody.velocity.y);
		boyfriend.angularVelocity = boyfriendBody.angularVel * 180 / Math.PI;
	}

	function boyfriendPhysicsOriginX():Float
		return boyfriend.origin.x * Math.abs(boyfriend.scale.x);

	function boyfriendPhysicsOriginY():Float
		return boyfriend.origin.y * Math.abs(boyfriend.scale.y);

	function boyfriendPhysicsX():Float
		return boyfriendVisualX() + boyfriendPhysicsOriginX();

	function boyfriendPhysicsY():Float
		return boyfriendVisualY() + boyfriendPhysicsOriginY();
	#end

	function setBoyfriendVisualPosition(visualX:Float, visualY:Float):Void
	{
		var scaleX:Float = Math.abs(boyfriend.scale.x);
		var scaleY:Float = Math.abs(boyfriend.scale.y);
		boyfriend.x = visualX + boyfriend.offset.x - boyfriend.origin.x + (boyfriend.origin.x * scaleX);
		boyfriend.y = visualY + boyfriend.offset.y - boyfriend.origin.y + (boyfriend.origin.y * scaleY);
	}

	function boyfriendVisualX():Float
	{
		return boyfriend.x - boyfriend.offset.x + boyfriend.origin.x - (boyfriend.origin.x * Math.abs(boyfriend.scale.x));
	}

	function boyfriendVisualY():Float
	{
		return boyfriend.y - boyfriend.offset.y + boyfriend.origin.y - (boyfriend.origin.y * Math.abs(boyfriend.scale.y));
	}

	function keepBoyfriendInBounds(bounce:Bool):Void
	{
		var minX:Float = 40;
		var maxX:Float = Math.max(minX, FlxG.width - boyfriend.width - 40);
		var minY:Float = -35;
		var maxY:Float = Math.max(minY, FlxG.height - BOYFRIEND_FLOOR_MARGIN - boyfriend.height);
		var visualX:Float = boyfriendVisualX();
		var visualY:Float = boyfriendVisualY();

		if(visualX < minX)
		{
			boyfriend.x += minX - visualX;
			if(bounce)
			{
				boyfriend.velocity.x = Math.abs(boyfriend.velocity.x) * BOYFRIEND_BOUNCE;
				boyfriend.angularVelocity += 90;
			}
		}
		else if(visualX > maxX)
		{
			boyfriend.x += maxX - visualX;
			if(bounce)
			{
				boyfriend.velocity.x = -Math.abs(boyfriend.velocity.x) * BOYFRIEND_BOUNCE;
				boyfriend.angularVelocity -= 90;
			}
		}

		if(visualY < minY)
		{
			boyfriend.y += minY - visualY;
			if(bounce)
				boyfriend.velocity.y = Math.abs(boyfriend.velocity.y) * BOYFRIEND_BOUNCE;
		}
		else if(visualY > maxY)
		{
			boyfriend.y += maxY - visualY;
			if(bounce)
			{
				boyfriend.velocity.y = -Math.abs(boyfriend.velocity.y) * BOYFRIEND_BOUNCE;
				boyfriend.velocity.x *= 0.86;
				boyfriend.angularVelocity *= 0.82;
			}
		}
	}

	function bounceBoyfriendPreview():Void
	{
		keepBoyfriendInBounds(true);
	}
}
