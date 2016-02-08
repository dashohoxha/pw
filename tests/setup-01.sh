# This file should be sourced by all test-scripts

cd "$(dirname "$0")"
TESTS="$(pwd -P)"

PW="$(dirname $TESTS)/src/pw.sh"
[[ ! -e $PW ]] && echo "Could not find pw.sh" &&  exit 1

source ./sharness.sh

export PW_DIR="$(pwd -P)/.pw"
rm -rf "$PW_DIR"
mkdir -p "$PW_DIR"
[[ ! -d $PW_DIR ]] && echo "Could not create $PW_DIR" && exit 1
