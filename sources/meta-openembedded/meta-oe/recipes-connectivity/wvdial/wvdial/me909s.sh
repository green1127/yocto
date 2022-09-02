#!/bin/sh
wvdial hw1 &
/etc/init.d/ppp0-uptime-test.sh &
