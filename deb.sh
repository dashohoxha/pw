#!/bin/bash

tmpdir=build-deb-package
debfile=pw.deb

# Make a control file needed to create debian package
# Contains all information about the package
mkdir -p $tmpdir/DEBIAN/
cat <<EOF > $tmpdir/DEBIAN/control
Source: pw
Package: pw
Version: 1.0
Section: custom
Priority: optional
Architecture: all
Depends: bash, gnupg, git, xclip, pwgen, tree, util-linux
Maintainer: https://github.com/dashohoxha/pw
Description: A simple command-line password manager.
EOF

# Copy all the files on the build directory
make install DESTDIR=$tmpdir

# Build the package
dpkg-deb --build $tmpdir $debfile
echo -e "\nThe new package can be installed with: 'apt install -f ./$debfile' \n"

# Clean up
rm -rf $tmpdir
