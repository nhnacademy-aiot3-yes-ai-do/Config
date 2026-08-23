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
COVERAGE_REQUIRED="$(
  jq -r 'if has("coverage_required") then .coverage_required else true end' \
    <<< "$CONFIG"
)"
ROLLOUT_TIMEOUT_SECONDS="$(
  jq -r '.rollout_timeout_seconds // 210' <<< "$CONFIG"
)"

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
case "$COVERAGE_REQUIRED" in
  true)
    [ "$COVERAGE" = "success" ] || {
      echo "::error::커버리지 검사 미통과: $COVERAGE"
      exit 1
    }
    ;;
  false)
    [ "$COVERAGE" = "not_configured" ] || {
      echo "::error::커버리지 제외 서비스의 결과가 잘못됨: $COVERAGE"
      exit 1
    }
    ;;
  *)
    echo "::error::잘못된 coverage_required 정책: $COVERAGE_REQUIRED"
    exit 1
    ;;
esac
[ "$BUILD" = "success" ] || {
  echo "::error::이미지 빌드 미통과: $BUILD"
  exit 1
}
[ -f "$MANIFEST_DIR/deployment.yaml" ] || {
  echo "::error::Deployment manifest가 없음: $MANIFEST_DIR/deployment.yaml"
  exit 1
}
[[ "$ROLLOUT_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || {
  echo "::error::유효하지 않은 rollout timeout: $ROLLOUT_TIMEOUT_SECONDS"
  exit 1
}
if [ "$ROLLOUT_TIMEOUT_SECONDS" -lt 30 ] \
  || [ "$ROLLOUT_TIMEOUT_SECONDS" -gt 900 ]; then
  echo "::error::rollout timeout 허용 범위는 30~900초입니다: $ROLLOUT_TIMEOUT_SECONDS"
  exit 1
fi

echo "manifest_dir=$MANIFEST_DIR" >> "$GITHUB_OUTPUT"
echo "deployment=$DEPLOYMENT" >> "$GITHUB_OUTPUT"
echo "container=$CONTAINER" >> "$GITHUB_OUTPUT"
echo "rollout_timeout_seconds=$ROLLOUT_TIMEOUT_SECONDS" >> "$GITHUB_OUTPUT"
