#!/bin/sh

set -e

. "$(dirname "$0")"/functions.sh

if ! which node; then
    die 'No `node` in $PATH!'
else
    node_version="$(node --version)"
    case "$node_version" in
        "$1") exit 1 ;;
        *) die "Incorrect node version - Expected: $1; actual: $node_version" ;;
    esac
fi
