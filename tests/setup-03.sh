source "$(dirname "$0")"/setup-02.sh

test_expect_success 'Create an archive.' '
    [[ ! -e "$PW_DIR/pw.tgz.gpg" ]] &&
    echo -e "$PASSPHRASE\n$PASSPHRASE\n" | "$PW" ls | grep "Creating a new archive " &&
    [[ -e "$PW_DIR/config.sh" ]] &&
    [[ -e "$PW_DIR/pw.tgz.gpg" ]] &&
    "$PW" ls <<< "$PASSPHRASE"
'
