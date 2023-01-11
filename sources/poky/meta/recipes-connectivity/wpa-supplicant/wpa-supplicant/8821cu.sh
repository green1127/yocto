#!/bin/sh

emota A check
emota M check

echo "enable gpio for pfe0"
echo 23 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio23/direction
echo 0 > /sys/class/gpio/gpio23/value
echo 1 > /sys/class/gpio/gpio23/value

# load the Wi-Fi ko file
echo "load 8821cu.ko"
insmod /lib/modules/5.10.41-rt42+gb5dbd57c1cb2/kernel/drivers/net/wireless/realtek/rtl8821cu/8821cu.ko

echo "8821cu CHIP_EN"
echo 89 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio89/direction
echo 0 > /sys/class/gpio/gpio89/value
echo 1 > /sys/class/gpio/gpio89/value

echo "8821cu WL_DIS"
echo 90 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio90/direction
echo 0 > /sys/class/gpio/gpio90/value
echo 1 > /sys/class/gpio/gpio90/value

echo "8821cu done"

echo "load sja1105.ko"
insmod /lib/modules/$(uname -r)/kernel/drivers/spi/sja1105pqrs.ko

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
