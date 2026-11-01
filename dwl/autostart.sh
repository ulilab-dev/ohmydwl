#!/bin/sh
exec >/dev/null 2>&1

wlr-randr --output HDMI-A-1 --mode 1920x1080@100

awww-daemon &
waybar &
dunst &

# Clipboard
wl-paste --type text --watch cliphist store &
wl-clip-persist --clipboard regular --reconnect-tries 0 &

# Wait (max ~2s) for the wallpaper daemon before restoring
for _ in 1 2 3 4 5 6 7 8 9 10; do
  awww query && break
  sleep 0.2
done
waypaper --restore &
