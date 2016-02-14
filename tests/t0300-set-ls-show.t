#!/usr/bin/env bash

test_description='Test commands: set, ls, show'
source "$(dirname "$0")"/setup-03.sh

test_expect_success 'Set a new password.' '
    pw set test1 <<-_EOF &&
$PASSPHRASE
$PASS1
$PASS1
_EOF
    pwp ls | grep "test1" &&
    local pass1=$(pwp show test1) &&
    [[ $PASS1 == $pass1 ]]
'

test_expect_success 'Check that password retype matches.' '
    local pass1="x-$PASS1" &&
    pw set test2 <<-_EOF | grep "Error: the entered passwords do not match."
$PASSPHRASE
$PASS1
$pass1
_EOF
'

test_expect_success 'Check that ls can show the password.' '
    local pass1=$(pwp ls test1) &&
    [[ $PASS1 == $pass1 ]]
'

test_done
