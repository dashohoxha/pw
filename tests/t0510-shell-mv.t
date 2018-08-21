#!/usr/bin/env bash

test_description='Test shell mv'
source "$(dirname "$0")"/setup-05.sh

test_expect_success 'Test usage' '
    run_in_shell "mv" | grep "Usage: mv " &&
    run_in_shell "mv test1" | grep "Usage: mv "
'

test_expect_success 'Test not found' '
    run_in_shell "mv test10 test11" | grep "Error: test10 is not in the archive."
'

test_expect_success 'Test mv' '
    run_in_shell "mv test1 test11" &&
    pwp ls | grep test11 &&
    ! $(pwp ls | grep test1)
'

test_expect_success 'Test mv dont overwrite' '
    run_in_shell "mv test6 test11" "n" &&
    pwp ls | grep test6
'

test_expect_success 'Test mv overwrite' '
    local pass=$(pwp show test6) &&
    run_in_shell "mv test6 test11" "y" &&
    ! $(pwp ls | grep test6) &&
    [[ "$(pwp show test11) == "$pass"" ]]
'

test_expect_success 'Test mv force' '
    local pass=$(pwp show test7) &&
    run_in_shell "mv test7 test11 -f" &&
    ! $(pwp ls | grep test7) &&
    [[ "$(pwp show test11) == "$pass"" ]]
'

test_expect_success 'Test mv recursive' '
    run_in_shell "mv test2 test12 -f" &&
    pwp ls | grep test12/test3 &&
    ! $(pwp ls | grep test12/test3)
'

test_done
