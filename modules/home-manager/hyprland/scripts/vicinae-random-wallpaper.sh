# shellcheck shell=bash

# @vicinae.schemaVersion 1
# @vicinae.title Random Wallpaper
# @vicinae.mode silent
# @vicinae.packageName Silere Shell
# @vicinae.icon 🎲
# @vicinae.description Picks a random image from $WALLPAPERS_DIR and sets it via wallpaper-set.

# Beginner orientation:
#
# This is a Vicinae script command (see docs.vicinae.com/scripts), scanned
# from ~/.local/share/vicinae/scripts by Vicinae itself -- it is never
# launched through Hyprland or systemd. wallpaper.nix installs it there via
# xdg.dataFile. Its installed filename ("random-wallpaper") is also its
# stable id, which is what keybindings.nix's Super+SHIFT+W deeplink targets
# (vicinae://launch/scripts/random-wallpaper): renaming this script command
# would silently break that bind.

dir="${WALLPAPERS_DIR:-$HOME/Pictures/wallpapers}"

pick="$(find "$dir" -maxdepth 1 -type f \
	\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.avif' -o -iname '*.bmp' \) \
	2>/dev/null | shuf -n1)"

if [ -z "$pick" ]; then
	echo "no wallpaper images found in $dir" >&2
	exit 1
fi

wallpaper-set "$pick"
echo "Set wallpaper to $(basename -- "$pick")"
