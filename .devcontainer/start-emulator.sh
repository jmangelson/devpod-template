#!/bin/bash
# start-emulator.sh
# Creates the in-container Android emulator(s) if needed and cold-boots them.
#
# - Starts EMULATOR_COUNT emulators (default 1): devpod-api35, devpod-api35-2, …
#   A second emulator lets Maestro split flows across devices
#   (`npm run e2e:parallel`).
# - Skips any AVD that is already running (no duplicates).
# - Gives each AVD 4 GB of RAM. avdmanager's default (2 GB), booted from a
#   snapshot, repeatedly dropped its adb connection during Maestro runs.
# - Cold boots (-no-snapshot) so every session starts from a clean boot.
# - Sends netsimd's error log to /dev/null (see below).
#
# Usage: bash .devcontainer/start-emulator.sh
#        EMULATOR_COUNT=2 bash .devcontainer/start-emulator.sh
# Env overrides: EMULATOR_COUNT, AVD_NAME (base name), AVD_SYSTEM_IMAGE,
#                EMULATOR_RAM_MB

set -e

EMULATOR_COUNT="${EMULATOR_COUNT:-1}"
AVD_NAME="${AVD_NAME:-devpod-api35}"
AVD_SYSTEM_IMAGE="${AVD_SYSTEM_IMAGE:-system-images;android-35;google_apis;x86_64}"
EMULATOR_RAM_MB="${EMULATOR_RAM_MB:-4096}"

# The emulator's network simulator (netsimd) can loop on "Error in packet
# stream" after an emulator exits, writing ~70 MB/s to its stderr log; it once
# filled a 916 GB disk. Point that log at /dev/null so it can't.
netsim_dir="${TMPDIR:-/tmp}/android-$(id -un)/netsimd"
mkdir -p "$netsim_dir"
if [ ! -L "$netsim_dir/netsim_stderr.log" ]; then
    rm -f "$netsim_dir/netsim_stderr.log"
    ln -s /dev/null "$netsim_dir/netsim_stderr.log"
fi

running_avds() {
    for serial in $(adb devices | awk '/^emulator-/{print $1}'); do
        adb -s "$serial" emu avd name 2>/dev/null | head -1 | tr -d '\r'
    done
}

started=()
for i in $(seq 1 "$EMULATOR_COUNT"); do
    name="$AVD_NAME"
    [ "$i" -gt 1 ] && name="$AVD_NAME-$i"

    if running_avds | grep -qx "$name"; then
        echo "$name is already running."
        continue
    fi

    if ! avdmanager list avd -c 2>/dev/null | grep -qx "$name"; then
        echo "Creating AVD $name..."
        echo no | avdmanager create avd --force --name "$name" --package "$AVD_SYSTEM_IMAGE"
    fi

    config="$HOME/.android/avd/$name.avd/config.ini"
    sed -i '/^hw.ramSize=/d' "$config"
    echo "hw.ramSize=${EMULATOR_RAM_MB}M" >>"$config"

    log="/tmp/devpod-emulator.log"
    [ "$i" -gt 1 ] && log="/tmp/devpod-emulator-$i.log"
    echo "Booting $name (${EMULATOR_RAM_MB} MB RAM, cold boot); log: $log"
    # setsid detaches the emulator from this shell so it outlives the caller.
    setsid nohup emulator -avd "$name" -no-window -no-audio -no-boot-anim -no-snapshot \
        >"$log" 2>&1 </dev/null &
    started+=("$name")
done

# Wait until every emulator has finished booting.
if [ "${#started[@]}" -gt 0 ]; then
    until [ "$(adb devices | grep -c '^emulator-.*device$')" -ge "$EMULATOR_COUNT" ]; do
        sleep 2
    done
    for serial in $(adb devices | awk '/^emulator-.*device$/{print $1}'); do
        until [ "$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
            sleep 2
        done
    done
fi
adb devices
