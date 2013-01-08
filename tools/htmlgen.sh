#!/usr/bin/env bash

if [[ "$1" == "" || "$2" == "" ]]; then
	echo "usage: $(basename $0) package version"
	exit 1
fi

PACKAGE=$1
VERSION=$2

if [[ ! -d $HOME/$PACKAGE-$VERSION ]]; then
	echo "I do not see the $PACKAGE-$VERSION directory."
	exit 1
fi

SBO_DIR="$HOME/$PACKAGE-$VERSION"
HTML_DIR="$HOME/html_man/$PACKAGE-$VERSION"
mkdir -p $HTML_DIR

for i in $(ls $SBO_DIR | grep '^man'); do
	mkdir -p $HTML_DIR/$i
	( cd $SBO_DIR/$i
		for j in $(ls); do
			man2html $j > $j.html
			mv $j.html $HTML_DIR/$i/
		done
	)
	( cd $HTML_DIR/$i
		sed -i 's/^Content-type.*$//g' *
		sed -i 's/^<A HREF.*Return to Main.*$//g' *
		sed -i -r "s#http://localhost/cgi-bin/man/man2html\?([0-9])\+([^\"]+)#/$PACKAGE/documentation/\2\1#g" *
		sed -i 's/j@dawnrazor.net/j_[at]_dawnrazor_[dot]_net/g' *
		sed -i 's/xocel@iquidus.org/xocel_[at]_iquidus_[dot]_org/g' *
		sed -i 's/<A HREF="mailto:xocel_\[at\]_iquidus_\[dot\]_org">//g' *
		sed -i 's#\[dot\]_org</A>#[dot]_org#g' *
		sed -i 's#<A HREF="http://localhost/cgi-bin/man/man2html">man2html</A>#man2html#g' *
		sed -i 's/^$//g' *
		sed -i 's/^<HTML><HEAD>.*$//g' *
		sed -i 's#^</HEAD><BODY>$##g' *
		for k in $(ls); do
			mv $k $k.tmp
			cat $k.tmp | awk "\$0 !~ /^$/ { print > \"$k\"; }"
			rm $k.tmp
		done
	)
done

echo "All done."
exit 0;
