source "$(dirname "$0")"/setup-03.sh

remove_special_chars() {
    sed 's/\x1B\[[0-9;]*[JKmsu]//g'
}


test_expect_success 'Create some test entries.' '
    cat <<-_EOF | pw set test1 &&
$PASSPHRASE
$PASS1
$PASS1
_EOF

    pwp gen test2/test3 &&

    cat <<-_EOF | pw set test2/test4 &&
$PASSPHRASE
$PASS2
$PASS2
_EOF

    cat <<-_EOF | pw set test2/test5 -m &&
$PASSPHRASE
$PASS3
second line
third line
_EOF

    pwp gen test6 &&
    pwp gen test7
'
