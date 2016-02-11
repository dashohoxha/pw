#!/usr/bin/env bash

test_description='Test command find'
source "$(dirname "$0")"/setup-04.sh

test_expect_success 'Test usage' '
    "$PW" find | grep "Usage: "
'

test_expect_success 'Test find' '
    [[ $("$PW" find test6 <<<"$PASSPHRASE") == "test6" ]] &&
    [[ $("$PW" find test3 <<<"$PASSPHRASE") == "test2/test3" ]]
'

test_expect_success 'Test find --tree' '
    cat <<-"_EOF" > find-1.txt &&
Search Terms: test5
`-- [01;34mtest2[00m
    `-- test5
_EOF
    echo "$PASSPHRASE" | "$PW" find test5 -t > find-2.txt &&
    test_cmp find-1.txt find-2.txt
'

test_done
