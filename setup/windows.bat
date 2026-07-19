@echo off
title Setup - Haxe Dependencies
color 0A
cd ..
cls

echo ==========================================================
echo.
echo              INSTALLING HAXE DEPENDENCIES
echo      This might take a few moments depending on your
echo                     internet speed.
echo.
echo ==========================================================
echo.

echo [1/3] Installing standard libraries...
echo ----------------------------------------------------------
haxelib install lime
haxelib install openfl
haxelib install flixel
haxelib install flixel-addons
haxelib install flixel-tools
haxelib install tjson
haxelib install hxdiscord_rpc
haxelib install funkin-modchart
haxelib install flixel-animate
haxelib install moonchart
haxelib install nape-haxe4
haxelib install haxeui-core
haxelib install haxeui-flixel

echo.
echo [2/3] Installing specific version libraries...
echo ----------------------------------------------------------
haxelib install hxvlc --skip-dependencies
haxelib install away3d 5.0.9
haxelib install yagp 1.1.4
haxelib install flxgif 1.0.3 --skip-dependencies

echo.
echo [3/3] Installing Git repositories...
echo ----------------------------------------------------------
haxelib git flxsoundfilters https://github.com/TheZoroForce240/FlxSoundFilters
haxelib git hscript-iris https://github.com/pisayesiwsi/hscript-iris.git dev
haxelib git linc_luajit https://github.com/superpowers04/linc_luajit.git
haxelib git funkin.vis https://github.com/FunkinCrew/funkVis.git 1966f8fbbbc509ed90d4b520f3c49c084fc92fd6
haxelib git grig.audio https://gitlab.com/haxe-grig/grig.audio.git

echo.
echo ==========================================================
echo.
echo                 SETUP FINISHED!
echo             Press any key to exit...
echo.
echo ==========================================================
pause >nul
