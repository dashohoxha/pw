#!/usr/bin/env bash

test_description='Test the shell'
source "$(dirname "$0")"/setup-05.sh

test_expect_success 'Test version and help' '
    run_shell_commands version | grep "pw: a simple password manager" &&
    run_shell_commands v | grep "pw: a simple password manager" &&
    run_shell_commands help | grep "Commands and their options are listed below."
'

test_expect_success 'Test ls' '
    run_shell_commands ls &&
    run_shell_commands "ls test2" | grep "test2/test3" &&
    [[ $(run_shell_commands "ls test1") == $PASS1 ]] &&
    [[ $(run_shell_commands "ls test2/test4") == $PASS2 ]]
'

test_expect_success 'Test ls -t' '
    cat <<-"_EOF" > ls-tree-1.txt &&
|-- test1
|-- test2
|   |-- test3
|   |-- test4
|   `-- test5
|-- test6
`-- test7
_EOF
    run_shell_commands "ls -t" | remove_special_chars > ls-tree-2.txt &&
    test_cmp ls-tree-1.txt ls-tree-2.txt
'

test_expect_success 'Test show' '
    [[ $(run_shell_commands "show test1") == $PASS1 ]] &&
    [[ $(run_shell_commands "show test2/test4") == $PASS2 ]]
'

# When the shell is not interactive, will not copy to clipboard, will echo instead.
test_expect_success 'Test get.' '
    [[ "$(run_shell_commands "get test1")" == $PASS1 ]] &&
    [[ "$(run_shell_commands "test2/test4")" == $PASS2 ]]
'

test_expect_success 'Test set.' '
    run_shell_commands "set" | grep "Usage: set " &&

    run_shell_commands "set test10" "$PASS1" "$PASS1" &&
    [[ "$(pwp show test10)" == $PASS1 ]] &&

    run_shell_commands "set test10" "y" "$PASS2" "$PASS2" &&
    [[ "$(pwp show test10)" == $PASS2 ]]

    run_shell_commands "set test10 -f" "$PASS3" "$PASS3" &&
    [[ "$(pwp show test10)" == $PASS3 ]]
'

test_expect_success 'Test gen.' '
    run_shell_commands "gen" | grep "Usage: gen " &&

    run_shell_commands "gen test11" &&
    [[ $(pwp show test11 | wc -m) -eq 31 ]] &&

    run_shell_commands "gen test12 35" &&
    [[ $(pwp show test12 | wc -m) -eq 36 ]] &&

    run_shell_commands "gen test3 xyz" | grep "Error: pass-length \"xyz\" must be a number." &&

    run_shell_commands "gen test1" "n" &&
    [[ $(pwp show test1) == $PASS1 ]] &&

    run_shell_commands "gen test1" "y" &&
    [[ $(pwp show test1) != $PASS1 ]] &&

    run_shell_commands "gen test2/test4 -f" &&
    [[ $(pwp show test2/test4) != $PASS2 ]] &&

    run_shell_commands "gen test1 -i -f" | grep "Usage: gen " &&

    run_shell_commands "gen test2/test5 -i" &&
    pwp show test2/test5 | grep "second line"
'

test_done
