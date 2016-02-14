#!/usr/bin/env bash

test_description='Test shell log'
source "$(dirname "$0")"/setup-05.sh

test_expect_success 'Test log' '
    runIn_shell "log" &&
    [[ $(run_in_shell "log" | wc -l) -eq 5 ]] &&
    run_in_shell "log" | grep "Add generated password for test7."

    run_in_shell "log -3" &&
    [[ $(run_in_shell "log -3" | wc -l) -eq 2 ]] &&
    run_in_shell "log -3" | grep "Add generated password for test7." &&
    ! $(run_in_shell "log -3" | grep "Add given password for test1.")
'

test_done
