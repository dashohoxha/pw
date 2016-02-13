#!/usr/bin/env bash

test_description='Test the shell'
source "$(dirname "$0")"/setup-05.sh

test_expect_success 'Test version and help' '
    run_shell_commands version | grep "pw: a simple password manager" &&
    run_shell_commands v | grep "pw: a simple password manager" &&
    run_shell_commands help | grep "Commands and their options are listed below."
'

test_done
