#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
dist/StretchBreak.app/Contents/MacOS/StretchBreakPrototype --export-previews "$PWD/Previews"
print "Exported previews to $PWD/Previews"
