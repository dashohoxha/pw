#!/usr/bin/env bash

test_description='Test command grep'
source "$(dirname "$0")"/setup-04.sh

test_expect_success 'Test usage' '
    pw grep | grep "Usage: "
'

test_expect_success 'Test grep' '
    export EDITOR=ed &&
    pw edit test1 <<-_EOF &&
$PASSPHRASE
a
test1 second line
.
wq
_EOF

    cat <<-"_EOF" > grep-1.txt &&
test2/test5:second line
test2/test5:third line
test1:test1 second line
_EOF

    pwp grep "line" | remove_special_chars > grep-2.txt &&
    test_cmp grep-1.txt grep-2.txt
'

test_done
