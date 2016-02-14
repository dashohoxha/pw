#!/usr/bin/env bash

test_description='Test gpg-keys'
source "$(dirname "$0")"/setup-06.sh

test_expect_success 'Set gpg key' '
    echo "$PASSPHRASE" | pw set-keys $KEY1 &&
    [[ -f "$PW_DIR/pw.tgz.gpg.keys" ]] &&
    source "$PW_DIR/pw.tgz.gpg.keys" &&
    [[ "$GPG_KEYS" == "$KEY1" ]] &&
    pw ls | grep "test1" &&
    [[ "$(pw show test1)" == "$PASS1" ]]
'

test_expect_success 'Set other gpg keys' '
    pw keys $KEY2 $KEY3 $KEY4 &&
    [[ -f "$PW_DIR/pw.tgz.gpg.keys" ]] &&
    source "$PW_DIR/pw.tgz.gpg.keys" &&
    [[ "$GPG_KEYS" == "$KEY2 $KEY3 $KEY4" ]] &&
    pw ls | grep "test1" &&
    [[ "$(pw show test1)" == "$PASS1" ]]
'

test_expect_success 'Set passphrase' '
    cat <<-_EOF | pw set-passphrase &&
passphrase1
passphrase1
_EOF
    [[ ! -f "$PW_DIR/pw.tgz.gpg.keys" ]] &&
    test_must_fail pw ls &&
    echo "passphrase1" | pw ls | grep "test1" &&
    [[ "$(pw show test1 <<<"passphrase1")" == "$PASS1" ]]
'

test_expect_success 'Set another passphrase' '
    cat <<-_EOF | pw pass &&
passphrase1
new-passphrase
new-passphrase
_EOF
    test_must_fail pw ls <<<"passphrase1" &&
    echo "new-passphrase" | pw ls | grep "test1" &&
    [[ "$(pw show test1 <<<"new-passphrase")" == "$PASS1" ]]
'

test_expect_success 'Set another key' '
    echo "new-passphrase" | pw set-keys $KEY5 &&
    [[ -f "$PW_DIR/pw.tgz.gpg.keys" ]] &&
    source "$PW_DIR/pw.tgz.gpg.keys" &&
    [[ "$GPG_KEYS" == "$KEY5" ]] &&
    pw ls | grep "test1" &&
    local pass1=$(run_in_shell "ls" "show test1" | tail -n 1) &&
    [[ $pass1 == $PASS1 ]]
'

test_done
