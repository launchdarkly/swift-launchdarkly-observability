#!/usr/bin/env bash

# Pushes a podspec to CocoaPods trunk. Versions that trunk already has are
# skipped instead of failing, so a release that got partway through the pods
# can be re-run without hitting "Unable to accept duplicate entry".
#
# Trunk sometimes reports a failure (timeout, 5xx) for a push that it goes on
# to accept, so after a failed push we poll trunk before giving up. Once a pod
# is accepted we also wait for it to reach the CDN, because later pods in the
# release lint against it from there.

set -euo pipefail

podspec="${1:?usage: publish-pod.sh <podspec>}"

max_push_attempts=${MAX_PUSH_ATTEMPTS:-3}
trunk_poll_seconds=${TRUNK_POLL_SECONDS:-300}
cdn_poll_seconds=${CDN_POLL_SECONDS:-900}
poll_interval=${POLL_INTERVAL:-15}

spec_json=$(pod ipc spec "$podspec")
name=$(printf '%s' "$spec_json" | ruby -rjson -e 'print JSON.parse(STDIN.read).fetch("name")')
version=$(printf '%s' "$spec_json" | ruby -rjson -e 'print JSON.parse(STDIN.read).fetch("version")')

trunk_status() {
  curl --silent --location --output /dev/null --write-out '%{http_code}' \
    "https://trunk.cocoapods.org/api/v1/pods/${name}/versions/${version}" || true
}

on_cdn() {
  local shard
  shard=$(ruby -rdigest -e 'print Digest::MD5.hexdigest(ARGV[0])[0, 3].chars.join("_")' "$name")
  curl --silent --fail --location "https://cdn.cocoapods.org/all_pods_versions_${shard}.txt" 2>/dev/null \
    | grep -E "^${name}/" | tr '/' '\n' | grep -qxF "$version"
}

wait_for() {
  local description=$1 timeout=$2 check=$3 waited=0
  until "$check"; do
    if [ "$waited" -ge "$timeout" ]; then
      return 1
    fi
    echo "Waiting for ${name} ${version} to ${description} (${waited}s/${timeout}s)..."
    sleep "$poll_interval"
    waited=$((waited + poll_interval))
  done
}

published_on_trunk() { [ "$(trunk_status)" = "200" ]; }

wait_for_cdn() {
  if wait_for "appear on the CocoaPods CDN" "$cdn_poll_seconds" on_cdn; then
    echo "${name} ${version} is available on the CocoaPods CDN."
  else
    echo "::warning title=CDN propagation slow::${name} ${version} is on trunk but not yet on the CDN; pods that depend on it may fail to lint."
  fi
}

http_code=$(trunk_status)
case "$http_code" in
  200)
    echo "::notice title=Pod already published::${name} ${version} is already on CocoaPods trunk, skipping push."
    wait_for_cdn
    exit 0
    ;;
  404) ;;
  *)
    echo "::warning title=Trunk check failed::Could not tell whether ${name} ${version} is published (HTTP ${http_code}), pushing anyway."
    ;;
esac

log=$(mktemp)
status=1
for attempt in $(seq 1 "$max_push_attempts"); do
  echo "Pushing ${name} ${version} to CocoaPods trunk (attempt ${attempt}/${max_push_attempts})."
  set +e
  pod trunk push "$podspec" --allow-warnings --synchronous 2>&1 | tee "$log"
  status=${PIPESTATUS[0]}
  set -e

  if [ "$status" -eq 0 ]; then
    break
  fi

  if grep -q 'Unable to accept duplicate entry' "$log"; then
    echo "::notice title=Pod already published::trunk rejected ${name} ${version} as a duplicate, treating as published."
    status=0
    break
  fi

  if grep -q 'did not pass validation' "$log"; then
    break
  fi

  if wait_for "show up on trunk after a failed push" "$trunk_poll_seconds" published_on_trunk; then
    echo "::notice title=Push reported failure but succeeded::trunk has ${name} ${version} even though pod trunk push exited with ${status}."
    status=0
    break
  fi
done

if [ "$status" -ne 0 ]; then
  exit "$status"
fi

wait_for_cdn
