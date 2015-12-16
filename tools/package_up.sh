#!/bin/bash

PACKAGE="sbotools"
VERSION=$(grep '^our $VERSION' SBO-Lib/lib/SBO/Lib.pm | grep -Eo '[0-9]+(\.[0-9RC]+){0,1}')
FILENAME=$PACKAGE-$VERSION.tar.gz

echo "Making package for $PACKAGE-$VERSION." \
    "Press enter to continue or Ctrl+C to abort."
read

PKG_HOME=`pwd`

cleanup() {
	if [[ "$1" != "" ]]; then
		rm -rf $1
	fi
}

update_info() {
    INFO=$1
    MD5=$(md5sum $PKG_HOME/$FILENAME | cut -d' ' -f1)
    sed -i -e "s/@FILENAME@/$FILENAME/" $INFO
    sed -i -e "s/@MD5@/$MD5/" $INFO
}

TMP_DIR=$(mktemp -d /tmp/$PACKAGE.XXXXXXXXXXXX)
PKG_DIR=$TMP_DIR/$PACKAGE-$VERSION
SBO_DIR=$TMP_DIR/$PACKAGE
mkdir $PKG_DIR
mkdir $SBO_DIR

for i in $(ls $PKG_HOME); do
	cp -R $PKG_HOME/$i $PKG_DIR
done

for remove in t tools README.md TODO; do
	if [[ -e $PKG_DIR/$remove ]]; then
		rm -rf $PKG_DIR/$remove
	fi
done
if [[ -d $PKG_DIR/slackbuild/$PACKAGE ]]; then
	if [[ -f $PKG_DIR/slackbuild/$PACKAGE/README ]]; then
		cp $PKG_DIR/slackbuild/$PACKAGE/README $PKG_DIR/
	fi
	mv $PKG_DIR/slackbuild/$PACKAGE/* $SBO_DIR
	rm -rf $PKG_DIR/slackbuild
fi


find $TMP_DIR -type f -name \*~ -exec rm {} \;

(cd $TMP_DIR
	tar cvzf $FILENAME $PACKAGE-$VERSION/
	cp $FILENAME $PKG_HOME
)
(cd $TMP_DIR
    update_info "$PACKAGE/$PACKAGE.info"
	tar cjf $PACKAGE.tar.bz2 $PACKAGE/
)
mv $TMP_DIR/$PACKAGE.tar.bz2 $PKG_HOME

cleanup $TMP_DIR
exit 0
