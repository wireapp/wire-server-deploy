#!/usr/bin/env bash

# The following environment variables must be set in order to query invitations
# links via teams API and generate invite and deeplink QR codes:
#
# TEAM_ADMIN_EMAIL="someone@default.domain"
# TEAM_ADMIN_PASSWORD="password"
# TEAM_ID="9cabf984-7a35-4cd5-9891-850c64f9195a"
# NGINZ_HOST="nginz-https.wire.default.domain"
# DEEPLINK_URL="https://assets.wire.default.domain/public/deeplink.html"
# INSTRUCTIONS=./instructions.txt
#
# This script is called with the email address of the user to create:
# ./generate-user-pdf.sh john.doe@nonexistent-domain.example

old_ifs="$IFS"

setsep() {
    local newifs="$1"
    IFS="$newifs"
}

resetsep() {
    IFS="$old_ifs"
}

error() {
    echo 'error:' "${@}" >&2
    exit 1
}

if [ -z "$TEAM_ADMIN_EMAIL" ]; then
    error 'TEAM_ADMIN_EMAIL is not set'
elif [ -z "$TEAM_ADMIN_PASSWORD" ]; then
    error 'TEAM_ADMIN_PASSWORD is not set'
elif [ -z "$NGINZ_HOST" ]; then
    error 'NGINZ_HOST is not set'
elif [ -z "$TEAM_ID" ]; then
    error 'TEAM_ID is not set'
elif [ -z "$DEEPLINK_URL" ]; then
    error 'DEEPLINK_URL is not set'
elif [ -z "$INSTRUCTIONS" ]; then
    error 'INSTRUCTIONS is not set'
elif [ ! -f "$INSTRUCTIONS" ] || [ ! -r "$INSTRUCTIONS" ]; then
    error 'INSTRUCTIONS file does not exist or is not readable'
fi

if grep -Eq '[{}\\]' "$INSTRUCTIONS"; then
    echo 'warning: instructions file contains LaTeX control characters' >&2
    echo 'warning: the output PDF file may not render as expected' >&2
    echo 'will continue in 3 seconds' >&2
    sleep 3
fi

if [ -z "$1" ]; then
    error 'no email address provided'
fi

user_email="$1"

if echo "$user_email" | grep -Fq "'"; then
    error 'email address contains invalid character'
fi

echo "info: get access token by logging in"
access_token=$(curl --location --request POST "https://$NGINZ_HOST/login" \
--header 'Content-Type: application/json' \
--data-raw "{
    \"email\": \"$TEAM_ADMIN_EMAIL\",
    \"password\": \"$TEAM_ADMIN_PASSWORD\"
}" | jq -r .access_token)

if [ "$access_token" = "null" ] ; then
    error "Cannot login. Are the credentials correct?"
fi

echo "info: enable feature"
feature_status=$(curl --location --request PUT "https://$NGINZ_HOST/teams/$TEAM_ID/features/exposeInvitationURLsToTeamAdmin" \
--header "Authorization: Bearer $access_token" \
--header 'Content-Type: application/json' \
--data-raw '{
    "status": "enabled"
}' | jq -r .status)

if [ "$feature_status" != "enabled" ] ; then
    error "Cannot set feature status. Please check server configuration."
fi

echo "info: create account and get invitation url"
invite_url=$(curl --location --request POST "https://$NGINZ_HOST/teams/$TEAM_ID/invitations" \
--header "Authorization: Bearer $access_token" \
--header 'Content-Type: application/json' \
--data-raw "{
    \"email\": \"$user_email\"
}" | jq -r .url)

if [ "$invite_url" = "null" ] ; then
    error "Cannot create invitation url. Is this email address already registered?"
fi

echo "info invitation url to be encoded: $invite_url"

set -e

# prepare QR codes and LaTeX sources for PDF generation
tmpdir=$(mktemp -d "/tmp/tmp.qr-code-provisioning.XXXXXXXX")
cleanup() {
    echo 'info: cleaning up...'
    rm -rf "$tmpdir"
}
trap cleanup EXIT

echo "info: user invite URL is $invite_url"

qrencode -s 30 -t PNG -o "$tmpdir/invite.png" "$invite_url"
echo 'info: created invite QR code'

qrencode -s 30 -t PNG -o "$tmpdir/deeplink.png" "$DEEPLINK_URL"
echo 'info: created deeplink QR code'

# generate LaTeX source file.
cat > "$tmpdir/onboarding.tex" <<EOF
\documentclass[a4paper,notitlepage]{article}
\usepackage[utf8]{inputenc}
\usepackage[a4paper]{geometry}
\usepackage{graphicx}
\usepackage{multicol}
\usepackage{parskip}

\renewcommand{\familydefault}{\sfdefault}

\begin{document}

EOF

cat "$INSTRUCTIONS" >> "$tmpdir/onboarding.tex"

cat >> "$tmpdir/onboarding.tex" <<EOF

\vspace{4em}

Email address: \texttt{$user_email}

\vspace{2em}

\begin{multicols}{2}
\begin{center}
\textbf{Invite} QR code
\includegraphics[width=2in]{invite.png}
\end{center}

\begin{center}
\textbf{Deeplink} QR code
\includegraphics[width=2in]{deeplink.png}
\end{center}

\end{multicols}

\end{document}
EOF

echo 'info: created LaTeX source document'

echo 'info: generating PDF...'
pushd "$tmpdir" > /dev/null
latexmk -pdf onboarding
popd > /dev/null
echo 'info: ...complete'

cp "$tmpdir/onboarding.pdf" "$user_email"'.pdf'
echo "info: user onboarding PDF in ${user_email}.pdf"

