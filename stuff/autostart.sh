#!/bin/sh 

wlr-randr --output HDMI-A-1 --mode 1920x1080@100 >/dev/null 2>&1 &
waybar >/dev/null 2>&1 &
waypaper --restore >/dev/null 2>&1 &
dunst >/dev/null 2>&1 &
awww-daemon >/dev/null 2>&1 &

# Clipboard
wl-paste --type text --watch cliphist store >/dev/null 2>&1 &
wl-clip-persist --clipboard regular --reconnect-tries 0 >/dev/null 2>&1 &
