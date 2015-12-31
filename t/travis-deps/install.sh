#!/bin/bash
mkdir -p /var/log/packages
cp -a t/travis-deps/*pkg /sbin/
echo "127.0.0.1 slackware.uk" >> /etc/hosts
