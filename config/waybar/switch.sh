#!/bin/bash

WAYBAR_DIR="$HOME/.config/waybar"
THEMES_DIR="$WAYBAR_DIR/themes"

if ! command -v rofi >/dev/null 2>&1; then
  notify-send "Error!! where is rofi??"
  exit 1
fi

CHOSEN_THEME=$(ls "$THEMES_DIR" | rofi -dmenu -config "~/.config/rofi/themes.rasi" -p "select")

if [ -z "$CHOSEN_THEME" ]; then
  exit 0
fi

SELECTED_THEME_DIR="$THEMES_DIR/$CHOSEN_THEME"

if [ -f "$SELECTED_THEME_DIR/config.jsonc" ] && [ -f "$SELECTED_THEME_DIR/style.css" ]; then
  cp "$SELECTED_THEME_DIR/config.jsonc" "$WAYBAR_DIR/config.jsonc"
  cp "$SELECTED_THEME_DIR/style.css" "$WAYBAR_DIR/style.css"

  killall waybar

  while pgrep -x waybar >/dev/null; do sleep 0.1; done

  waybar >/dev/null 2>&1 &
fi