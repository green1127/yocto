#!/bin/sh
HELP_MSG="
usage: route-default-gw.sh -i <interface>\n
\tinterface: ppp0, wlan0
"

interface=

while getopts "i:h" arg
do
    case $arg in
        i)
            interface=$OPTARG
            ;;
        h)
            echo -e $HELP_MSG
            exit 1
            ;;
        ?)
            echo -e $HELP_MSG
            exit 1
            ;;
    esac
done

if [ "$interface" = "ppp0" ]; then
    ifconfig $interface | awk '/[0-9]+\.[0-9]+\.[0-9]+\./ {print $2}' | xargs route del default gw
    ifconfig $interface | awk '/[0-9]+\.[0-9]+\.[0-9]+\./ {print $2}' | xargs route add default gw
    exit 0
fi

if [ "$interface" = "wlan0" ]; then
    ifconfig $interface | awk '/[0-9]+\.[0-9]+\.[0-9]+\./ {print $2}' | xargs route del default gw
    ifconfig $interface | awk '/[0-9]+\.[0-9]+\.[0-9]+\./ {print $2}' | xargs route add default gw
    exit 0
fi

echo "Illegal option -i"
echo -e $HELP_MSG
