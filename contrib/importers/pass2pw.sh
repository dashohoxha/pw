#!/usr/bin/env bash
# Copyright (C) 2016 Dashamir Hoxha <dashohoxha@gmail.com>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

pw=$(which pw)
PREFIX="${PASSWORD_STORE_DIR:-$HOME/.password-store}"

usage() {
    echo "
Usage: $0 [-a <archive>]
"
    exit 1
}
get_passphrase() {
    read -r -p "Enter the passphrase of the pw archive: " -s passphrase || exit 1
    [[ -t 0 ]] && echo
}
get_options() {
    while true; do
        case $1 in
            -h|--help) usage ;;
            -a) archive=$2; shift 2 ;;
            *)  break ;;
        esac
    done
}
list_paths() {
    find $PREFIX -name '.git' -prune -or -type f \
        | sed -e '/\.gpg-id$/d' -e "s#$PREFIX/##" -e 's/\.gpg$//'
}

get_options "$@"
get_passphrase
[[ -n $archive ]] && pw="$pw -a $archive"

list_paths | while read path; do
    [[ -z "$path" ]] && continue
    echo "$path"
    { echo "$passphrase"; pass show "$path"; } | $pw set "$path" --multiline --force >/dev/null
done
