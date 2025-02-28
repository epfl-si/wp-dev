#!/usr/bin/env bash
## Usage:
##   ensure-git-clone.sh <repository> <destination> <branch>

#set -e -x

REPOSITORY_URL="$1"
TARGET_DIR="$2"
TARGET_BRANCH="${3:-main}"

do_git_clone() {
    echo "$REPOSITORY_URL → $TARGET_DIR | $TARGET_BRANCH"
    git clone -b "$TARGET_BRANCH" "$REPOSITORY_URL" "$TARGET_DIR"
}

if test -L "$TARGET_DIR"; then
    # Clean up symlink if exists
    rm "$TARGET_DIR"
fi

if ! test -d "$TARGET_DIR"; then
    do_git_clone
elif [ "$(cd "$TARGET_DIR" && git remote get-url origin)" != "$REPOSITORY_URL" ] ; then
    mv "$TARGET_DIR" "$TARGET_DIR"-orig
    do_git_clone
fi
