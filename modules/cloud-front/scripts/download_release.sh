#!/usr/bin/env bash
set -euo pipefail

RELEASE_TAG=${1:-}
REPO_OWNER=${2:-}
REPO_NAME=${3:-}
GITHUB_TOKEN=${4:-""}
BUCKETNAME=${5:-}
EXTRA=${6:-}
ASSET_NAME=${7:-build.zip}

[[ -z $RELEASE_TAG || $RELEASE_TAG == "none" ]] && {
  echo '{"result":"tag none"}'; exit 0; }

ROOT=$BUCKETNAME
mkdir -p "$ROOT"

# ---------- monta cabeçalhos ----------
API="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME"

# cabeçalhos JSON
HDR=(-H "Accept: application/vnd.github+json")
# cabeçalhos para download binário
HDR_BIN=(-H "Accept: application/octet-stream")

if [[ -n $GITHUB_TOKEN && $GITHUB_TOKEN != "none" ]]; then
  HDR+=(-H "Authorization: Bearer $GITHUB_TOKEN")
  HDR_BIN+=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

USE_AUTH=false
if [[ -n $GITHUB_TOKEN && $GITHUB_TOKEN != "none" ]]; then
  USE_AUTH=true
fi
# --------------------------------------

json_escape() {
  jq -Rn --arg value "$1" '$value'
}

fail_with_url() {
  local message=$1
  local url=$2
  printf '{"error":%s}\n' "$(json_escape "$message. URL: $url")"
  exit 1
}

curl_status() {
  local output=$1
  shift

  local http_code
  if ! http_code=$(curl -sSL -w "%{http_code}" -o "$output" "$@" 2>/dev/null); then
    echo "curl_error"
    return 1
  fi

  printf '%s' "$http_code"
}

curl_json() {
  local url=$1
  local response_file
  local http_code
  local response

  response_file=$(mktemp)

  http_code=$(curl_status "$response_file" "${HDR[@]}" "$url") || fail_with_url "falha ao consultar GitHub" "$url"
  if [[ $http_code =~ ^2[0-9][0-9]$ ]]; then
    response=$(cat "$response_file")
    rm -f "$response_file"
    printf '%s' "$response"
    return 0
  fi

  if [[ $USE_AUTH == true ]]; then
    http_code=$(curl_status "$response_file" -H "Accept: application/vnd.github+json" "$url") || fail_with_url "falha ao consultar GitHub" "$url"
    if [[ $http_code =~ ^2[0-9][0-9]$ ]]; then
      response=$(cat "$response_file")
      rm -f "$response_file"
      printf '%s' "$response"
      return 0
    fi
  fi

  rm -f "$response_file"
  fail_with_url "falha ao consultar GitHub (HTTP $http_code)" "$url"
}

curl_download() {
  local url=$1
  local output=$2
  local http_code

  http_code=$(curl_status "$output" "${HDR_BIN[@]}" "$url") || fail_with_url "falha ao baixar arquivo do GitHub" "$url"
  if [[ $http_code =~ ^2[0-9][0-9]$ ]]; then
    return 0
  fi

  if [[ $USE_AUTH == true ]]; then
    http_code=$(curl_status "$output" -H "Accept: application/octet-stream" "$url") || fail_with_url "falha ao baixar arquivo do GitHub" "$url"
    if [[ $http_code =~ ^2[0-9][0-9]$ ]]; then
      return 0
    fi
  fi

  rm -f "$output"
  fail_with_url "falha ao baixar arquivo do GitHub (HTTP $http_code)" "$url"
}

try_download() {
  local url=$1
  local output=$2
  local http_code

  http_code=$(curl_status "$output" -H "Accept: application/octet-stream" "$url") || return 1
  [[ $http_code =~ ^2[0-9][0-9]$ ]]
}

if [[ $RELEASE_TAG == "-1" ]]; then
  ZIP=$ROOT/build-main.zip
  DIST=$ROOT/dist-main

  if [[ $USE_AUTH == true ]]; then
    REPO_URL=$API
    REPO_RESPONSE=$(curl_json "$REPO_URL")
    DEFAULT_BRANCH=$(jq -r '.default_branch // "main"' <<<"$REPO_RESPONSE")
    BRANCH_ZIP_URL="$API/zipball/$DEFAULT_BRANCH"
    curl_download "$BRANCH_ZIP_URL" "$ZIP"
  else
    DEFAULT_BRANCH=""

    for branch in main master; do
      BRANCH_ZIP_URL="https://codeload.github.com/$REPO_OWNER/$REPO_NAME/zip/refs/heads/$branch"
      if try_download "$BRANCH_ZIP_URL" "$ZIP"; then
        DEFAULT_BRANCH=$branch
        break
      fi
    done

    [[ -z $DEFAULT_BRANCH ]] && fail_with_url "falha ao baixar branch publica; branches testadas: main, master" "https://codeload.github.com/$REPO_OWNER/$REPO_NAME/zip/refs/heads/main"
  fi

  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT

  rm -rf "$DIST" && mkdir -p "$DIST"
  unzip -q -o "$ZIP" -d "$TMP_DIR"

  SRC_DIR=$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)
  if [[ -n ${SRC_DIR:-} ]]; then
    cp -R "$SRC_DIR"/. "$DIST"/
  else
    cp -R "$TMP_DIR"/. "$DIST"/
  fi

  [[ -n $EXTRA ]] && rm -f "$DIST"/{favicon.svg,logo.png}

  echo "{\"result\":\"Download da branch $DEFAULT_BRANCH concluído.\"}"
  exit 0
fi

ZIP=$ROOT/build-$RELEASE_TAG.zip
DIST=$ROOT/dist-$RELEASE_TAG

if [[ ! -f $ZIP ]]; then
  RELEASE_URL="$API/releases/tags/$RELEASE_TAG"
  RESPONSE=$(curl_json "$RELEASE_URL")

  ASSET_ID=$(jq -r --arg FILE "$ASSET_NAME" \
             '.assets? // [] | map(select(.name==$FILE)) | .[0].id // empty' \
             <<<"$RESPONSE")
  ASSET_BROWSER_URL=$(jq -r --arg FILE "$ASSET_NAME" \
                    '.assets? // [] | map(select(.name==$FILE)) | .[0].browser_download_url // empty' \
                    <<<"$RESPONSE")

  [[ -z $ASSET_ID ]] && {
    printf '{"error":%s}\n' "$(json_escape "asset $ASSET_NAME ausente em $RELEASE_TAG. URL: $RELEASE_URL")"
    exit 1; }

  if [[ $USE_AUTH == true ]]; then
    ASSET_URL="$API/releases/assets/$ASSET_ID"
  else
    ASSET_URL=$ASSET_BROWSER_URL
  fi

  [[ -z $ASSET_URL ]] && {
    printf '{"error":%s}\n' "$(json_escape "url de download do asset $ASSET_NAME ausente em $RELEASE_TAG. URL: $RELEASE_URL")"
    exit 1; }

  curl_download "$ASSET_URL" "$ZIP"
fi

rm -rf "$DIST" && mkdir -p "$DIST"
unzip -q -o "$ZIP" -d "$DIST"

[[ -n $EXTRA ]] && rm -f "$DIST"/{favicon.svg,logo.png}

echo '{"result":"Download e unzip concluídos."}'
