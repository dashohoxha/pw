cmd_gen() {
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

    archive_unlock    # extract to $TEMPDIR

    mkdir -p "$TEMPDIR/$(dirname "$path")"
    local pwfile="$TEMPDIR/$path"

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

    archive_lock      # cleanup $TEMPDIR
}
