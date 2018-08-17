#!/usr/bin/env bash

test_description='Test shell grep'
source "$(dirname "$0")"/setup-05.sh

test_expect_success 'Test usage' '
    run_in_shell "grep" | grep "Usage: grep "
'

test_expect_success 'Test grep' '
    export EDITOR=ed &&
    run_in_shell "edit test1" "a" "test1 second line" "." "wq" &&

    cat <<-"_EOF" > grep-1.txt &&
test1:test1 second line
test2/test5:second line
test2/test5:third line
_EOF

    run_in_shell "grep line" | remove_special_chars > grep-2.txt &&
    test_cmp grep-1.txt grep-2.txt
'

test_done
