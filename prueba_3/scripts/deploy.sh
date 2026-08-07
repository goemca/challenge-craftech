#!/usr/bin/env sh
set -eu

DEPLOY_ENV="${1:?usage: deploy.sh <staging|production> <image-ref> <port>}"
NEW_IMAGE="${2:?image reference is required}"
HOST_PORT="${3:?host port is required}"
PROJECT="nginx-${DEPLOY_ENV}"
CONTAINER="${PROJECT}-nginx-1"

case "${NEW_IMAGE}" in
  *:latest) echo "latest is not accepted; use an immutable tag" >&2; exit 1 ;;
esac

PREVIOUS_IMAGE=""
if docker inspect "${CONTAINER}" >/dev/null 2>&1; then
  PREVIOUS_IMAGE="$(docker inspect --format '{{.Config.Image}}' "${CONTAINER}")"
fi

deploy_image() {
  IMAGE_REF="$1" DEPLOY_ENV="${DEPLOY_ENV}" HOST_PORT="${HOST_PORT}" \
    docker compose -p "${PROJECT}" up -d --pull always --force-recreate
}

deploy_image "${NEW_IMAGE}"

attempt=0
until curl --fail --silent "http://127.0.0.1:${HOST_PORT}/healthz" >/dev/null; do
  attempt=$((attempt + 1))
  if [ "${attempt}" -ge 12 ]; then
    echo "Health check failed for ${NEW_IMAGE}" >&2
    if [ -n "${PREVIOUS_IMAGE}" ]; then
      echo "Rolling back to ${PREVIOUS_IMAGE}"
      deploy_image "${PREVIOUS_IMAGE}"
    fi
    exit 1
  fi
  sleep 5
done

echo "${DEPLOY_ENV} is healthy on ${NEW_IMAGE}"
