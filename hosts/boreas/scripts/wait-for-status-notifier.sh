# shellcheck shell=bash

set -eu

attempt=0
max_attempts=150

until busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1; do
  attempt=$((attempt + 1))

  if [ "$attempt" -ge "$max_attempts" ]; then
    echo "Timed out waiting for the desktop tray service" >&2
    exit 1
  fi

  sleep 0.2
done
