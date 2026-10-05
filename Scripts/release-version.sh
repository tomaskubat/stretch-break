#!/bin/zsh

# Source from the repository root, then resolve the optional version/tag argument.
resolve_release_version() {
    if (( $# > 1 )); then
        print -u2 'Expected at most one version argument, for example v1.0.1.'
        return 1
    fi
    local version_input
    if (( $# == 0 )); then
        version_input=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist) || return 1
    else
        version_input="$1"
    fi
    STRETCHBREAK_VERSION="${version_input#v}"
    local version_pattern='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
    if [[ ! "$STRETCHBREAK_VERSION" =~ "$version_pattern" ]]; then
        print -u2 'Invalid version. Use X.Y.Z or vX.Y.Z without leading zeroes or prerelease suffixes.'
        return 1
    fi
    STRETCHBREAK_APP_ARCHIVE="StretchBreak-${STRETCHBREAK_VERSION}-arm64.zip"
    STRETCHBREAK_SOURCE_ARCHIVE="StretchBreak-${STRETCHBREAK_VERSION}-source.zip"
}
