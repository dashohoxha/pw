#!/usr/bin/env bash

test_description='Test shell rm'
source "$(dirname "$0")"/setup-05.sh

test_expect_success 'Test usage' '
    run_in_shell "rm" | grep "Usage: rm "
'

test_expect_success 'Test rm n' '
    [[ $(pwp show test1) == "$PASS1" ]] &&
    run_in_shell "rm test1" "n" &&
    [[ $(pwp show test1) == "$PASS1" ]]
'

test_expect_success 'Test rm y' '
    [[ $(pwp show test1) == "$PASS1" ]] &&
    run_in_shell "rm test1" "y" &&
    pwp show test1 | grep "Error: test1 is not in the archive." &&
    run_in_shell "rm test1" | grep "Error: test1 is not in the archive."
'

test_expect_success 'Test rm -f' '
    [[ $(pwp show test2/test4) == "$PASS2" ]] &&
    run_in_shell "rm test2/test4 -f" &&
    pwp show test2/test4 | grep "Error: test2/test4 is not in the archive."
'

test_expect_success 'Test rm -r' '
    run_in_shell "rm test2 -r -f" &&
    pwp show test2/test5 | grep "Error: test2/test5 is not in the archive."
'

test_done
