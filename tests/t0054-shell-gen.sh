#!/usr/bin/env bash

test_description='Test shell gen'
source "$(dirname "$0")"/setup-05.sh

test_expect_success 'Test gen usage' '
    run_shell_commands "gen" | grep "Usage: gen "
'

test_expect_success 'Test gen new entry' '
    run_shell_commands "gen test11" &&
    [[ $(pwp show test11 | wc -m) -eq 31 ]]
'

test_expect_success 'Test gen with given length' '
    run_shell_commands "gen test12 35" &&
    [[ $(pwp show test12 | wc -m) -eq 36 ]]
'

test_expect_success 'Test gen check length' '
    run_shell_commands "gen test3 xyz" | grep "Error: pass-length \"xyz\" must be a number."
'

test_expect_success 'Test gen dont overwrite' '
    run_shell_commands "gen test1" "n" &&
    [[ $(pwp show test1) == $PASS1 ]]
'

test_expect_success 'Test gen overwrite' '
    run_shell_commands "gen test1" "y" &&
    [[ $(pwp show test1) != $PASS1 ]]
'

test_expect_success 'Test gen force' '
    run_shell_commands "gen test2/test4 -f" &&
    [[ $(pwp show test2/test4) != $PASS2 ]]
'
test_expect_success 'Test gen options -i -f are exclusive' '
    run_shell_commands "gen test1 -i -f" | grep "Usage: gen "
'
test_expect_success 'Test gen --in-place' '
    run_shell_commands "gen test2/test5 -i" &&
    pwp show test2/test5 | grep "second line"
'

test_done
