#!/bin/zsh
# Builds the universal (Apple silicon + Intel) release zip used by get.sh.
set -euo pipefail
cd "$(dirname "$0")"
UNIVERSAL=1 ./build.sh
rm -rf dist; mkdir dist
ditto -c -k --keepParent "build/WalkScape Widget.app" dist/WalkScape-Widget.zip
echo "dist/WalkScape-Widget.zip ($(du -h dist/WalkScape-Widget.zip | cut -f1))"
