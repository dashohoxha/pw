source "$(dirname "$0")"/setup-04.sh

test_expect_success 'Test starting and quiting the shell' '
    cat <<-_EOF | pw | grep "Type q to quit, p to change the passphrase."
$PASSPHRASE
q
_EOF
'

run_in_shell() {
    local commands=$(IFS=$'\n'; echo "$*")
    cat <<-_EOF | pw | sed -e '/Commands:/,+2d'
$PASSPHRASE
$commands
q
_EOF
}
