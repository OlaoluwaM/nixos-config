# shellcheck shell=bash

# Usage: wallpaper-set <image-path>
#
# Updates, in order: the live desktop background (awww), the shell's
# matugen-derived theme, and the stable path hyprlock reads.

if [ "$#" -ne 1 ]; then
	echo "usage: wallpaper-set <image-path>" >&2
	exit 1
fi

src="$1"

if [ ! -f "$src" ] || [ ! -r "$src" ]; then
	echo "wallpaper-set: not a readable file: $src" >&2
	exit 1
fi

awww img "$src" --transition-type grow --transition-duration 2 --transition-fps 60
matugen image "$src" --source-color-index 0 -q

stable="$HYPR_WALLPAPER_PATH"
stable_dir="$(dirname -- "$stable")"

# Convert into a temporary file in the same directory as the stable path,
# then rename over it. Rename is atomic on the same filesystem, so hyprlock
# never observes a partially written file. Converting instead of copying also
# means the stable path's .png extension always matches the pixel format.
tmp="$(mktemp "$stable_dir/.wallpaper-set.XXXXXX.png")"
trap 'rm -f "$tmp"' EXIT
magick "$src" "$tmp"
mv -f "$tmp" "$stable"
trap - EXIT
