#!/bin/sh

usage_exit() {
	echo "Usage: $(basename $0) (-g) version"
	exit 1
}

if [[ "$1" == "" ]]; then
	usage_exit
fi

if [[ "$1" == "-?" ]]; then
	usage_exit
fi

if [[ "$1" == "-h" ]]; then
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

update_perl="
	SBO-Lib/lib/SBO/Lib.pm
	SBO-Lib/lib/SBO/Lib/Util.pm
	SBO-Lib/lib/SBO/Lib/Tree.pm
	SBO-Lib/lib/SBO/Lib/Repo.pm
	SBO-Lib/lib/SBO/Lib/Readme.pm
	SBO-Lib/lib/SBO/Lib/Pkgs.pm
	SBO-Lib/lib/SBO/Lib/Info.pm
	SBO-Lib/lib/SBO/Lib/Download.pm
	SBO-Lib/lib/SBO/Lib/Build.pm
  SBO-Lib/lib/SBO/App.pm
  SBO-Lib/lib/SBO/App/Remove.pm
  SBO-Lib/lib/SBO/App/Snap.pm
"
update_other="
  SBO-Lib/README
	slackbuild/sbotools/sbotools.SlackBuild
	slackbuild/sbotools/sbotools.info
"

old_version=$(grep '^our $VERSION' SBO-Lib/lib/SBO/Lib.pm | grep -Eo '[0-9]+(\.[0-9RC@gita-f]+){0,1}')

tmpfile=$(mktemp /tmp/XXXXXXXXXX)

for i in $update_other; do
	cat $i | sed "s/$old_version/$version/g" > $tmpfile
	if [[ "$?" == "0" ]]; then
		mv $tmpfile $i
	fi
done

for i in $update_perl; do
  cat $i | sed "s/'$old_version'/'$version'/g" > $tmpfile
  if [[ "$?" == "0" ]]; then
    mv $tmpfile $i
  fi
done
