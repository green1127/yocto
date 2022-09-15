#!/bin/sh
HELP_MSG="
usage: wifi-sta.sh [-s <ssid>] [-p <password>] [-d]\n
\t-s <ssid>\tspecify SSID\n
\t-p <password>\tspecify password for SSID\n
\t-d\t\tclose STA\n
"

SSID="testap"
PSK="12345678"
ssid_is_set=0

while getopts "s:p:dh" arg
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
        d)
            pidof wpa_supplicant | xargs kill
            pidof udhcpc | xargs kill
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
echo "ssid_is_set: $ssid_is_set"

if [ $ssid_is_set -ne 1 ]; then
    echo "ssid is not set"
    ssid=$SSID
    psk=$PSK
fi

echo "ssid: $ssid"
echo "psk: $psk"

ssid_param=\'\"$ssid\"\'
echo "ssid_param: $ssid_param"

psk_param=\'\"$psk\"\'
echo "psk_param: $psk_param"

wpa_supplicant -Dnl80211 -iwlan0 -c /etc/wpa_0_8.conf -B
wpa_cli -p/var/run/wpa_supplicant add_network
sh -c "wpa_cli -p/var/run/wpa_supplicant set_network 0 ssid $ssid_param"

if [ ! -n "$psk" ]; then
    echo "psk is not set"
    wpa_cli -p/var/run/wpa_supplicant set_network 0 key_mgmt NONE
else
    echo "psk is set"
    wpa_cli -p/var/run/wpa_supplicant set_network 0 key_mgmt WPA-PSK
    sh -c "wpa_cli -p/var/run/wpa_supplicant set_network 0 psk $psk_param"
fi

wpa_cli -p/var/run/wpa_supplicant select_network 0
udhcpc -i wlan0 -R
/etc/init.d/route-default-gw.sh -i wlan0
