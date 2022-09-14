#!/bin/sh
echo "8821cu CHIP_EN"
cd /sys/class/gpio/
echo 89 > export
cd gpio89
echo out > direction
echo 0 > value
echo 1 > value

echo "8821cu WL_DIS"
cd /sys/class/gpio/
echo 90 > export
cd gpio90
echo out > direction
echo 0 > value
echo 1 > value

echo "8821cu done"

COUNT_MAX=60

received="0"
count=0

while [ "$received" = "0" ]
do
    received=`ifconfig wlan0 | head -n +1 | awk '{ print $1 }'`
    echo "received: $received"

    if [ ! -n "$received" ]; then
        received="0"
        count=`expr $count + 1`
        sleep 1s
    else
        if [ "$received" = "wlan0:" ]; then
            uptime=`cat /proc/uptime | awk '{ print $1 }'`
            echo "uptime: $uptime"

            echo "wlan0 uptime: $uptime seconds" > /home/root/wlan0_uptime.log

            # /etc/init.d/wifi-sta.sh -d
            # /etc/init.d/wifi-sta.sh -s testap &
            # /etc/init.d/wlan0-uptime-test.sh &

            exit 0
        fi
    fi

    echo "count: $count"
    if [ $count -eq $COUNT_MAX ]; then
        exit 0
    fi
done
