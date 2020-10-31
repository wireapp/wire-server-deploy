#!/usr/bin/env bash

set -eou pipefail


key="$1"
case $key in
    --list)
    if [[ -z "${TF_STATE:-}" ]]; then
      terraform output -json ansible-inventory
    else
      terraform output -state="${TF_STATE}" -json ansible-inventory
    fi

    ;;
    --host)
    echo "{}"
    ;;
    --help|*)
    echo "Usage: [TF_STATE=<path to tfstate>] $0 [ --list | --host | --help ]" >&2
    ;;
esac

