#!/usr/bin/env bash

# This is a temporary script to accept team invitations if team settings
# are not available; if team settings is made available, then you do not
# need this script at all!

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/.."

display_usage() {
    echo "Usage: accept-invitation <name> <invitation-url>"
    echo "  name           - name of the user to be created"
    echo "  email          - email of the user that was just invited"
    echo "  invitation-url - paste the url exactly as you received on the email"
    exit 1
}

name="$1"
email="$2"
url="$3"

if [[ $name == "" || $email == "" || $url == "" ]]; then
    display_usage
    exit 1
fi

# This assumes that team_code is the last URL parameter
team_code=$(echo $url | awk -F= '{print $NF}')

# Prompt for a user password
echo -n "Password for the user (8 to 1024 characters long):"
read -s password

CURL_OUT=$(curl -i -v -s --show-error \
    -XPOST "$url" \
    -H'Content-type: application/json' \
    -d'{"team_code":"'$team_code'", "email":"'$email'","password":"'$password'","name":"'"$name"'"}')

echo "$CURL_OUT"
