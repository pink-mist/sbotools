#!/bin/sh

usage_exit() {
	echo "Usage: $(basename $0) (-g) version"
	exit 1
}

if [[ "$1" == "" ]]; then
	usage_exit
fi

if [[ "$1" == "-g" ]]; then
	git=true
	shift
fi

if [[ "$1" == "" ]]; then
	usage_exit
fi

version="$1"

update="
	SBO-Lib/lib/SBO/Lib.pm
	slackbuild/sbotools/sbotools.SlackBuild
	slackbuild/sbotools/sbotools.info
"

old_version=$(grep '^our $VERSION' SBO-Lib/lib/SBO/Lib.pm | grep -Eo '[0-9]+(\.[0-9RC]+){0,1}')

tmpfile=$(mktemp /tmp/XXXXXXXXXX)

for i in $update; do
	cat $i | sed "s/$old_version/$version/g" > $tmpfile
	if [[ "$?" == "0" ]]; then
		mv $tmpfile $i
	fi
done
