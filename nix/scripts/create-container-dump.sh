#!/usr/bin/env bash
# This consumes a list of containers from stdin and produces a `skopeo sync`
# dir at $1.
set -eou pipefail

if [[ ! $# -eq 1 ]]; then
  echo "usage: $0 OUTPUT-DIR" >&2
  exit 1
fi

export HTTP_TIMEOUT=600     # Timeout in seconds (default is typically 90)
export REGISTRY_TIMEOUT=600 # Registry specific timeout

output_dir=$1
mkdir -p $1

# Download all the docker images into $1, and append its name to an index.txt
# If this errors out for you, copy default-policy.json from the skopeo repo to
# /etc/containers/policy.json
while IFS= read -r image; do

# sanitize the image file name, replace slashes with underscores, suffix with .tar
  image_filename=$(sed -r "s/[:\/]/_/g" <<< "$image")
  image_path="$(realpath "$1")/${image_filename}.tar"

  if [[ -s "$image_path" ]]; then
    echo "Skipping $image_filename…"
    continue
  fi

  echo "Fetching $image_filename…"

  # All of these images should be publicly fetchable, especially given we
  # ship public tarballs containing these images.
  # ci.sh already honors DOCKER_LOGIN, so do the same here, otherwise
  # fallback to unauthorized fetching.

  # If an image has both a tag and digest, remove the tag. Return the original if there is no match.
  image_trimmed=$(echo "$image" | sed -E 's/(.+)(:.+(@.+))/\1\3/')

  tmp_path="${image_path}.tmp"
  rm -f "$tmp_path"

  success=false

  for attempt in {1..5}; do
    echo "Attempt $attempt/5 for $image_trimmed"

    if [[ -n "${DOCKER_LOGIN:-}" && "$image" =~ quay.io/wire ]]; then
      skopeo copy --insecure-policy \
        --src-creds "$DOCKER_LOGIN" \
        --retry-times 10 \
        "docker://$image_trimmed" \
        "docker-archive:${tmp_path}" \
        --additional-tag "$image" || rc=$?
    else
      skopeo copy --insecure-policy \
        --retry-times 10 \
        "docker://$image_trimmed" \
        "docker-archive:${tmp_path}" \
        --additional-tag "$image" || rc=$?
    fi

    rc=$?

    if [[ $rc -eq 0 && -s "$tmp_path" ]]; then
      mv "$tmp_path" "$image_path"
      success=true
      break
    fi

    echo "Fetch failed for $image_trimmed with rc=$rc; retrying…"
    rm -f "$tmp_path"
    sleep $((attempt * 20))
  done

  if [[ "$success" != true ]]; then
    echo "ERROR: failed to fetch $image after retries" >&2
    exit 1
  fi

  echo "${image_filename}.tar" >> "$(realpath "$1")/index.txt"
  create-build-entry "$image" "$output_dir"
done
