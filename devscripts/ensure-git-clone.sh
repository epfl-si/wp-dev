#!/bin/sh
## Usage : 
## ensure-git-clone.sh <gitURL> <directory>

set -e -x

GIT_URL="$1"
TARGET_DIR="$2"

do_git_clone() {
    git clone "$GIT_URL" "$TARGET_DIR"
}

if test -L "$TARGET_DIR"; then
    # Was probably a link to a module under jahia2wp, which got re-hosted.
    rm "$TARGET_DIR"
fi

if ! test -d "$TARGET_DIR"; then
    do_git_clone
elif [ "$(cd "$TARGET_DIR" && git remote get-url origin)" != "$GIT_URL" ] ; then
    mv "$TARGET" "$TARGET"-orig
    do_git_clone
fi
