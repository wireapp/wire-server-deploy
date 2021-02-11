#!/usr/bin/env bash
# This consumes a list of containers from stdin and produces a `skopeo sync`
# dir at $1.
set -eou pipefail

if [[ ! $# -eq 1 ]]; then
  echo "usage: $0 OUTPUT-DIR" >&2
  exit 1
fi

mkdir -p $1
# Download all the docker images into $1, and append its name to an index.txt
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

      # All of these images should be publicly fetchable, especially given we
      # ship public tarballs containing these images.
      # ci.sh already honors DOCKER_LOGIN, so do the same here, otherwise
      # fallback to unauthorized fetching.
      if [[ -n "${DOCKER_LOGIN:-}" && "$image" =~ quay.io/wire ]];then
        skopeo copy --insecure-policy --src-creds "$DOCKER_LOGIN" \
          docker://$image docker-archive:${image_path} --additional-tag $image
      else
        skopeo copy --insecure-policy \
          docker://$image docker-archive:${image_path} --additional-tag $image
      fi
      echo "${image_filename}.tar" >> $(realpath "$1")/index.txt
    fi
done
