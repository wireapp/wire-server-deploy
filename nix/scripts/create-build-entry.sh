#!/bin/bash

# Initial check for args
if [[ -z "$1" ]]; then
  echo "Usage: $0 <tarball-name>"
  exit 1
fi

tarball_file="$1"
deploy_builds="deploy-builds.json"
repositories_file_name="repositories"

# Check if deploy-builds.json exists, if not, instantiate it
if [[ ! -f "$deploy_builds" ]]; then
  echo "[]" > "$deploy_builds"
fi

echo "Writing $1 to deploy-builds.json"

temp_dir=$(mktemp -d)

# Extract repositories file from the tarball
tar -xvf "$tarball_file" $repositories_file_name

mv $repositories_file_name $temp_dir

repositories_file="$temp_dir/$repositories_file_name"

if [[ ! -f "$repositories_file" ]]; then
  echo "Repositories file not present in the tarball."
  rm -rf "$temp_dir"
  # Dont return 1 (error) else the script execution stops, we will "skip" it instead
  exit 0
fi

## else append repositories content to deploy-buids.json

jq ". += [$(cat "$repositories_file")]" "$deploy_builds" > "$deploy_builds.tmp" && mv "$deploy_builds.tmp" "$deploy_builds"

rm -rf "$temp_dir"
