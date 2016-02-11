source "$(dirname "$0")"/setup-03.sh

remove_special_chars() {
    sed 's/\x1B\[[0-9;]*[JKmsu]//g'
}


test_expect_success 'Create some test entries.' '
    pw set test1 <<-_EOF &&
$PASSPHRASE
$PASS1
$PASS1
_EOF

    pwp gen test2/test3 &&

    pw set test2/test4 <<-_EOF &&
$PASSPHRASE
$PASS2
$PASS2
_EOF

    pw set test2/test5 -m <<-_EOF &&
$PASSPHRASE
$PASS3
second line
third line
_EOF

    pwp gen test6 &&
    pwp gen test7
'
