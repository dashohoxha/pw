#!/usr/bin/env bash
# Copyright (C) 2016 Dashamir Hoxha <dashohoxha@gmail.com>.
# Copyright (C) 2013 Tom Hendrikx <tom@whyscream.net>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

usage() {
    echo -e "\n Usage: $(basename $0) <pwsafe-export> <pw-archive> \n"
    exit 1
}

[[ -z $1 ]] && usage
[[ -z $2 ]] && usage
export=$1
ARCHIVE=$2

# create a tmp dir
TEMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/pw.XXXXXXXXXXXXX")"

echo -e "\nExporting from pwsafe:\n"
IFS="	" # tab character
cat "$export" | while read uuid group name login passwd notes; do
     test "$uuid" = "# passwordsafe version 2.0 database" && continue
     test "$uuid" = "uuid" && continue
     test "$name" = '""' && continue;

     group="$(echo $group | cut -d'"' -f2)"
     login="$(echo $login | cut -d'"' -f2)"
     passwd="$(echo $passwd | cut -d'"' -f2)"
     name="$(echo $name | cut -d'"' -f2)"

     # cleanup
     test "${name:0:4}" = "http" && name="$(echo $name | cut -d'/' -f3)"
     test "${name:0:4}" = "www." && name="$(echo $name | cut -c 5-)"

     entry=""
     test -n "$login" && entry="${entry}login: $login\n"
     test -n "$passwd" && entry="${entry}pass: $passwd\n"
     test -n "$group" && entry="${entry}group: $group\n"

     echo $name:
     mkdir -p "$(dirname "$TEMPDIR/$name")"
     echo -e $entry > "$TEMPDIR/$name"
done

echo -e "\nImporting to pw:\n"
pw -a $ARCHIVE import $TEMPDIR

# cleanup
rm -rf $TEMPDIR
