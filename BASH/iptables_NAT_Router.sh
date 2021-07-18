#!/bin/bash
# This script will effectively make your machine a NAT Router if you have multiple interfaces
# Tested under Ubuntu and Raspbian
# D. Marx (derco0n), 2021/07

# Internal device
INTERNAL=wlan1

# External device
EXTERNAL=wlan0

# Enable forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

#Forward outgoing traffic
iptables -A FORWARD -i $INTERNAL -o $EXTERNAL -j ACCEPT

# Forward already established, incoming connections
iptables -A FORWARD -i $EXTERNAL -o $INTERNAL -m state --state ESTABLISHED,RELATED -j ACCEPT

# NAT all outgoing connections
iptables -t nat -A POSTROUTING -o $EXTERNAL -j MASQUERADE
