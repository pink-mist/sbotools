#!/bin/bash


if [[ "$1" == "" || "$2" == "" ]]; then
	echo "Usage: $(basename $0) package version"
	exit 1
fi

PACKAGE=$1
VERSION=$2

PKG_HOME=$HOME/projects/$PACKAGE

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
SBO_DIR=$TMP_DIR/$PACKAGE
mkdir $PKG_DIR
mkdir $SBO_DIR

for i in $(ls $PKG_HOME); do
	cp -R $PKG_HOME/$i $PKG_DIR
done

if [[ -d $PKG_DIR/t ]]; then
	rm -rf $PKG_DIR/t
fi
if [[ -d $PKG_DIR/tools ]]; then
	rm -rf $PKG_DIR/tools
fi	
if [[ -d $PKG_DIR/slackbuild/$PACKAGE ]]; then
	if [[ -f $PKG_DIR/slackbuild/$PACKAGE/README ]]; then
		cp $PKG_DIR/slackbuild/$PACKAGE/README $PKG_DIR/
	fi
	mv $PKG_DIR/slackbuild/$PACKAGE/* $SBO_DIR
	rm -rf $PKG_DIR/slackbuild
	(cd $TMP_DIR
		tar cjf $PACKAGE.tar.bz2 $PACKAGE/
	)
	mv $TMP_DIR/$PACKAGE.tar.bz2 $HOME/SBo/
fi


find $TMP_DIR -type f -name \*~ -exec rm {} \;

FILENAME=$PACKAGE-$VERSION.tar.gz

(cd $TMP_DIR
	tar czf $FILENAME $PACKAGE-$VERSION/
	cp $FILENAME $HOME
)

cleanup $TMP_DIR
exit 0
