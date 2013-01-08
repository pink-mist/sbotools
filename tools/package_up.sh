#!/bin/bash


if [[ "$1" == "" || "$2" == "" ]]; then
	echo "Usage: $(basename $0) package version"
	exit 1
fi

PACKAGE=$1
VERSION=$2

PKG_HOME=/home/d4wnr4z0r/projects/$PACKAGE

if [[ ! -d $PKG_HOME ]]; then
	echo "$PKG_HOME doesn't seem to exist."
	exit 1
fi

function cleanup () {
	if [[ "$1" != "" ]]; then
		rm -rf $1
	fi
}

trap "cleanup $TMP_DIR; exit 2" INT TERM EXIT

TMP_DIR=$(mktemp -d /tmp/$PACKAGE.XXXXXXXXXXXX)
PKG_DIR=$TMP_DIR/$PACKAGE-$VERSION
mkdir $PKG_DIR

for i in $(ls $PKG_HOME); do
	cp -R $PKG_HOME/$i $PKG_DIR
done

if [[ -d $PKG_DIR/t ]]; then
	rm -rf $PKG_DIR/t
fi

find $PKG_DIR -type f -name \*~ -exec rm {} \;

FILENAME=$PACKAGE-$VERSION.tar.xz

(cd $TMP_DIR
	tar cJf $FILENAME $PACKAGE-$VERSION/
	cp $FILENAME $HOME
)
(cd $HOME
	tar xf $FILENAME
)

if [[ ! -d $HOME/$PACKAGE ]]; then
	echo "Unable to find the slackbuild directory."
	cleanup $TMP_DIR
	exit 1
fi

mv $TMP_DIR/$FILENAME $HOME/$PACKAGE
OUTFILE=$PACKAGE-$VERSION.tar

(cd $HOME
	tar cf $OUTFILE $PACKAGE
)

cleanup $TMP_DIR
exit 0
