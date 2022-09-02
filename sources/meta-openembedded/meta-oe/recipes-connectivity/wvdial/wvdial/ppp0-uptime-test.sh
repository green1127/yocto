#!/bin/sh
COUNT_MAX=60

received="0"
count=0

while [ "$received" = "0" ]
do
    received=`ping -I ppp0 -c 1 114.114.114.114 | grep received | awk '{ print $4 }'`
    echo "received: $received"

    if [ ! -n "$received" ]; then
        received="0"
        count=`expr $count + 1`
        sleep 1s
    else
        if [ "$received" = "1" ]; then
            uptime=`cat /proc/uptime | awk '{ print $1 }'`
            echo "uptime: $uptime"

            echo "ppp0 connected time: $uptime seconds" > /home/root/ppp0_connected_time.log
            exit 0
        fi
    fi

    echo "count: $count"
    if [ $count -eq $COUNT_MAX ]; then
        exit 0
    fi
done
