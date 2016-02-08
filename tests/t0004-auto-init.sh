#!/usr/bin/env bash

test_description='If an archive does not exist, it is created automatically.'
source "$(dirname "$0")"/setup-02.sh

test_expect_success 'A new archive is created if it does not exist.' '
    [[ ! -e "$PW_DIR/pw.tgz.gpg" ]] &&
    echo -e "$PASSPHRASE\n$PASSPHRASE\n" | "$PW" ls | grep "Creating a new archive " &&
    [[ -e "$PW_DIR/config.sh" ]] &&
    [[ -e "$PW_DIR/pw.tgz.gpg" ]] &&
    "$PW" ls <<< "$PASSPHRASE"
'

test_expect_success 'A given archive is created if it does not exist.' '
    [[ ! -e "$PW_DIR/test1.tgz.gpg" ]] &&
    echo -e "$PASSPHRASE\n$PASSPHRASE\n" | "$PW" -a test1 ls | grep "Creating a new archive " &&
    [[ -e "$PW_DIR/test1.tgz.gpg" ]] &&
    "$PW" -a test1 ls <<< "$PASSPHRASE"
'

test_expect_success 'Another archive is created if it does not exist.' '
    [[ ! -e "$PW_DIR/test2.tgz.gpg" ]] &&
    echo -e "$PASSPHRASE\n$PASSPHRASE\n" | "$PW" -a test2 ls | grep "Creating a new archive " &&
    [[ -e "$PW_DIR/test2.tgz.gpg" ]] &&
    "$PW" -a test2 ls <<< "$PASSPHRASE"
'

test_done
