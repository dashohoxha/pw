cmd_find() {
    local pattern="$1"
    [[ -z $pattern ]] && echo "Usage: $COMMAND <pattern>" && return 1
    cmd_list | grep -i "$pattern"
}
