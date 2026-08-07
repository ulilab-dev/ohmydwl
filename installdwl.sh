#!/bin/sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

sudo cp stuff/ohmydwl /bin/ohmydwl 

sleep 1
mkdir -p ~/.config/Builds/dwl/ 
mkdir -p ~/.config/Builds/patch/ 

git clone https://codeberg.org/dwl/dwl.git ~/.config/Builds/dwl/ 

wget -P ~/.config/Builds/patch https://raw.githubusercontent.com/ulilab-dev/dwindle_dwl/refs/heads/main/dwindle.patch

wget -P ~/.config/Builds/patch https://codeberg.org/dwl/dwl-patches/raw/branch/main/stale-patches/ipc/ipc.patch

wget -P ~/.config/Builds/patch https://codeberg.org/dwl/dwl-patches/raw/branch/main/patches/vanitygaps/vanitygaps-0.8.patch

wget -P ~/.config/Builds/patch https://codeberg.org/dwl/dwl-patches/raw/branch/main/patches/autostart/autostart-0.8.patch

wget -P ~/.config/Builds/patch https://codeberg.org/dwl/dwl-patches/raw/branch/main/patches/alwayscenter/alwayscenter.patch

wget -P ~/.config/Builds/patch https://codeberg.org/dwl/dwl-patches/raw/branch/main/patches/swapandfocusdir/swapandfocusdir.patch

sleep 2
mv ~/.config/Builds/patch ~/.config/Builds/dwl/ 

sleep 0.5
cd ~/.config/Builds/dwl || exit 1

patch -i ~/.config/Builds/dwl/patch/alwayscenter.patch
patch -i ~/.config/Builds/dwl/patch/autostart-0.8.patch
patch -i ~/.config/Builds/dwl/patch/vanitygaps-0.8.patch
patch -i ~/.config/Builds/dwl/patch/swapandfocusdir.patch
patch -i ~/.config/Builds/dwl/patch/ipc.patch
patch -i ~/.config/Builds/dwl/patch/dwindle.patch

sleep 1 
mv dwl-ipc-unstable-v2.xml protocols/

sleep 1 
cp $SCRIPT_DIR/stuff/autostart.sh ~/.config/Builds/dwl/
cp $SCRIPT_DIR/stuff/dwl.desktop ~/.config/Builds/dwl/
cp $SCRIPT_DIR/stuff/config.def.h ~/.config/Builds/dwl/

sleep 1
cp -r config/* ~/.config/
