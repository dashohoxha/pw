#!/usr/bin/env bash

test_description='Test shell edit'
source "$(dirname "$0")"/setup-05.sh

test_expect_success 'Test edit usage' '
    run_in_shell "edit" | grep "Usage: edit "
'

test_expect_success 'Test edit.' '
    export EDITOR=ed &&
    run_in_shell "edit test2/test3" "1c" "$PASS2" "." "wq" &&
    [[ $(pwp show test2/test3 | head -n 1) == $PASS2 ]]
'

test_done
