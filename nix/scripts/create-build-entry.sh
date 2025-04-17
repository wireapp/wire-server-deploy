#!/usr/bin/env bash
set -eou pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <docker-image-with-tag> <directory>"
  exit 1
fi

IMAGE_WITH_TAG=$1
DIRECTORY=$2

IMAGE=$(echo "$IMAGE_WITH_TAG" | cut -d':' -f1)
TAG=$(echo "$IMAGE_WITH_TAG" | cut -d':' -f2)

JSON_FILE="$DIRECTORY/images.json"

if [ ! -d "$DIRECTORY" ]; then
  mkdir -p "$DIRECTORY"
fi

append_image_entry() {
  local image=$1
  local tag=$2
  local json_file=$3

  if [ -f "$json_file" ]; then
    existing_content=$(jq '.' "$json_file")

    new_entry=$(jq -n --arg image "$image" --arg tag "$tag" '{$image: $tag}')
    updated_content=$(echo "$existing_content" | jq --argjson new_entry "$new_entry" '. += [$new_entry]')
  else
    updated_content=$(jq -n --arg image "$image" --arg tag "$tag" '[{$image: $tag}]')
  fi

  echo "$updated_content" | jq '.' > "$json_file"
}

append_image_entry "$IMAGE" "$TAG" "$JSON_FILE"
