#!/bin/bash
# Called by rlwrap, because it cannot call directly `read` (it is an internal bash command).

read line
echo $line
