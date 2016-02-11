#!/usr/bin/env bash

test_description='Test command `ls -t`'
source "$(dirname "$0")"/setup-04.sh

test_expect_success 'Test ls --tree' '
    cat <<-"_EOF" > ls-tree-1.txt &&
|-- test1
|-- test2
|   |-- test3
|   |-- test4
|   `-- test5
|-- test6
`-- test7
_EOF
    echo "$PASSPHRASE" | "$PW" ls -t | remove_special_chars > ls-tree-2.txt &&
    test_cmp ls-tree-1.txt ls-tree-2.txt
'

test_done
