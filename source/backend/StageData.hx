package backend;

import openfl.utils.Assets;
import haxe.Json;
import backend.Song;
import psychlua.ModchartSprite;

typedef StageFile = {
	var directory:String;
	var defaultZoom:Float;
	@:optional var isPixelStage:Null<Bool>;
	var stageUI:String;

	var boyfriend:Array<Dynamic>;
	var girlfriend:Array<Dynamic>;
	var opponent:Array<Dynamic>;
	var hide_girlfriend:Bool;

	var camera_boyfriend:Array<Float>;
	var camera_opponent:Array<Float>;
	var camera_girlfriend:Array<Float>;
	var camera_speed:Null<Float>;

	@:optional var preload:Dynamic;
	@:optional var objects:Array<Dynamic>;
	@:optional var _editorMeta:Dynamic;
}

enum abstract LoadFilters(Int) from Int from UInt to Int to UInt
{
	var LOW_QUALITY:Int = (1 << 0);
	var HIGH_QUALITY:Int = (1 << 1);

	var STORY_MODE:Int = (1 << 2);
	var FREEPLAY:Int = (1 << 3);
}

class StageData {
	public static function dummy():StageFile
	{
		return {
			directory: "",
			defaultZoom: 0.9,
			stageUI: "normal",

			boyfriend: [770, 100],
			girlfriend: [400, 130],
			opponent: [100, 100],
			hide_girlfriend: false,

			camera_boyfriend: [0, 0],
			camera_opponent: [0, 0],
			camera_girlfriend: [0, 0],
			camera_speed: 1,

			_editorMeta: {
				gf: "gf",
				dad: "dad",
				boyfriend: "bf"
			}
		};
	}

	public static var forceNextDirectory:String = null;
	public static function loadDirectory(SONG:SwagSong) {
		var stage:String = '';
		if(SONG.stage != null)
			stage = SONG.stage;
		else if(Song.loadedSongName != null)
			stage = vanillaSongStage(Paths.formatToSongPath(Song.loadedSongName));
		else
			stage = 'stage';

		var stageFile:StageFile = getStageFile(stage);
		forceNextDirectory = (stageFile != null) ? stageFile.directory : ''; //preventing crashes
	}

	public static function getStageFile(stage:String):StageFile {
		try
		{
			var path:String = Paths.getPath('data/stages/' + stage + '.json', TEXT, null, true);
			#if ADDONS_ALLOWED
			if(FileSystem.exists(path))
				return cast tjson.TJSON.parse(Paths.getTextFromFile(path));
			#else
			if(Assets.exists(path))
				return cast tjson.TJSON.parse(Assets.getText(path));
			#end
		}
		return dummy();
	}

	public static function vanillaSongStage(songName):String
	{
		switch (songName)
		{
			case 'spookeez' | 'south' | 'monster':
				return 'spooky';
			case 'pico' | 'blammed' | 'philly' | 'philly-nice':
				return 'philly';
			case 'milf' | 'satin-panties' | 'high':
				return 'limo';
			case 'cocoa' | 'eggnog':
				return 'mall';
			case 'winter-horrorland':
				return 'mallEvil';
			case 'senpai' | 'roses':
				return 'school';
			case 'thorns':
				return 'schoolEvil';
			case 'ugh' | 'guns' | 'stress':
				return 'tank';
		}
		return 'stage';
	}

	public static var reservedNames:Array<String> = ['gf', 'gfGroup', 'dad', 'dadGroup', 'boyfriend', 'boyfriendGroup']; //blocks these names from being used on stage editor's name input text
	public static function characterObjectRole(type:String):String
	{
		return switch(type)
		{
			case 'gf', 'gfGroup': 'gf';
			case 'dad', 'dadGroup': 'dad';
			case 'boyfriend', 'boyfriendGroup': 'boyfriend';
			default: null;
		}
	}

	public static function isCharacterObjectType(type:String):Bool
		return characterObjectRole(type) != null;

	public static function applyBasicObjectData(data:Dynamic, spr:FlxSprite):Void
	{
		if(data == null || spr == null)
			return;

		var scale:Array<Dynamic> = Reflect.field(data, 'scale');
		if(scale != null && scale.length > 1)
		{
			var scaleX:Float = Std.parseFloat(Std.string(scale[0]));
			var scaleY:Float = Std.parseFloat(Std.string(scale[1]));
			if(!Math.isNaN(scaleX) && !Math.isNaN(scaleY))
			{
				// A Character is used instead of its group inside the Stage Editorr
				if(Std.isOfType(spr, objects.Character) && scaleX == 1 && scaleY == 1)
				{
					var character:objects.Character = cast spr;
					character.scale.set(character.jsonScale, character.jsonScale);
					character.updateCharacterHitbox();
				}
				else
				{
					spr.scale.set(scaleX, scaleY);
					updateBasicObjectHitbox(spr);
				}
			}
		}

		var scroll:Array<Dynamic> = Reflect.field(data, 'scroll');
		if(scroll != null && scroll.length > 1)
		{
			var scrollX:Float = Std.parseFloat(Std.string(scroll[0]));
			var scrollY:Float = Std.parseFloat(Std.string(scroll[1]));
			if(!Math.isNaN(scrollX) && !Math.isNaN(scrollY))
				spr.scrollFactor.set(scrollX, scrollY);
		}

		var color:Dynamic = Reflect.field(data, 'color');
		if(color != null)
			spr.color = CoolUtil.colorFromString(Std.string(color));

		for(varName in ['alpha', 'angle'])
		{
			var value:Dynamic = Reflect.field(data, varName);
			if(value != null)
				Reflect.setProperty(spr, varName, value);
		}

		for(varName in ['flipX', 'flipY'])
		{
			var value:Dynamic = Reflect.field(data, varName);
			if(value != null)
			{
				if(Std.isOfType(spr, objects.Character) && value == false)
				{
					var character:objects.Character = cast spr;
					Reflect.setProperty(character, varName, varName == 'flipX' ? (character.originalFlipX != character.isPlayer) : false);
				}
				else
					Reflect.setProperty(spr, varName, value);
			}
		}

		var antialiasing:Dynamic = Reflect.field(data, 'antialiasing');
		if(antialiasing != null)
		{
			if(Std.isOfType(spr, objects.Character) && antialiasing == true)
			{
				var character:objects.Character = cast spr;
				character.antialiasing = ClientPrefs.data.antialiasing && !character.noAntialiasing;
			}
			else
			{
				var newAntialiasing:Bool = antialiasing == true && ClientPrefs.data.antialiasing;
				var changed:Bool = spr.antialiasing != newAntialiasing;
				spr.antialiasing = newAntialiasing;
				if(changed && Std.isOfType(spr, FlxSpriteGroup))
				{
					var spriteGroup:FlxSpriteGroup = cast spr;
					for(member in spriteGroup.members)
						if(member != null)
							member.antialiasing = spr.antialiasing;
				}
			}
		}
	}

	static function updateBasicObjectHitbox(spr:FlxSprite):Void
	{
		if(Std.isOfType(spr, FlxSpriteGroup))
		{
			var spriteGroup:FlxSpriteGroup = cast spr;
			for(member in spriteGroup.members)
				if(member != null)
				{
					if(Std.isOfType(member, objects.Character))
						cast(member, objects.Character).updateCharacterHitbox();
					else
						member.updateHitbox();
				}
		}
		else if(Std.isOfType(spr, objects.Character))
			cast(spr, objects.Character).updateCharacterHitbox();
		else
			spr.updateHitbox();
	}

	public static function addObjectsToState(objectList:Array<Dynamic>, gf:FlxSprite, dad:FlxSprite, boyfriend:FlxSprite, ?group:Dynamic = null, ?ignoreFilters:Bool = false)
	{
		var addedObjects:Map<String, FlxSprite> = [];
		for (num => data in objectList)
		{
			if (addedObjects.exists(data)) continue;

			switch(data.type)
			{
				case 'gf', 'gfGroup':
					if(gf != null)
					{
						gf.ID = num; 
						applyBasicObjectData(data, gf);
						if (group != null) group.add(gf);
						addedObjects.set('gf', gf);
					}
				case 'dad', 'dadGroup':
					if(dad != null)
					{
						dad.ID = num;
						applyBasicObjectData(data, dad);
						if (group != null) group.add(dad);
						addedObjects.set('dad', dad);
					}
				case 'boyfriend', 'boyfriendGroup':
					if(boyfriend != null)
					{
						boyfriend.ID = num;
						applyBasicObjectData(data, boyfriend);
						if (group != null) group.add(boyfriend);
						addedObjects.set('boyfriend', boyfriend);
					}

				case 'square', 'sprite', 'animatedSprite':
					if(!ignoreFilters && !validateVisibility(data.filters)) continue;

					var spr:ModchartSprite = new ModchartSprite(data.x, data.y);
					spr.ID = num;
					if(data.type != 'square')
					{
						if(data.type == 'sprite')
							spr.loadGraphic(Paths.image(data.image));
						else
							spr.frames = Paths.getAtlas(data.image);
						
						if(data.type == 'animatedSprite' && data.animations != null)
						{
							var anims:Array<objects.Character.AnimArray> = cast data.animations;
							for (key => anim in anims)
							{
								if(anim.indices == null || anim.indices.length < 1)
									spr.animation.addByPrefix(anim.anim, anim.name, anim.fps, anim.loop);
								else
									spr.animation.addByIndices(anim.anim, anim.name, anim.indices, '', anim.fps, anim.loop);
	
								if(anim.offsets != null)
									spr.addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
	
								if(spr.animation.curAnim == null || data.firstAnimation == anim.anim)
									spr.playAnim(anim.anim, true);
							}
						}
						for (varName in ['antialiasing', 'flipX', 'flipY'])
						{
							var dat:Dynamic = Reflect.getProperty(data, varName);
							if(dat != null) Reflect.setProperty(spr, varName, dat);
						}
						if(!ClientPrefs.data.antialiasing) spr.antialiasing = false;
					}
					else
					{
						spr.makeGraphic(1, 1, FlxColor.WHITE);
						spr.antialiasing = false;
					}

					if(data.scale != null && (data.scale[0] != 1.0 || data.scale[1] != 1.0))
					{
						spr.scale.set(data.scale[0], data.scale[1]);
						spr.updateHitbox();
					}
					spr.scrollFactor.set(data.scroll[0], data.scroll[1]);
					spr.color = CoolUtil.colorFromString(data.color);
					
					for (varName in ['alpha', 'angle'])
					{
						var dat:Dynamic = Reflect.getProperty(data, varName);
						if(dat != null) Reflect.setProperty(spr, varName, dat);
					}

					if (group != null) group.add(spr);
					addedObjects.set(data.name, spr);

				default:
					var err = '[Stage .JSON file] Unknown sprite type detected: ${data.type}';
					trace(err);
					FlxG.log.error(err);
			}
		}
		return addedObjects;
	}

	public static function validateVisibility(filters:LoadFilters)
	{
		if((filters & STORY_MODE) == STORY_MODE)
			if(!PlayState.isStoryMode) return false;
		else if((filters & FREEPLAY) == FREEPLAY)
			if(PlayState.isStoryMode) return false;

		return ((ClientPrefs.data.lowQuality && (filters & LOW_QUALITY) == LOW_QUALITY) ||
			(!ClientPrefs.data.lowQuality && (filters & HIGH_QUALITY) == HIGH_QUALITY));
	}
}
