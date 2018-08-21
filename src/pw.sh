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
unset GIT_DIR GIT_WORK_TREE PROGRAM COMMAND

#
# BEGIN helper functions
#

get_passphrase() {
    symmetric_encryption || return
    [[ -z $PASSPHRASE ]] || return
    read -r -p "Passphrase for archive '$ARCHIVE': " -s PASSPHRASE || exit 1
    [[ -t 0 ]] && echo
}

new_passphrase() {
    local passphrase passphrase_again
    while true; do
        read -r -p "Enter new passphrase for archive '$ARCHIVE': " -s passphrase || return 1
        echo
        read -r -p "Retype the passphrase for archive '$ARCHIVE': " -s passphrase_again || return 1
        echo
        if [[ "$passphrase" == "$passphrase_again" ]]; then
            PASSPHRASE="$passphrase"
            break
        else
            echo "Error: the entered passphrases do not match."
        fi
    done
}

symmetric_encryption() {
    case $1 in
        enable)
            unset GPG_KEYS
            rm -f "$ARCHIVE.gpg.keys"
            ;;
        disable)
            unset PASSPHRASE
            cat <<<"GPG_KEYS=\"$GPG_KEYS\"" > "$ARCHIVE.gpg.keys"
            ;;
        *)  # test
            [[ -z $GPG_KEYS ]] && return 0
            return 1
            ;;
    esac
}

decrypt() {
    [[ -s "$ARCHIVE.gpg" ]] || return 1

    local gpg="gpg -o- --quiet --yes --batch $GPG_OPTS"
    if symmetric_encryption; then
        [[ -n $PASSPHRASE ]] || return 1
        exec 3< <(cat <<< "$PASSPHRASE")
        $gpg --passphrase-fd 3 "$ARCHIVE.gpg"
    else
        $gpg --decrypt "$ARCHIVE.gpg"
    fi
}

encrypt() {
    local gpg="gpg --quiet --yes --batch --compress-algo=none $GPG_OPTS"
    if symmetric_encryption; then
        [[ -n $PASSPHRASE ]] || return 1
        local gpg_version=$(gpg --version | head -1 | cut -d' ' -f3)
        [[ $gpg_version > '2.2.6' ]] && gpg+=' --no-symkey-cache'
        exec 3< <(cat <<< "$PASSPHRASE")
        $gpg --symmetric --passphrase-fd 3 --output "$ARCHIVE.gpg.1"
    else
        local recipients=''
        for key in $GPG_KEYS; do recipients="$recipients -r $key"; done
        $gpg --encrypt --output "$ARCHIVE.gpg.1" --no-encrypt-to $recipients
    fi
    local err=$?
    [[ $err == 0 ]] || return $err
    [[ -s "$ARCHIVE.gpg.1" ]] && mv -f "$ARCHIVE.gpg.1" "$ARCHIVE.gpg"
}

archive_unlock() {
    [[ -s "$ARCHIVE.gpg" ]] || return 1

    make_tempdir
    [[ -d "$TEMPDIR" ]] || return 1

    export GIT_DIR="$TEMPDIR/.git"
    export GIT_WORK_TREE="$TEMPDIR"

    get_passphrase
    decrypt \
        | tar --gunzip --extract -f- --directory="$TEMPDIR" &>/dev/null
}

archive_lock() {
    [[ -d "$TEMPDIR" ]] || return 1
    get_passphrase
    tar --create --gzip --to-stdout --directory="$TEMPDIR" . \
        | encrypt
    local err=$?
    remove_tempdir
    return $err
}

file_exists() {
    local file="$1"
    get_passphrase
    decrypt | tar --gunzip --list "./$file" &>/dev/null
}

file_extract() {
    local file="$1"
    get_passphrase
    decrypt | tar --gunzip --extract --to-stdout "./$file"
}

git_add_file() {
    [[ -d "$GIT_DIR" ]] || return 1
    git add "$1" >/dev/null || return 1
    [[ -n $(git status --porcelain "$1") ]] || return 1
    git_commit "$2"
}
git_commit() {
    [[ -d "$GIT_DIR" ]] || return 1
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
    local pass="$1"
    local path="$2"

    # xclip works only if there is an X display
    if [[ -z $DISPLAY ]]; then
        echo "$pass"
        return
    fi

    local sleep_argv0="pw sleep on display $DISPLAY"
    pkill -f "^$sleep_argv0" 2>/dev/null && sleep 0.5
    local before="$(xclip -o -selection "$X_SELECTION" 2>/dev/null | base64)"
    echo -n "$pass" | xclip -selection "$X_SELECTION" \
        || { echo "Error: Could not copy data to the clipboard"; return 1; }
    (
        ( exec -a "$sleep_argv0" sleep "$CLIP_TIME" )

        # This base64 business is because bash cannot store binary
        # data in a shell variable. Specifically, it cannot store
        # nulls nor (non-trivally) store trailing new lines.
        local now="$(xclip -o -selection "$X_SELECTION" | base64)"
        [[ $now != $(echo -n "$pass" | base64) ]] && before="$now"

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
    echo "Password of $path sent to clipboard. Will clear in $CLIP_TIME seconds."
}

make_tempdir() {
    local warn=1
    [[ $1 == "nowarn" ]] && warn=0
    local template="XXXXXXXXXXXXXXXXXXXX"
    if [[ -d /dev/shm && -w /dev/shm && -x /dev/shm ]]; then
        TEMPDIR="$(mktemp -d "/dev/shm/$template")"
    else
        if [[ $warn == 1 ]]; then
            yesno "$(cat <<- _EOF
Your system does not have /dev/shm, which means that it may
be difficult to entirely erase the temporary non-encrypted
password directory after editing.

Are you sure you would like to continue?
_EOF
                    )" || return
        fi
        TEMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/$template")"
    fi
    [[ -d "$TEMPDIR" ]]  || exit 1
    trap remove_tempdir INT TERM EXIT
}

remove_tempdir() {
    [[ -d $TEMPDIR ]] || return
    [[ ${TEMPDIR:0:8} == '/dev/shm' || ${TEMPDIR:0:4} == '/tmp' ]] || return 1

    [[ ${TEMPDIR:0:4} == '/tmp' ]] && find "$TEMPDIR" -type f -exec $SHRED {} +
    rm -rf "$TEMPDIR"
    unset TEMPDIR
    trap - INT TERM EXIT
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

    get pwfile
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
    [[ $err != 0 ]] && echo "Usage: $COMMAND [path] [-t,--tree]" && return 1

    local path="$1"
    check_sneaky_paths "$path"

    archive_unlock    # extract to $TEMPDIR
    if [[ -f "$TEMPDIR/$path" ]]; then
        cat "$TEMPDIR/$path"
    elif [[ -d "$TEMPDIR/$path" ]]; then
        if [[ $tree == 0 ]]; then
            find "$TEMPDIR/$path" -name '.git' -prune -or -type f | sed -e "s#$TEMPDIR/##" -e '/\.git/d' | sort
        else
            [[ -n $path ]] && echo "${path%\/}"
            tree -C -l --noreport "$TEMPDIR/$path" | tail -n +2
        fi
    else
        echo "Error: $path is not in the archive."
    fi
    remove_tempdir
}

cmd_get() {
    local path="$1"
    check_sneaky_paths "$path"

    archive_unlock    # extract to $TEMPDIR
    if [[ -f "$TEMPDIR/$path" ]]; then
        local pass="$(cat "$TEMPDIR/$path" | head -n 1)"
        [[ -n "$pass" ]] && clip "$pass" "$path"
    else
        echo "Error: $path is not in the archive."
    fi
    remove_tempdir
}

cmd_show() {
    local path="$1"
    check_sneaky_paths "$path"

    archive_unlock    # extract to $TEMPDIR
    if [[ -f "$TEMPDIR/$path" ]]; then
        cat "$TEMPDIR/$path"
    elif [[ -d "$TEMPDIR/$path" ]]; then
        # list
        find "$TEMPDIR/$path" -name '.git' -prune -or -type f | sed -e "s#$TEMPDIR/##" -e '/\.git/d' | sort
    else
        echo "Error: $path is not in the archive."
    fi
    remove_tempdir
}

cmd_grep() {
    [[ $# != 1 ]] && echo "Usage: $COMMAND search-string" && return 1
    local search="$1"
    archive_unlock    # extract to $TEMPDIR
    grep --color=always "$search" --exclude-dir=.git --recursive "$TEMPDIR" | sed -e "s#$TEMPDIR/##" | sort
    remove_tempdir
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
    [[ $err != 0 || ( $multiline == 1 && $noecho == 0 ) || $# != 1 ]] \
        && echo "Usage: $COMMAND pwfile [-e,--echo | -m,--multiline] [-f,--force]" \
        && return 1

    local path="$1"
    check_sneaky_paths "$path"

    # check whether the file exists
    if file_exists "$path" && [[ $force == 0 ]]; then
        yesno "An entry already exists for $path. Overwrite it?" || return
    fi

    # get the content of the file
    make_tempdir
    mkdir -p "$TEMPDIR/$(dirname "$path")" || return 1
    if [[ $multiline == 1 ]]; then
        echo "Enter contents of $path and press Ctrl+D when finished:"
        cat > "$TEMPDIR/$path" || return 1
    elif [[ $noecho == 1 ]]; then
        local password password_again
        while true; do
            read -r -p "Enter password for $path: " -s password || return 1
            echo
            read -r -p "Retype password for $path: " -s password_again || return 1
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
        read -r -p "Enter password for $path: " -e password || return 1
        cat <<< "$password" > "$TEMPDIR/$path"
    fi
    local file_content=$(cat "$TEMPDIR/$path")
    remove_tempdir

    # store the new file in the archive
    archive_unlock    # extract to $TEMPDIR
    mkdir -p "$TEMPDIR/$(dirname "$path")"
    cat > "$TEMPDIR/$path" <<< "$file_content"
    [[ -s "$TEMPDIR/$path" ]] || err=1
    [[ $err == 0 ]] && git_add_file "$TEMPDIR/$path" "Add given password for $path."
    archive_lock      # cleanup $TEMPDIR
    return $err
}

cmd_edit() {
    # get the path of the file to be edited
    [[ $# != 1 ]] && echo "Usage: $COMMAND pwfile" && return 1
    local path="$1"
    check_sneaky_paths "$path"

    local action="Add" ; file_exists "$path" && action="Edit"

    # get the content of the file to be edited
    local file_content=''
    [[ $action == 'Edit' ]] && file_content=$(file_extract "$path")

    # edit the content of the file
    make_tempdir
    mkdir -p "$TEMPDIR/$(dirname "$path")"
    cat > "$TEMPDIR/$path" <<< "$file_content"
    ${EDITOR:-vi} "$TEMPDIR/$path"
    file_content="$(cat "$TEMPDIR/$path")"
    remove_tempdir

    # save the edited content of the file
    archive_unlock    # extract to $TEMPDIR
    cat > "$TEMPDIR/$path" <<< "$file_content"
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
    [[ $# != 1 ]] && echo "Usage: $COMMAND pwfile [-r,--recursive] [-f,--force]" && return 1
    local path="$1"
    check_sneaky_paths "$path"

    if ! file_exists "$path"; then
        echo "Error: $path is not in the archive."
        return 1
    elif [[ $force != 1 ]]; then
        yesno "Are you sure you would like to delete $path?" || return
    fi

    archive_unlock    # extract to $TEMPDIR

    local pwfile="$TEMPDIR/${path%/}"
    if [[ -d "$pwfile" && -z $recursive ]]; then
        echo "To remove a directory use the option: -r, --recursive"
        remove_tempdir
        return 1
    fi
    rm $recursive -f "$pwfile"
    if [[ -d $GIT_DIR && ! -e $pwfile ]]; then
        git rm -qr "$pwfile" >/dev/null
        git_commit "Remove $path from store."
    fi
    rmdir -p "${pwfile%/*}" 2>/dev/null

    archive_lock
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
    [[ $# != 2 ]] && echo "Usage: $COMMAND old-path new-path [-f,--force]" && return 1
    check_sneaky_paths "$@"

    local src="$1"
    local dst="$2"

    # check whether the source exists
    if ! file_exists "$src"; then
        echo "Error: $src is not in the archive."
        return 1
    fi

    # check whether the destination already exists
    if file_exists "$dst" && [[ $force == 0 ]]; then
        yesno "An entry for $dst already exists. Continue?" || return
    fi

    archive_unlock    # extract to $TEMPDIR
    local old_path="$TEMPDIR/${src%/}"
    local new_path="$TEMPDIR/$dst"
    mkdir -p "${new_path%/*}"
    if [[ $move == 1 ]]; then
        mv -f "$old_path" "$new_path"

        if [[ -d "$GIT_DIR" && ! -e "$old_path" ]]; then
            git rm -qr "$old_path" >/dev/null
            git_add_file "$new_path" "Rename $src to $dst."
        fi
        rmdir -p "$old_path" 2>/dev/null
    else
        cp -rf "$old_path" "$new_path"
        git_add_file "$new_path" "Copy $src to $dst."
    fi
    archive_lock
}

cmd_git() {
    archive_unlock    # extract to $TEMPDIR

    if [[ $1 == "init" ]]; then
        git "$@" >/dev/null || return 1
        git_add_file "$TEMPDIR" "Initialization."
    elif [[ -d "$GIT_DIR" ]]; then
        local tmpdir="$TMPDIR"
        export TMPDIR="$TEMPDIR"
        git "$@"
        export TMPDIR="$tmpdir"
    else
        echo "Error: the archive is not a git repository."
    fi
    archive_lock      # cleanup $TEMPDIR
}
cmd_log() {
    cmd_git log --pretty=format:"%ar: %s" --reverse "$@"
}

cmd_set_passphrase() {
    local passphrase1 passphrase2

    # get and save the current passphrase
    get_passphrase
    [[ -n $PASSPHRASE ]] && passphrase1=$PASSPHRASE

    # get a new passphrase and save it
    new_passphrase
    [[ -z $PASSPHRASE ]] && return 1
    passphrase2=$PASSPHRASE

    # switch back to the current passphrase
    # and unlock the archive
    PASSPHRASE=$passphrase1
    archive_unlock || return 1

    # enable symmetric encryption
    symmetric_encryption enable

    # switch to the new passphrase and lock the archive
    PASSPHRASE=$passphrase2
    archive_lock
}

cmd_set_gpg_keys() {
    # get the keys
    local gpg_keys="$*"
    [[ -z $gpg_keys ]] && gpg_keys=$(gen_gpg_key)
    [[ -z $gpg_keys ]] && return 1

    # unlock archive and then lock with asymmetric encryption
    archive_unlock || return 1
    GPG_KEYS="$gpg_keys"
    symmetric_encryption disable
    archive_lock
}
gen_gpg_key() {
    local gpg_key
    local homedir="$PW_DIR/.gnupg"

    if [[ -d "$homedir" ]]; then
        gpg_key=$(gpg --homedir "$homedir" --list-keys --with-colons | grep '^pub:' | cut -d':' -f5)
        [[ -n $gpg_key ]] && echo $gpg_key && return
    fi

    mkdir -p "$homedir"
    gpg --homedir "$homedir" --gen-key
    gpg_key=$(gpg --homedir "$homedir" --list-keys --with-colons | grep '^pub:' | cut -d':' -f5)
    if [[ -n $gpg_key ]]; then
        GPG_OPTS="$GPG_OPTS --homedir '$homedir'"
        sed -i "$PW_DIR/config.sh" -e "/GPG_OPTS=/c GPG_OPTS=\"$GPG_OPTS\""
        echo $gpg_key
    fi
}

cmd_export() {
    local path=$1
    [[ -z "$path" ]] && echo "Usage: $COMMAND dirpath" && return 1
    [[ ! -d "$path" ]] && echo "Error: $path is not a directory" && return 1

    archive_unlock || return 1
    cp -a "$TEMPDIR"/* "$path/"
    cp -a "$TEMPDIR/.git" "$path/"
    remove_tempdir
}

cmd_import() {
    local path=$1
    [[ ! -d "$path" ]] && echo "Usage: $COMMAND dirpath" && return 1
    path=${path%/}

    archive_unlock || return 1
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

    # cleanup
    remove_tempdir
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

create_archive() {
    echo "Creating a new archive '$ARCHIVE'."
    new_passphrase
    mkdir -p "$PW_DIR"
    make_tempdir
    archive_lock
    cmd_git init
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
    [[ -f "$ARCHIVE.gpg" ]] || create_archive
    [[ -f "$ARCHIVE.gpg.keys" ]] &&  source "$ARCHIVE.gpg.keys"    # get GPG_KEYS

    COMMAND="$PROGRAM $1"
    run_cmd "$@"

    timeout_clear
    exit 0
}

main "$@"
