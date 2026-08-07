#!/bin/sh

cliphist list | rofi -dmenu -config "~/.config/rofi/clip.rasi" -p " " -display-columns 2 | cliphist decode | wl-copy
