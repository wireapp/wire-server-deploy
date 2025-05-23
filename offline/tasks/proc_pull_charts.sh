#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR=""
# Default exclude lists
HELM_CHART_EXCLUDE_LIST="inbucket,wire-server-enterprise,cert-manager"

# Parse the arguments
for arg in "$@"
do
  case $arg in
    OUTPUT_DIR=*)
      OUTPUT_DIR="${arg#*=}"
      ;;
    HELM_CHART_EXCLUDE_LIST=*)
      HELM_CHART_EXCLUDE_LIST="${arg#*=}"
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

# Check if OUTPUT_DIR is set
if [[ -z "$OUTPUT_DIR" ]]; then
  echo "usage: $0 OUTPUT_DIR=\"output-dir\" [HELM_CHART_EXCLUDE_LIST=\"chart1,chart2,...\"]" >&2
  exit 1
fi

echo "Pulling Helm charts in $OUTPUT_DIR"

HELM_CHART_EXCLUDE_LIST=$(echo "$HELM_CHART_EXCLUDE_LIST" | jq -R 'split(",")')
echo "Excluding following charts from the release: $HELM_CHART_EXCLUDE_LIST"

wire_build_chart_release () {

  wire_build="$1"
  curl "$wire_build" | jq -r --argjson HELM_CHART_EXCLUDE_LIST "$HELM_CHART_EXCLUDE_LIST" '
  .helmCharts
  | with_entries(select(.key as $k | $HELM_CHART_EXCLUDE_LIST | index($k) | not))
  | to_entries
  | map("\(.key) \(.value.repo) \(.value.version)")
  | join("\n")
  '
}

# pull_charts() accepts charts in format
# <chart-name> <repo-url> <chart-version>
# on stdin
pull_charts() {
  local dest_dir="${1:-${OUTPUT_DIR}/charts}"
  echo "Pulling charts into $dest_dir ..."
  mkdir -p "$dest_dir"

  home=$(mktemp -d)
  export HELM_CACHE_HOME="$home"
  export HELM_DATA_HOME="$home"
  export HELM_CONFIG_HOME="$home"

  declare -A repos
  # needed to handle associative array lookup
  set +u

  while IFS=$'\n' read -r line
  do
    echo "$line"
    IFS=$' ' read -r -a parts <<< "$line"
    name=${parts[0]}
    repo=${parts[1]}
    version=${parts[2]}

    # we add and update the repo only the first time we see it to speed up the process
    repo_short_name=${repos[$repo]}
    if [ "$repo_short_name" == "" ]; then
      n=${#repos[@]}
      repo_short_name="repo_$((n+1))"
      repos[$repo]=$repo_short_name
      helm repo add "$repo_short_name" "$repo"
      helm repo update "$repo_short_name"
    fi
    # Check if the chart is already pulled
    if [ -d "$dest_dir/$name" ]; then
      echo "Chart directory $dest_dir/$name already exists, skipping pull."
      continue
    fi
    echo "Pulling chart $name from $repo_short_name with version $version..."
    helm pull --version "$version" --untar -d "$dest_dir" "$repo_short_name/$name"
  done
  echo "Pulling charts done."
}

pull_from_wire_helm_charts() {
  local chart_name="$1"
  local repo_owner="wireapp"
  local repo_name="helm-charts"
  local branch="cert-manager-in-bundle"  # Change to PR branch name if needed, e.g. "pull/27/head"
  local output_dir="${OUTPUT_DIR}/charts"

  echo "Fetching $chart_name chart from $repo_owner/$repo_name ($branch)..."

  local tmp_dir
  tmp_dir=$(mktemp -d)
  git clone --depth 1 --branch "$branch" "https://github.com/${repo_owner}/${repo_name}.git" "$tmp_dir"
  if [[ -d "$tmp_dir/charts/$chart_name" ]]; then
    mkdir -p "$output_dir"
    cp -R "$tmp_dir/charts/$chart_name" "$output_dir/"
    
    # Parse the dependencies from the requirements.yaml file and pull them untarred
    local requirements_file="$tmp_dir/charts/$chart_name/requirements.yaml"
    if [[ -f "$requirements_file" ]]; then
      echo "Parsing dependencies from $requirements_file..."
      local dependencies
      dependencies=$(yq eval '.dependencies[] | "\(.name) \(.repository) \(.version)"' "$requirements_file")
      echo "$dependencies" | pull_charts "$output_dir/$chart_name/charts"
    else
      echo "No requirements.yaml file found for $chart_name."
    fi
  else
    echo "Chart '$chart_name' not found in repo."
  fi
  rm -rf "$tmp_dir"
}

wire_build="https://raw.githubusercontent.com/wireapp/wire-builds/6074076265c6b456330116574c11b12906f1c158/build.json"
wire_build_chart_release "$wire_build" | pull_charts

# Pulls the charts from https://github.com/wireapp/helm-charts
pull_from_wire_helm_charts "cert-manager"