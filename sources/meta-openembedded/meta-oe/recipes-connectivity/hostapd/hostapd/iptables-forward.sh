#!/bin/sh
iptables -t nat -A POSTROUTING -o ppp0 -j MASQUERADE
iptables -A FORWARD -i ppp0 -o wlan1 -j ACCEPT
iptables -A FORWARD -i wlan1 -o ppp0 -j ACCEPT
echo 1 > /proc/sys/net/ipv4/ip_forward
