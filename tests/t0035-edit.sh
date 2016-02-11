#!/usr/bin/env bash

test_description='Test edit'
source "$(dirname "$0")"/setup-03.sh

test_expect_success 'Test command edit.' '
    "$PW" gen test1 <<<"$PASSPHRASE" &&
    export EDITOR=ed &&
    "$PW" edit test1 <<-_EOF &&
$PASSPHRASE
1c
$PASS1
.
wq
_EOF
    local pass=$("$PW" show test1 <<<"$PASSPHRASE" | head -n 1) &&
    [[ "$pass" == "$PASS1" ]]
'

test_done
