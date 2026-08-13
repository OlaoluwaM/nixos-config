# shellcheck shell=bash

# @vicinae.schemaVersion 1
# @vicinae.title Set Wallpaper
# @vicinae.mode silent
# @vicinae.packageName Silere Shell
# @vicinae.icon 🖼️
# @vicinae.argument1 { "type": "text", "placeholder": "filename in $WALLPAPERS_DIR, or an absolute path" }
# @vicinae.description Sets the wallpaper via wallpaper-set. A bare filename resolves against $WALLPAPERS_DIR.

# Beginner orientation:
#
# See vicinae-random-wallpaper.sh for how Vicinae discovers and runs script
# commands like this one. This one takes its target as a script-command
# argument (Vicinae passes it through as $1) instead of picking one itself.

target="$1"

case "$target" in
/*) path="$target" ;;
*) path="${WALLPAPERS_DIR:-$HOME/Pictures/wallpapers}/$target" ;;
esac

wallpaper-set "$path"
echo "Set wallpaper to $(basename -- "$path")"
