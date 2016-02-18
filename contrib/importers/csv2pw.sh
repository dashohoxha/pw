#!/usr/bin/env bash
# Copyright (C) 2016 Dashamir Hoxha <dashohoxha@gmail.com>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

usage() {
    echo "
Usage: $(basename $0) <file.csv> <archive>

Note: This works with CSV files exported from keepassx, which have
the fields: Group, Title, Username, Password, URL, Notes.
For other types of csv files it needs to be fixed.
"
    exit 1
}

# get the arguments
[[ -z $1 ]] && usage
CSVFILE=$1
[[ -z $2 ]] && usage
ARCHIVE=$2

# create a tmp dir
TEMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/pw.XXXXXXXXXXXXX")"

cat $CSVFILE | while IFS=, read group title username password url notes
do
    group=${group:1:-1}
    title=${title:1:-1}
    username=${username:1:-1}
    password=${password:1:-1}
    url=${url:1:-1}
    notes=${notes:1:-1}

    group=${group// /-}
    title=${title// /-}

    echo "$group:$title:$username:$password:$url:$notes"
    mkdir -p "$TEMPDIR/$group"
    cat <<-_EOF > "$TEMPDIR/$group/$title"
$password
Username: $username
URL: $url
Notes: $notes
_EOF

done

echo -e "\nImporting to pw:\n"
pw -a $ARCHIVE import $TEMPDIR

# cleanup
rm -rf $TEMPDIR
