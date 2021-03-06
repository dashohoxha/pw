source "$(dirname "$0")"/setup-02.sh

test_expect_success 'Create an archive.' '
    [[ ! -e "$PW_DIR/pw.tgz.gpg" ]] &&
    cat <<-_EOF | pw ls | grep "Creating a new archive " &&
$PASSPHRASE
$PASSPHRASE
_EOF
    [[ -e "$PW_DIR/config.sh" ]] &&
    [[ -e "$PW_DIR/pw.tgz.gpg" ]] &&
    pwp ls
'
