#!/usr/bin/env bash

test_description='Test command log'
source "$(dirname "$0")"/setup-04.sh

test_expect_success 'Test log' '
    pwp log &&
    [[ $(pwp log | wc -l) -eq 5 ]] &&
    pwp log | grep "Add generated password for test7."

    pwp log -3 &&
    [[ $(pwp log -3 | wc -l) -eq 2 ]] &&
    pwp log -3 | grep "Add generated password for test7." &&
    ! $(pwp log -3 | grep "Add given password for test1.")
'

test_done
