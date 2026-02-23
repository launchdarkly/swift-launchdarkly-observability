#!/bin/bash
set -euo pipefail

SCHEME="${1:-swift-launchdarkly-observability-Package}"

if [ -n "${DESTINATION:-}" ]; then
    DEST="$DESTINATION"
else
    SIM_ID=$(xcrun simctl list devices available -j \
        | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data['devices'].items():
    if 'iOS' in runtime:
        for d in devices:
            if 'iPhone' in d['name'] and d['isAvailable']:
                print(d['udid'])
                sys.exit(0)
sys.exit(1)
")
    DEST="platform=iOS Simulator,id=${SIM_ID}"
fi

echo "Running tests for: ${SCHEME}"
echo "Destination: ${DEST}"
echo ""

if command -v xcpretty &>/dev/null; then
    xcodebuild test \
        -scheme "$SCHEME" \
        -destination "$DEST" \
        -skipPackagePluginValidation \
        | xcpretty
    exit ${PIPESTATUS[0]}
else
    xcodebuild test \
        -scheme "$SCHEME" \
        -destination "$DEST" \
        -skipPackagePluginValidation
fi
