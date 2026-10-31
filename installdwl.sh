#!/bin/sh

sudo cp stuff/ohmydwl /bin

mkdir -p ~/.config

sleep 0.5

cp -r dwl/ ~/.config
cp -r config/* ~/.config
