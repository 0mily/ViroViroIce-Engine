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

// Mobile Controls
import mobile.input.MobileInputID;
import mobile.backend.SwipeUtil;
import mobile.backend.TouchUtil;
#if TOUCH_CONTROLS_ALLOWED
import mobile.objects.Hitbox;
import mobile.objects.TouchPad;
import mobile.objects.TouchButton;
import mobile.backend.MobileData;
import mobile.input.MobileInputManager;
import mobile.objects.TouchZone;
import mobile.objects.ScrollableObject;
#end
// Android
#if android
import extension.androidtools.content.Context as AndroidContext;
import extension.androidtools.widget.Toast as AndroidToast;
import extension.androidtools.os.Environment as AndroidEnvironment;
import extension.androidtools.Permissions as AndroidPermissions;
import extension.androidtools.Settings as AndroidSettings;
import extension.androidtools.Tools as AndroidTools;
import extension.androidtools.os.Build.VERSION as AndroidVersion;
import extension.androidtools.os.Build.VERSION_CODES as AndroidVersionCode;
#end

#if sys
import sys.*;
import sys.io.*;
#elseif js
import js.html.*;
import backend.JSFileSystem as FileSystem;
#end

import backend.NativeFileSystem as NativeFileSystem;
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

#if !js
import mobile.backend.StorageUtil;
#end

import backend.ui.*; //Psych-UI

import debug.Log;

import objects.Alphabet;
import objects.BGSprite;
import objects.PerspectiveSprite;
import shaders.SserafimShader;

import states.PlayState;
import states.LoadingState;

#if flxanimate
import animate.*;
import flxanimate.PsychFlxAnimate as FlxAnimate;
#end

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
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.addons.transition.FlxTransitionableState;

using StringTools;
#end
