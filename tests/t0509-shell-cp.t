#!/usr/bin/env bash

test_description='Test shell cp'
source "$(dirname "$0")"/setup-05.sh

test_expect_success 'Test usage' '
    run_in_shell "cp" | grep "Usage: cp " &&
    run_in_shell "cp test1" | grep "Usage: cp "
'

test_expect_success 'Test not found' '
    run_in_shell "cp test10 test11" | grep "Error: test10 is not in the archive."
'

test_expect_success 'Test cp' '
    run_in_shell "cp test1 test10" &&
    pwp ls | grep test10
'

test_expect_success 'Test cp dont overwrite' '
    run_in_shell "cp test6 test11" "n" &&
    pwp ls | grep test6
'

test_expect_success 'Test cp overwrite' '
    run_in_shell "cp test6 test11" "y" &&
    [[ "$(pwp show test6)" == "$(pwp show test11)" ]]
'

test_expect_success 'Test cp force' '
    run_in_shell "cp test7 test11 -f" &&
    [[ "$(pwp show test7)" == "$(pwp show test11)" ]]
'

test_expect_success 'Test cp recursive' '
    run_in_shell "cp test2 test12" &&
    pwp ls | grep test12/test3
'

test_done
