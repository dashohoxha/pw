#!/usr/bin/env bash

test_description='Test shell set'
source "$(dirname "$0")"/setup-05.sh

test_expect_success 'Test set usage' '
    run_in_shell "set" | grep "Usage: set "
'

test_expect_success 'Test set new entry' '
    run_in_shell "set test10" "$PASS1" "$PASS1" &&
    [[ "$(pwp show test10)" == $PASS1 ]]
'

test_expect_success 'Test set overwrite' '
    run_in_shell "set test10" "y" "$PASS2" "$PASS2" &&
    [[ "$(pwp show test10)" == $PASS2 ]]
'

test_expect_success 'Test set force' '
    run_in_shell "set test10 -f" "$PASS3" "$PASS3" &&
    [[ "$(pwp show test10)" == $PASS3 ]]
'

test_done
