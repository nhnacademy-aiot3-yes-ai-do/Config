#!/usr/bin/env bash
set -euo pipefail

case "$SERVICE" in
  gateway-service)
    EXPECTED_REPOSITORY="nhnacademy-aiot3-yes-ai-do/Gateway"
    EXPECTED_IMAGE="ghcr.io/nhnacademy-aiot3-yes-ai-do/gateway"
    echo "manifest_dir=k8s-services/gateway" >> "$GITHUB_OUTPUT"
    echo "deployment=gateway-service" >> "$GITHUB_OUTPUT"
    echo "container=gateway-service" >> "$GITHUB_OUTPUT"
    ;;
  *) echo "::error::허용되지 않은 서비스: $SERVICE"; exit 1 ;;
esac

[ "$REPOSITORY" = "$EXPECTED_REPOSITORY" ] || exit 1
[ "$IMAGE" = "$EXPECTED_IMAGE" ] || exit 1
[ "$BRANCH" = "main" ] || exit 1
[[ "$SHA" =~ ^[0-9a-f]{40}$ ]] || exit 1
[ "$QUALITY" = "success" ] || exit 1
[ "$COVERAGE" = "success" ] || exit 1
[ "$BUILD" = "success" ] || exit 1
