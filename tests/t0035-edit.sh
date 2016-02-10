#!/usr/bin/env bash

test_description='Test edit'
source "$(dirname "$0")"/setup-03.sh

test_expect_success 'Test command edit.' '
    "$PW" gen test1 <<<"$PASSPHRASE" &&

    export FAKE_EDITOR_PASSWORD="fake password" &&
    export EDITOR="$SHARNESS_TEST_DIRECTORY/fake-editor.sh" &&
    "$PW" edit test1 <<<"$PASSPHRASE" &&

    local pass=$("$PW" show test1 <<<"$PASSPHRASE" | head -n 1) &&
    [[ "$pass" == "$FAKE_EDITOR_PASSWORD" ]]
'

test_done
