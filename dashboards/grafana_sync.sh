#!/usr/bin/env bash
set -euo pipefail

GRAFANA_URL="<GRAFANA_URL>"  # Replace with your Grafana URL
API_TOKEN="<API_TOKEN>"  # Replace with your Grafana API token
DASHBOARD_DIR="./api_upload"
TEMP_FILE="/tmp/dashboard_payload.json"

for file in "$DASHBOARD_DIR"/*.json; do
  echo "Uploading: $file"
  title=$(jq -r '.dashboard.title // empty' "$file")
  if [[ -z "$title" ]]; then
    echo "❌ Skipping $file: missing dashboard title"
    continue
  fi

  # Save payload to temporary file instead of keeping it in a variable
  jq 'del(.dashboard.id) | {dashboard: .dashboard, folderId: 0, overwrite: true}' "$file" > "$TEMP_FILE"

  response=$(curl -s -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_TOKEN" \
    -X POST "$GRAFANA_URL/api/dashboards/db" \
    -d "@$TEMP_FILE")

  # Check if the response contains both body and HTTP code. Then parse them.
  # If the response is shorter than 3 characters, assume it's just the body.
  if [[ ${#response} -ge 3 ]]; then
    http_code="${response: -3}"
    body="${response:0:${#response}-3}"
  else
    http_code="000"
    body="$response"
  fi

  if [[ "$http_code" == "200" ]]; then
    echo "✅ Uploaded: $file"
  else
    echo "❌ Failed to upload: $file (HTTP $http_code)"
    echo "Response: $body"
  fi
done

# Clean up
rm -f "$TEMP_FILE"
