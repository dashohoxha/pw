#!/usr/bin/env bash

test_description='Test entry paths.'
source "$(dirname "$0")"/setup-03.sh

test_expect_success 'Test entry with subpaths.' '
    local entry="a/b/c/d" &&
    echo -e "$PASSPHRASE\n$PASS1\n$PASS1" | "$PW" set $entry &&
    echo -e "$PASSPHRASE" | "$PW" ls | grep "$entry" &&
    local pass1=$("$PW" show "$entry" <<<"$PASSPHRASE") &&
    [[ $PASS1 == $pass1 ]]
'

test_expect_success 'Test entry with spaces.' '
    local entry="a b/c d" &&
    echo -e "$PASSPHRASE\n$PASS1\n$PASS1" | "$PW" set "$entry" &&
    echo -e "$PASSPHRASE" | "$PW" ls | grep "$entry" &&
    local pass1=$("$PW" show "$entry" <<<"$PASSPHRASE") &&
    [[ $PASS1 == $pass1 ]]
'

test_done
