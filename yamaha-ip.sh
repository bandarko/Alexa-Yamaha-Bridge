#!/bin/bash

# Yamaha receiver identity.
# Replace these values with your own receiver's MAC address and device_id.
MAC="ac:44:f2:85:b5:44"
DEVICE_ID="AC44F285B544"
CACHE="/tmp/yamaha-ip"

check_ip() {
    local ip="$1"
    [ -n "$ip" ] || return 1

    local info
    info=$(curl -fsS --connect-timeout 1 --max-time 2 \
        "http://${ip}/YamahaExtendedControl/v1/system/getDeviceInfo" 2>/dev/null) || return 1

    echo "$info" | grep -qi "$DEVICE_ID"
}

# 1. Try the last known address first.
if [ -f "$CACHE" ]; then
    IP=$(cat "$CACHE")
    if check_ip "$IP"; then
        echo "$IP"
        exit 0
    fi
fi

# 2. Look for the Yamaha MAC address in the local neighbour/ARP table.
IP=$(ip neigh 2>/dev/null | awk -v mac="$MAC" 'tolower($0) ~ tolower(mac) {print $1; exit}')
if check_ip "$IP"; then
    echo "$IP" > "$CACHE"
    echo "$IP"
    exit 0
fi

# 3. Populate the neighbour table with a quick parallel ping sweep.
# Change 192.168.1 if your LAN uses a different /24 subnet.
for i in $(seq 1 254); do
    ping -c 1 -W 1 "192.168.1.$i" >/dev/null 2>&1 &
done
wait

IP=$(ip neigh 2>/dev/null | awk -v mac="$MAC" 'tolower($0) ~ tolower(mac) {print $1; exit}')
if check_ip "$IP"; then
    echo "$IP" > "$CACHE"
    echo "$IP"
    exit 0
fi

exit 1
