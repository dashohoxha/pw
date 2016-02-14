#!/usr/bin/env bash

test_description='Test command set.'
source "$(dirname "$0")"/setup-03.sh

test_expect_success 'Set a password.' '
    cat <<-_EOF | pw set test1 &&
$PASSPHRASE
$PASS1
$PASS1
_EOF
    local pass1=$(pwp show test1) &&
    [[ $PASS1 == $pass1 ]]
'

test_expect_success 'Check that options -e and -m are exclusive.' '
    cat <<-_EOF | pw set test2 -e -m | grep "Usage:"
$PASSPHRASE
$PASS1
$PASS1
_EOF
'

test_expect_success 'Set with multiline' '
    cat <<-_EOF | pw set test2 -m &&
$PASSPHRASE
password
second line
third line
_EOF
    local lines=$(pwp show test2 | wc -l) &&
    [[ $lines -eq 3 ]]
'

test_expect_success 'Do not overwrite existing entry.' '
    echo -e "$PASSPHRASE\n\n" | pw set test1 &&
    local pass1=$(pwp show test1) &&
    [[ "$PASS1" == "$pass1" ]]
'

test_expect_success 'Overwrite existing entry.' '
    local pass1="x-$PASS1" &&
    cat <<-_EOF | pw set test1 &&
$PASSPHRASE
y
$pass1
$pass1
_EOF
    local pass2=$(pwp show test1) &&
    [[ "$pass2" == "$pass1" ]]
'

test_expect_success 'Overwrite with -f,--force' '
    local pass1="xyz" &&
    cat <<-_EOF | pw set test1 -f &&
$PASSPHRASE
$pass1
$pass1
_EOF
    local pass2=$(pwp show test1) &&
    [[ "$pass2" == "$pass1" ]]
'

test_done
