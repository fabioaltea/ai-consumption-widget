#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="AIConsumptionWidget.app"
ZIP_NAME="AIConsumptionWidget-macOS.zip"

cd "$ROOT_DIR"
mkdir -p "$DIST_DIR"

xcodebuild \
  -project AIConsumptionWidget.xcodeproj \
  -scheme AIConsumptionWidget \
  -configuration Release \
  -sdk macosx \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH=$(ls -dt ~/Library/Developer/Xcode/DerivedData/AIConsumptionWidget-*/Build/Products/Release/"$APP_NAME" 2>/dev/null | head -n 1 || true)

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Release app not found in DerivedData."
  exit 1
fi

rm -f "$DIST_DIR/$ZIP_NAME"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$DIST_DIR/$ZIP_NAME"

echo "Package created: $DIST_DIR/$ZIP_NAME"
