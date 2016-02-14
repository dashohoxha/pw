#!/usr/bin/env bash

test_description='Test shell cp and mv'
source "$(dirname "$0")"/setup-05.sh

test_expect_success 'Test usage' '
    run_in_shell "cp" | grep "Usage: cp " &&
    run_in_shell "cp test1" | grep "Usage: cp " &&
    run_in_shell "mv" | grep "Usage: mv " &&
    run_in_shell "mv test1" | grep "Usage: mv "
'

test_expect_success 'Test not found' '
    run_in_shell "cp test10 test11" | grep "Error: test10 is not in the password store." &&
    run_in_shell "mv test10 test11" | grep "Error: test10 is not in the password store."
'

test_expect_success 'Test cp' '
    run_in_shell "cp test1 test10" &&
    pwp ls | grep test10
'

test_expect_success 'Test mv' '
    run_in_shell "mv test10 test11" &&
    pwp ls | grep test11 &&
    ! $(pwp ls | grep test10)
'

test_expect_success 'Test cp dont overwrite' '
    run_in_shell "cp test6 test11" "n" &&
    pwp ls | grep test6
'

test_expect_success 'Test mv dont overwrite' '
    run_in_shell "mv test6 test11" "n" &&
    pwp ls | grep test6
'

test_expect_success 'Test cp overwrite' '
    run_in_shell "cp test6 test11" "y" &&
    [[ "$(pwp show test6)" == "$(pwp show test11)" ]]
'

test_expect_success 'Test mv overwrite' '
    local pass=$(pwp show test6) &&
    run_in_shell "mv test6 test11" "y" &&
    ! $(pwp ls | grep test6) &&
    [[ "$(pwp show test11) == "$pass"" ]]
'

test_expect_success 'Test cp force' '
    run_in_shell "cp test7 test11 -f" &&
    [[ "$(pwp show test7)" == "$(pwp show test11)" ]]
'

test_expect_success 'Test mv force' '
    local pass=$(pwp show test7) &&
    run_in_shell "mv test7 test11 -f" &&
    ! $(pwp ls | grep test7) &&
    [[ "$(pwp show test11) == "$pass"" ]]
'

test_expect_success 'Test cp recursive' '
    run_in_shell "cp test2 test12" &&
    pwp ls | grep test12/test3
'

test_expect_success 'Test mv recursive' '
    run_in_shell "mv test2 test12 -f" &&
    pwp ls | grep test12/test2/test3 &&
    ! $(pwp ls | grep test2/test3)
'

test_done
