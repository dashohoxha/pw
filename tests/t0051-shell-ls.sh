#!/usr/bin/env bash

test_description='Test shell ls'
source "$(dirname "$0")"/setup-05.sh

test_expect_success 'Test ls' '
    run_in_shell ls &&
    run_in_shell "ls test2" | grep "test2/test3" &&
    [[ $(run_in_shell "ls test1") == $PASS1 ]] &&
    [[ $(run_in_shell "ls test2/test4") == $PASS2 ]]
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
    run_in_shell "ls -t" | remove_special_chars > ls-tree-2.txt &&
    test_cmp ls-tree-1.txt ls-tree-2.txt
'

test_done
