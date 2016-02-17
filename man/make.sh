#!/bin/bash

cd $(dirname $0)
export RONN_STYLE="$(pwd)"
ronn --manual="Password Manager" \
     --organization="dashohoxha" \
     --style="toc,80c,dark" \
     pw.1.ronn
