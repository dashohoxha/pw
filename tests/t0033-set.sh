#!/usr/bin/env bash

test_description='Test command set.'
source "$(dirname "$0")"/setup-03.sh

test_expect_success 'Set a password.' '
    "$PW" set test1 <<-_EOF &&
$PASSPHRASE
$PASS1
$PASS1
_EOF
    local pass1=$("$PW" show test1 <<<"$PASSPHRASE") &&
    [[ $PASS1 == $pass1 ]]
'

test_expect_success 'Check that options -e and -m are exclusive.' '
    "$PW" set test2 -e -m <<-_EOF | grep "Usage:"
$PASSPHRASE
$PASS1
$PASS1
_EOF
'

test_expect_success 'Set with multiline' '
    "$PW" set test2 -m <<-_EOF &&
$PASSPHRASE
password
second line
third line
_EOF
    local lines=$("$PW" show test2 <<<"$PASSPHRASE" | wc -l) &&
    [[ $lines -eq 3 ]]
'

test_expect_success 'Do not overwrite existing entry.' '
    echo -e "$PASSPHRASE\n\n" | "$PW" set test1 &&
    local pass1=$("$PW" show test1 <<<"$PASSPHRASE") &&
    [[ "$PASS1" == "$pass1" ]]
'

test_expect_success 'Overwrite existing entry.' '
    local pass1="x-$PASS1" &&
    "$PW" set test1 <<-_EOF &&
$PASSPHRASE
y
$pass1
$pass1
_EOF
    local pass2=$("$PW" show test1 <<<"$PASSPHRASE") &&
    [[ "$pass2" == "$pass1" ]]
'

test_expect_success 'Overwrite with -f,--force' '
    local pass1="xyz" &&
    "$PW" set test1 -f <<-_EOF &&
$PASSPHRASE
$pass1
$pass1
_EOF
    local pass2=$("$PW" show test1 <<<"$PASSPHRASE") &&
    [[ "$pass2" == "$pass1" ]]
'

test_done
