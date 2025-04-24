#!/usr/bin/env bash
set -euo pipefail
set -x

RELEASE_TAG=$1      # v1.2.3
REPO_OWNER=$2       # org-ou-usuario
REPO_NAME=$3        # meu-repo
GITHUB_TOKEN=$4
BUCKETNAME=$5
ADICIONAL=${6:-}

ROOTPATH=$BUCKETNAME/dist
FILE_NAME=$ROOTPATH/build-$RELEASE_TAG.zip
DISTDIR=$ROOTPATH/dist-$RELEASE_TAG

mkdir -p "$ROOTPATH"

[[ "$RELEASE_TAG" == "none" ]] && { echo '{"result":"tag none"}'; exit 0; }

if [[ ! -f "$FILE_NAME" ]]; then
  API_URL="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME"
  HDR=(-H "Authorization: Bearer $GITHUB_TOKEN"
       -H "Accept: application/vnd.github+json")

  # 1. Descobre o asset id do build.zip nesse tag
  ASSET_ID=$(curl -s "${HDR[@]}" \
      "$API_URL/releases/tags/$RELEASE_TAG" |
      jq -r '.assets[] | select(.name=="build.zip") | .id')

  [[ -z "$ASSET_ID" ]] && {
      echo "{\"error\":\"build.zip não encontrado no release $RELEASE_TAG\"}"
      exit 1; }

  # 2. Baixa o binário
  curl -sL \
       -H "Authorization: Bearer $GITHUB_TOKEN" \
       -H "Accept: application/octet-stream" \
       "$API_URL/releases/assets/$ASSET_ID" \
       -o "$FILE_NAME"
fi

# Descompacta
rm -rf "$DISTDIR"
mkdir -p "$DISTDIR"
unzip -q -o "$FILE_NAME" -d "$DISTDIR"

if [[ -n "$ADICIONAL" ]]; then
  rm -f "$DISTDIR"/{favicon.svg,logo.png}
fi

echo '{"result":"Download e unzip concluídos."}'
