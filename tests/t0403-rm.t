#!/usr/bin/env bash

test_description='Test command rm'
source "$(dirname "$0")"/setup-04.sh

test_expect_success 'Test rm' '
    [[ $(pwp show test1) == "$PASS1" ]] &&
    cat <<-_EOF | pw rm test1 &&
$PASSPHRASE
n
_EOF
    [[ $(pwp show test1) == "$PASS1" ]] &&

    cat <<-_EOF | pw rm test1 &&
$PASSPHRASE
y
_EOF
    pwp show test1 | grep "Error: test1 is not in the password store." &&
    pwp rm test1 | grep "Error: test1 is not in the password store."
'

test_expect_success 'Test rm -f' '
    [[ $(pwp show test2/test4) == "$PASS2" ]] &&
    pwp rm test2/test4 -f &&
    pwp show test2/test4 | grep "Error: test2/test4 is not in the password store."
'

test_expect_success 'Test rm -r' '
    pwp rm test2 -r -f &&
    pwp show test2/test5 | grep "Error: test2/test5 is not in the password store."
'

test_done
