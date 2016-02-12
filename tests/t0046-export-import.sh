#!/usr/bin/env bash

test_description='Test command `ls -t`'
source "$(dirname "$0")"/setup-04.sh

test_expect_success 'Test usage' '
    pw export | grep "Usage:"
'

test_expect_success 'Test export' '
    [[ ! -d test-export ]] &&
    mkdir -p test-export &&
    pwp export test-export &&
    [[ -f test-export/test1 ]] &&
    [[ -d test-export/test2 ]] &&
    [[ -f test-export/test2/test3 ]] &&
    [[ -d test-export/.git ]] &&
    [[ $(cat test-export/test1) == $PASS1 ]]
'

test_expect_success 'Test import' '
    pw -a archive1 gen test1 <<-_EOF &&
$PASSPHRASE
$PASSPHRASE
_EOF
    pwp -a archive1 gen test2/test4 &&

    pwp -a archive1 import test-export &&

    [[ $(pwp -a archive1 show test1) == $PASS1 ]] &&
    [[ $(pwp -a archive1 show test2/test4) == $PASS2 ]] &&
    pwp -a archive1 ls | grep "test6" &&
    pwp -a archive1 ls | grep "test2/test3" &&
    [[ $(pwp -a archive1 log | grep "Import" | wc -l) == 6 ]]
'

test_done
