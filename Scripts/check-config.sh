#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

for SCRIPT in Scripts/*.sh; do
    zsh -n "$SCRIPT"
done
plutil -lint Resources/Info.plist

# Update the version and its Apple Silicon archive checksum together; see Docs/Actionlint.md.
ACTIONLINT_VERSION="1.7.12"
ACTIONLINT_SHA256="aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f"
ACTIONLINT_ARCHIVE="actionlint_${ACTIONLINT_VERSION}_darwin_arm64.tar.gz"
TOOLS_DIR="$PWD/.build/actionlint-${ACTIONLINT_VERSION}"
mkdir -p "$TOOLS_DIR"
curl --fail --silent --show-error --location --retry 3 \
    --connect-timeout 15 --max-time 120 \
    --output "$TOOLS_DIR/$ACTIONLINT_ARCHIVE" \
    "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/${ACTIONLINT_ARCHIVE}"
(
    cd "$TOOLS_DIR"
    print -r -- "$ACTIONLINT_SHA256  $ACTIONLINT_ARCHIVE" | shasum -a 256 -c -
    tar -xzf "$ACTIONLINT_ARCHIVE" actionlint
)
"$TOOLS_DIR/actionlint" -color
