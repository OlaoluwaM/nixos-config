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

stable="$HYPR_WALLPAPER_PATH"
stable_dir="$(dirname -- "$stable")"

# Convert into a temporary file in the same directory as the stable path,
# then rename over it. Rename is atomic on the same filesystem, so hyprlock
# never observes a partially written file. Converting instead of copying also
# means the stable path's .png extension always matches the pixel format.
tmp="$(mktemp "$stable_dir/.wallpaper-set.XXXXXX.png")"
trap 'rm -f "$tmp"' EXIT

# A source that already holds PNG pixels has the guaranteed format the comment
# above relies on, so skip magick's full re-encode (a needless pass over a 4K
# image on every single pick) and just copy the bytes. Decided by content, not
# by name: a few wallpapers named .png carry JPEG bytes, and copying those by
# extension put JPEG data at a path that promises PNG. Anything else goes
# through magick to make the promise true.
if [ "$(magick identify -format '%m' "${src}[0]" 2>/dev/null)" = "PNG" ]; then
	cp -- "$src" "$tmp"
else
	magick "$src" "$tmp"
fi

mv -f "$tmp" "$stable"
trap - EXIT

# The retint runs last, after the stable path is already in sync with awww.
# This script runs under `set -e`, so an ordering the other way around lets
# a matugen failure (e.g. a template input missing from the shell package)
# strand hyprlock on a stale image after the live desktop already swapped --
# the lock screen must not depend on the theming pipeline being healthy.
matugen image "$src" --source-color-index 0 -q
