#!/usr/bin/env bash
# Fake editor program for testing 'pw edit'.
#
# Intended use:
#   export FAKE_EDITOR_PASSWORD="blah blah blah"
#   export EDITOR=fake-editor.sh
#   $EDITOR <password file>

[[ $# -ne 1 ]] && echo "Usage: $0 <filename>" && exit 1
filename=$1
new_password="${FAKE_EDITOR_PASSWORD:-Hello World}"
echo "$new_password" > "$filename"
exit 0
