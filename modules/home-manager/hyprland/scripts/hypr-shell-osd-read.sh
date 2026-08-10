# shellcheck shell=bash

# Reads the current display and keyboard backlight brightness as integer
# percents for the OSD, and prints them as "<display> <keyboard>".
#
# Either field is -1 when the device has no backlight (e.g. a VM or a desktop
# with no kbd backlight), so the QML layer can suppress the OSD instead of
# flashing a phantom 0% bar.

read_percent() {
	# brightnessctl -m prints: name,class,current,percent,max — field 4 is "NN%".
	# `|| true` keeps a missing device from aborting under set -e/pipefail; the
	# empty output then falls back to the -1 sentinel below.
	brightnessctl -m "$@" 2>/dev/null | awk -F, '{ print $4 }' | tr -d '%' || true
}

bri="$(read_percent)"
kbd="$(read_percent -d '*::kbd_backlight')"

printf '%s %s' "${bri:--1}" "${kbd:--1}"
