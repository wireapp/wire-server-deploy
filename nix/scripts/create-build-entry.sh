#!/bin/bash

# Initial check for args
if [[ -z "$1" || -z "$2" ]]; then
  echo "Usage: $0 <tarball-name> <containers-type>"
  exit 1
fi

# Dont create an entry for zauth
skip="containers-adminhost"

if [["$2" == "$skip"]]; then
  echo "Skipping creating entry for zauth container"
  # return 0 to continue parent script execution
  exit 0
fi

tarball_file="$1"
json_file="$2.json"
repositories_file_name="repositories"

# Check if json exists, if not, create it
if [[ ! -f "$json_file" ]]; then
  echo "[]" > "$json_file"
fi

echo "Writing $1 entry to $2.json"

temp_dir=$(mktemp -d)

# Extract repositories file from the tarball
tar -xf "$tarball_file" $repositories_file_name

mv $repositories_file_name $temp_dir

repositories_file="$temp_dir/$repositories_file_name"

if [[ ! -f "$repositories_file" ]]; then
  echo "Repositories file not present in the tarball."
  rm -rf "$temp_dir"
  # return 0 so parent script doesnt stop execution
  exit 0
fi

## else append repositories content to json

jq ". += [$(cat "$repositories_file")]" "$json_file" > "$json_file.tmp" && mv "$json_file.tmp" "$json_file"

rm -rf "$temp_dir"
