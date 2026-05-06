package backend;


import openfl.display.BitmapData;
import openfl.utils.Assets;

import backend.StageData;

typedef CharacterSpecificFile = 
{
    var enabled:Null<Bool>;
    var angle:Null<Float>;
    var altMaskImage:Null<String>;
    var useAltMask:Null<Bool>;
    var maskThreshold:Null<Float>;
}
typedef DropShadowFile = 
{
    var enabled:Null<Bool>;
    var color:Null<String>;
    var distance:Null<Float>;
    var strength:Null<Float>;
    var threshold:Null<Float>;
    var useAltMask:Null<Bool>;
    var antialiasAmt:Null<Float>;
    var altMaskImage:Null<String>;
    var maskThreshold:Null<Float>;
    var hue:Null<Float>;
    var saturation:Null<Float>;
    var brightness:Null<Float>;
    var contrast:Null<Float>;
    var girlfriend:CharacterSpecificFile;
    var boyfriend:CharacterSpecificFile;
    var dad:CharacterSpecificFile;
}
typedef CharacterSpecificData = 
{
    var enabled:Null<Bool>;
    var angle:Null<Float>;
    var altMaskImage:Null<BitmapData>;
    var useAltMask:Null<Bool>;
    var maskThreshold:Null<Float>;

}
class DropShadowData 
{
    public var enabled:Bool = false;
    public var color:FlxColor = 0xFFFFFFFF;
    public var distance:Float = 0;
    public var strength:Float = 0;
    public var threshold:Float = 0;
    public var useAltMask:Bool = false;
    public var antialiasAmt:Float = 2;
    public var hue:Float = 0;
    public var saturation:Float = 0;
    public var brightness:Float = 0;
    public var contrast:Float = 0;

    public var girlfriend:CharacterSpecificData = 
    {
        enabled: false,
        angle: 0,
        altMaskImage: null,
        useAltMask: false,
        maskThreshold: 0
    };
    public var boyfriend:CharacterSpecificData = 
    {
        enabled: false,
        angle: 0,
        altMaskImage: null,
        useAltMask: false,
        maskThreshold: 0
    };
    public var dad:CharacterSpecificData = 
    {
        enabled: false,
        angle: 0,
        altMaskImage: null,
        useAltMask: false,
        maskThreshold: 0
    };

    var defaultDropShadow:DropShadowFile =
    {
        enabled: false,
        color: 'FFFFFF',
        distance: 0,
        strength: 0,
        threshold: 0,
        useAltMask: false,
        antialiasAmt: 2,
        altMaskImage: null,
        maskThreshold: 0,
        hue: 0,
        saturation: 0,
        brightness: 0,
        contrast: 0,
        boyfriend: 
        {
            enabled: false,
            angle: 0,
            altMaskImage: '',
            useAltMask: false,
            maskThreshold: 0
        },
        girlfriend: 
        {
            enabled: false,
            angle: 0,
            altMaskImage: '',
            useAltMask: false,
            maskThreshold: 0
        },
        dad: 
        {
            enabled: false,
            angle: 0,
            altMaskImage: '',
            useAltMask: false,
            maskThreshold: 0
        },
    };
	public function new()
    {
        if(PlayState.SONG != null)
        {
            if(PlayState.SONG.stage != null)
            {
                var stageData = StageData.getStageFile(PlayState.curStage);
                var dataToUse:DropShadowFile = stageData.dropshadow;
                if(dataToUse == null)
                    dataToUse = defaultDropShadow;
                var data:DropShadowFile = fixNullValues(dataToUse);
                
                enabled = data.enabled;
                color = FlxColor.fromString('#' + data.color);
                distance = data.distance;
                strength = data.strength;
                threshold = data.threshold;
                antialiasAmt = data.antialiasAmt;
                hue = data.hue;
                saturation = data.saturation;
                brightness = data.brightness;
                contrast = data.contrast;
                girlfriend = 
                {
                    enabled: data.girlfriend.enabled,
                    angle: data.girlfriend.angle,
                    useAltMask: data.girlfriend.useAltMask,
                    altMaskImage: useAltMask ? BitmapData.fromFile(Paths.getPath('images/' + data.girlfriend.altMaskImage, IMAGE)) : null,
                    maskThreshold: data.girlfriend.maskThreshold
                };
                dad = 
                {
                    enabled: data.dad.enabled,
                    angle: data.dad.angle,
                    useAltMask: data.dad.useAltMask,
                    altMaskImage: useAltMask ? BitmapData.fromFile(Paths.getPath('images/' + data.dad.altMaskImage, IMAGE)) : null,
                    maskThreshold: data.dad.maskThreshold
                };
                boyfriend = 
                {
                    enabled: data.boyfriend.enabled,
                    angle: data.boyfriend.angle,
                    useAltMask: data.boyfriend.useAltMask,
                    altMaskImage: useAltMask ? BitmapData.fromFile(Paths.getPath('images/' + data.boyfriend.altMaskImage, IMAGE)) : null,
                    maskThreshold: data.boyfriend.maskThreshold
                };
            }
        } 
    }

    function fixNullValues(data:DropShadowFile):DropShadowFile
    {
        if(data.enabled == null)
            data.enabled = false;
        if(data.color == null)
            data.color = 'FFFFFF';
        if(data.distance == null)
            data.distance = 0;
        if(data.strength == null)
            data.strength = 0;
        if(data.threshold == null)
            data.threshold = 0;
        if(data.useAltMask == null)
            data.useAltMask = false;
        if(data.antialiasAmt == null)
            data.antialiasAmt = 2;
        if(data.maskThreshold == null)
            data.maskThreshold = 0;
        if(data.hue == null)
            data.hue = 0;
        if(data.saturation == null)
            data.saturation = 0;
        if(data.brightness == null)
            data.brightness = 0;
        if(data.contrast == null)
            data.contrast = 0;

        if(data.girlfriend == null)
        {
            data.girlfriend =
            {
                enabled: false,
                angle: 0,
                altMaskImage: '',
                useAltMask: false,
                maskThreshold: 0
            };
        }
        else
        {
            var characterData:CharacterSpecificFile = data.girlfriend;
            if(characterData.enabled == null)
                characterData.enabled = false;
            if(characterData.angle == null)
                characterData.angle = 0;
            if(characterData.altMaskImage != null)
                characterData.altMaskImage = '';
            if(characterData.useAltMask == null)
                characterData.useAltMask = false;
            if(characterData.maskThreshold == null)
                characterData.maskThreshold = 0;
            data.girlfriend = characterData;
        }

        if(data.boyfriend == null)
        {
            data.boyfriend =
            {
                enabled: false,
                angle: 0,
                altMaskImage: '',
                useAltMask: false,
                maskThreshold: 0
            };
        }
        else
        {
            var characterData:CharacterSpecificFile = data.boyfriend;
            if(characterData.enabled == null)
                characterData.enabled = false;
            if(characterData.angle == null)
                characterData.angle = 0;
            if(characterData.altMaskImage != null)
                characterData.altMaskImage = '';
            if(characterData.useAltMask == null)
                characterData.useAltMask = false;
            if(characterData.maskThreshold == null)
                characterData.maskThreshold = 0;
            data.boyfriend = characterData;
            
        }

        if(data.dad == null)
        {
            data.dad =
            {
                enabled: false,
                angle: 0,
                altMaskImage: '',
                useAltMask: false,
                maskThreshold: 0
            };
        }
        else
        {
            var characterData:CharacterSpecificFile = data.dad;
            if(characterData.enabled == null)
                characterData.enabled = false;
            if(characterData.angle == null)
                characterData.angle = 0;
            if(characterData.altMaskImage != null)
                characterData.altMaskImage = '';
            if(characterData.useAltMask == null)
                characterData.useAltMask = false;
            if(characterData.maskThreshold == null)
                characterData.maskThreshold = 0;
            data.dad = characterData;
        }

        return data;
    }
}