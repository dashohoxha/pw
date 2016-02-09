#!/usr/bin/env bash

test_description='Test commands: set, ls, show'
source "$(dirname "$0")"/setup-03.sh

test_expect_success 'Set a new password.' '
    echo -e "$PASSPHRASE\n$PASS1\n$PASS1" | "$PW" set test1 &&
    echo -e "$PASSPHRASE" | "$PW" ls | grep "test1" &&
    local pass1=$("$PW" show test1 <<<"$PASSPHRASE") &&
    [[ $PASS1 == $pass1 ]]
'

test_expect_success 'Check that password retype matches.' '
    local pass1="x-$PASS1" &&
    echo -e "$PASSPHRASE\n$PASS1\n$pass1" | "$PW" set test2 | grep "Error: the entered passwords do not match."
'

test_expect_success 'Check that ls can show the password.' '
    local pass1=$("$PW" ls test1 <<<"$PASSPHRASE") &&
    [[ $PASS1 == $pass1 ]]
'

test_done
