#!/usr/bin/env bash

test_description='Test gen'
source "$(dirname "$0")"/setup-03.sh

test_expect_success 'Generate a password with default length.' '
    "$PW" gen test1 <<<"$PASSPHRASE" &&
    local pass=$("$PW" show test1 <<<"$PASSPHRASE") &&
    [[ $(echo "$pass" | wc -m) -eq 31 ]]
'

test_expect_success 'Generate a password with a given length.' '
    "$PW" gen test2 35 <<<"$PASSPHRASE" &&
    local pass=$("$PW" show test2 <<<"$PASSPHRASE") &&
    [[ $(echo "$pass" | wc -m) -eq 36 ]]
'

test_expect_success 'Check that the given length is a number.' '
    "$PW" gen test3 xyz <<<"$PASSPHRASE" | grep "Error: pass-length \"xyz\" must be a number."
'

test_expect_success 'Do not overwrite existing entry.' '
    local pass1=$("$PW" show test1 <<<"$PASSPHRASE") &&

    "$PW" gen test1 <<-_EOF &&
$PASSPHRASE
n
_EOF
    local pass2=$("$PW" show test1 <<<"$PASSPHRASE") &&
    [[ "$pass1" == "$pass2" ]]
'

test_expect_success 'Overwrite existing entry.' '
    local pass1=$("$PW" show test1 <<<"$PASSPHRASE") &&

    "$PW" gen test1 <<_EOF &&
$PASSPHRASE
y
_EOF
    local pass2=$("$PW" show test1 <<<"$PASSPHRASE") &&
    [[ "$pass1" != "$pass2" ]]
'

test_expect_success 'Overwrite existing entry with -f.' '
    local pass1=$("$PW" show test1 <<<"$PASSPHRASE") &&
    "$PW" gen test1 -f <<<"$PASSPHRASE" &&
    local pass2=$("$PW" show test1 <<<"$PASSPHRASE") &&
    [[ "$pass1" != "$pass2" ]]
'

test_expect_success 'Check that options -i and -f are exclusive.' '
    "$PW" gen test1 -i -f <<<"$PASSPHRASE" | grep "Usage:"
'

test_expect_success 'Check replacement of the first line with -i.' '
    "$PW" set test3 -m <<-_EOF &&
$PASSPHRASE
$PASS1
second line
third line
_EOF
    "$PW" gen test3 -i <<<"$PASSPHRASE" &&

    local lines=$("$PW" show test3 <<<"$PASSPHRASE" | wc -l) &&
    [[ $lines -eq 3 ]] &&

    local pass1=$("$PW" show test3 <<<"$PASSPHRASE" | head -n 1) &&
    [[ $pass1 != $PASS1 ]]
'

test_done
