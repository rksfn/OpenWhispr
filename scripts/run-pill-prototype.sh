#!/bin/zsh
set -euo pipefail

prototype_source="$(cd "$(dirname "$0")/.." && pwd)/Prototypes/PillTransitionPrototype.swift"
prototype_info="$(cd "$(dirname "$0")/.." && pwd)/Prototypes/PillTransitionPrototype-Info.plist"
prototype_app="/tmp/OpenWhisprPillTransitionPrototype.app"
prototype_binary="$prototype_app/Contents/MacOS/PillTransitionPrototype"

mkdir -p "$prototype_app/Contents/MacOS"
cp "$prototype_info" "$prototype_app/Contents/Info.plist"
swiftc -parse-as-library "$prototype_source" -framework SwiftUI -framework AppKit -o "$prototype_binary"
open -n "$prototype_app"
