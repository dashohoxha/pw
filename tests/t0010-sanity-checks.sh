#!/usr/bin/env bash

test_description='Sanity checks'
source "$(dirname "$0")"/setup-01.sh

test_expect_success 'Make sure we can run `ls`' '
    ls -al
'

test_expect_success 'Make sure we can run `pw`' '
    "$PW" version
'

test_done
