cmd_field() {
    [[ $# != 2 ]] && echo "Usage: $COMMAND <entry> <fieldname>" && return 1
    entry=$1
    field=$2
    cmd_show $entry | grep "^$field:" | sed -e "s/^$field: *//"
}
