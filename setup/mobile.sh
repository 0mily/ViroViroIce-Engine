#!/bin/bash
echo Installing dependencies...
echo This might take a few moments depending on your internet speed.
haxelib install lime
haxelib install openfl
haxelib install flixel
haxelib install flixel-addons
haxelib install flixel-tools
haxelib install tjson
haxelib install flixel-animate
haxelib install hxdiscord_rpc
haxelib install hxvlc --skip-dependencies
haxelib install funkin-modchart
haxelib install moonchart
haxelib install away3d 5.0.9
haxelib install yagp 1.1.4 --quiet 
haxelib install flxgif 1.0.3 --quiet --skip-dependencies 
haxelib git hscript-iris https://github.com/pisayesiwsi/hscript-iris.git dev
haxelib install extension-haptics 1.0.4 --quiet --skip-dependencies
haxelib install extension-androidtools 2.2.2 --quiet --skip-dependencies
haxelib git linc_luajit https://github.com/xdshiho/linc_luajit-mobile --quiet
echo Finished!
