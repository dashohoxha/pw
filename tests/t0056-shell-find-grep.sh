#!/usr/bin/env bash

test_description='Test shell find and grep'
source "$(dirname "$0")"/setup-05.sh

test_expect_success 'Test usage' '
    run_in_shell "find" | grep "Usage: find " &&
    run_in_shell "grep" | grep "Usage: grep "
'

test_expect_success 'Test find' '
    [[ $(run_in_shell "find test6") == "test6" ]] &&
    [[ $(run_in_shell "find test3") == "test2/test3" ]]
'

test_expect_success 'Test find --tree' '
    cat <<-"_EOF" > find-1.txt &&
Search Terms: test5
`-- test2
    `-- test5
_EOF
    run_in_shell "find test5 -t" | remove_special_chars > find-2.txt &&
    test_cmp find-1.txt find-2.txt
'

test_expect_success 'Test grep' '
    export EDITOR=ed &&
    run_in_shell "edit test1" "a" "test1 second line" "." "wq" &&

    cat <<-"_EOF" > grep-1.txt &&
test2/test5:second line
test2/test5:third line
test1:test1 second line
_EOF

    run_in_shell "grep line" | remove_special_chars > grep-2.txt &&
    test_cmp grep-1.txt grep-2.txt
'

test_done
