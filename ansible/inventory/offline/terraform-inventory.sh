#!/usr/bin/env bash

if [[ -n "$TF_STATE" ]]; then
  args="-state=$TF_STATE"
else
  args=""
fi

key="$1"
case $key in
    --list)
    terraform output "$args" -json ansible-inventory
    ;;
    --host)
    echo "{}"
    ;;
    --help|*)
    echo "Usage: [TF_STATE=<path to tfstate>] $0 [ --list | --host | --help ]" >&2
    ;;
esac

