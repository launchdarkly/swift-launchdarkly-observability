#!/bin/bash
set -euo pipefail

DEFAULT_SCHEME="swift-launchdarkly-observability-Package"
SCHEME="$DEFAULT_SCHEME"
DEST="${DESTINATION:-}"
ONLY_TESTING=()
SKIP_TESTING=()
TEST_FILES=()

usage() {
    cat <<'EOF'
Usage:
  ./test.sh [options]
  ./test.sh <scheme> [options]   # backward compatible positional scheme

Options:
  -s, --scheme <name>            Xcode scheme (default: swift-launchdarkly-observability-Package)
  -d, --destination <dest>       xcodebuild destination (or set DESTINATION env)
      --only-testing <id>        Pass through to xcodebuild (repeatable)
      --skip-testing <id>        Pass through to xcodebuild (repeatable)
      --test-file <path>         Derive --only-testing from Tests/<Target>/<File>.swift
  -h, --help                     Show this help

Examples:
  ./test.sh
  ./test.sh --only-testing SessionReplayTests
  ./test.sh --only-testing SessionReplayTests/RRWebEventGeneratorTests
  ./test.sh --test-file Tests/SessionReplayTests/SessionReplayEventGeneratorTests.swift
EOF
}

derive_test_identifier_from_file() {
    local file_path="$1"
    python3 - "$file_path" <<'PY'
import os
import re
import sys

path = os.path.normpath(sys.argv[1])
parts = path.split(os.sep)

try:
    tests_idx = parts.index("Tests")
    target = parts[tests_idx + 1]
except (ValueError, IndexError):
    print(f"ERROR: cannot infer test target from path '{path}' (expected Tests/<Target>/...)", file=sys.stderr)
    sys.exit(2)

suite = None
try:
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            m = re.match(r"^\s*(?:final\s+)?(?:class|struct)\s+([A-Za-z_][A-Za-z0-9_]*)\b", line)
            if m:
                suite = m.group(1)
                break
except OSError as e:
    print(f"ERROR: cannot read test file '{path}': {e}", file=sys.stderr)
    sys.exit(2)

if not suite:
    suite = os.path.splitext(os.path.basename(path))[0]

print(f"{target}/{suite}")
PY
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--scheme)
            SCHEME="$2"
            shift 2
            ;;
        -d|--destination)
            DEST="$2"
            shift 2
            ;;
        --only-testing)
            ONLY_TESTING+=("$2")
            shift 2
            ;;
        --skip-testing)
            SKIP_TESTING+=("$2")
            shift 2
            ;;
        --test-file)
            TEST_FILES+=("$2")
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage
            exit 2
            ;;
        *)
            if [[ "$SCHEME" == "$DEFAULT_SCHEME" ]]; then
                SCHEME="$1"
                shift
            else
                echo "Unexpected argument: $1" >&2
                usage
                exit 2
            fi
            ;;
    esac
done

for test_file in "${TEST_FILES[@]+"${TEST_FILES[@]}"}"; do
    ONLY_TESTING+=("$(derive_test_identifier_from_file "$test_file")")
done

if [ -z "$DEST" ]; then
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

CMD=(
    xcodebuild test
    -scheme "$SCHEME"
    -destination "$DEST"
    -skipPackagePluginValidation
)

for spec in "${ONLY_TESTING[@]+"${ONLY_TESTING[@]}"}"; do
    CMD+=(-only-testing "$spec")
done

for spec in "${SKIP_TESTING[@]+"${SKIP_TESTING[@]}"}"; do
    CMD+=(-skip-testing "$spec")
done

echo "Running tests for: ${SCHEME}"
echo "Destination: ${DEST}"
if [ "${ONLY_TESTING[0]+x}" = "x" ]; then
    echo "only-testing:"
    for spec in "${ONLY_TESTING[@]+"${ONLY_TESTING[@]}"}"; do
        echo "  - ${spec}"
    done
fi
if [ "${SKIP_TESTING[0]+x}" = "x" ]; then
    echo "skip-testing:"
    for spec in "${SKIP_TESTING[@]+"${SKIP_TESTING[@]}"}"; do
        echo "  - ${spec}"
    done
fi
echo ""

if command -v xcpretty >/dev/null 2>&1; then
    # With `set -e -o pipefail`, a failing pipeline exits immediately, so
    # temporarily disable errexit to capture both statuses and return xcodebuild's.
    set +e
    "${CMD[@]}" | xcpretty
    xcodebuild_status=${PIPESTATUS[0]}
    xcpretty_status=${PIPESTATUS[1]}
    set -e

    if [ "$xcpretty_status" -ne 0 ]; then
        echo "Warning: xcpretty failed with exit code ${xcpretty_status}; preserving xcodebuild exit code ${xcodebuild_status}" >&2
    fi

    exit "$xcodebuild_status"
else
    "${CMD[@]}"
fi
