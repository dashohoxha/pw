#!/usr/bin/env bash

test_description='Command: help'
source "$(dirname "$0")"/setup-01.sh

test_expect_success 'Make sure we can run `pw help`' '
    "$PW" help | grep "Commands and their options are listed below."
'

test_expect_success 'Make sure we can run `pw --help`' '
    "$PW" --help | grep "Commands and their options are listed below."
'

test_expect_success 'Make sure we can run `pw -h`' '
    "$PW" -h | grep "Commands and their options are listed below."
'

test_done
