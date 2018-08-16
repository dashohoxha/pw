#!/bin/bash

# Copyright (C) 2012 - 2014 Jason A. Donenfeld <Jason@zx2c4.com>.
# Copyright (C) 2016 Dashamir Hoxha <dashohoxha@gmail.com>.
# All Rights Reserved. This file is licensed under the GPLv2+.
# Please see COPYING for more information.

PW_DIR="${PW_DIR:-$HOME/.pw}"

LIBDIR="$(dirname "$0")"
PLATFORM="$(uname | cut -d _ -f 1 | tr '[:upper:]' '[:lower:]')"

umask 077
set -o pipefail

# unset global vars, to prevent inheriting from environment
unset TEMPDIR PASSPHRASE GPG_KEYS
unset GIT_DIR GIT_WORK_TREE RUN_SHELL PROGRAM COMMAND

#
# BEGIN helper functions
#

GPG="gpg" ; which gpg2 &>/dev/null && GPG="gpg2"

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
    [[ -d "$TEMPDIR" ]]  || return

    local tar_create="tar --create --gzip --to-stdout"
    local gpg_opts="--quiet --yes --batch --compress-algo=none $GPG_OPTS"
    if symmetric_encryption; then
        get_passphrase
        exec 3< <(cat <<< "$PASSPHRASE")
        $tar_create --directory="$TEMPDIR" . \
            | $GPG --symmetric $gpg_opts \
                   --no-symkey-cache \
                   --passphrase-fd 3 \
                   --output "$ARCHIVE.gpg"
    else
        local recipients=''
        for key in $GPG_KEYS; do recipients="$recipients -r $key"; done
        $tar_create --directory="$TEMPDIR" . \
            | $GPG --encrypt $gpg_opts \
                   --no-encrypt-to \
                   $recipients \
                   --output "$ARCHIVE.gpg"
    fi
}

archive_unlock() {
    [[ -s "$ARCHIVE.gpg" ]] || return

    make_workdir
    export GIT_DIR="$TEMPDIR/.git"
    export GIT_WORK_TREE="$TEMPDIR"

    local tar_extract="tar --extract --gunzip -f-"
    local gpg_opts="--quiet --yes --batch $GPG_OPTS"
    if symmetric_encryption; then
        get_passphrase
        exec 3< <(cat <<< "$PASSPHRASE")
        $GPG $gpg_opts --passphrase-fd 3 -o- "$ARCHIVE.gpg" \
            | $tar_extract --directory="$TEMPDIR"
    else
        $GPG --decrypt $gpg_opts -o- "$ARCHIVE.gpg" \
            | $tar_extract --directory="$TEMPDIR"
    fi
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
symmetric_encryption() {
    [[ -z $GPG_KEYS ]] && return 0
    return 1
}
die() {
    echo "$@" >&2
    exit 1
}
check_sneaky_paths() {
    local path
    for path in "$@"; do
        [[ $path =~ /\.\.$ || $path =~ ^\.\./ || $path =~ /\.\./ || $path =~ ^\.\.$ ]] \
            && die "Error: You've attempted to pass a sneaky path. Go home."
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
    local template="XXXXXXXXXXXXXXXXXXXX"
    if [[ -d /dev/shm && -w /dev/shm && -x /dev/shm ]]; then
        TEMPDIR="$(mktemp -d "/dev/shm/$template")"
        remove_tempdir() {
            rm -rf "$TEMPDIR"
        }
        trap remove_tempdir INT TERM EXIT
    else
        if [[ $warn -eq 1 ]]; then
            yesno "$(cat <<- _EOF
Your system does not have /dev/shm, which means that it may
be difficult to entirely erase the temporary non-encrypted
password directory after editing.

Are you sure you would like to continue?
_EOF
                    )" || return
        fi
        TEMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/$template")"
        shred_tmpfile() {
            find "$TEMPDIR" -type f -exec $SHRED {} +
            rm -rf "$TEMPDIR"
        }
        trap shred_tmpfile INT TERM EXIT
    fi
    [[ -d "$TEMPDIR" ]]  || exit 1
}

GETOPT="getopt"
SHRED="shred -f -z"

platform_file="$LIBDIR/platform/$PLATFORM.sh"
[[ -f "$platform_file" ]] && source "$platform_file"

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
        =               v1.2               =
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

    set pwfile [-e,--echo | -m,--multiline] [-f,--force]
        Insert new password. Optionally, echo the password back to the
        console during entry. Or, optionally, the entry may be multiline.
        Prompt before overwriting existing password unless forced.

    edit pwfile
        Edit or add a password file using ${EDITOR:-vi}.

    grep search-string
        Search for password files containing search-string when decrypted.

    rm pwfile [-r,--recursive] [-f,--force]
        Remove existing password file or directory, optionally forcefully.

    mv old-path new-path [-f,--force]
        Rename or move old-path to new-path, optionally forcefully.

    cp old-path new-path [-f,--force]
        Copy old-path to new-path, optionally forcefully.

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

External commands:

    gen pwfile [length] [-n,--no-symbols] [-i,--in-place | -f,--force]
        Generate a new password with optionally no symbols.  Put it on
        the clipboard and clear board after $CLIP_TIME seconds.
        Prompt before overwriting existing password unless forced.
        Optionally replace only the first line of an existing file
        with a new password.

    find pattern
        List pwfiles that match pattern.

    field pwfile field-name
        Display the value of the given field from pwfile. The field
        name starts at the begining of line and ends with a column,
        for example: 'username: ...' or 'url: ...'.

    qr pwfile
        Display the password as a QR image.

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

    archive_unlock    # extract to $TEMPDIR
    if [[ -f "$TEMPDIR/$path" ]]; then
        cat "$TEMPDIR/$path" || return
    elif [[ -d "$TEMPDIR/$path" ]]; then
        if [[ $tree -eq 0 ]]; then
            find "$TEMPDIR/$path" -name '.git' -prune -or -type f | sed -e "s#$TEMPDIR/##" -e '/\.git/d'
        else
            [[ -n $path ]] && echo "${path%\/}"
            tree -C -l --noreport "$TEMPDIR/$path" | tail -n +2
        fi
    else
        echo "Error: $path is not in the password store."
    fi
    rm -rf "$TEMPDIR"   # cleanup
}

cmd_get() {
    local path="$1"
    check_sneaky_paths "$path"

    archive_unlock    # extract to $TEMPDIR
    if [[ -f "$TEMPDIR/$path" ]]; then
        local pass="$(cat "$TEMPDIR/$path" | head -n 1)"
        [[ -n "$pass" ]] \
            && if [[ -t 0 || -z $RUN_SHELL ]]; then clip "$pass" "$path"; else echo "$pass"; fi
    else
        echo "Error: $path is not in the password store."
    fi
    rm -rf "$TEMPDIR"   # cleanup
}

cmd_show() {
    local path="$1"
    check_sneaky_paths "$path"

    archive_unlock    # extract to $TEMPDIR
    if [[ -f "$TEMPDIR/$path" ]]; then
        cat "$TEMPDIR/$path"
    elif [[ -d "$TEMPDIR/$path" ]]; then
        cmd_list "$path"
    else
        echo "Error: $path is not in the password store."
    fi
    rm -rf "$TEMPDIR"   # cleanup
}

cmd_grep() {
    [[ $# -ne 1 ]] && echo "Usage: $COMMAND search-string" && return
    local search="$1"
    archive_unlock    # extract to $TEMPDIR
    grep --color=always "$search" --exclude-dir=.git --recursive "$TEMPDIR" | sed -e "s#$TEMPDIR/##"
    rm -rf "$TEMPDIR"   # cleanup
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

    archive_unlock    # extract to $TEMPDIR

    local path="$1"
    check_sneaky_paths "$path"
    if [[ $force -eq 0 && -e "$TEMPDIR/$path" ]]; then
        yesno "An entry already exists for $path. Overwrite it?" || return
    fi
    mkdir -p "$TEMPDIR/$(dirname "$path")" || return

    if [[ $multiline -eq 1 ]]; then
        echo "Enter contents of $path and press Ctrl+D when finished:"
        echo
        cat > "$TEMPDIR/$path" || return
    elif [[ $noecho -eq 1 ]]; then
        local password password_again
        while true; do
            read -r -p "Enter password for $path: " -s password || return
            echo
            read -r -p "Retype password for $path: " -s password_again || return
            echo
            if [[ "$password" == "$password_again" ]]; then
                cat <<< "$password" > "$TEMPDIR/$path"
                break
            else
                echo "Error: the entered passwords do not match."
            fi
        done
    else
        local password
        read -r -p "Enter password for $path: " -e password
        cat <<< "$password" > "$TEMPDIR/$path"
    fi
    git_add_file "$TEMPDIR/$path" "Add given password for $path."

    archive_lock      # cleanup $TEMPDIR
}

cmd_edit() {
    # get the path of the file to be edited
    [[ $# -ne 1 ]] && echo "Usage: $COMMAND pwfile" && return
    local path="$1"
    check_sneaky_paths "$path"

    # get the content of the file to be edited
    archive_unlock    # extract to $TEMPDIR
    mkdir -p "$TEMPDIR/$(dirname "$path")"
    local action="Add" ; [[ -f "$TEMPDIR/$path" ]] && action="Edit"
    touch "$TEMPDIR/$path"
    local file_content="$(cat "$TEMPDIR/$path")"
    archive_lock      # cleanup $TEMPDIR

    # edit the content of the file
    make_workdir
    mkdir -p "$TEMPDIR/$(dirname "$path")"
    cat <<EOF > "$TEMPDIR/$path"
$file_content
EOF
    ${EDITOR:-vi} "$TEMPDIR/$path"
    file_content="$(cat "$TEMPDIR/$path")"
    rm -rf "$TEMPDIR"
    unset TEMPDIR

    # save the edited content of the file
    archive_unlock    # extract to $TEMPDIR
    cat <<EOF > "$TEMPDIR/$path"
$file_content
EOF
    git_add_file "$TEMPDIR/$path" "$action password for $path using ${EDITOR:-vi}."
    archive_lock      # cleanup $TEMPDIR
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

    archive_unlock    # extract to $TEMPDIR

    local pwfile="$TEMPDIR/${path%/}"
    if [[ ! -d "$pwfile" ]]; then
        pwfile="$TEMPDIR/$path"
        if [[ ! -f "$pwfile" ]]; then
            echo "Error: $path is not in the password store."
            rm -rf "$TEMPDIR"  # cleanup $TEMPDIR
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

    archive_lock      # cleanup $TEMPDIR
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

    archive_unlock    # extract to $TEMPDIR

    local old_path="$TEMPDIR/${1%/}"
    local new_path="$TEMPDIR/$2"
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

    archive_lock      # cleanup $TEMPDIR
}

cmd_git() {
    archive_unlock    # extract to $TEMPDIR

    if [[ $1 == "init" ]]; then
        git "$@" >/dev/null || return
        git_add_file "$TEMPDIR" "Initialization."
    elif [[ -d "$GIT_DIR" ]]; then
        export TMPDIR="$TEMPDIR"
        git "$@"
    else
        echo "Error: the password store is not a git repository."
    fi
    archive_lock      # cleanup $TEMPDIR
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
    GPG_KEYS="$*"
    [[ -z $GPG_KEYS ]] && gen_gpg_key
    unset PASSPHRASE
    archive_lock
    cat <<<"GPG_KEYS=\"$GPG_KEYS\"" > "$ARCHIVE.gpg.keys"
}
gen_gpg_key() {
    local homedir="$PW_DIR/.gnupg"
    if [[ -d "$homedir" ]]; then
        GPG_KEYS=$($GPG --homedir "$homedir" --list-keys --with-colons | grep '^pub:' | cut -d':' -f5)
        [[ -n "$GPG_KEYS" ]] && return
    fi
    mkdir -p "$homedir"
    GPG_OPTS="$GPG_OPTS --homedir $homedir"
    sed -i "$PW_DIR/config.sh" -e "/GPG_OPTS=/c GPG_OPTS=\"$GPG_OPTS\""
    $GPG $GPG_OPTS --gen-key
    GPG_KEYS=$($GPG --homedir "$homedir" --list-keys --with-colons | grep '^pub:' | cut -d':' -f5)
}

cmd_export() {
    local path=$1
    [[ ! -d "$path" ]] && echo "Usage: $COMMAND dirpath" && return

    archive_unlock || return
    cp -a "$TEMPDIR"/* "$path/"
    cp -a "$TEMPDIR/.git" "$path/"
    rm -rf "$TEMPDIR"
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
        mkdir -p "$(dirname "$TEMPDIR/$pwfile")"
        cat "$path/$pwfile" > "$TEMPDIR/$pwfile"
        git_add_file "$TEMPDIR/$pwfile" "Import $pwfile."
    done
    archive_lock
}

#
# END subcommand functions
#

# The file 'customize.sh' can be used to redefine
# and customize some functions, without having to
# touch the code of the main script.
customize_file="$PW_DIR/customize.sh"
[[ -f "$customize_file" ]] && source "$customize_file"

run_cmd() {
    local cmd="$1" ; shift
    case "$cmd" in
        '')                      run_shell ;;
        help|-h|--help)          cmd_help "$@" ;;
        v|-v|version|--version)  cmd_version "$@" ;;
        ls|list)                 cmd_list "$@" ;;
        get)                     cmd_get "$@" ;;
        show)                    cmd_show "$@" ;;
        grep)                    cmd_grep "$@" ;;
        set)                     cmd_set "$@" ;;
        edit)                    cmd_edit "$@" ;;
        #gen|generate)            cmd_generate "$@" ;;
        del|delete|rm|remove)    cmd_delete "$@" ;;
        mv|rename)               cmd_copy_move "move" "$@" ;;
        cp|copy)                 cmd_copy_move "copy" "$@" ;;
        log)                     cmd_log "$@" ;;
        pass|set-passphrase)     cmd_set_passphrase "$@" ;;
        keys|set-keys)           cmd_set_gpg_keys "$@" ;;
        export)                  cmd_export "$@" ;;
        import)                  cmd_import "$@" ;;
        *)                       try_ext_cmd $cmd "$@" ;;
    esac

    # cleanup the temporary workdir, if it is still there
    [[ -n "$TEMPDIR" ]] && rm -rf "$TEMPDIR"
}
run_shell() {
    RUN_SHELL='true'
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
    [[ -t 0 ]] || return
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
    [[ -n $TIMEOUT_PID ]] && kill $TIMEOUT_PID && wait $TIMEOUT_PID 2>/dev/null
}

try_ext_cmd() {
    local cmd=$1; shift

    # try '~/.pw/cmd_xyz.sh'
    if [[ -f "$PW_DIR/cmd_$cmd.sh" ]]; then
        debug loading: "$PW_DIR/cmd_$cmd.sh"
        source "$PW_DIR/cmd_$cmd.sh"
        debug running: cmd_$cmd "$@"
        cmd_$cmd "$@"
        return
    fi

    # try 'src/ext/platform/cmd_xyz.sh'
    if [[ -f "$LIBDIR/ext/$PLATFORM/cmd_$cmd.sh" ]]; then
        debug loading: "$LIBDIR/ext/$PLATFORM/cmd_$cmd.sh"
        source "$LIBDIR/ext/$PLATFORM/cmd_$cmd.sh"
        debug running: cmd_$cmd "$@"
        cmd_$cmd "$@"
        return
    fi

    # try 'src/ext/cmd_xyz.sh'
    if [[ -f "$LIBDIR/ext/cmd_$cmd.sh" ]]; then
        debug loading: "$LIBDIR/ext/cmd_$cmd.sh"
        source "$LIBDIR/ext/cmd_$cmd.sh"
        debug running: cmd_$cmd "$@"
        cmd_$cmd "$@"
        return
    fi

    # try to show the entry
    cmd_get $cmd
}

debug() {
    [[ -z $DEBUG ]] && return
    echo "$@"
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

# Additional GnuPG options (like --homedir).
GPG_OPTS=""

# Enable debug output
DEBUG=
_EOF
    source "$config_file"

    # set defaults, if some configurations are missing
    ARCHIVE=${ARCHIVE:-pw}
    X_SELECTION="${X_SELECTION:-clipboard}"
    CLIP_TIME="${CLIP_TIME:-45}"
    TIMEOUT=${TIMEOUT:-300}  # default 5 min
    GPG_OPTS=${GPG_OPTS:-}
    DEBUG=${DEBUG:-}
}

main() {
    case "$1" in
        v|-v|version|--version)  cmd_version "$@" ; exit 0 ;;
        help|-h|--help)          cmd_help "$@" ; exit 0 ;;
    esac

    config

    PROGRAM="${0##*/}"

    # get the archive
    local archive=pw
    if [[ $1 == '-a' ]]; then
        [[ -n $2 ]] || die "Usage: $PROGRAM [-a <archive>] [<command> <options>]"
        archive=$2
        shift 2
    fi
    ARCHIVE="$PW_DIR/$archive.tgz"
    [[ -f "$ARCHIVE.gpg" ]] || archive_init
    [[ -f "$ARCHIVE.gpg.keys" ]] &&  source "$ARCHIVE.gpg.keys"    # get GPG_KEYS

    COMMAND="$PROGRAM $1"
    run_cmd "$@"

    timeout_clear
    exit 0
}

main "$@"
