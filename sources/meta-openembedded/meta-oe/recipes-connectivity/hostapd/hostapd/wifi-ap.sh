#!/bin/sh
HELP_MSG="
usage: wifi-ap.sh [-s <ssid>] [-p <password>] [-c <channel>] [-d]\n
\t-s <ssid>\tspecify SSID\n
\t-p <password>\tspecify password for SSID\n
\t-c <channel>\tchannel for 2g or 5g\n
\t-d\t\tclose AP\n
"

SSID="testap"
SSID5G="testap5g"
PSK="12345678"
CHANNEL="2g"
ssid_is_set=0

channel=$CHANNEL

while getopts "s:p:c:dh" arg
do
    case $arg in
        s)
            ssid=$OPTARG
            ssid_is_set=1
            echo "ssid: $ssid"
            ;;
        p)
            psk=$OPTARG
            echo "psk: $psk"
            ;;
        c)
            channel=$OPTARG
            echo "channel: $channel"
            ;;
        d)
            pidof hostapd | xargs kill
            pidof udhcpd | xargs kill
            exit 0
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

echo "ssid: $ssid"
echo "psk: $psk"
echo "channel: $channel"

if [ $ssid_is_set -ne 1 ]; then
    echo "ssid is not set"

    if [ $channel = "2g" ]; then
        ssid=$SSID
    else
        ssid=$SSID5G
    fi

    psk=$PSK
fi

if [ $channel = "2g" ]; then
    echo "channel: $channel"
    conf_file="/etc/rtl_hostapd_2G.conf"
elif [ $channel = "5g" ]; then
    echo "channel: $channel"
    conf_file="/etc/rtl_hostapd_5G.conf"
else
    echo "Illegal option -c"
    echo -e $HELP_MSG
    exit 1
fi

echo "ssid: $ssid"
echo "psk: $psk"
echo "channel: $channel"
echo "conf_file: $conf_file"

sed -i "/ssid=/cssid=$ssid" $conf_file

if [ ! -n "$psk" ]; then
    echo "psk is not set"
    sed -i "/wpa=/c#wpa=" $conf_file
    sed -i "/wpa_passphrase=/c#wpa_passphrase=" $conf_file
    sed -i "/wpa_key_mgmt=/c#wpa_key_mgmt=" $conf_file
    sed -i "/wpa_pairwise=/c#wpa_pairwise=" $conf_file
else
    echo "psk is set"
    sed -i "/wpa=/cwpa=2" $conf_file
    sed -i "/wpa_passphrase=/cwpa_passphrase=$psk" $conf_file
    sed -i "/wpa_key_mgmt=/cwpa_key_mgmt=WPA-PSK" $conf_file
    sed -i "/wpa_pairwise=/cwpa_pairwise=CCMP" $conf_file    
fi

ifconfig wlan1 up
ifconfig wlan1 192.168.2.1
hostapd $conf_file -B
udhcpd /etc/udhcpd.conf
