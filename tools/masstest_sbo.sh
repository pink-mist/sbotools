#!/usr/bin/bash

# set DISTCLEAN TRUE to preserve space
sboconfig -d TRUE
# clear out work directories and distfiles
sboclean -dw

SBOS=$(find /usr/sbo -type f -iname \*.info | sed -r 's|.*/([^/]+)\.info$|\1|g');

TLOG=~/tmp.log
ILOG=~/install.log
RLOG=~/remove.log

# zero out logs in case they have content from previous run
:> $ILOG
:> $RLOG

for i in build md5sum wget noinfo nomulti else; do
	:> ~/$i.fail.log
done

function build_things() {
	if [ ! -z $1 ]; then
		. /usr/sbo/*/$1/$1.info
		for i in $REQUIRES; do
			if [[ "$i" != "%README%" ]]; then
				build_things $i
			fi
		done
		echo "=============" > $TLOG
		echo "sboinstall -r $1" >> $TLOG
		sboinstall -r $1 >> $TLOG 2>&1
		case "$?" in
			"0") OLOG="" ;;
			"3") OLOG=~/build.fail.log ;;
			"4") OLOG=~/md5sum.fail.log ;;
			"5") OLOG=~/wget.fail.log ;;
			"7") OLOG=~/noinfo.fail.log ;;
			"9") OLOG=~/nomulti.fail.log ;;
			*) OLOG=~/else.fail.log
		esac
		if [[ "$OLOG" != "" ]]; then
			if ! grep -q "^$1 added to install queue.$" $OLOG; then
				echo "" >> $OLOG
				cat $TLOG >> $OLOG
			fi
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
