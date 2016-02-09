#!/usr/bin/env bash

test_description='Test commands: set, ls, show'
source "$(dirname "$0")"/setup-03.sh

test_expect_success 'Set a new password.' '
    local pass1="xyz" &&
    echo -e "$PASSPHRASE\n$pass1\n$pass1" | "$PW" set test1 &&
    echo -e "$PASSPHRASE" | "$PW" ls | grep "test1" &&
    local pass2=$("$PW" show test1 <<<"$PASSPHRASE") &&
    [[ $pass1 == $pass2 ]]
'

test_done
