#!/usr/bin/env bash
set -euo pipefail

if ! CONFIG="$(
  jq -cer --arg service "$SERVICE" '.[$service]' deploy-services.json
)"; then
  echo "::error::허용되지 않은 서비스: $SERVICE"
  exit 1
fi

EXPECTED_REPOSITORY="$(jq -r '.repository' <<< "$CONFIG")"
EXPECTED_IMAGE="$(jq -r '.image' <<< "$CONFIG")"
MANIFEST_DIR="$(jq -r '.manifest_dir' <<< "$CONFIG")"
DEPLOYMENT="$(jq -r '.deployment' <<< "$CONFIG")"
CONTAINER="$(jq -r '.container' <<< "$CONFIG")"

[ "$REPOSITORY" = "$EXPECTED_REPOSITORY" ] || {
  echo "::error::저장소 불일치: expected=$EXPECTED_REPOSITORY actual=$REPOSITORY"
  exit 1
}
[ "$IMAGE" = "$EXPECTED_IMAGE" ] || {
  echo "::error::이미지 불일치: expected=$EXPECTED_IMAGE actual=$IMAGE"
  exit 1
}
[ "$BRANCH" = "main" ] || {
  echo "::error::배포 허용 브랜치가 아님: $BRANCH"
  exit 1
}
[[ "$SHA" =~ ^[0-9a-f]{40}$ ]] || {
  echo "::error::유효하지 않은 commit SHA: $SHA"
  exit 1
}
[ "$QUALITY" = "success" ] || {
  echo "::error::품질 검사 미통과: $QUALITY"
  exit 1
}
[ "$COVERAGE" = "success" ] || {
  echo "::error::커버리지 검사 미통과: $COVERAGE"
  exit 1
}
[ "$BUILD" = "success" ] || {
  echo "::error::이미지 빌드 미통과: $BUILD"
  exit 1
}
[ -f "$MANIFEST_DIR/deployment.yaml" ] || {
  echo "::error::Deployment manifest가 없음: $MANIFEST_DIR/deployment.yaml"
  exit 1
}

echo "manifest_dir=$MANIFEST_DIR" >> "$GITHUB_OUTPUT"
echo "deployment=$DEPLOYMENT" >> "$GITHUB_OUTPUT"
echo "container=$CONTAINER" >> "$GITHUB_OUTPUT"
