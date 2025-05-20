#!/usr/bin/env bash
set -euo pipefail
set -x

RELEASE_TAG=${1:-}
REPO_OWNER=${2:-}
REPO_NAME=${3:-}
GITHUB_TOKEN=${4:-""}        # pode vir vazio
BUCKETNAME=${5:-}
EXTRA=${6:-}
ASSET_NAME=${7:-build.zip}

[[ -z $RELEASE_TAG || $RELEASE_TAG == "none" ]] && {
  echo '{"result":"tag none"}'; exit 0; }

ROOT=$BUCKETNAME/dist
ZIP=$ROOT/build-$RELEASE_TAG.zip
DIST=$ROOT/dist-$RELEASE_TAG
mkdir -p "$ROOT"

# ---------- monta cabeçalhos ----------
API="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME"

# cabeçalhos JSON
HDR=(-H "Accept: application/vnd.github+json")
# cabeçalhos para download binário
HDR_BIN=(-H "Accept: application/octet-stream")

if [[ -n $GITHUB_TOKEN ]]; then
  HDR+=(-H "Authorization: Bearer $GITHUB_TOKEN")
  HDR_BIN+=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi
# --------------------------------------

if [[ ! -f $ZIP ]]; then
  RESPONSE=$(curl --fail -sSL "${HDR[@]}" "$API/releases/tags/$RELEASE_TAG") \
    || { echo '{"error":"release não encontrado"}'; exit 1; }

  ASSET_ID=$(jq -r --arg FILE "$ASSET_NAME" \
             '.assets? // [] | map(select(.name==$FILE)) | .[0].id // empty' \
             <<<"$RESPONSE")

  [[ -z $ASSET_ID ]] && {
    echo "{\"error\":\"asset $ASSET_NAME ausente em $RELEASE_TAG\"}"
    exit 1; }

  curl --fail -sSL "${HDR_BIN[@]}" \
       "$API/releases/assets/$ASSET_ID" -o "$ZIP"
fi

rm -rf "$DIST" && mkdir -p "$DIST"
unzip -q -o "$ZIP" -d "$DIST"

[[ -n $EXTRA ]] && rm -f "$DIST"/{favicon.svg,logo.png}

echo '{"result":"Download e unzip concluídos."}'
