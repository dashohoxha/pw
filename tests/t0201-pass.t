#!/usr/bin/env bash

test_description='Change the passphrase of an archive.'
source "$(dirname "$0")"/setup-02.sh

test_expect_success 'Create a test archive.' '
    cat <<-_EOF | pw -a test-archive ls | grep "Creating a new archive " &&
passphrase
passphrase
_EOF
    [[ -e "$PW_DIR/test-archive.tgz.gpg" ]] &&
    echo "passphrase" | pw -a test-archive ls
'

test_expect_success 'Change the passphrase of the test archive.' '
    cat <<-_EOF | pw -a test-archive set-passphrase &&
passphrase
new-passphrase
new-passphrase
_EOF

    echo "passphrase" | pw -a test-archive ls | grep "gpg: decryption failed: Bad session key" &&

    cat <<-_EOF | pw -a test-archive set test1 &&
new-passphrase
$PASS1
$PASS1
_EOF
    echo "new-passphrase" | pw -a test-archive ls | grep "test1"

    cat <<-_EOF | pw -a test-archive pass
new-passphrase
another-passphrase
another-passphrase
_EOF
'

test_done
