#!/usr/bin/env bash

set -eu

# lint all shell scripts with ShellCheck
# FUTUREWORK: Fix issues of the explicitly (no globbing) excluded files.

mapfile -t SHELL_FILES_TO_LINT < <(
    git ls-files |
        grep "\.sh$" |
        grep -v "ansible/files/registry/images.sh" |
        grep -v "ansible/files/registry/registry-run.sh" |
        grep -v "ansible/files/registry/upload_image.sh" |
        grep -v "ansible/files/registry/upload_image.sh" |
        grep -v "bin/accept-invitation.sh" |
        grep -v "bin/bootstrap/init.sh" |
        grep -v "bin/demo-setup.sh" |
        grep -v "bin/generate-image-list.sh" |
        grep -v "bin/offline-cluster.sh" |
        grep -v "bin/offline-deploy.sh" |
        grep -v "bin/offline-env.sh" |
        grep -v "bin/offline-secrets.sh" |
        grep -v "bin/prod-init.sh" |
        grep -v "bin/prod-setup.sh" |
        grep -v "bin/secrets.sh" |
        grep -v "bin/test-aws-s3-auth-v4.sh" |
        grep -v "examples/team-provisioning-qr-codes/generate-user-pdf.sh" |
        grep -v "nix/scripts/create-container-dump.sh" |
        grep -v "nix/scripts/list-helm-containers.sh" |
        grep -v "offline/cd.sh" |
        grep -v "offline/cd_staging.sh"
)

shellcheck -x "${SHELL_FILES_TO_LINT[@]}"
