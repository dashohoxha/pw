#!/usr/bin/env bash

test_description='Test shell show and get'
source "$(dirname "$0")"/setup-05.sh

test_expect_success 'Test show' '
    [[ $(run_in_shell "show test1") == $PASS1 ]] &&
    [[ $(run_in_shell "show test2/test4") == $PASS2 ]]
'

# When the shell is not interactive, will not copy to clipboard, will echo instead.
test_expect_success 'Test get.' '
    [[ "$(run_in_shell "get test1")" == $PASS1 ]] &&
    [[ "$(run_in_shell "test2/test4")" == $PASS2 ]]
'

test_done
