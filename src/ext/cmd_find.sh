cmd_find() {
    [[ -z $1 ]] && echo "Usage: $COMMAND <pattern>" && return
    cmd_list | grep $1
}
