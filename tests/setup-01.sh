# This file should be sourced by all test-scripts

cd "$(dirname "$0")"
source ./sharness.sh

PW="$(dirname $SHARNESS_TEST_DIRECTORY)/src/pw.sh"
[[ ! -x $PW ]] && echo "Could not find pw.sh" &&  exit 1

export PW_DIR="$SHARNESS_TRASH_DIRECTORY/.pw"
rm -rf "$PW_DIR" ; mkdir -p "$PW_DIR"
[[ ! -d $PW_DIR ]] && echo "Could not create $PW_DIR" && exit 1

pw() {
    "$PW" "$@"
}
