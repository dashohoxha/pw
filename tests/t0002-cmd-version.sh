#!/usr/bin/env bash

test_description='Command: version'
source "$(dirname "$0")"/setup.sh


test_expect_success 'Make sure we can run `pw version`' '
    "$PW" version | grep "pw: a simple password manager"
'

test_expect_success 'Make sure we can run `pw v`' '
    "$PW" v | grep "pw: a simple password manager"
'

test_expect_success 'Make sure we can run `pw -v`' '
    "$PW" -v | grep "pw: a simple password manager"
'

test_expect_success 'Make sure we can run `pw --version`' '
    "$PW" --version | grep "pw: a simple password manager"
'

test_done
