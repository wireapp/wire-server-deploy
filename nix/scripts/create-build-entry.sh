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
echo "Temp dir created: $temp_dir"

# Extract repositories file from the tarball
tar -xvf "$tarball_file" $repositories_file_name -C "$temp_dir"

echo "Files in temp dir after extraction:"
ls -lR "$temp_dir"

repositories_file="$temp_dir/$repositories_file_name"

echo $repositories_file

if [[ ! -f "$repositories_file" ]]; then
  echo "Repositories file not present in the tarball."
  rm -rf "$temp_dir"
  # Dont return 1 (error) so the script execution stops, we will "skip" it instead
  exit 0
fi

# Loop through each line
while IFS= read -r line; do
  # Check if valid JSON
  if [[ "$line" =~ ^\{.*\}$ ]]; then
    # Append to deploy-builds.json
    jq ". += [$line]" "$json_file" > "$json_file.tmp" && mv "$json_file.tmp" "$json_file"
  fi
done < "$repositories_file"

rm -rf "$temp_dir"
