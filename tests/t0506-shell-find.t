#!/usr/bin/env bash

test_description='Test shell find'
source "$(dirname "$0")"/setup-05.sh

test_expect_success 'Test usage' '
    run_in_shell "find" | grep "Usage: find "
'

test_expect_success 'Test find' '
    [[ $(run_in_shell "find test6") == "test6" ]] &&
    [[ $(run_in_shell "find test3") == "test2/test3" ]]
'

test_done
