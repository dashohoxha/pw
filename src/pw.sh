#!/usr/bin/env bash

# Copyright (C) 2012 - 2014 Jason A. Donenfeld <Jason@zx2c4.com>.
# Copyright (C) 2016 Dashamir Hoxha <dashohoxha@gmail.com>.
# All Rights Reserved. This file is licensed under the GPLv2+.
# Please see COPYING for more information.

PW_DIR="${PW_DIR:-$HOME/.pw}"

umask 077
set -o pipefail

#
# BEGIN helper functions
#

GPG="gpg" ; which gpg2 &>/dev/null && GPG="gpg2"

encrypt() {
    local archive=$1
    local opts="--quiet --yes --batch --compress-algo=none $GPG_OPTS"
    if [[ -z $GPG_KEYS ]]; then
        $GPG --symmetric $opts --cipher-algo=AES256 \
            --passphrase-fd 0 "$archive" <<< "$PASSPHRASE"
    else
        local recipients=''
        for key in $GPG_KEYS; do recipients="$recipients -r $key"; done
        $GPG --encrypt $opts --use-agent --no-encrypt-to \
            $recipients "$archive"
    fi
}
decrypt() {
    local archive=$1
    local opts="--quiet --yes --batch $GPG_OPTS"
    if [[ -z $GPG_KEYS ]]; then
        $GPG $opts --passphrase-fd 0 "$archive.gpg" <<< "$PASSPHRASE"
    else
        $GPG --decrypt $opts --use-agent --output="$archive" "$archive.gpg"
    fi
}

get_passphrase() {
    [[ -z $GPG_KEYS ]] || return
    [[ -z $PASSPHRASE ]] || return
    read -r -p "Passphrase for archive '$ARCHIVE': " -s PASSPHRASE || exit 1
    [[ -t 0 ]] && echo
}
new_passphrase() {
    local passphrase passphrase_again
    while true; do
        read -r -p "Enter new passphrase for archive '$ARCHIVE': " -s passphrase || return
        echo
        read -r -p "Retype the passphrase for archive '$ARCHIVE': " -s passphrase_again || return
        echo
        if [[ "$passphrase" == "$passphrase_again" ]]; then
            PASSPHRASE="$passphrase"
            break
        else
            echo "Error: the entered passphrases do not match."
        fi
    done
}

archive_init() {
    echo "Creating a new archive '$ARCHIVE'."
    new_passphrase
    mkdir -p "$PW_DIR"
    make_workdir
    archive_lock
    cmd_git init
}
archive_lock() {
    [[ -d "$WORKDIR" ]]  || return

    get_passphrase
    tar -czf "$ARCHIVE" -C "$WORKDIR" . >/dev/null 2>&1
    encrypt "$ARCHIVE"
    local err=$?

    rm -rf "$WORKDIR" "$ARCHIVE"
    unset WORKDIR

    [[ $err -ne 0 ]] && exit $err
}
archive_unlock() {
    [[ -s "$ARCHIVE.gpg" ]] || return

    make_workdir
    [[ -d "$WORKDIR" ]]  || exit 1
    export GIT_DIR="$WORKDIR/.git"
    export GIT_WORK_TREE="$WORKDIR"

    get_passphrase
    decrypt "$ARCHIVE"
    local err=$?
    [[ $err -ne 0 ]] && exit $err
    tar -xzf "$ARCHIVE" -C "$WORKDIR" >/dev/null 2>&1
    rm -f "$ARCHIVE"
}

git_add_file() {
    [[ -d "$GIT_DIR" ]] || return
    git add "$1" >/dev/null || return
    [[ -n $(git status --porcelain "$1") ]] || return
    git_commit "$2"
}
git_commit() {
    [[ -d "$GIT_DIR" ]] || return
    git commit -m "$1" >/dev/null
}
yesno() {
    local response
    read -r -p "$1 [y/N] " response
    [[ $response == [yY] ]] || return 1
}
die() {
    echo "$@" >&2
    exit 1
}
check_sneaky_paths() {
    local path
    for path in "$@"; do
        [[ $path =~ /\.\.$ || $path =~ ^\.\./ || $path =~ /\.\./ || $path =~ ^\.\.$ ]] && die "Error: You've attempted to pass a sneaky path. Go home."
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
    echo -n "$1" | xclip -selection "$X_SELECTION" \
        || { echo "Error: Could not copy data to the clipboard"; return; }
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
    echo "Password of $2 sent to clipboard. Will clear in $CLIP_TIME seconds."
}

make_workdir() {
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
        if [[ $warn -eq 1 ]]; then
            yesno "$(cat <<- _EOF
Your system does not have /dev/shm, which means that it may
be difficult to entirely erase the temporary non-encrypted
password file after editing.

Are you sure you would like to continue?
_EOF
                    )" || return
        fi
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
        ====================================
        = pw: a simple password manager    =
        =                                  =
        =               v0.9               =
        =                                  =
        = https://github.com/dashohoxha/pw =
        ====================================
_EOF
}

cmd_help() {
    cat <<-_EOF

Usage: $PROGRAM [-a <archive>] [<command> <options>]

Commands and their options are listed below.

    ls [path] [-t,--tree]
        List password files, optionally as a tree.

    [get] pwfile
        Copy to clipboard the password (it will be cleared in $CLIP_TIME seconds).

    show pwfile
        Print out the password contained in the given file.

    gen pwfile [length] [-n,--no-symbols] [-i,--in-place | -f,--force]
        Generate a new password with optionally no symbols.  Put it on
        the clipboard and clear board after $CLIP_TIME seconds.
        Prompt before overwriting existing password unless forced.
        Optionally replace only the first line of an existing file
        with a new password.

    set pwfile [-e,--echo | -m,--multiline] [-f,--force]
        Insert new password. Optionally, echo the password back to the
        console during entry. Or, optionally, the entry may be multiline.
        Prompt before overwriting existing password unless forced.

    edit pwfile
        Edit or add a password file using ${EDITOR:-vi}.

    find pattern [-t,--tree]
        List pwfiles that match pattern, optionally in tree format.

    grep search-string
        Search for password files containing search-string when decrypted.

    rm [-r,--recursive] [-f,--force] pwfile
        Remove existing password file or directory, optionally forcefully.

    mv [-f,--force] old-path new-path
        Renames or moves old-path to new-path, optionally forcefully.

    cp [-f,--force] old-path new-path
        Copies old-path to new-path, optionally forcefully.

    log [-10]
        List the history of (last 10) changes.

    pass,set-passphrase
        Set the passphrase of the archive (gpg symmetric encryption).

    keys,set-keys [gpg-key]...
        Set the gpg key(s) of the archive (asymmetric encryption).
        Note: Symmetric and asymmetric encryption are exclusive; either
        you use a passphrase (for symmetric encryption), or gpg key(s)
        (for asymmetric encryption).

    export dirpath
        Export the content of the archive to the given directory.

    import dirpath
        Import the content of the archive from the given directory.

    help
        Show this help text.

    version
        Show version information.

More information may be found in the pw(1) man page.

_EOF
}

cmd_list() {
    local opts tree=0
    opts="$($GETOPT -o t -l tree -n "$PROGRAM" -- "$@")"
    local err=$?
    eval set -- "$opts"
    while true; do
        case $1 in
            -t|--tree) tree=1; shift ;;
            --) shift; break ;;
        esac
    done
    [[ $err -ne 0 ]] && echo "Usage: $COMMAND [path] [-t,--tree]" && return

    local path="$1"
    check_sneaky_paths "$path"

    archive_unlock    # extract to $WORKDIR
    if [[ -f "$WORKDIR/$path" ]]; then
        cat "$WORKDIR/$path" || return
    elif [[ -d "$WORKDIR/$path" ]]; then
        if [[ $tree -eq 0 ]]; then
            find "$WORKDIR/$path" -name '.git' -prune -or -type f | sed -e "s#$WORKDIR/##" -e '/\.git/d'
        else
            [[ -n $path ]] && echo "${path%\/}"
            tree -C -l --noreport "$WORKDIR/$path" | tail -n +2
        fi
    else
        echo "Error: $path is not in the password store."
    fi
    rm -rf "$WORKDIR"   # cleanup
}

cmd_get() {
    local path="$1"
    check_sneaky_paths "$path"

    archive_unlock    # extract to $WORKDIR
    if [[ -f "$WORKDIR/$path" ]]; then
        local pass="$(cat "$WORKDIR/$path" | head -n 1)"
        [[ -n "$pass" ]] && clip "$pass" "$path"
    else
        echo "Error: $path is not in the password store."
    fi
    rm -rf "$WORKDIR"   # cleanup
}

cmd_show() {
    local path="$1"
    check_sneaky_paths "$path"

    archive_unlock    # extract to $WORKDIR
    if [[ -f "$WORKDIR/$path" ]]; then
        cat "$WORKDIR/$path"
    elif [[ -d "$WORKDIR/$path" ]]; then
        cmd_list "$path"
    else
        echo "Error: $path is not in the password store."
    fi
    rm -rf "$WORKDIR"   # cleanup
}

cmd_find() {
    local opts tree=0
    opts="$($GETOPT -o t -l tree -n "$PROGRAM" -- "$@")"
    local err=$?
    eval set -- "$opts"
    while true; do
        case $1 in
            -t|--tree) tree=1; shift ;;
            --) shift; break ;;
        esac
    done
    [[ $err -ne 0 || $# -eq 0 ]] && echo "Usage: $COMMAND pattern [-t,--tree]" && return

    archive_unlock    # extract to $WORKDIR
    if [[ $tree -eq 0 ]]; then
        pattern="*${1}*"
        find "$WORKDIR" -name '.git' -prune -or \( -type f -and -name "$pattern" \) \
            | sed -e "s#$WORKDIR/##" -e '/\.git/d'
    else
        IFS="," eval 'echo "Search Terms: $*"'
        local terms="*$(printf '%s*|*' "$@")"
        tree -C -l --noreport -P "${terms%|*}" --prune "$WORKDIR" | tail -n +2
    fi
    rm -rf "$WORKDIR"   # cleanup
}

cmd_grep() {
    [[ $# -ne 1 ]] && echo "Usage: $COMMAND search-string" && return
    local search="$1"
    archive_unlock    # extract to $WORKDIR
    grep --color=always "$search" --exclude-dir=.git --recursive "$WORKDIR" | sed -e "s#$WORKDIR/##"
    rm -rf "$WORKDIR"   # cleanup
}

cmd_set() {
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
    [[ $err -ne 0 || ( $multiline -eq 1 && $noecho -eq 0 ) || $# -ne 1 ]] \
        && echo "Usage: $COMMAND pwfile [-e,--echo | -m,--multiline] [-f,--force]" \
        && return

    archive_unlock    # extract to $WORKDIR

    local path="$1"
    check_sneaky_paths "$path"
    if [[ $force -eq 0 && -e "$WORKDIR/$path" ]]; then
        yesno "An entry already exists for $path. Overwrite it?" || return
    fi
    mkdir -p "$WORKDIR/$(dirname "$path")" || return

    if [[ $multiline -eq 1 ]]; then
        echo "Enter contents of $path and press Ctrl+D when finished:"
        echo
        cat > "$WORKDIR/$path" || return
    elif [[ $noecho -eq 1 ]]; then
        local password password_again
        while true; do
            read -r -p "Enter password for $path: " -s password || return
            echo
            read -r -p "Retype password for $path: " -s password_again || return
            echo
            if [[ "$password" == "$password_again" ]]; then
                cat <<< "$password" > "$WORKDIR/$path"
                break
            else
                echo "Error: the entered passwords do not match."
            fi
        done
    else
        local password
        read -r -p "Enter password for $path: " -e password
        cat <<< "$password" > "$WORKDIR/$path"
    fi
    git_add_file "$WORKDIR/$path" "Add given password for $path."

    archive_lock      # cleanup $WORKDIR
}

cmd_edit() {
    [[ $# -ne 1 ]] && echo "Usage: $COMMAND pwfile" && return

    archive_unlock    # extract to $WORKDIR

    local path="$1"
    check_sneaky_paths "$path"
    mkdir -p "$WORKDIR/$(dirname "$path")"
    local action="Add" ; [[ -f "$WORKDIR/$path" ]] && action="Edit"
    ${EDITOR:-vi} "$WORKDIR/$path"
    git_add_file "$WORKDIR/$path" "$action password for $path using ${EDITOR:-vi}."

    archive_lock      # cleanup $WORKDIR
}

cmd_generate() {
    local opts force=0 symbols="-y" inplace=0
    opts="$($GETOPT -o nif -l no-symbols,in-place,force -n "$PROGRAM" -- "$@")"
    local err=$?
    eval set -- "$opts"
    while true; do
        case $1 in
            -n|--no-symbols) symbols=""; shift ;;
            -f|--force) force=1; shift ;;
            -i|--in-place) inplace=1; shift ;;
            --) shift; break ;;
        esac
    done

    [[ $err -ne 0 || $# -lt 1 || ( $force -eq 1 && $inplace -eq 1 ) ]] \
        && echo "Usage: $COMMAND pwfile [length] [-n,--no-symbols] [-i,--in-place | -f,--force]" \
        && return

    local path="$1"
    local length="${2:-30}"    # default length 30
    check_sneaky_paths "$path"
    [[ ! $length =~ ^[0-9]+$ ]] \
        && echo "Error: pass-length \"$length\" must be a number." \
        && return

    archive_unlock    # extract to $WORKDIR

    mkdir -p "$WORKDIR/$(dirname "$path")"
    local pwfile="$WORKDIR/$path"

    if [[ $inplace -eq 0 && $force -eq 0 && -e $pwfile ]]; then
        yesno "An entry already exists for $path. Overwrite it?" || return
    fi

    local pass="$(pwgen -s $symbols $length 1)"
    [[ -n $pass ]] || return
    if [[ $inplace -eq 0 ]]; then
        cat <<< "$pass" > "$pwfile"
    else
        local pwfile_temp="${pwfile}.tmp.${RANDOM}.${RANDOM}.${RANDOM}.${RANDOM}.--"
        cat "$pwfile" | sed $'1c \\\n'"$(sed 's/[\/&]/\\&/g' <<<"$pass")"$'\n' > "$pwfile_temp"
        mv "$pwfile_temp" "$pwfile"
        rm -f "$pwfile_temp"
    fi
    clip "$pass" "$path"

    local verb="Add" ; [[ $inplace -eq 1 ]] && verb="Replace"
    git_add_file "$pwfile" "$verb generated password for ${path}."

    archive_lock      # cleanup $WORKDIR
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
    [[ $# -ne 1 ]] && echo "Usage: $COMMAND pwfile [-r,--recursive] [-f,--force]" && return
    local path="$1"
    check_sneaky_paths "$path"

    archive_unlock    # extract to $WORKDIR

    local pwfile="$WORKDIR/${path%/}"
    if [[ ! -d "$pwfile" ]]; then
        pwfile="$WORKDIR/$path"
        if [[ ! -f "$pwfile" ]]; then
            echo "Error: $path is not in the password store."
            rm -rf "$WORKDIR"  # cleanup $WORKDIR
            return
        fi
    fi

    if [[ $force -ne 1 ]]; then
        yesno "Are you sure you would like to delete $path?" || return
    fi

    rm $recursive -f "$pwfile"
    if [[ -d $GIT_DIR && ! -e $pwfile ]]; then
        git rm -qr "$pwfile" >/dev/null
        git_commit "Remove $path from store."
    fi
    rmdir -p "${pwfile%/*}" 2>/dev/null

    archive_lock      # cleanup $WORKDIR
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
    [[ $# -ne 2 ]] && echo "Usage: $COMMAND old-path new-path [-f,--force]" && return
    check_sneaky_paths "$@"

    archive_unlock    # extract to $WORKDIR

    local old_path="$WORKDIR/${1%/}"
    local new_path="$WORKDIR/$2"
    local old_dir="$old_path"

    if [[ ! -d "$old_path" ]]; then
        old_dir="${old_path%/*}"
        old_path="${old_path}"
        [[ ! -f "$old_path" ]] && echo "Error: $1 is not in the password store." && return
    fi

    [[ -d "$old_path" || -d "$new_path" || "$new_path" =~ /$ ]] || new_path="${new_path}"
    if [[ $force -eq 0 ]]; then
        if [[ -f "$new_path" ]] || [[ -d "$new_path" ]]; then
            yesno "An entry for $2 already exists. Continue?" || return
        fi
    fi
    mkdir -p "${new_path%/*}"

    if [[ $move -eq 1 ]]; then
        mv -f "$old_path" "$new_path" || return

        if [[ -d "$GIT_DIR" && ! -e "$old_path" ]]; then
            git rm -qr "$old_path" >/dev/null
            git_add_file "$new_path" "Rename ${1} to ${2}."
        fi
        rmdir -p "$old_dir" 2>/dev/null
    else
        cp -rf "$old_path" "$new_path" || return
        git_add_file "$new_path" "Copy ${1} to ${2}."
    fi

    archive_lock      # cleanup $WORKDIR
}

cmd_git() {
    archive_unlock    # extract to $WORKDIR

    if [[ $1 == "init" ]]; then
        git "$@" >/dev/null || return
        git_add_file "$WORKDIR" "Initialization."
    elif [[ -d "$GIT_DIR" ]]; then
        export TMPDIR="$WORKDIR"
        git "$@"
    else
        echo "Error: the password store is not a git repository."
    fi
    archive_lock      # cleanup $WORKDIR
}
cmd_log() {
    cmd_git log --pretty=format:"%ar: %s" --reverse "$@"
}

cmd_set_passphrase() {
    archive_unlock || return
    new_passphrase
    unset GPG_KEYS
    archive_lock
    rm -f "$ARCHIVE.gpg.keys"
}

cmd_set_gpg_keys() {
    archive_unlock || return
    GPG_KEYS="$@"
    [[ -z $GPG_KEYS ]] && $GPG --gen-key
    unset PASSPHRASE
    archive_lock
    cat <<<"GPG_KEYS=\"$GPG_KEYS\"" > "$ARCHIVE.gpg.keys"
}

cmd_export() {
    local path=$1
    [[ ! -d "$path" ]] && echo "Usage: $COMMAND dirpath" && return

    archive_unlock || return
    cp -a "$WORKDIR"/* "$path/"
    cp -a "$WORKDIR/.git" "$path/"
    rm -rf "$WORKDIR"
}

cmd_import() {
    local path=$1
    [[ ! -d "$path" ]] && echo "Usage: $COMMAND dirpath" && return
    path=${path%/}

    archive_unlock || return
    find "$path" -name '.git' -prune -or -type f \
        | sed -e '/\.git$/d' -e "s#$path/##" \
        | while read pwfile
    do
        echo "$pwfile"
        mkdir -p "$(dirname "$WORKDIR/$pwfile")"
        cat "$path/$pwfile" > "$WORKDIR/$pwfile"
        git_add_file "$WORKDIR/$pwfile" "Import $pwfile."
    done
    archive_lock
}

#
# END subcommand functions
#

run_cmd() {
    local cmd="$1" ; shift
    case "$cmd" in
        '')                      run_shell ;;
        help|-h|--help)          cmd_help "$@" ;;
        v|-v|version|--version)  cmd_version "$@" ;;
        ls|list)                 cmd_list "$@" ;;
        get)                     cmd_get "$@" ;;
        show)                    cmd_show "$@" ;;
        find|search)             cmd_find "$@" ;;
        grep)                    cmd_grep "$@" ;;
        set)                     cmd_set "$@" ;;
        edit)                    cmd_edit "$@" ;;
        gen|generate)            cmd_generate "$@" ;;
        del|delete|rm|remove)    cmd_delete "$@" ;;
        mv|rename)               cmd_copy_move "move" "$@" ;;
        cp|copy)                 cmd_copy_move "copy" "$@" ;;
        log)                     cmd_log "$@" ;;
        pass|set-passphrase)     cmd_set_passphrase "$@" ;;
        keys|set-keys)           cmd_set_gpg_keys "$@" ;;
        export)                  cmd_export "$@" ;;
        import)                  cmd_import "$@" ;;
        *)       COMMAND="get" ; cmd_get "$cmd" ;;
    esac

    # cleanup the temporary workdir, if it is still there
    [[ -n "$WORKDIR" ]] && rm -rf "$WORKDIR"
}
run_shell() {
    get_passphrase
    list_commands
    timeout_start
    while true; do
        read -e -p 'pw> ' command options
        COMMAND=$command
        case "$command" in
            q)   return ;;
            p)   cmd_set_passphrase ;;
            '')  list_commands ;;
            *)   run_cmd $command $options ;;
        esac
        timeout_start
    done
}
list_commands() {
    cat <<-_EOF
Commands:
    gen, set, ls, get, show, edit, find, grep, rm, mv, cp, log, help
Type q to quit, p to change the passphrase.
_EOF
}
timeout_start() {
    timeout_clear
    timeout_wait $$ &
    TIMEOUT_PID=$!
}
timeout_wait() {
    sleep $TIMEOUT
    echo -e "\nTimeout"
    kill -9 "$1" >/dev/null 2>&1
}
timeout_clear() {
    [[ -n $TIMEOUT_PID ]] && kill $TIMEOUT_PID
}

config() {
    [[ -d "$PW_DIR" ]] || mkdir -p "$PW_DIR"

    # read the config file
    local config_file="$PW_DIR/config.sh"
    [[ -f "$config_file" ]] || cat <<-_EOF > "$config_file"
# Default archive, if no -a option is given.
ARCHIVE=pw

# Clipboard related.
X_SELECTION=clipboard
CLIP_TIME=45

# Shell will time out after this many seconds of inactivity.
TIMEOUT=300  # 5 min

# May be needed for asymmetric encryption.
GPG_OPTS=
_EOF
    source "$config_file"

    # set defaults, if some configurations are missing
    ARCHIVE=${ARCHIVE:-pw}
    X_SELECTION="${X_SELECTION:-clipboard}"
    CLIP_TIME="${CLIP_TIME:-45}"
    TIMEOUT=${TIMEOUT:-300}  # default 5 min
}

main() {
    case "$1" in
        v|-v|version|--version)  cmd_version "$@" ; exit 0 ;;
        help|-h|--help)          cmd_help "$@" ; exit 0 ;;
    esac

    config

    PROGRAM="${0##*/}"

    # get the archive
    if [[ $1 == '-a' ]]; then
        [[ -z $2 ]] && echo "Usage: $PROGRAM [-a <archive>] [<command> <options>]" && exit 1
        ARCHIVE=$2
        shift 2
    fi
    ARCHIVE="$PW_DIR/$ARCHIVE.tgz"
    [[ -f "$ARCHIVE.gpg" ]] || archive_init
    [[ -f "$ARCHIVE.gpg.keys" ]] &&  source "$ARCHIVE.gpg.keys"    # get GPG_KEYS

    COMMAND="$PROGRAM $1"
    run_cmd "$@"

    timeout_clear
    exit 0
}

main "$@"
