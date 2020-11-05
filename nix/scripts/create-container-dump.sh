#!/usr/bin/env bash
# This consumes a list of containers from stdin and produces a `skopeo sync`
# dir at $1.
set -eou pipefail

if [[ ! $# -eq 1 ]]; then
  echo "usage: $0 OUTPUT-DIR" >&2
  exit 1
fi

mkdir -p $1
# Download all the docker images into $1
# If this errors out for you, copy default-policy.json from the skopeo repo to
# /etc/containers/policy.json
while IFS= read -r image; do
    # sanitize the image file name, replace slashes with underscores, suffix with .tar
    image_filename=$(sed -r "s/[:\/]/_/g" <<< $image)
    image_path=$(realpath $1)/${image_filename}.tar
    if [[ -e $image_path ]];then
      echo "Skipping $image_filename…"
    else
      echo "Fetching $image_filename…"
      # If the image is tagless, just push it without a tag
      if [[ $image =~ "@" ]]; then
        skopeo copy docker://$image docker-archive:${image_path}
      else
        skopeo copy docker://$image docker-archive:${image_path} --additional-tag $image
      fi
    fi
done

