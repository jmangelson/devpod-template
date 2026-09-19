#!/bin/bash
# start-display.sh
# Starts Xvfb / x11vnc / noVNC / Fluxbox for the in-container browser GUI.
#
# This is the only thing postCreateCommand runs. Everything else is baked
# into the Docker image. Adding a mount or recreating the container only
# reruns this script — it completes in a few seconds.

set -e

DISPLAY_NUM=":99"
export DISPLAY="$DISPLAY_NUM"

echo "Starting virtual display..."

if ! pgrep -f "Xvfb $DISPLAY_NUM" >/dev/null 2>&1; then
    Xvfb "$DISPLAY_NUM" -screen 0 1280x1024x24 -ac >/tmp/devpod-xvfb.log 2>&1 &
fi

display_ready=0
for _ in $(seq 1 15); do
    if xdpyinfo -display "$DISPLAY_NUM" >/dev/null 2>&1; then
        display_ready=1
        break
    fi
    sleep 1
done

if [ "$display_ready" -ne 1 ]; then
    echo "ERROR: Xvfb failed to start. Check /tmp/devpod-xvfb.log"
    exit 1
fi

if ! pgrep -f "x11vnc .*${DISPLAY_NUM}" >/dev/null 2>&1; then
    x11vnc -display "$DISPLAY_NUM" -localhost -nopw -forever -shared -bg \
        >/tmp/devpod-x11vnc.log 2>&1
fi

if ! pgrep -f "websockify .*6080" >/dev/null 2>&1; then
    websockify --web=/usr/share/novnc 0.0.0.0:6080 localhost:5900 \
        >/tmp/devpod-websockify.log 2>&1 &
fi

if ! pgrep -f "fluxbox" >/dev/null 2>&1; then
    DISPLAY="$DISPLAY_NUM" fluxbox >/tmp/devpod-fluxbox.log 2>&1 &
fi

echo "Display ready — noVNC available on port 6080"
