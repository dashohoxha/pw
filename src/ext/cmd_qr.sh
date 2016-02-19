cmd_qr() {
    cmd_show "$@" | head -n 2 | qrencode --size=10 -o - | display
}
