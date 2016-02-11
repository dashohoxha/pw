#!/usr/bin/env bash

test_description='Test edit'
source "$(dirname "$0")"/setup-03.sh

test_expect_success 'Test command edit.' '
    pwp gen test1 &&
    export EDITOR=ed &&
    pw edit test1 <<-_EOF &&
$PASSPHRASE
1c
$PASS1
.
wq
_EOF
    local pass=$(pwp show test1 | head -n 1) &&
    [[ "$pass" == "$PASS1" ]]
'

test_done
