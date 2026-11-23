#!/usr/bin/env bash
# Usage: bash scripts/switch_project.sh NEW_PROJECT_ID
set -euo pipefail
NEW="${1:?Usage: bash scripts/switch_project.sh NEW_PROJECT_ID}"
OLD="$(grep -o '"default": *"[^"]*"' .firebaserc | sed 's/.*"\([^"]*\)"$/\1/')"
[ "$OLD" = "$NEW" ] && { echo "Already on $NEW"; exit 0; }
echo "Switching $OLD -> $NEW"
FILES=$(grep -rl "$OLD" --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=.agents \
        --exclude-dir=ios --exclude-dir=macos --exclude-dir=build . || true)
for f in $FILES; do
  sed -i.bak "s/$OLD/$NEW/g" "$f" && rm -f "$f.bak"
  echo "  updated $f"
done
# these belong to the old project; flutterfire configure recreates them
rm -f app/android/app/google-services.json app/ios/Runner/GoogleService-Info.plist app/lib/firebase_options.dart
echo
echo "Done. Next: cd app && flutterfire configure --project=$NEW"
