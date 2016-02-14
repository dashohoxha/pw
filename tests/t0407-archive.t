#!/usr/bin/env bash

test_description='Working with archives.'
source "$(dirname "$0")"/setup-04.sh

test_expect_success 'Copy default archive to test-archive.' '
    cp "$PW_DIR/pw.tgz.gpg" "$PW_DIR/test-archive.tgz.gpg" &&
    [[ "$(pwp ls)" == "$(pwp -a test-archive ls)" ]]
'

test_expect_success 'Move test-archive to another directory.' '
    local PW_DIR_1="$PW_DIR/test-dir" &&
    mkdir -p "$PW_DIR_1" &&
    mv "$PW_DIR/test-archive.tgz.gpg" "$PW_DIR_1/" &&
    [[ "$(pwp ls)" != "$(pwp -a test-archive ls)" ]] &&
    [[ "$(pwp ls)" == "$(PW_DIR="$PW_DIR_1" pwp -a test-archive ls)" ]]
'

test_done
