#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
source Scripts/release-version.sh
resolve_release_version "$@"
swift -module-cache-path .build/update-module-cache Scripts/verify-release.swift distribution "$STRETCHBREAK_VERSION" "$PWD" "$PWD/dist"
