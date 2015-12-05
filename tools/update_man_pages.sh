#!/bin/sh

usage_exit() {
	echo "Usage: $(basename $0) (-d) (-g)"
	exit 1
}

if [[ "$1" == "-h" ]]; then
	usage_exit
fi

if [[ "$1" == "-?" ]]; then
	usage_exit
fi

if [[ "$1" == "-d" ]]; then
	date=true
	shift
fi

if [[ "$1" == "-g" ]]; then
	git=true
	shift
fi

version=$(grep '^our $VERSION' SBO-Lib/lib/SBO/Lib.pm | grep -Eo '[0-9]+(\.[0-9RC]+){0,1}')

if ! [[ -d "./man1" ]]; then
	echo "you do not seem to be at the right place to run this."
	echo "the man{1,5}/ directories should be under ."
	exit 1
fi

old_version=$(head -1 man1/sbocheck.1 | rev | cut -d' ' -f2 | rev \
	| sed 's/"//g')

tmpfile=$(mktemp /tmp/XXXXXXXXX)

sed_file() {
	if [[ "$1" == "" || "$2" == "" ]]; then
		echo "sed_file(): two arguments required."
		exit 1
	fi

	file="$1"
	sed_cmd="$2"

	cat $file | sed "$sed_cmd" > $tmpfile
	if [[ "$?" == "0" ]]; then
		mv $tmpfile $file
	else
		return 1
	fi

	return 0
}

for i in $(ls man1); do
	sed_file man1/$i "s/$old_version/$version/g"
done

for i in $(ls man5); do
	sed_file man5/$i "s/$old_version/$version/g"
done

if [[ "$?" == "0" ]]; then
	echo "version updated."
fi

update_date() {
	if ! which ddate >/dev/null 2>&1; then
		echo "I can't find ddate."
		return 1
	fi

	old_date=$(head -1 man1/sbocheck.1 | cut -d' ' -f4- | rev \
		| cut -d' ' -f4- | rev | sed 's/"//g')

	new_date=$(ddate +"%{%A, %B %d%}, %Y YOLD")

	for i in man1/*; do
		sed_file $i "s/$old_date/$new_date/g"
	done

	for i in man5/*; do
		sed_file $i "s/$old_date/$new_date/g"
	done

	if [[ "$?" == "0" ]]; then
		echo "date updated."
	else
		return 1
	fi

	return 0
}

update_git() {
	if ! which git >/dev/null 2>&1; then
		echo "I can't find git."
		return 1
	fi

	if [[ "$date" == "true" ]]; then
		extra=" and dates"
	fi

	git add man1/* man5/*
	git commit -m "updated versions$extra for man pages"
	git push

	if [[ "$?" == "0" ]]; then
		echo "git updated."
	else
		return 1
	fi

	return 0
}

if [[ "$date" == "true" ]]; then
	update_date
	date_return=$?
fi

if [[ "$git" == "true" ]]; then
	update_git
	git_return=$?
fi

if [[ "$date_return" != "0" || "$git_return" != "0" ]]; then
	exit 1
fi

exit 0
