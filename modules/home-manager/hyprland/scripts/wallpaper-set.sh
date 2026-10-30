# shellcheck shell=bash

# Usage: wallpaper-set <image-path>
#
# Updates, in order: the live desktop background (awww), the stable path
# hyprlock reads, the shell's matugen-derived theme, and the wallpaper sample
# the shell's adaptive glass follows.

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

# One region of the fitted frame as a JSON object: mean luminance, standard
# deviation (how busy it is) and its one-pixel tone. Every magick call is
# checked by hand because `set -e` is off inside a function called under `||`.
sample_region() {
	local fit="$1" gravity="$2" crop="$3"
	local stats tone
	stats="$(magick "$fit" -gravity "$gravity" -crop "$crop" +repage -colorspace Gray \
		-format '%[fx:mean] %[fx:standard_deviation]' info:)" || return 1
	tone="$(magick "$fit" -gravity "$gravity" -crop "$crop" +repage -scale '1x1!' \
		-format '%[hex:u.p{0,0}]' info:)" || return 1
	case "$stats $tone" in
	[0-9.]*\ [0-9.]*\ [0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]) ;;
	*) return 1 ;;
	esac
	printf '{"luminance":%s,"noise":%s,"tone":"#%s"}' "${stats% *}" "${stats#* }" "$tone"
}

# A region that also records its brightest tenth. A pane spanning a bright sky
# and a dark field has a middling mean, yet its text is only as legible as the
# brightest part it covers. The 32x32 cells stand in for the compositor's blur,
# so one bright pixel cannot count as a bright area.
sample_peak_region() {
	local fit="$1" gravity="$2" crop="$3"
	local region peak
	region="$(sample_region "$fit" "$gravity" "$crop")" || return 1
	peak="$(magick "$fit" -gravity "$gravity" -crop "$crop" +repage +gravity -colorspace Gray \
		-scale '32x32!' -crop 32x1 +repage +append -sort-pixels \
		-format '%[fx:p{921,0}.intensity]' info:)" || return 1
	case "$peak" in
	[0-9.]*) ;;
	*) return 1 ;;
	esac
	printf '%s,"peak":%s}' "${region%\}}" "$peak"
}

# The shell's adaptive glass (fork ADRs 0004 and 0005) follows a sample of the
# wallpaper: the strip under a top bar, the strip under a bottom bar, the whole
# picture, and the corner the menu opens into under either bar, measured on the
# image cover-fitted to the focused monitor the way awww shows it. The sample
# goes to the shell's own config directory, beside the settings it already
# watches, through the same tmp-and-rename the stable path uses so the shell
# never reads a half-written file.
sample_glass() {
	local image="$1"
	local out_dir="${XDG_CONFIG_HOME:-$HOME/.config}/silere-shell"
	local size scale width height menu_w menu_h fit top bottom field menu_top menu_bottom tmp_json
	# The focused monitor's mode and scale. A compositor that is not answering
	# falls back to the panel this profile ships on, which only skews the crops.
	size="$(hyprctl monitors -j 2>/dev/null \
		| jq -r 'first(.[] | select(.focused)) | "\(.width)x\(.height)@\(.scale)"' 2>/dev/null)" || size=""
	case "$size" in
	[1-9]*x[1-9]*@[0-9]*) ;;
	*) size="2560x1600@1.6" ;;
	esac
	scale="${size#*@}"
	size="${size%@*}"
	width="${size%x*}"
	height="${size#*x}"
	# The menu opens under the workspaces widget, which leads this profile's
	# left bar zone, so it hugs the left edge: its compact width (400 logical
	# px) by its height cap (72% of the screen). Both are the fork's
	# MenuWindow constants; a moved launcher or a retuned panel moves them.
	menu_w="$(jq -n --argjson s "$scale" --argjson w "$width" '[400 * $s, $w] | min | floor')" || return 1
	menu_h="$(jq -n --argjson h "$height" '$h * 0.72 | floor')" || return 1
	fit="$(mktemp "${TMPDIR:-/tmp}/wallpaper-set.XXXXXX.miff")" || return 1
	# The source, not the stable PNG: magick reads by content, so a mislabelled
	# file samples fine, and the first frame covers animated formats.
	if ! magick "${image}[0]" -alpha off -resize "${width}x${height}^" -gravity Center \
		-extent "${width}x${height}" +repage "$fit"; then
		rm -f "$fit"
		return 1
	fi
	top="$(sample_region "$fit" North "${width}x64+0+0")" || { rm -f "$fit"; return 1; }
	bottom="$(sample_region "$fit" South "${width}x64+0+0")" || { rm -f "$fit"; return 1; }
	field="$(sample_region "$fit" NorthWest "${width}x${height}+0+0")" || { rm -f "$fit"; return 1; }
	menu_top="$(sample_peak_region "$fit" NorthWest "${menu_w}x${menu_h}+0+0")" || { rm -f "$fit"; return 1; }
	menu_bottom="$(sample_peak_region "$fit" SouthWest "${menu_w}x${menu_h}+0+0")" || { rm -f "$fit"; return 1; }
	rm -f "$fit"
	mkdir -p "$out_dir" || return 1
	tmp_json="$(mktemp "$out_dir/.glass.XXXXXX.json")" || return 1
	if ! printf '{"version":1,"source":%s,"top":%s,"bottom":%s,"field":%s,"menuTop":%s,"menuBottom":%s}\n' \
		"$(jq -Rn --arg s "$image" '$s')" "$top" "$bottom" "$field" "$menu_top" "$menu_bottom" > "$tmp_json"; then
		rm -f "$tmp_json"
		return 1
	fi
	mv -f "$tmp_json" "$out_dir/glass.json"
}

# Last, and never fatal: the retint above is what the lock screen and the
# palette depend on, so a sampling failure must not abort it. The shell keeps
# its previous sample, the same failure mode a stale palette already has.
sample_glass "$src" || echo "wallpaper-set: glass sample failed; the shell keeps its last sample" >&2
