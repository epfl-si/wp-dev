#!/bin/sh
## Usage : 
## ensure-git-clone.sh <gitURL> <directory>
test -d "$2" || git clone "$1" "$2"
