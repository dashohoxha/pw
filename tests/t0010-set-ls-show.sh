#!/usr/bin/env bash

test_description='Test commands: set, ls, show'
source "$(dirname "$0")"/setup-03.sh

test_expect_success 'Set a new password.' '
    "$PW" set test1 <<-_EOF &&
$PASSPHRASE
$PASS1
$PASS1
_EOF
    echo "$PASSPHRASE" | "$PW" ls | grep "test1" &&
    local pass1=$("$PW" show test1 <<<"$PASSPHRASE") &&
    [[ $PASS1 == $pass1 ]]
'

test_expect_success 'Check that password retype matches.' '
    local pass1="x-$PASS1" &&
    "$PW" set test2 <<-_EOF | grep "Error: the entered passwords do not match."
$PASSPHRASE
$PASS1
$pass1
_EOF
'

test_expect_success 'Check that ls can show the password.' '
    local pass1=$("$PW" ls test1 <<<"$PASSPHRASE") &&
    [[ $PASS1 == $pass1 ]]
'

test_done
