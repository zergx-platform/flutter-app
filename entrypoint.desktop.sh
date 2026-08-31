#!/bin/sh
set -e

export XDG_RUNTIME_DIR=/tmp/xdg
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

# Headless Wayland compositor (no GPU/input devices).
WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 labwc >/tmp/labwc.log 2>&1 &
LABWC_PID=$!

i=0
until ls "$XDG_RUNTIME_DIR" 2>/dev/null | grep -q '^wayland'; do
  i=$((i+1))
  if [ "$i" -gt 100 ]; then
    echo "wayland compositor failed to start" >&2
    cat /tmp/labwc.log >&2 || true
    exit 1
  fi
  sleep 0.2
done

# Expose the Wayland desktop over VNC (wayvnc) then VNC->websocket via noVNC.
wayvnc 0.0.0.0 5900 >/tmp/wayvnc.log 2>&1 &
WAYVNC_PID=$!

websockify --web /usr/share/novnc 6080 localhost:5900 >/tmp/websockify.log 2>&1 &
WS_PID=$!

cleanup() {
  kill $WS_PID $WAYVNC_PID $LABWC_PID 2>/dev/null || true
}
trap cleanup TERM INT

wait $WS_PID