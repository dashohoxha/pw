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

# xclip works only if there is an X display
if [[ -z $DISPLAY ]]
then
    test_expect_success 'Test get.' '
        local pass1=$(pwp get test1) &&
        [[ $PASS1 == $pass1 ]]
    '
else
    test_expect_success 'Test get.' '
        pwp get test1 &&
        local pass1=$(xclip -selection clipboard -o) &&
        [[ $PASS1 == $pass1 ]]
    '
fi

test_done
