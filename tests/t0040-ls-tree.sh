#!/usr/bin/env bash

test_description='Test command `ls -t`'
source "$(dirname "$0")"/setup-04.sh

test_expect_success 'Test ls --tree' '
    cat <<-"_EOF" > /tmp/ls-tree-1.txt &&
|-- test1
|-- [01;34mtest2[00m
|   |-- test3
|   |-- test4
|   `-- test5
|-- test6
`-- test7
_EOF
    echo "$PASSPHRASE" | "$PW" ls -t > /tmp/ls-tree-2.txt &&
    test_cmp /tmp/ls-tree-1.txt /tmp/ls-tree-2.txt
'

test_done
