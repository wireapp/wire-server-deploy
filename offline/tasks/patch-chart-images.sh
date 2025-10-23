#!/usr/bin/env bash
# Script to patch bitnami repository references in chart files

set -euo pipefail

CHARTS_DIR="${1:-}"

if [[ -z "$CHARTS_DIR" ]]; then
    echo "Usage: $0 <charts-directory>"
    echo "Example: $0 ./output/charts"
    exit 1
fi

# Charts maintained by Wire (should not contain bitnami refs)
# These charts are excluded from patching to avoid masking potential issues
PATCH_EXCLUDE_LIST=(
  "wire-server"
  "wire-server-enterprise"
  "backoffice"
  "ldap-scim-bridge"
  "account-pages"
  "webapp"
  "team-settings"
  "sftd"
  "calling-test"
  "migrate-features"
  "wire-utility"
  "fake-aws"
  "fake-aws-s3"
  "fake-aws-sqs"
  "demo-smtp"
)

echo "Patching bitnami repository references in: $CHARTS_DIR"
echo "Excluded charts: ${PATCH_EXCLUDE_LIST[*]}"

patched_count=0
file_count=0
skipped_count=0

# Function to check if chart should be excluded from patching
is_excluded_chart() {
    local chart_name="$1"
    for excluded in "${PATCH_EXCLUDE_LIST[@]}"; do
        if [[ "$chart_name" == "$excluded" ]]; then
            return 0  # true - chart is excluded
        fi
    done
    return 1  # false - chart should be patched
}

# Function to patch a single file
patch_file() {
    local file="$1"
    local temp_file
    local chart_name=""

    temp_file=$(mktemp)

    # Extract chart name from file path for logging
    if [[ "$file" =~ /charts/([^/]+)/ ]]; then
        chart_name="${BASH_REMATCH[1]}"
    else
        chart_name="unknown"
    fi

    # Check if this chart should be excluded from patching
    if is_excluded_chart "$chart_name"; then
        rm "$temp_file"
        return 2  # Special return code for skipped charts
    fi

    # Apply sed replacements for various image reference patterns
    sed -e 's|repository: bitnami/|repository: bitnamilegacy/|g' \
        -e 's|repository: docker\.io/bitnami/|repository: docker.io/bitnamilegacy/|g' \
        -e 's|image: bitnami/|image: bitnamilegacy/|g' \
        -e 's|image: docker\.io/bitnami/|image: docker.io/bitnamilegacy/|g' \
        -e 's|: bitnami/|: bitnamilegacy/|g' \
        -e 's|: docker\.io/bitnami/|: docker.io/bitnamilegacy/|g' \
        "$file" > "$temp_file"

    # Check if file was modified and log specific changes
    if ! cmp -s "$file" "$temp_file"; then
        # Show what was changed
        echo "  ✅ Patched chart: $chart_name"
        echo "     File: $(basename "$file")"

        # Extract and log the specific bitnami references that were changed
        local changes
        changes=$(diff "$file" "$temp_file" 2>/dev/null | grep "^<\|^>" | grep -E "(bitnami|bitnamilegacy)" || true)
        if [[ -n "$changes" ]]; then
            echo "     Changes:"
            echo "$changes" | while read -r line; do
                if [[ "$line" =~ ^\<.*bitnami/ ]]; then
                    local old_ref
                    old_ref=$(echo "$line" | sed 's/^< *//' | grep -o 'bitnami/[^[:space:]]*' || echo "bitnami reference")
                    echo "       - $old_ref → bitnamilegacy/${old_ref#bitnami/}"
                fi
            done
        fi

        mv "$temp_file" "$file"
        return 0
    else
        rm "$temp_file"
        return 1
    fi
}

echo "Scanning and patching files..."

# Process values.yaml files
while IFS= read -r -d '' file; do
    file_count=$((file_count + 1))
    patch_file "$file" && rc=$? || rc=$?
    if [[ $rc -eq 0 ]]; then
        patched_count=$((patched_count + 1))
    elif [[ $rc -eq 2 ]]; then
        skipped_count=$((skipped_count + 1))
    fi
done < <(find "$CHARTS_DIR" -name "values.yaml" -print0)

# Process Chart.yaml files
while IFS= read -r -d '' file; do
    file_count=$((file_count + 1))
    patch_file "$file" && rc=$? || rc=$?
    if [[ $rc -eq 0 ]]; then
        patched_count=$((patched_count + 1))
    elif [[ $rc -eq 2 ]]; then
        skipped_count=$((skipped_count + 1))
    fi
done < <(find "$CHARTS_DIR" -name "Chart.yaml" -print0)

# Process template files (for direct image references)
while IFS= read -r -d '' file; do
    file_count=$((file_count + 1))
    patch_file "$file" && rc=$? || rc=$?
    if [[ $rc -eq 0 ]]; then
        patched_count=$((patched_count + 1))
    elif [[ $rc -eq 2 ]]; then
        skipped_count=$((skipped_count + 1))
    fi
done < <(find "$CHARTS_DIR" -path "*/templates/*.yaml" -print0)

echo
echo "=== Patching Summary ==="
echo "Files processed: $file_count"
echo "Files skipped (excluded charts): $skipped_count"
echo "Files modified: $patched_count"
echo "Files unchanged: $((file_count - skipped_count - patched_count))"

if [[ $patched_count -gt 0 ]]; then
    echo
    echo "Charts with bitnami references successfully patched:"
    # Extract unique chart names from the log output above
    echo "  (See detailed changes above for specific image references)"
else
    echo "No bitnami image references found in any charts."
fi
echo "=========================="