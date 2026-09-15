#!/usr/bin/env bash
# Works around a bug in the app_links plugin's Android build script (used
# transitively by supabase_flutter for deep-link auth callbacks): its
# android/build.gradle declares its own separate Android Gradle Plugin
# classpath, which breaks Flutter's `flutter.compileSdkVersion` property
# injection for that specific plugin subproject and fails the build with:
#
#   "Could not get unknown property 'flutter' for extension 'android'..."
#
# Run this once after `flutter pub get` (and again any time pub re-fetches
# app_links from a clean cache) before building for Android.
set -euo pipefail

GRADLE_FILE=$(find "$(dirname "$(command -v dart)")/../.pub-cache" \
  "$HOME/.pub-cache" "$LOCALAPPDATA/Pub/Cache" \
  -path "*/app_links-*/android/build.gradle" 2>/dev/null | head -n1)

if [ -z "$GRADLE_FILE" ]; then
  echo "Could not locate app_links's android/build.gradle in the pub cache." >&2
  echo "Run 'flutter pub get' first, then re-run this script." >&2
  exit 1
fi

if grep -q "com.android.tools.build:gradle:8.6.1" "$GRADLE_FILE"; then
  # Remove the redundant nested buildscript block (repositories + classpath)
  # that precedes "rootProject.allprojects {" in the affected version.
  python3 - "$GRADLE_FILE" <<'PYEOF' 2>/dev/null || \
  perl -0pi -e 's/buildscript \{.*?\n\}\n\n(?=rootProject\.allprojects)//s' "$GRADLE_FILE"
import sys, re
path = sys.argv[1]
text = open(path).read()
text = re.sub(r"buildscript \{.*?\n\}\n\n(?=rootProject\.allprojects)", "", text, flags=re.S)
open(path, "w").write(text)
PYEOF
  echo "Patched: $GRADLE_FILE"
else
  echo "Already patched (or a different app_links version): $GRADLE_FILE"
fi
