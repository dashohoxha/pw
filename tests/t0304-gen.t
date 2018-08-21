#!/usr/bin/env bash

test_description='Test gen'
source "$(dirname "$0")"/setup-03.sh

test_expect_success 'Generate a password with default length.' '
    pwp gen test1 &&
    local pass=$(pwp show test1) &&
    [[ $(echo "$pass" | wc -m) == 31 ]]
'

test_expect_success 'Generate a password with a given length.' '
    pwp gen test2 35 &&
    local pass=$(pwp show test2) &&
    [[ $(echo "$pass" | wc -m) == 36 ]]
'

test_expect_success 'Check that the given length is a number.' '
    pwp gen test3 xyz | grep "Error: pass-length \"xyz\" must be a number."
'

test_expect_success 'Do not overwrite existing entry.' '
    local pass1=$(pwp show test1) &&

    cat <<-_EOF | pw gen test1 &&
$PASSPHRASE
n
_EOF
    local pass2=$(pwp show test1) &&
    [[ "$pass1" == "$pass2" ]]
'

test_expect_success 'Overwrite existing entry.' '
    local pass1=$(pwp show test1) &&

    cat <<-_EOF | pw gen test1 &&
$PASSPHRASE
y
_EOF
    local pass2=$(pwp show test1) &&
    [[ "$pass1" != "$pass2" ]]
'

test_expect_success 'Overwrite existing entry with -f.' '
    local pass1=$(pwp show test1) &&
    pwp gen test1 -f &&
    local pass2=$(pwp show test1) &&
    [[ "$pass1" != "$pass2" ]]
'

test_expect_success 'Check that options -i and -f are exclusive.' '
    pw gen test1 -i -f | grep "Usage:"
'

test_expect_success 'Check replacement of the first line with -i.' '
    cat <<-_EOF | pw set test3 -m &&
$PASSPHRASE
$PASS1
second line
third line
_EOF
    pwp gen test3 -i &&

    local lines=$(pwp show test3 | wc -l) &&
    [[ $lines == 3 ]] &&

    local pass1=$(pwp show test3 | head -n 1) &&
    [[ $pass1 != $PASS1 ]]
'

test_done
