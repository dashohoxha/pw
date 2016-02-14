#!/usr/bin/env bash

test_description='Test command get.'
source "$(dirname "$0")"/setup-03.sh

test_expect_success 'Set a new password.' '
    cat <<-_EOF | pw set test1
$PASSPHRASE
$PASS1
$PASS1
_EOF
'

test_expect_success 'Test get.' '
    pwp get test1 &&
    local pass1=$(xclip -selection clipboard -o) &&
    [[ $PASS1 == $pass1 ]]
'

test_expect_success 'Test that get is the default command.' '
    pwp test1 &&
    local pass1=$(xclip -selection clipboard -o) &&
    [[ $PASS1 == $pass1 ]]
'

test_done
