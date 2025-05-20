#!/usr/bin/env bash
set -euo pipefail
set -x

RELEASE_TAG=${1:-}
REPO_OWNER=${2:-}
REPO_NAME=${3:-}
GITHUB_TOKEN=${4:-}
BUCKETNAME=${5:-}
EXTRA=${6:-}                 # renomeei para clareza
ASSET_NAME=${7:-build.zip}   # permite escolher outro nome

[[ -z $RELEASE_TAG || $RELEASE_TAG == "none" ]] && {
  echo '{"result":"tag none"}'; exit 0; }

ROOT=$BUCKETNAME/dist
ZIP=$ROOT/build-$RELEASE_TAG.zip
DIST=$ROOT/dist-$RELEASE_TAG

mkdir -p "$ROOT"

if [[ ! -f $ZIP ]]; then
  API="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME"
  HDR=(-H "Authorization: Bearer $GITHUB_TOKEN"
       -H "Accept: application/vnd.github+json")

  # --fail faz curl devolver exit 22 se a URL não existir
  RESPONSE=$(curl --fail -s "${HDR[@]}" "$API/releases/tags/$RELEASE_TAG") \
    || { echo '{"error":"release não encontrado"}'; exit 1; }

  # “? // empty” impede o erro de iterate-null
  ASSET_ID=$(jq -r --arg FILE "$ASSET_NAME" \
             '.assets? // [] | map(select(.name==$FILE)) | .[0].id' \
             <<<"$RESPONSE")

  [[ -z $ASSET_ID || $ASSET_ID == "null" ]] && {
    echo "{\"error\":\"asset $ASSET_NAME ausente em $RELEASE_TAG\"}"
    exit 1; }

  curl --fail -sL \
       -H "Authorization: Bearer $GITHUB_TOKEN" \
       -H "Accept: application/octet-stream" \
       "$API/releases/assets/$ASSET_ID" -o "$ZIP"
fi

rm -rf  "$DIST" && mkdir -p "$DIST"
unzip -q -o "$ZIP" -d "$DIST"

if [[ -n $EXTRA ]]; then
  rm -f "$DIST"/{favicon.svg,logo.png}
fi

echo '{"result":"Download e unzip concluídos."}'
