#!/usr/bin/env bash
# Script to patch bitnami repository references in chart files

set -euo pipefail

CHARTS_DIR="${1:-}"

if [[ -z "$CHARTS_DIR" ]]; then
    echo "Usage: $0 <charts-directory>"
    echo "Example: $0 ./output/charts"
    exit 1
fi

echo "Patching bitnami repository references in: $CHARTS_DIR"

patched_count=0
file_count=0

# Function to patch a single file
patch_file() {
    local file="$1"
    local temp_file=$(mktemp)
    local chart_name=""

    # Extract chart name from file path for logging
    if [[ "$file" =~ /charts/([^/]+)/ ]]; then
        chart_name="${BASH_REMATCH[1]}"
    else
        chart_name="unknown"
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
        local changes=$(diff "$file" "$temp_file" 2>/dev/null | grep "^<\|^>" | grep -E "(bitnami|bitnamilegacy)" || true)
        if [[ -n "$changes" ]]; then
            echo "     Changes:"
            echo "$changes" | while read -r line; do
                if [[ "$line" =~ ^\<.*bitnami/ ]]; then
                    local old_ref=$(echo "$line" | sed 's/^< *//' | grep -o 'bitnami/[^[:space:]]*' || echo "bitnami reference")
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
    if patch_file "$file"; then
        patched_count=$((patched_count + 1))
    fi
done < <(find "$CHARTS_DIR" -name "values.yaml" -print0)

# Process Chart.yaml files
while IFS= read -r -d '' file; do
    file_count=$((file_count + 1))
    if patch_file "$file"; then
        patched_count=$((patched_count + 1))
    fi
done < <(find "$CHARTS_DIR" -name "Chart.yaml" -print0)

# Process template files (for direct image references)
while IFS= read -r -d '' file; do
    file_count=$((file_count + 1))
    if patch_file "$file"; then
        patched_count=$((patched_count + 1))
    fi
done < <(find "$CHARTS_DIR" -path "*/templates/*.yaml" -print0)

echo
echo "=== Patching Summary ==="
echo "Files processed: $file_count"
echo "Files modified: $patched_count"

if [[ $patched_count -gt 0 ]]; then
    echo
    echo "Charts with bitnami references successfully patched:"
    # Extract unique chart names from the log output above
    echo "  (See detailed changes above for specific image references)"
else
    echo "No bitnami image references found in any charts."
fi
echo "=========================="