#!/usr/bin/bash

# set DISTCLEAN TRUE to preserve space
sboconfig -d TRUE

SBOS=$(find /usr/sbo -type f -iname \*.info | sed -r 's|.*/([^/]+)\.info$|\1|g');

TLOG=~/tmp.log
FLOG=~/fail.log
ILOG=~/install.log
RLOG=~/remove.log

# zero out logs in case they have content from previous run
:> $FLOG
:> $ILOG
:> $RLOG

function build_things() {
	if [ ! -z $1 ]; then
		. /usr/sbo/*/$1/$1.info
		for i in $REQUIRES; do
			if [[ "$i" != "%README%" ]]; then
				build_things $i
			fi
		done
		echo "=============" > $TLOG
		echo "sboupgrade -oNr $1" >> $TLOG
		sboupgrade -oNr $i >> $TLOG 2>&1
		if [[ $? != "0" ]]; then
			echo "" >> $FLOG
			cat $TLOG >> $FLOG
		fi
		echo "" >> $ILOG
		cat $TLOG >> $ILOG
		:> $TLOG
	else
		echo "build_things() requires an argument."
		exit 1
	fi
}

function remove_things() {
	if [ ! -z $1 ]; then
		echo "=============" > $TLOG
		echo "sboremove --nointeractive $1" >> $TLOG
		sboremove --nointeractive $1 >> $TLOG 2>&1
		if [[ $? != 0 ]]; then
			echo "" >> $FLOG
			cat $TLOG >> $FLOG
		fi
		echo "" >> $RLOG
		cat $TLOG >> $RLOG
		:> $TLOG
	fi
}

for i in $SBOS; do
	echo $i
	build_things $i
	remove_things $i
	removepkg $(ls /var/log/packages|grep SBo) > /dev/null 2>&1
done

exit 0
