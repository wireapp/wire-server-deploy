EXAMPLE: Onboarding users with QR codes instead of emails
=========================================================

This example includes a bash script to automate provisioning of users in a Wire
team on a private server instance without users needing to be able to receive
email.

New users are invited to a team by a team administrator, who sends an invite
link to each user's email address from the team settings page. When the user
opens the invite link, they are then prompted to create a new account on the
Wire server, which then becomes a member of the team.

The script in this directory takes a user's email address, and extracts
the invite code which was generated for their email address from the server
database. Then, it generates a PDF containing administrator-provided setup
instructions, the email address they should use when creating their account,
and QR codes for their invite link and the Wire server's deeplink (for
configuring mobile clients to use the private instance instead of the public
cloud instance).

## Usage

This script assumes that the private Wire server instance is deployed and
functioning correctly. The operator requires shell access to one of the
Cassandra nodes backing the server instance, as the script reads users' invite
codes directly from the database.

The `qrencode` command line tool is used for generating the URL QR codes,
and a LaTeX toolchain and the `latexmk` script are used for generating the
final PDF with the user's QR codes and instructions. On Debian and Ubuntu Linux
systems, these tools may be obtained by installing the `qrencode`, `texlive`,
and `latexmk` packages. Other distributions may have different names for these
packages. Alternatively, if you are using the offline installation instructions
described [here](../../offline/docs.md), the installation artifact tarball
includes these packages, which may be installed inside the deployment and
administration docker container.

The administrator must also provide a file containing setup instructions for
the user to follow when they receive a copy of the PDF. These instructions
should direct the user to first scan the invite link QR code, and create an
account on the Wire server using the email address listed in the PDF. Then,
if they are using a mobile client, they should scan the deeplink QR code, and
open the link to trigger configuration of the mobile client application with
the private server instance.

The script reads configuration from a series of environment variables:

- `TEAM_URL`: the URL for the private Wire server's team management
  page. Example: `https://teams.wire.example.com`.

- `DEEPLINK_URL`: the URL for the private Wire server's deeplink. See [this
  page](https://docs.wire.com/how-to/associate/deeplink.html) for further
  information on using deeplinks with private Wire instances. Example:
  `https://assets.wire.example.com/public/deeplink.html`.

- `CQLSH`: a shell command to run to invoke the `cqlsh` command against the
  Cassandra database in use by the Wire server. If the Cassandra host is
  accessible over SSH, this could look like `ssh admin@cassandra.example.com
  cqlsh`; alternatively, if you're running Cassandra on Kubernetes, the command
  could look like `kubectl -n cassandra-namespace exec cassandra-pod-0 --
  cqlsh`.

- `INSTRUCTIONS`: path to a file containing administrator-provided setup
  instructions to be included in the generated PDF. The contents of this file
  are included in the LaTeX sources verbatim. If the instructions file includes
  LaTeX control characters, the script will print a warning, as invalid LaTeX
  may cause the build step for generating the PDF to fail.

In order to use the script to generate a PDF file for a user, the team
administrator must first send an invitation link to that user's email
address. The Wire server uses the email address to uniquely identify the user
internally, however the email address in this case does not need to be able
to receive email, and may be a placeholder value. The administrator must also
write the setup instruction file, as described above.

The PDF generation script may then be run with the user's email address as a
single argument, and the script will extract their invite code, generate QR
codes, and then build the PDF, which will be copied into the script's current
working directory.

An example invocation of the script could look like this:

    $ cat > instructions.txt <<EOF
    These are instructions for onboarding into example.com's private Wire
    server. Please scan the invite QR code on your mobile device, and create an
    account using the email address listed below. Then, please install the Wire
    application for your mobile device, and then scan the deeplink QR code and
    open the link on that page in order to configure your client to work with
    example.com's Wire server.
    EOF
    $
    $ export TEAM_URL="https://teams.wire.example.com"
    $ export DEEPLINK_URL="https://assets.wire.example.com/public/deeplink.html"
    $ export CQLSH="ssh admin@cassandra.example.com cqlsh"
    $ export INSTRUCTIONS=./instructions.txt
    $
    $ ./generate-user-pdf.sh john.doe@nonexistent-domain.example

The generated PDF file for this user would then be
`john.doe@nonexistent-domain.example.pdf`.


