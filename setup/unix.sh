#!/bin/bash

# Configuração de cores DENOVO
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # não fale comigo nesse tom... de pel-

clear

echo -e "${GREEN}==========================================================${NC}"
echo ""
echo -e "${CYAN}      INSTALLING HAXE DEPENDENCIES (LINUX & MACOS)${NC}"
echo -e "      This might take a few moments depending on your"
echo -e "                     internet speed."
echo ""
echo -e "${YELLOW}      REMINDER: You need Haxe installed prior to${NC}"
echo -e "${YELLOW}      using this script. (https://haxe.org/download)${NC}"
echo ""
echo -e "${GREEN}==========================================================${NC}"
echo ""

cd ..

echo -e "${CYAN}[1/4] Setting up Haxelib directory...${NC}"
echo "----------------------------------------------------------"
# Usando mkdir -p para não dar erro se a pasta já existir... NÉ?-
mkdir -p ~/haxelib && haxelib setup ~/haxelib

echo ""
echo -e "${CYAN}[2/4] Installing standard libraries...${NC}"
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
echo -e "${CYAN}[3/4] Installing specific version libraries...${NC}"
echo "----------------------------------------------------------"
haxelib install hxvlc --skip-dependencies
haxelib install away3d 5.0.9
haxelib install yagp 1.1.4
haxelib install flxgif 1.0.3 --skip-dependencies

echo ""
echo -e "${CYAN}[4/4] Installing Git repositories...${NC}"
echo "----------------------------------------------------------"
haxelib git flxsoundfilters https://github.com/TheZoroForce240/FlxSoundFilters
haxelib git hscript-iris https://github.com/pisayesiwsi/hscript-iris.git dev
haxelib git linc_luajit https://github.com/superpowers04/linc_luajit.git
haxelib git funkin.vis https://github.com/FunkinCrew/funkVis.git 1966f8fbbbc509ed90d4b520f3c49c084fc92fd6
haxelib git grig.audio https://gitlab.com/haxe-grig/grig.audio.git

echo ""
echo -e "${GREEN}==========================================================${NC}"
echo ""
echo -e "${CYAN}                   SETUP FINISHED!${NC}"
echo ""
echo -e "${GREEN}==========================================================${NC}"
