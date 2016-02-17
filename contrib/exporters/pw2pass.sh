#!/usr/bin/env bash
# Copyright (C) 2016 Dashamir Hoxha <dashohoxha@gmail.com>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

usage() {
    echo -e "\n Usage: $(basename $0) <pw-archive> \n"
    exit 1
}

# get the pw archive
[[ -z $1 ]] && usage
ARCHIVE=$1

# create a tmp dir
TEMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/pw.XXXXXXXXXXXXX")"

# get a list of password files from the temp dir
list_paths() {
    find $TEMPDIR -name '.git' -prune -or -type f | sed -e "s#$TEMPDIR/##"
}

echo -e "\nExporting from pw:\n"
pw -a $ARCHIVE export $TEMPDIR
rm -rf $TEMPDIR/.git

echo -e "\nImporting to pass:\n"
list_paths | while read path; do
    [[ -z "$path" ]] && continue
    echo "$path"
    cat "$TEMPDIR/$path" | pass insert --multiline --force "$path" >/dev/null
done

# cleanup
rm -rf $TEMPDIR
