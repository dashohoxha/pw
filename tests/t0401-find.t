#!/usr/bin/env bash

test_description='Test command find'
source "$(dirname "$0")"/setup-04.sh

test_expect_success 'Test usage' '
    pw find | grep "Usage: "
'

test_expect_success 'Test find' '
    [[ $(pwp find test6) == "test6" ]] &&
    [[ $(pwp find test3) == "test2/test3" ]]
'

test_expect_success 'Test find --tree' '
    cat <<-"_EOF" > find-1.txt &&
Search Terms: test5
`-- test2
    `-- test5
_EOF
    pwp find test5 -t | remove_special_chars > find-2.txt &&
    test_cmp find-1.txt find-2.txt
'

test_done
