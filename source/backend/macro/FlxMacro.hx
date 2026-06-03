package backend.macro;

//#if !display
#if macro
class FlxMacro // This shit adds 'zIndex' used by some V-Slice components
{
  /**
   * Added also some cool nmv shit
   */
  public static macro function buildFlxSprite():Array<haxe.macro.Expr.Field>
  {
    var pos:haxe.macro.Expr.Position = haxe.macro.Context.currentPos();
    var fields:Array<haxe.macro.Expr.Field> = haxe.macro.Context.getBuildFields();

    fields = fields.concat([
      {
        name: "loadFromSheet",
        access: [haxe.macro.Expr.Access.APublic],
        kind: haxe.macro.Expr.FieldType.FFun({
          args: [
            {name: "path", type: macro:String},
            {name: "animName", type: macro:String},
            {name: "fps", type: macro:Int, value: macro $v{24}},
            {name: "looped", type: macro:Bool, value: macro $v{true}}
          ],
          expr: macro {
            this.frames = backend.Paths.getAtlas(path);
            this.animation.addByPrefix(animName, animName, fps, looped);
            this.animation.play(animName);
            if(this.animation.curAnim == null || this.animation.curAnim.numFrames <= 1)
              this.active = false;
            return this;
          }
        }),
        pos: pos,
      },
      {
        name: "loadSparrowFrames",
        access: [haxe.macro.Expr.Access.APublic],
        kind: haxe.macro.Expr.FieldType.FFun({
          args: [
            {name: "path", type: macro:String}
          ],
          expr: macro {
            this.frames = backend.Paths.getSparrowAtlas(path);
            this.active = true;
            return this;
          }
        }),
        pos: pos,
      },
      {
        name: "loadAtlasFrames",
        access: [haxe.macro.Expr.Access.APublic],
        kind: haxe.macro.Expr.FieldType.FFun({
          args: [
            {name: "frames", type: macro:flixel.graphics.frames.FlxAtlasFrames}
          ],
          expr: macro {
            this.frames = frames;
            this.active = true;
            return this;
          }
        }),
        pos: pos,
      },
      {
        name: "makeScaledGraphic",
        access: [haxe.macro.Expr.Access.APublic],
        kind: haxe.macro.Expr.FieldType.FFun({
          args: [
            {name: "width", type: macro:Float},
            {name: "height", type: macro:Float},
            {name: "color", type: macro:flixel.util.FlxColor, value: macro flixel.util.FlxColor.WHITE}
          ],
          expr: macro {
            this.makeGraphic(1, 1, color);
            this.scale.set(width, height);
            this.updateHitbox();
            return this;
          }
        }),
        pos: pos,
      },
      {
        name: "centerOnObject",
        access: [haxe.macro.Expr.Access.APublic],
        kind: haxe.macro.Expr.FieldType.FFun({
          args: [
            {name: "object", type: macro:flixel.FlxObject},
            {name: "axes", type: macro:flixel.util.FlxAxes, value: macro flixel.util.FlxAxes.XY}
          ],
          expr: macro {
            if(axes.x) this.x = object.x + (object.width - this.width) / 2;
            if(axes.y) this.y = object.y + (object.height - this.height) / 2;
            return this;
          }
        }),
        pos: pos,
      }
    ]);

    return fields;
  }

  /**
   * A macro to be called targeting the `FlxBasic` class.
   * @return An array of fields that the class contains.
   */
  public static macro function buildFlxBasic():Array<haxe.macro.Expr.Field>
  {
    var pos:haxe.macro.Expr.Position = haxe.macro.Context.currentPos();
    // The FlxBasic class. We can add new properties to this class.
    var cls:haxe.macro.Type.ClassType = haxe.macro.Context.getLocalClass().get();
    // The fields of the FlxClass.
    var fields:Array<haxe.macro.Expr.Field> = haxe.macro.Context.getBuildFields();

    // haxe.macro.Context.info('[INFO] ${cls.name}: Adding zIndex attribute...', pos);

    // Here, we add the zIndex attribute to all FlxBasic objects.
    // This has no functional code tied to it, but it can be used as a target value
    // for the FlxTypedGroup.sort method, to rearrange the objects in the scene.
    fields = fields.concat([
      {
        name: "zIndex", // Field name.
        access: [haxe.macro.Expr.Access.APublic], // Access level
        kind: haxe.macro.Expr.FieldType.FVar(macro :Int, macro $v{0}), // Variable type and default value
        pos: pos, // The field's position in code.
      }
    ]);

    return fields;
  }
}
#end
//#end
