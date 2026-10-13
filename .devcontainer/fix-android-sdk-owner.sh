#!/bin/bash
# fix-android-sdk-owner.sh
# Makes the Android SDK writable by the remote user.
#
# The Dockerfile chowns the SDK to USER_UID at build time, but DevPod /
# devcontainers remap the remote user's UID to match the host user when the
# container is created (updateRemoteUserUID). That remap re-owns only the home
# directory, so the SDK can end up owned by a stale UID. Gradle then fails to
# auto-install packages a project needs (for example the NDK or CMake for
# React Native) with "The SDK directory is not writable".
#
# Runs from postCreateCommand. No-ops when Android is disabled or the SDK is
# already owned by the current user.

set -e

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"

if [ -z "$SDK_ROOT" ] || [ ! -d "$SDK_ROOT" ]; then
    echo "Android SDK not installed -- skipping SDK ownership fix."
    exit 0
fi

if [ "$(stat -c %u "$SDK_ROOT")" = "$(id -u)" ]; then
    echo "Android SDK already owned by $(id -un)."
    exit 0
fi

echo "Re-owning $SDK_ROOT to $(id -un) (UID changed after image build)..."
sudo chown -R "$(id -u):$(id -g)" "$SDK_ROOT"
