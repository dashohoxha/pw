#!/usr/bin/env bash
# Copyright (C) 2016 Dashamir Hoxha <dashohoxha@gmail.com>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

pw=$(which pw)

usage() {
    echo "
Usage: $0 [-a <archive>] [-k]

The option -k indicates that the archive is encrypted with asymmetric keys,
otherwise it has a symmetric encryption with a passphrase.
"
    exit 1
}
get_passphrase() {
    read -r -p "Passphrase: " -s passphrase || exit 1
    [[ -t 0 ]] && echo
}
get_options() {
    while true; do
        case $1 in
            -h|--help) usage ;;
            -a) archive=$2; shift 2 ;;
            -k) gpg_keys=1; shift ;;
            *)  break ;;
        esac
    done
}

get_options "$@"
[[ -z $gpg_keys ]] && get_passphrase
[[ -n $archive ]] && pw="$pw -a $archive"

echo "$passphrase" | $pw ls | while read pwfile; do
    echo "$pwfile"
    echo "$passphrase" | $pw ls $pwfile | pass insert --multiline --force "$pwfile" >/dev/null
done
