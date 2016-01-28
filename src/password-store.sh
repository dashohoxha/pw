#!/usr/bin/env bash

# Copyright (C) 2012 - 2014 Jason A. Donenfeld <Jason@zx2c4.com>. All Rights Reserved.
# This file is licensed under the GPLv2+. Please see COPYING for more information.

umask 077
set -o pipefail

HOMEDIR="${PASSWORD_STORE_DIR:-$HOME/.pass}"
X_SELECTION="${PASSWORD_STORE_X_SELECTION:-clipboard}"
CLIP_TIME="${PASSWORD_STORE_CLIP_TIME:-45}"

#
# BEGIN helper functions
#

GPG="gpg"
which gpg2 &>/dev/null && GPG="gpg2"

encrypt() {
    $GPG -o $1 --symmetric --passphrase="$PASSPHRASE" \
         --quiet --yes --batch \
         --compress-algo=none --cipher-algo=AES256
}
decrypt() {
    $GPG -o - --passphrase="$PASSPHRASE" \
         --quiet --yes --batch
}

passphrase() {
    [[ -z $PASSPHRASE ]] || return
    read -r -p "Enter passphrase: " -s PASSPHRASE || exit 1
    echo
}

archive_init() {
    make_workdir
    archive_lock
}
archive_lock() {
    passphrase
    tar -czf - -C $WORKDIR . | encrypt $HOMEDIR/pass.tgz.gpg.1
    mv -f $HOMEDIR/pass.tgz.gpg{.1,}
    rm -rf $WORKDIR
}
archive_unlock() {
    passphrase
    make_workdir
    cat $HOMEDIR/pass.tgz.gpg | decrypt | tar -xzf - -C $WORKDIR
}

git_add_file() {
    [[ -d $GIT_DIR ]] || return
    git add "$1" || return
    [[ -n $(git status --porcelain "$1") ]] || return
    git_commit "$2"
}
git_commit() {
    local sign=""
    [[ -d $GIT_DIR ]] || return
    [[ $(git config --bool --get pass.signcommits) == "true" ]] && sign="-S"
    git commit $sign -m "$1"
}
yesno() {
    [[ -t 0 ]] || return 0
    local response
    read -r -p "$1 [y/N] " response
    [[ $response == [yY] ]] || exit 1
}
die() {
    echo "$@" >&2
    exit 1
}
check_sneaky_paths() {
    local path
    for path in "$@"; do
        [[ $path =~ /\.\.$ || $path =~ ^\.\./ || $path =~ /\.\./ || $path =~ ^\.\.$ ]] && die "Error: You've attempted to pass a sneaky path to pass. Go home."
    done
}

#
# END helper functions
#

#
# BEGIN platform definable
#

clip() {
    # This base64 business is because bash cannot store binary data in a shell
    # variable. Specifically, it cannot store nulls nor (non-trivally) store
    # trailing new lines.
    local sleep_argv0="password store sleep on display $DISPLAY"
    pkill -f "^$sleep_argv0" 2>/dev/null && sleep 0.5
    local before="$(xclip -o -selection "$X_SELECTION" 2>/dev/null | base64)"
    echo -n "$1" | xclip -selection "$X_SELECTION" || die "Error: Could not copy data to the clipboard"
    (
        ( exec -a "$sleep_argv0" sleep "$CLIP_TIME" )
        local now="$(xclip -o -selection "$X_SELECTION" | base64)"
        [[ $now != $(echo -n "$1" | base64) ]] && before="$now"

        # It might be nice to programatically check to see if klipper exists,
        # as well as checking for other common clipboard managers. But for now,
        # this works fine -- if qdbus isn't there or if klipper isn't running,
        # this essentially becomes a no-op.
        #
        # Clipboard managers frequently write their history out in plaintext,
        # so we axe it here:
        qdbus org.kde.klipper /klipper org.kde.klipper.klipper.clearClipboardHistory &>/dev/null

        echo "$before" | base64 -d | xclip -selection "$X_SELECTION"
    ) 2>/dev/null & disown
    echo "Copied $2 to clipboard. Will clear in $CLIP_TIME seconds."
}

make_workdir() {
    [[ -n $WORKDIR ]] && return
    local warn=1
    [[ $1 == "nowarn" ]] && warn=0
    local template="$PROGRAM.XXXXXXXXXXXXX"
    if [[ -d /dev/shm && -w /dev/shm && -x /dev/shm ]]; then
        WORKDIR="$(mktemp -d "/dev/shm/$template")"
        remove_tmpfile() {
            rm -rf "$WORKDIR"
        }
        trap remove_tmpfile INT TERM EXIT
    else
        [[ $warn -eq 1 ]] && yesno "$(cat <<- _EOF
Your system does not have /dev/shm, which means that it may
be difficult to entirely erase the temporary non-encrypted
password file after editing.

Are you sure you would like to continue?
_EOF
        )"
        WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/$template")"
        shred_tmpfile() {
            find "$WORKDIR" -type f -exec $SHRED {} +
            rm -rf "$WORKDIR"
        }
        trap shred_tmpfile INT TERM EXIT
    fi
}

GETOPT="getopt"
SHRED="shred -f -z"

source "$(dirname "$0")/platform/$(uname | cut -d _ -f 1 | tr '[:upper:]' '[:lower:]').sh" 2>/dev/null # PLATFORM_FUNCTION_FILE

#
# END platform definable
#


#
# BEGIN subcommand functions
#

cmd_version() {
    cat <<-_EOF
        ============================================
        = pass: the standard unix password manager =
        =                                          =
        =                  v1.6.5                  =
        =                                          =
        =             Jason A. Donenfeld           =
        =               Jason@zx2c4.com            =
        =                                          =
        =      http://www.passwordstore.org/       =
        ============================================
_EOF
}

cmd_usage() {
    cmd_version
    echo
    cat <<-_EOF
        Usage:
            $PROGRAM init
                Initialize password storage.
            $PROGRAM [ls] [subfolder]
                List passwords.
            $PROGRAM find pass-names...
                List passwords that match pass-names.
            $PROGRAM [show] [--clip,-c] pass-name
                Show existing password and optionally put it on the clipboard.
                If put on the clipboard, it will be cleared in $CLIP_TIME seconds.
            $PROGRAM grep search-string
                Search for password files containing search-string when decrypted.
            $PROGRAM insert [--echo,-e | --multiline,-m] [--force,-f] pass-name
                Insert new password. Optionally, echo the password back to the console
                during entry. Or, optionally, the entry may be multiline. Prompt before
                overwriting existing password unless forced.
            $PROGRAM edit pass-name
                Insert a new password or edit an existing password using ${EDITOR:-vi}.
            $PROGRAM generate [--no-symbols,-n] [--clip,-c] [--in-place,-i | --force,-f] pass-name pass-length
                Generate a new password of pass-length with optionally no symbols.
                Optionally put it on the clipboard and clear board after $CLIP_TIME seconds.
                Prompt before overwriting existing password unless forced.
                Optionally replace only the first line of an existing file with a new password.
            $PROGRAM rm [--recursive,-r] [--force,-f] pass-name
                Remove existing password or directory, optionally forcefully.
            $PROGRAM mv [--force,-f] old-path new-path
                Renames or moves old-path to new-path, optionally forcefully.
            $PROGRAM cp [--force,-f] old-path new-path
                Copies old-path to new-path, optionally forcefully.
            $PROGRAM git git-command-args...
                If the password store is a git repository, execute a git command
                specified by git-command-args.
            $PROGRAM help
                Show this text.
            $PROGRAM version
                Show version information.

        More information may be found in the pass(1) man page.
_EOF
}

cmd_init() {
    mkdir -v -p $HOMEDIR
    archive_init
    echo "Password store initialized."
}

cmd_show() {
    local opts clip=0
    opts="$($GETOPT -o c -l clip -n "$PROGRAM" -- "$@")"
    local err=$?
    eval set -- "$opts"
    while true; do
        case $1 in
            -c|--clip) clip=1; shift ;;
            --) shift; break ;;
        esac
    done

    [[ $err -ne 0 ]] && die "Usage: $PROGRAM $COMMAND [--clip,-c] [pass-name]"

    local path="$1"
    local passfile="$WORKDIR/$path"
    check_sneaky_paths "$path"
    if [[ -f $passfile ]]; then
        if [[ $clip -eq 0 ]]; then
            cat "$passfile" || exit $?
        else
            local pass="$(cat "$passfile" | head -n 1)"
            [[ -n $pass ]] || exit 1
            clip "$pass" "$path"
        fi
    elif [[ -d $WORKDIR/$path ]]; then
        if [[ -z $path ]]; then
            echo "Password Store"
        else
            echo "${path%\/}"
        fi
        tree -C -l --noreport "$WORKDIR/$path" | tail -n +2
    elif [[ -z $path ]]; then
        die "Error: password store is empty. Try \"pass init\"."
    else
        die "Error: $path is not in the password store."
    fi
}

cmd_find() {
    [[ -z "$@" ]] && die "Usage: $PROGRAM $COMMAND pass-names..."
    IFS="," eval 'echo "Search Terms: $*"'
    local terms="*$(printf '%s*|*' "$@")"
    tree -C -l --noreport -P "${terms%|*}" --prune "$WORKDIR" | tail -n +2
}

cmd_grep() {
    [[ $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND search-string"
    local search="$1" passfile grepresults
    grep --color=always "$search" -r $WORKDIR | sed -e "s#$WORKDIR/##"
}

cmd_insert() {
    local opts multiline=0 noecho=1 force=0
    opts="$($GETOPT -o mef -l multiline,echo,force -n "$PROGRAM" -- "$@")"
    local err=$?
    eval set -- "$opts"
    while true; do
        case $1 in
            -m|--multiline) multiline=1; shift ;;
            -e|--echo) noecho=0; shift ;;
            -f|--force) force=1; shift ;;
            --) shift; break ;;
        esac
    done

    [[ $err -ne 0 || ( $multiline -eq 1 && $noecho -eq 0 ) || $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND [--echo,-e | --multiline,-m] [--force,-f] pass-name"
    local path="$1"
    local passfile="$WORKDIR/$path"
    check_sneaky_paths "$path"

    [[ $force -eq 0 && -e $passfile ]] && yesno "An entry already exists for $path. Overwrite it?"

    mkdir -p "$WORKDIR/$(dirname "$path")"

    if [[ $multiline -eq 1 ]]; then
        echo "Enter contents of $path and press Ctrl+D when finished:"
        echo
        cat > "$passfile" || exit 1
    elif [[ $noecho -eq 1 ]]; then
        local password password_again
        while true; do
            read -r -p "Enter password for $path: " -s password || exit 1
            echo
            read -r -p "Retype password for $path: " -s password_again || exit 1
            echo
            if [[ $password == "$password_again" ]]; then
                cat <<< "$password" > "$passfile"
                break
            else
                echo "Error: the entered passwords do not match."
            fi
        done
    else
        local password
        read -r -p "Enter password for $path: " -e password
        cat <<< "$password" > "$passfile"
    fi
    git_add_file "$passfile" "Add given password for $path to store."
}

cmd_edit() {
    [[ $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND pass-name"

    local path="$1"
    check_sneaky_paths "$path"
    mkdir -p "$WORKDIR/$(dirname "$path")"
    local passfile="$WORKDIR/$path"

    local action="Add"
    [[ -f $passfile ]] && action="Edit"

    ${EDITOR:-vi} "$passfile"
    git_add_file "$passfile" "$action password for $path using ${EDITOR:-vi}."
    rm -f $tmp_file
}

cmd_generate() {
    local opts clip=0 force=0 symbols="-y" inplace=0
    opts="$($GETOPT -o ncif -l no-symbols,clip,in-place,force -n "$PROGRAM" -- "$@")"
    local err=$?
    eval set -- "$opts"
    while true; do
        case $1 in
            -n|--no-symbols) symbols=""; shift ;;
            -c|--clip) clip=1; shift ;;
            -f|--force) force=1; shift ;;
            -i|--in-place) inplace=1; shift ;;
            --) shift; break ;;
        esac
    done

    [[ $err -ne 0 || $# -ne 2 || ( $force -eq 1 && $inplace -eq 1 ) ]] && die "Usage: $PROGRAM $COMMAND [--no-symbols,-n] [--clip,-c] [--in-place,-i | --force,-f] pass-name pass-length"
    local path="$1"
    local length="$2"
    check_sneaky_paths "$path"
    [[ ! $length =~ ^[0-9]+$ ]] && die "Error: pass-length \"$length\" must be a number."
    mkdir -p "$WORKDIR/$(dirname "$path")"
    local passfile="$WORKDIR/$path"

    [[ $inplace -eq 0 && $force -eq 0 && -e $passfile ]] && yesno "An entry already exists for $path. Overwrite it?"

    local pass="$(pwgen -s $symbols $length 1)"
    [[ -n $pass ]] || exit 1
    if [[ $inplace -eq 0 ]]; then
        cat <<< "$pass" > "$passfile"
    else
        local passfile_temp="${passfile}.tmp.${RANDOM}.${RANDOM}.${RANDOM}.${RANDOM}.--"
        cat "$passfile" | sed $'1c \\\n'"$(sed 's/[\/&]/\\&/g' <<<"$pass")"$'\n' > "$passfile_temp"
        mv "$passfile_temp" "$passfile"
        rm -f "$passfile_temp"
    fi
    local verb="Add"
    [[ $inplace -eq 1 ]] && verb="Replace"
    git_add_file "$passfile" "$verb generated password for ${path}."

    if [[ $clip -eq 0 ]]; then
        printf "\e[1m\e[37mThe generated password for \e[4m%s\e[24m is:\e[0m\n\e[1m\e[93m%s\e[0m\n" "$path" "$pass"
    else
        clip "$pass" "$path"
    fi
}

cmd_delete() {
    local opts recursive="" force=0
    opts="$($GETOPT -o rf -l recursive,force -n "$PROGRAM" -- "$@")"
    local err=$?
    eval set -- "$opts"
    while true; do
        case $1 in
            -r|--recursive) recursive="-r"; shift ;;
            -f|--force) force=1; shift ;;
            --) shift; break ;;
        esac
    done
    [[ $# -ne 1 ]] && die "Usage: $PROGRAM $COMMAND [--recursive,-r] [--force,-f] pass-name"
    local path="$1"
    check_sneaky_paths "$path"

    local passfile="$WORKDIR/${path%/}"
    if [[ ! -d $passfile ]]; then
        passfile="$WORKDIR/$path"
        [[ ! -f $passfile ]] && die "Error: $path is not in the password store."
    fi

    [[ $force -eq 1 ]] || yesno "Are you sure you would like to delete $path?"

    rm $recursive -f -v "$passfile"
    if [[ -d $GIT_DIR && ! -e $passfile ]]; then
        git rm -qr "$passfile"
        git_commit "Remove $path from store."
    fi
    rmdir -p "${passfile%/*}" 2>/dev/null
}

cmd_copy_move() {
    local opts move=1 force=0
    [[ $1 == "copy" ]] && move=0
    shift
    opts="$($GETOPT -o f -l force -n "$PROGRAM" -- "$@")"
    local err=$?
    eval set -- "$opts"
    while true; do
        case $1 in
            -f|--force) force=1; shift ;;
            --) shift; break ;;
        esac
    done
    [[ $# -ne 2 ]] && die "Usage: $PROGRAM $COMMAND [--force,-f] old-path new-path"
    check_sneaky_paths "$@"
    local old_path="$WORKDIR/${1%/}"
    local new_path="$WORKDIR/$2"
    local old_dir="$old_path"

    if [[ ! -d $old_path ]]; then
        old_dir="${old_path%/*}"
        old_path="${old_path}"
        [[ ! -f $old_path ]] && die "Error: $1 is not in the password store."
    fi

    mkdir -p "${new_path%/*}"
    [[ -d $old_path || -d $new_path || $new_path =~ /$ ]] || new_path="${new_path}"

    local interactive="-i"
    [[ ! -t 0 || $force -eq 1 ]] && interactive="-f"

    if [[ $move -eq 1 ]]; then
        mv $interactive -v "$old_path" "$new_path" || exit 1

        if [[ -d $GIT_DIR && ! -e $old_path ]]; then
            git rm -qr "$old_path"
            git_add_file "$new_path" "Rename ${1} to ${2}."
        fi
        rmdir -p "$old_dir" 2>/dev/null
    else
        cp $interactive -r -v "$old_path" "$new_path" || exit 1
        git_add_file "$new_path" "Copy ${1} to ${2}."
    fi
}

cmd_git() {
    export GIT_DIR="$WORKDIR/.git"
    export GIT_WORK_TREE="$WORKDIR"

    if [[ $1 == "init" ]]; then
        git "$@" || exit 1
        git_add_file "$WORKDIR" "Add current contents of password store."
    elif [[ -d $GIT_DIR ]]; then
        export TMPDIR="$WORKDIR"
        git "$@"
    else
        die "Error: the password store is not a git repository. Try \"$PROGRAM git init\"."
    fi
}

#
# END subcommand functions
#

PROGRAM="${0##*/}"
COMMAND="$1"

case "$1" in
    init)
        shift
        cmd_init "$@"
        ;;

    help|--help)
        shift
        cmd_usage "$@"
        ;;

    version|--version)
        shift
        cmd_version "$@"
        ;;

    show|ls|list)
        archive_unlock
        shift
        cmd_show "$@"
        ;;

    find|search)
        archive_unlock
        shift
        cmd_find "$@"
        ;;

    grep)
        archive_unlock
        shift
        cmd_grep "$@"
        ;;

    insert|add)
        archive_unlock
        shift
        cmd_insert "$@"
        archive_lock
        ;;

    edit)
        archive_unlock
        shift
        cmd_edit "$@"
        archive_lock
        ;;

    generate)
        archive_unlock
        shift
        cmd_generate "$@"
        archive_lock
        ;;

    delete|rm|remove)
        archive_unlock
        shift
        cmd_delete "$@"
        archive_lock
        ;;

    rename|mv)
        archive_unlock
        shift
        cmd_copy_move "move" "$@"
        archive_lock
        ;;

    copy|cp)
        archive_unlock
        shift
        cmd_copy_move "copy" "$@"
        archive_lock
        ;;

    git)
        archive_unlock
        shift
        cmd_git "$@"
        archive_lock
        ;;

    *)
        archive_unlock
        COMMAND="show";
        cmd_show "$@"
        ;;
esac

[[ -n $WORKDIR ]] && rm -rf $WORKDIR

exit 0
