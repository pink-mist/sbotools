#!/bin/bash
mkdir -p /var/log/packages
cp -a t/travis-deps/*pkg /sbin/
echo "127.0.0.1 slackware.uk" >> /etc/hosts

if [ "$TEST_MULTILIB" = "1" ]
then
	mkdir -p /etc/profile.d/
	touch /etc/profile.d/32dev.sh
elif [ "$TEST_MULTILIB" = "2" ]
then
	mkdir -p /etc/profile.d/ /usr/sbin/
	touch /etc/profile.d/32dev.sh
	cp -a t/travis-deps/convertpkg-compat32 /usr/sbin
fi
