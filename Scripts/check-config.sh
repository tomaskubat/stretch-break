#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

for SCRIPT in Scripts/*.sh; do
    zsh -n "$SCRIPT"
done
plutil -lint Resources/Info.plist

# Pin both the workflow checker and the checksum of its Apple Silicon archive.
TOOLS_DIR="$PWD/.build/actionlint-1.7.12"
mkdir -p "$TOOLS_DIR"
curl --fail --silent --show-error --location --retry 3 \
    --connect-timeout 15 --max-time 120 \
    --output "$TOOLS_DIR/actionlint.tar.gz" \
    https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_darwin_arm64.tar.gz
(
    cd "$TOOLS_DIR"
    print -r -- 'aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f  actionlint.tar.gz' | shasum -a 256 -c -
    tar -xzf actionlint.tar.gz actionlint
)
"$TOOLS_DIR/actionlint" -color
