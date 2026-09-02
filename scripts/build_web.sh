#!/usr/bin/env bash
# Builds the CodeRunner web bundle the same way the release workflow does
# (.github/workflows/coderunner-web-release.yaml), so a local build reports the
# same version as a released one instead of pubspec's placeholder 0.0.0.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="$(git describe --tags --match 'v[0-9]*' --abbrev=0 2>/dev/null || echo v0.0.0)"
VERSION="${VERSION#v}"

flutter build web -t lib/coderunner/main_coderunner.dart \
  --base-href /pathplanner/ \
  --no-web-resources-cdn \
  --build-name="$VERSION" \
  --build-number="${BUILD_NUMBER:-1}"

echo "Built PathPlanner web v$VERSION -> build/web"
