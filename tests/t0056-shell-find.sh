#!/usr/bin/env bash

test_description='Test shell find'
source "$(dirname "$0")"/setup-05.sh

test_expect_success 'Test find usage' '
    run_in_shell "find" | grep "Usage: find "
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

test_done
