#!/bin/bash

# Configuração de cores pq amo
GREEN='\033[1;32m'
CYAN='\033[1;36m'
NC='\033[0m' # Sem cor ksksksksks

clear

echo -e "${GREEN}==========================================================${NC}"
echo ""
echo -e "${CYAN}         INSTALLING HAXE DEPENDENCIES (MOBILE)${NC}"
echo -e "      This might take a few moments depending on your"
echo -e "                     internet speed."
echo ""
echo -e "${GREEN}==========================================================${NC}"
echo ""

echo -e "${CYAN}[1/3] Installing standard libraries...${NC}"
echo "----------------------------------------------------------"
haxelib install lime
haxelib install openfl
haxelib install flixel
haxelib install flixel-addons
haxelib install flixel-tools
haxelib install tjson
haxelib install flixel-animate
haxelib install hxdiscord_rpc
haxelib install funkin-modchart
haxelib install moonchart
haxelib install nape-haxe4

echo ""
echo -e "${CYAN}[2/3] Installing specific version & mobile libraries...${NC}"
echo "----------------------------------------------------------"
haxelib install hxvlc --skip-dependencies
haxelib install away3d 5.0.9
haxelib install yagp 1.1.4
haxelib install flxgif 1.0.3 --skip-dependencies
haxelib install extension-haptics 1.0.4 --skip-dependencies
haxelib install android-manager 1.0.1 --skip-dependencies

echo ""
echo -e "${CYAN}[3/3] Installing Git repositories (Mobile specifics)...${NC}"
echo "----------------------------------------------------------"
haxelib git flxsoundfilters https://github.com/TheZoroForce240/FlxSoundFilters
haxelib git hxcpp https://github.com/xdshiho/hxcpp.git
haxelib git hscript-iris https://github.com/pisayesiwsi/hscript-iris.git dev
haxelib git linc_luajit https://github.com/xdshiho/linc_luajit-mobile
haxelib git funkin.vis https://github.com/FunkinCrew/funkVis.git 1966f8fbbbc509ed90d4b520f3c49c084fc92fd6
haxelib git grig.audio https://gitlab.com/haxe-grig/grig.audio.git

echo ""
echo -e "${GREEN}==========================================================${NC}"
echo ""
echo -e "${CYAN}                   SETUP FINISHED!${NC}"
echo ""
echo -e "${GREEN}==========================================================${NC}"