#!/usr/bin/env bash

test_description='Command: version'
source "$(dirname "$0")"/setup-01.sh


test_expect_success 'Make sure we can run `pw version`' '
    pw version | grep "pw: a simple password manager"
'

test_expect_success 'Make sure we can run `pw v`' '
    pw v | grep "pw: a simple password manager"
'

test_expect_success 'Make sure we can run `pw -v`' '
    pw -v | grep "pw: a simple password manager"
'

test_expect_success 'Make sure we can run `pw --version`' '
    pw --version | grep "pw: a simple password manager"
'

test_done
