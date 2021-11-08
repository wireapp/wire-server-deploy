#!/bin/bash

# The following environment variables must be set in order to query invite
# codes from the database and generate invite and deeplink QR codes:
#
# TEAM_URL='https://teams.wire.example.com'
# DEEPLINK_URL='https://assets.wire.example.com/public/deeplink.html
# CQLSH='ssh admin@cassandra.example.com cqlsh'
# INSTRUCTIONS=./instructions.txt

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

if [ -z "$TEAM_URL" ]; then
    error 'TEAM_URL is not set'
elif [ -z "$DEEPLINK_URL" ]; then
    error 'DEEPLINK_URL is not set'
elif [ -z "$CQLSH" ]; then
    error 'CQLSH is not set'
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

cql_query='select code from brig.team_invitation_email where email = '"'$user_email'"';'

# perform cassandra query
cass_output="$($CQLSH -e "$cql_query")"

if [ "$?" -ne 0 ]; then
    error 'error when executing cassandra query!'
fi

# strip formatting from cqlsh output
setsep ''
cass_results=$(echo -n "$cass_output" | sed -Ee '1,3d' -e '/^$/,$d' -e 's/^ //')
resetsep

# split output
setsep $'\n'
cass_rows=($(echo -n "$cass_results"))
resetsep

if [ "${#cass_rows[@]}" -gt 1 ]; then
    error 'email address is associated with more than one invite code'
elif [ "${#cass_rows[@]}" -eq 0 ]; then
    error 'email address is not associated with any invite codes'
fi

# assemble output data
invite_code="$cass_rows"
invite_url="$TEAM_URL"'/join/?team-link='"$invite_code"

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

