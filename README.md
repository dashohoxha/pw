
Simple Password Manager
=======================

This is a simple password manager that keeps passwords inside a
**gpg** encrypted **tgz** archive. The content of the archive is a
directory tree with a file for each password entry.  The first line of
the file is the password, and the rest can optionally be additional or
related info. It provides commands for manipulating the passwords,
allowing the user to add, remove, edit, generate passwords etc.

Please see the man page for documentation and examples:
http://dashohoxha.github.io/pw/man/

It started by forking **[pass](http://www.passwordstore.org/)**.

Depends on:
- [bash](http://www.gnu.org/software/bash/)
- [GnuPG2](http://www.gnupg.org/)
- [git](http://www.git-scm.com/)
- [xclip](http://sourceforge.net/projects/xclip/)
- [pwgen](http://sourceforge.net/projects/pwgen/)
- [tree](http://mama.indstate.edu/users/ice/tree/) >= 1.7.0
- [GNU getopt](http://software.frodo.looijaard.name/getopt/)
- ed (used by tests)

To install simply type: `make`
