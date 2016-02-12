#!/usr/bin/env bash

test_description='Test command mv'
source "$(dirname "$0")"/setup-04.sh

test_expect_success 'Test usage' '
    pw cp | grep "Usage:" &&
    pw cp test1 | grep "Usage:" &&
    pw mv | grep "Usage:" &&
    pw mv test1 | grep "Usage:"
'

test_expect_success 'Test not found' '
    pwp cp test10 test11 | grep "Error: test10 is not in the password store." &&
    pwp mv test10 test11 | grep "Error: test10 is not in the password store."
'

test_expect_success 'Test cp' '
    pwp cp test1 test10 &&
    pwp ls | grep test10
'

test_expect_success 'Test mv' '
    pwp mv test10 test11 &&
    pwp ls | grep test11 &&
    ! $(pwp ls | grep test10)
'

test_expect_success 'Test cp dont overwrite' '
    pw cp test6 test11 <<-_EOF &&
$PASSPHRASE
n
_EOF
    pwp ls | grep test6
'

test_expect_success 'Test mv dont overwrite' '
    pw mv test6 test11 <<-_EOF &&
$PASSPHRASE
n
_EOF
    pwp ls | grep test6
'

test_expect_success 'Test cp overwrite' '
    pw cp test6 test11 <<-_EOF &&
$PASSPHRASE
y
_EOF
    [[ "$(pwp show test6)" == "$(pwp show test11)" ]]
'

test_expect_success 'Test mv overwrite' '
    local pass=$(pwp show test6) &&
    pw mv test6 test11 <<-_EOF &&
$PASSPHRASE
y
_EOF
    ! $(pwp ls | grep test6) &&
    [[ "$(pwp show test11) == "$pass"" ]]
'

test_expect_success 'Test cp force' '
    pwp cp test7 test11 -f &&
    [[ "$(pwp show test7)" == "$(pwp show test11)" ]]
'

test_expect_success 'Test mv force' '
    local pass=$(pwp show test7) &&
    pwp mv test7 test11 -f &&
    ! $(pwp ls | grep test7) &&
    [[ "$(pwp show test11) == "$pass"" ]]
'

test_expect_success 'Test cp recursive' '
    pwp cp test2 test12 &&
    pwp ls | grep test12/test3
'

test_expect_success 'Test mv recursive' '
    pwp mv test2 test12 -f &&
    pwp ls &&
    pwp ls | grep test12/test2/test3 &&
    ! $(pwp ls | grep test2/test3)
'

test_done
