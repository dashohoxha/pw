cmd_field() {
    [[ $# -ne 2 ]] && echo "Usage: $COMMAND <entry> <fieldname>" && return
    entry=$1
    field=$2
    cmd_show $entry | grep "^$field:" | sed -e "s/^$field: *//"
}
