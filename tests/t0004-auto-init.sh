#!/usr/bin/env bash

test_description='If an archive does not exist, it is created automatically.'
source "$(dirname "$0")"/setup-02.sh

test_expect_success 'A new archive is created if it does not exist.' '
    [[ ! -e "$PW_DIR/pw.tgz.gpg" ]] &&
    "$PW" ls <<-_EOF | grep "Creating a new archive " &&
$PASSPHRASE
$PASSPHRASE
_EOF
    [[ -e "$PW_DIR/config.sh" ]] &&
    [[ -e "$PW_DIR/pw.tgz.gpg" ]] &&
    "$PW" ls <<< "$PASSPHRASE"
'

test_expect_success 'A given archive is created if it does not exist.' '
    [[ ! -e "$PW_DIR/test1.tgz.gpg" ]] &&
    "$PW" -a test1 ls <<-_EOF | grep "Creating a new archive " &&
$PASSPHRASE
$PASSPHRASE
_EOF
    [[ -e "$PW_DIR/test1.tgz.gpg" ]] &&
    "$PW" -a test1 ls <<< "$PASSPHRASE"
'

test_expect_success 'Error: the entered passphrases do not match..' '
    [[ ! -e "$PW_DIR/test3.tgz.gpg" ]] &&
    echo -e "abc\n123" | "$PW" -a test3 ls | grep "Error: the entered passphrases do not match." &&
    [[ ! -e "$PW_DIR/test3.tgz.gpg" ]]
'

test_done
