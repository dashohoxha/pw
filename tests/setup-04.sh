source "$(dirname "$0")"/setup-03.sh

remove_special_chars() {
    sed 's/\x1B\[[0-9;]*[JKmsu]//g'
}


test_expect_success 'Create some test entries.' '
    "$PW" set test1 <<-_EOF &&
$PASSPHRASE
$PASS1
$PASS1
_EOF

    "$PW" gen test2/test3 <<<"$PASSPHRASE" &&

    "$PW" set test2/test4 <<-_EOF &&
$PASSPHRASE
$PASS2
$PASS2
_EOF

    "$PW" set test2/test5 -m <<-_EOF &&
$PASSPHRASE
$PASS3
second line
third line
_EOF

    "$PW" gen test6 <<<"$PASSPHRASE" &&
    "$PW" gen test7 <<<"$PASSPHRASE"
'
