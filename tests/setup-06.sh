source "$(dirname "$0")"/setup-05.sh

# We don't want any currently running agent to conflict.
unset GPG_AGENT_INFO

# Keys used for testing (they are unencrypted).
KEY1="CF90C77B"
KEY2="D774A374"
KEY3="EB7D54A8"
KEY4="E4691410"
KEY5="39E5020C"
