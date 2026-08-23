#!/usr/bin/env bash
set -eu
export PATH=$HOME/bin:$PATH

ROOT="/tmp/central-deploy-${RUN_ID}"
DIR="$ROOT/${MANIFEST_DIR}"

trap 'rm -rf "$ROOT"' EXIT

case "$SIMULATE" in
  true|false) ;;
  *) SIMULATE=false ;;
esac

case "${ROLLOUT_TIMEOUT_SECONDS:-}" in
  ''|*[!0-9]*) ROLLOUT_TIMEOUT_SECONDS=210 ;;
esac
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT_SECONDS}s"

if [ "$SIMULATE" = "true" ]; then
  TARGET_TAG="${TARGET_TAG}-rollback-test-missing"
  echo "롤백 테스트 모드: $IMAGE:$TARGET_TAG"
fi

PREVIOUS_REVISION="$(
  kubectl get deployment "$DEPLOYMENT" \
    -o jsonpath='{.metadata.annotations.deployment\.kubernetes\.io/revision}' \
    2>/dev/null || true
)"

PREVIOUS_IMAGE="$(
  kubectl get deployment "$DEPLOYMENT" \
    -o jsonpath="{.spec.template.spec.containers[?(@.name==\"$CONTAINER\")].image}" \
    2>/dev/null || true
)"

for RESOURCE in rbac.yaml configmap.yaml service.yaml ingress.yaml; do
  if [ -f "$DIR/$RESOURCE" ]; then
    kubectl apply -f "$DIR/$RESOURCE"
  fi
done

RENDERED_MANIFEST="$ROOT/deployment.rendered.yaml"

kubectl set image \
  -f "$DIR/deployment.yaml" \
  "$CONTAINER=$IMAGE:$TARGET_TAG" \
  --local -o yaml > "$RENDERED_MANIFEST"

kubectl apply -f "$RENDERED_MANIFEST"

if ! kubectl rollout status \
  "deployment/$DEPLOYMENT" --timeout="$ROLLOUT_TIMEOUT"; then
  echo "배포 실패: $IMAGE:$TARGET_TAG"

  if [ -z "$PREVIOUS_REVISION" ] || [ -z "$PREVIOUS_IMAGE" ]; then
    echo "::error::롤백 가능한 이전 배포가 없습니다."
    exit 1
  fi

  if ! kubectl rollout undo \
    "deployment/$DEPLOYMENT" \
    --to-revision="$PREVIOUS_REVISION"; then
    echo "::error::Revision $PREVIOUS_REVISION 롤백 명령 실패"
    exit 1
  fi

  if ! kubectl rollout status \
    "deployment/$DEPLOYMENT" --timeout="$ROLLOUT_TIMEOUT"; then
    echo "::error::롤백 후 정상 상태 복구 실패"
    exit 1
  fi

  RECOVERED_IMAGE="$(
    kubectl get deployment "$DEPLOYMENT" \
      -o jsonpath="{.spec.template.spec.containers[?(@.name==\"$CONTAINER\")].image}"
  )"

  if [ "$RECOVERED_IMAGE" != "$PREVIOUS_IMAGE" ]; then
    echo "::error::롤백 이미지 불일치"
    echo "expected=$PREVIOUS_IMAGE"
    echo "actual=$RECOVERED_IMAGE"
    exit 1
  fi

  echo "롤백 완료: revision=$PREVIOUS_REVISION image=$RECOVERED_IMAGE"
  exit 1
fi

echo "배포 완료: image=$IMAGE:$TARGET_TAG"
echo "DEPLOYMENT_VERIFIED image=$IMAGE:$TARGET_TAG"
