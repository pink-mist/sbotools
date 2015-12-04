#!/usr/bin/env bash

if [[ "$1" == "" ]]; then
	echo "usage: $(basename $0) destdir"
	exit 1
fi

DESTDIR=$1
PACKAGE="sbotools"
VERSION=$(grep '^our $VERSION' SBO-Lib/lib/SBO/Lib.pm | grep -Eo '[0-9]+(\.[0-9RC]+){0,1}')


SBO_DIR=`pwd`
TMP_DIR=$(mktemp -d "/tmp/$PACKAGE.XXXXXXXXXX")
HTML_DIR="$TMP_DIR/html"
mkdir -p $DESTDIR $HTML_DIR

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
		sed -i -r "s#http://localhost/cgi-bin/man/man2html\?([0-9])\+([^\"]+)#/$PACKAGE/documentation/\2.\1.html#g" *
		sed -i 's/j@dawnrazor.net/j_[at]_dawnrazor_[dot]_net/g' *
		sed -i 's/xocel@iquidus.org/xocel_[at]_iquidus_[dot]_org/g' *
		sed -i 's/andreas.guldstrand@gmail.com/andreas_[dot]_guldstrand_[at]_gmail_[dot]_com/g' *
		sed -i 's/<A HREF="mailto:xocel_\[at\]_iquidus_\[dot\]_org">//g' *
		sed -i 's/<A HREF="mailto:andreas_\[dot\]_guldstrand_\[at\]_gmail_\[dot\]_com">//g' *
		sed -i 's#\[dot\]_org</A>#[dot]_org#g' *
		sed -i 's#\[dot\]_com</A>#[dot]_com#g' *
		sed -i 's#<A HREF="http://localhost/cgi-bin/man/man2html">man2html</A>#man2html#g' *
		sed -i 's/^$//g' *
		sed -i 's/^<HTML><HEAD>.*$//g' *
		sed -i 's#^</HEAD><BODY>$##g' *
		sed -i 's#</BODY>##g' *
		sed -i 's#</HTML>##g' *
		for k in $(ls); do
			mv $k $k.tmp
			cat $k.tmp | awk "\$0 !~ /^$/ { print > \"$k\"; }"
			rm $k.tmp
			mv $k ..
		done
	)
	rmdir $HTML_DIR/$i
done

template() {
    SRC=$1
    TEMPLATE="$DESTDIR/template.html"
    NAME=${SRC//.?.html/}
    echo "Writing $DESTDIR/$SRC ($NAME)"
    perl -0777 -pE 's/\@TITLE\@/'$NAME'/g; s/\@MAN\@/<>/e' $TEMPLATE $SRC > $DESTDIR/$SRC
}

(cd $HTML_DIR
    for src in $(ls)
    do
        template $src
    done
)

echo "All done."
exit 0;
