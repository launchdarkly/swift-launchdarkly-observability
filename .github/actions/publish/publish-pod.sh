#!/usr/bin/env bash

# Pushes a podspec to CocoaPods trunk. Versions that trunk already has are
# skipped instead of failing, so a release that got partway through the pods
# can be re-run without hitting "Unable to accept duplicate entry".

set -euo pipefail

podspec="${1:?usage: publish-pod.sh <podspec>}"

spec_json=$(pod ipc spec "$podspec")
name=$(printf '%s' "$spec_json" | ruby -rjson -e 'print JSON.parse(STDIN.read).fetch("name")')
version=$(printf '%s' "$spec_json" | ruby -rjson -e 'print JSON.parse(STDIN.read).fetch("version")')

http_code=$(curl --silent --location --output /dev/null --write-out '%{http_code}' \
  "https://trunk.cocoapods.org/api/v1/pods/${name}/versions/${version}" || true)

case "$http_code" in
  200)
    echo "::notice title=Pod already published::${name} ${version} is already on CocoaPods trunk, skipping push."
    exit 0
    ;;
  404) ;;
  *)
    echo "::warning title=Trunk check failed::Could not tell whether ${name} ${version} is published (HTTP ${http_code}), pushing anyway."
    ;;
esac

echo "Pushing ${name} ${version} to CocoaPods trunk."
log=$(mktemp)
set +e
pod trunk push "$podspec" --allow-warnings --synchronous 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
set -e

if [ "$status" -ne 0 ] && grep -q 'Unable to accept duplicate entry' "$log"; then
  echo "::notice title=Pod already published::trunk rejected ${name} ${version} as a duplicate, treating as published."
  exit 0
fi

exit "$status"
