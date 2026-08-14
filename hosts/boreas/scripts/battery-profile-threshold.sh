# shellcheck shell=bash

set -eu

battery_dir=
for candidate in /sys/class/power_supply/BAT*; do
  if [ -f "$candidate/capacity" ] && [ -f "$candidate/status" ]; then
    battery_dir="$candidate"
    break
  fi
done

if [ -z "$battery_dir" ]; then
  systemd-cat -t battery-profile-threshold -p warning echo "No battery found; skipping profile update"
  exit 0
fi

capacity="$(cat "$battery_dir/capacity")"
status="$(cat "$battery_dir/status")"

choices="$(cat /sys/firmware/acpi/platform_profile_choices 2>/dev/null || true)"

has_choice() {
  case " $choices " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

case "$status" in
  Charging | Full | Not\ charging)
    requested=performance
    ;;
  Discharging)
    if [ "$capacity" -le 35 ]; then
      requested=low-power
    elif [ "$capacity" -le 65 ]; then
      requested=balanced
    else
      requested=performance
    fi
    ;;
  *)
    systemd-cat -t battery-profile-threshold -p warning echo "Unknown battery status '$status'; skipping profile update"
    exit 0
    ;;
esac

case "$requested" in
  performance)
    if has_choice performance; then
      target_cli=Performance
      target_sysfs=performance
    else
      systemd-cat -t battery-profile-threshold -p warning echo "Performance profile unavailable; falling back to Balanced"
      target_cli=Balanced
      target_sysfs=balanced
    fi
    ;;
  balanced)
    target_cli=Balanced
    target_sysfs=balanced
    ;;
  low-power)
    if has_choice quiet; then
      target_cli=Quiet
      target_sysfs=quiet
    elif has_choice low-power; then
      target_cli=LowPower
      target_sysfs=low-power
    else
      systemd-cat -t battery-profile-threshold -p warning echo "Quiet/LowPower profile unavailable; falling back to Balanced"
      target_cli=Balanced
      target_sysfs=balanced
    fi
    ;;
esac

current="$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || true)"
if [ "$requested" = low-power ] && { [ "$current" = quiet ] || [ "$current" = low-power ]; }; then
  systemd-cat -t battery-profile-threshold echo "ASUS platform profile already $current ($status, ${capacity}%)"
  exit 0
fi

if [ -n "$current" ] && [ "$current" = "$target_sysfs" ]; then
  systemd-cat -t battery-profile-threshold echo "ASUS platform profile already $target_cli ($status, ${capacity}%)"
  exit 0
fi

if asusctl profile set "$target_cli"; then
  systemd-cat -t battery-profile-threshold echo "Set ASUS platform profile to $target_cli ($status, ${capacity}%)"
  exit 0
fi

if [ "$target_cli" != Balanced ]; then
  systemd-cat -t battery-profile-threshold -p warning echo "Profile $target_cli failed; falling back to Balanced"
  if asusctl profile set Balanced; then
    systemd-cat -t battery-profile-threshold echo "Set ASUS platform profile to Balanced ($status, ${capacity}%)"
    exit 0
  fi
fi

systemd-cat -t battery-profile-threshold -p err echo "Could not set an ASUS platform profile ($status, ${capacity}%)"
exit 1
