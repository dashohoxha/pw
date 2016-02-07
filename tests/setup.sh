# This file should be sourced by all test-scripts
#
# This scripts sets the following:
#   $PW         Full path to password-store script to test
#   $GPG        Name of gpg executable
#   $KEY{1..5}  GPG key ids of testing keys
#   $TEST_HOME  This folder


cd "$(dirname "$0")"
TESTS="$(pwd -P)"
PW="$(dirname $TESTS)/src/pw.sh"

source ./sharness.sh

export PW_DIR="$(pwd -P)/.pw"
rm -rf "$PW_DIR"
mkdir -p "$PW_DIR"
if [[ ! -d $PW_DIR ]]; then
    echo "Could not create $PW_DIR"
    exit 1
fi

PASSPHRASE='0123456789'

#git config --global user.email "dashohoxha+wp-test@gmail.com"
#git config --global user.name "PW Testing Suite"

if [[ ! -e $PW ]]; then
    echo "Could not find pw.sh"
    exit 1
fi

## Note: the assumption is the test key is unencrypted.
#export GNUPGHOME="$TESTS/gnupg/"
#chmod 700 "$GNUPGHOME"
#GPG="gpg"
#which gpg2 &>/dev/null && GPG="gpg2"

## We don't want any currently running agent to conflict.
#unset GPG_AGENT_INFO

#KEY1="CF90C77B"  # pass test key 1
#KEY2="D774A374"  # pass test key 2
#KEY3="EB7D54A8"  # pass test key 3
#KEY4="E4691410"  # pass test key 4
#KEY5="39E5020C"  # pass test key 5
