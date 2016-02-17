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

# get a list of password files from pass
list_paths() {
    local PREFIX="${PASSWORD_STORE_DIR:-$HOME/.password-store}"

    find $PREFIX -name '.git' -prune -or -type f \
        | sed -e '/\.gpg-id$/d' -e "s#$PREFIX/##" -e 's/\.gpg$//'
}

# create a tmp dir
TEMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/pw.XXXXXXXXXXXXX")"

echo -e "\nExtracting from pass:\n"
list_paths | while read path; do
    [[ -z "$path" ]] && continue
    echo "$path"
    mkdir -p "$(dirname "$TEMPDIR/$path")"
    pass show "$path" | cat > "$TEMPDIR/$path"
done

echo -e "\nImporting to pw:\n"
pw -a $ARCHIVE import $TEMPDIR

# cleanup
rm -rf $TEMPDIR
