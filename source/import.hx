#if !macro

import haxe.Exception;

//Discord API
#if DISCORD_ALLOWED
import backend.Discord;
#end

//Psych
#if LUA_ALLOWED
import llua.*;
import llua.Lua;
#end

#if ACHIEVEMENTS_ALLOWED
import backend.Achievements;
#end

import mobile.backend.TouchUtil;
#if mobile
import mobile.backend.StorageSystem;
import mobile.backend.utils.PopUp;
// Não por agora
#end

#if sys
import sys.*;
import sys.io.*;
#elseif js
import js.html.*;
import backend.JSFileSystem as FileSystem;
#end

import backend.ArrayTools;
import backend.MathUtil;
import backend.Constants;
import backend.AtlasUtil;
import backend.Paths;
import backend.Controls;
import backend.CoolUtil;
import backend.ScriptedState;
import backend.ScriptedSubState;
import backend.MusicBeatState;
import backend.MusicBeatSubstate;
import backend.CustomFadeTransition;
import backend.ClientPrefs;
import backend.Conductor;
import backend.BaseStage;
import backend.Difficulty;
import backend.EditorSFX;
import backend.Mods;
import backend.Language;

import backend.ui.*; //Psych-UI

import debug.Log;

import objects.Alphabet;
import objects.BGSprite;
import objects.PerspectiveSprite;

import states.PlayState;
import states.LoadingState;

import animate.*;

//Flixel
import flixel.sound.FlxSound;
import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.util.FlxDestroyUtil;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import backend.ViroText as FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.text.FlxText.FlxTextFormat;
import flixel.text.FlxText.FlxTextFormatMarkerPair;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.addons.transition.FlxTransitionableState;

using StringTools;
#end
