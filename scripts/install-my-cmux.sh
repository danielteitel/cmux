#!/usr/bin/env bash
# Build this fork and refresh the double-clickable copy in /Applications.
#
# The tagged build lives in DerivedData, which is not a stable home for an app
# you keep in the Dock. This installs it to a fixed path so the Dock tile keeps
# working across rebuilds, and so double-clicking always gets your latest code.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

TAG="${CMUX_FORK_TAG:-dan}"
BUILD=1
LAUNCH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) TAG="${2:-}"; shift 2 ;;
    --no-build) BUILD=0; shift ;;
    --launch) LAUNCH=1; shift ;;
    -h|--help)
      echo "usage: $0 [--tag <tag>] [--no-build] [--launch]"
      exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

if [[ ! "$TAG" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "error: tag must be alphanumeric/dash/underscore, got '$TAG'" >&2
  exit 1
fi

APP_NAME="cmux DEV ${TAG}"
INSTALLED="/Applications/${APP_NAME}.app"
BUILT="${HOME}/Library/Developer/Xcode/DerivedData/cmux-${TAG}/Build/Products/Debug/${APP_NAME}.app"

# Never let a bad tag point this at the real cmux install.
case "$INSTALLED" in
  "/Applications/cmux.app"|"/Applications/cmux DEV.app")
    echo "error: refusing to overwrite $INSTALLED" >&2
    exit 1 ;;
esac

if [[ "$BUILD" == "1" ]]; then
  echo "==> Building tag '${TAG}'"
  ./scripts/reload.sh --tag "$TAG"
fi

if [[ ! -d "$BUILT" ]]; then
  echo "error: no build found at: $BUILT" >&2
  echo "       run without --no-build, or build first with: ./scripts/reload.sh --tag $TAG" >&2
  exit 1
fi

# Quit only this tag's installed copy. The pattern is the full executable path,
# so the release /Applications/cmux.app is never matched.
if pgrep -f "${INSTALLED}/Contents/MacOS/" >/dev/null 2>&1; then
  echo "==> Quitting running ${APP_NAME}"
  pkill -f "${INSTALLED}/Contents/MacOS/" || true
  sleep 2
fi

echo "==> Installing to ${INSTALLED}"
rm -rf "$INSTALLED"
ditto "$BUILT" "$INSTALLED"

# This build inherits upstream's Sparkle feed. Left alone it will offer to
# "update" your fork into the official cmux binary, replacing your build.
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "${INSTALLED}/Contents/Info.plist")"
defaults write "$BUNDLE_ID" SUEnableAutomaticChecks -bool false
defaults write "$BUNDLE_ID" SUAutomaticallyUpdate -bool false
echo "==> Update checks disabled for ${BUNDLE_ID}"

if [[ "$LAUNCH" == "1" ]]; then
  open "$INSTALLED"
fi

echo
echo "Installed: ${INSTALLED}"
echo "Double-click it in /Applications, or use the Dock tile."
