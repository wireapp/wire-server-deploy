#!/bin/bash

GRAFANA_URL="<GRAFANA_URL>"  # Replace with your Grafana URL
API_TOKEN="<API_TOKEN>"  # Replace with your Grafana API token
OUTPUT_DIR="./downloaded_dashboards"

mkdir -p "$OUTPUT_DIR"

echo "Fetching dashboard list..."
dashboard_uids=$(curl -s -H "Authorization: Bearer $API_TOKEN" "$GRAFANA_URL/api/search?type=dash-db" | jq -r '.[].uid')

for uid in $dashboard_uids; do
  echo "Downloading dashboard UID: $uid"
  
  dashboard_json=$(curl -s -H "Authorization: Bearer $API_TOKEN" "$GRAFANA_URL/api/dashboards/uid/$uid")
  
  title=$(echo "$dashboard_json" | jq -r '.dashboard.title' | tr ' ' '_' | tr -cd '[:alnum:]_-')
  file_path="$OUTPUT_DIR/${title:-$uid}.json"
  
  echo "$dashboard_json" | jq . > "$file_path"

  echo "Saved: $file_path"
done

echo "✅ Download complete: Dashboards saved in $OUTPUT_DIR/"
