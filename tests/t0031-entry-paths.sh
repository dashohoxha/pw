#!/usr/bin/env bash

test_description='Test entry paths.'
source "$(dirname "$0")"/setup-03.sh

test_expect_success 'Test entry with subpaths.' '
    local entry="a/b/c/d" &&
    pw set $entry <<-_EOF &&
$PASSPHRASE
$PASS1
$PASS1
_EOF
    pwp ls | grep "$entry" &&
    local pass1=$(pwp show "$entry") &&
    [[ $PASS1 == $pass1 ]]
'

test_expect_success 'Test entry with spaces.' '
    local entry="a b/c d" &&
    pw set "$entry" <<-_EOF &&
$PASSPHRASE
$PASS1
$PASS1
_EOF
    pwp ls | grep "$entry" &&
    local pass1=$(pwp show "$entry") &&
    [[ $PASS1 == $pass1 ]]
'

test_done
